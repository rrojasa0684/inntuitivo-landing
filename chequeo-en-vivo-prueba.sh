#!/usr/bin/env bash
# Prueba de chequeo-en-vivo.sh contra un sitio local de juguete (python3 -m http.server): el caso sano pasa y cada falla que el chequeo promete detectar, falla.
set -euo pipefail
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"; PID=""
trap '[ -n "$PID" ] && kill "$PID" 2>/dev/null || true; rm -rf "$TMP"' EXIT
PUERTO=0
export CHEQUEO_NAVEGADOR=no   # el sitio de juguete no es la portada real; el navegador se prueba aparte, más abajo
sitio() {   # sitio <carpeta>: sano por defecto (el sitemap se arma en servir(), cuando ya se sabe el puerto)
    mkdir -p "$1"
    printf '<a href="/privacidad.html">p</a> <h3>2 · Cómo llega</h3><summary>Ver las fuentes</summary> <a href="onboarding.html">o</a> <a href="https://x.example/f">fuera</a> <a href="mailto:a@b.c">m</a>' > "$1/index.html"
    printf 'ok' > "$1/privacidad.html"; printf 'ok' > "$1/onboarding.html"; printf 'ok' > "$1/cancelar.html"
    printf '<urlset><url><loc>http://127.0.0.1:PUERTO/</loc></url><url><loc>http://127.0.0.1:PUERTO/privacidad.html</loc></url></urlset>' > "$1/sitemap.xml"
    printf 'User-agent: *\nAllow: /\n' > "$1/robots.txt"
}
servir() {   # un puerto nuevo por caso; el sitemap lleva PUERTO como marcador
    [ -n "$PID" ] && kill "$PID" 2>/dev/null || true
    PUERTO=$((20000 + RANDOM % 20000))
    if [ -f "$1/sitemap.xml" ]; then sed -i.bak "s/PUERTO/$PUERTO/g" "$1/sitemap.xml"; rm -f "$1/sitemap.xml.bak"; fi
    python3 -m http.server "$PUERTO" --bind 127.0.0.1 --directory "$1" >/dev/null 2>&1 &
    PID=$!; sleep 1
}
espera() {   # espera <ok|falla> <texto que debe aparecer> <carpeta>
    servir "$3"
    if salida="$(bash "$AQUI/chequeo-en-vivo.sh" "http://127.0.0.1:$PUERTO" 2>&1)"; then rc=0; else rc=1; fi
    if [ "$1" = ok ] && [ "$rc" = 0 ] && grep -q CHEQUEO_EN_VIVO_OK <<<"$salida"; then echo "ok: $2"; return; fi
    if [ "$1" = falla ] && [ "$rc" = 1 ] && grep -q "$2" <<<"$salida"; then echo "ok: falla como debe ($2)"; return; fi
    echo "FALLO la prueba ($1 / $2):"; echo "$salida"; exit 1
}
sitio "$TMP/sano";                                                        espera ok "sitio sano" "$TMP/sano"
sitio "$TMP/cifras"; printf '<a href="/privacidad.html">p</a> <summary>Ver las fuentes</summary> <h4>Cifras públicas de terceros</h4>' > "$TMP/cifras/index.html"; espera falla "la portada publicada trae «Cifras públicas de terceros»" "$TMP/cifras"
sitio "$TMP/dedonde"; printf '<a href="/privacidad.html">p</a> <summary>Ver las fuentes</summary> <th>De dónde sale el decisor</th>' > "$TMP/dedonde/index.html"; espera falla "la portada publicada trae «De dónde sale el decisor»" "$TMP/dedonde"
sitio "$TMP/sinfuentes"; printf '<a href="/privacidad.html">p</a>' > "$TMP/sinfuentes/index.html"; espera falla "la portada publicada no trae «Ver las fuentes»" "$TMP/sinfuentes"
# con navegador (solo si hay Playwright): una tabla dibujada por JavaScript, como la vieja, no se ve con curl y el navegador sí la caza
if [ -d "$AQUI/node_modules/playwright" ]; then
    sitio "$TMP/js"; printf '<meta charset="utf-8"><a href="/privacidad.html">p</a> <summary>Ver las fuentes</summary><div id="t"></div><script>document.getElementById("t").textContent="Cifras "+"públicas de terceros"</script>' > "$TMP/js/index.html"
    servir "$TMP/js"
    if salida="$(CHEQUEO_NAVEGADOR=si bash "$AQUI/chequeo-en-vivo.sh" "http://127.0.0.1:$PUERTO" 2>&1)"; then echo "FALLO: el navegador no cazó la tabla dibujada por JavaScript"; echo "$salida"; exit 1; fi
    grep -q "el sitio publicado muestra «Cifras públicas de terceros»" <<<"$salida" && echo "ok: falla como debe (tabla dibujada por JavaScript, con navegador)" || { echo "FALLO: otra razón"; echo "$salida"; exit 1; }
fi
sitio "$TMP/roto"; printf '<a href="/no-existe.html">x</a>' > "$TMP/roto/index.html"; espera falla "enlace roto" "$TMP/roto"
sitio "$TMP/retirada"; printf 'ok' > "$TMP/retirada/activar.html";            espera falla "activar.html debería dar 404" "$TMP/retirada"
sitio "$TMP/paddle"; printf 'Pago procesado por Paddle' > "$TMP/paddle/privacidad.html"; espera falla "menciona una página o proveedor retirado" "$TMP/paddle"
sitio "$TMP/sin200"; rm "$TMP/sin200/cancelar.html";                       espera falla "cancelar.html responde 404" "$TMP/sin200"
sitio "$TMP/mapa"; printf '<urlset><url><loc>http://127.0.0.1:PUERTO/activar.html</loc></url></urlset>' > "$TMP/mapa/sitemap.xml"; espera falla "sitemap" "$TMP/mapa"
sitio "$TMP/sinmapa"; rm "$TMP/sinmapa/sitemap.xml";                       espera falla "sitemap.xml responde 404" "$TMP/sinmapa"
sitio "$TMP/sinrobots"; rm "$TMP/sinrobots/robots.txt";                    espera falla "robots.txt responde 404" "$TMP/sinrobots"
sitio "$TMP/vacio"; printf '<urlset></urlset>' > "$TMP/vacio/sitemap.xml"; espera falla "el sitemap no trae ninguna dirección" "$TMP/vacio"
# 15-nov-2026: un 5xx pasajero de Pages se reintenta (3 veces, espera creciente); un 4xx no. Servidor de juguete que contesta 503 las primeras K veces que le piden una ruta y cuenta los pedidos de cada ruta.
cat > "$TMP/servidor503.py" <<'PYEOF'
import http.server, sys, os, collections
carpeta, puerto, ruta, k = sys.argv[1], int(sys.argv[2]), sys.argv[3], int(sys.argv[4])
hits = collections.Counter()
class H(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw): super().__init__(*a, directory=carpeta, **kw)
    def do_GET(self):
        hits[self.path] += 1
        open(os.path.join(carpeta, "..", "hits.txt"), "w").write("\n".join(f"{p} {n}" for p, n in hits.items()))
        if self.path == ruta and hits[self.path] <= k:
            self.send_response(503); self.end_headers(); return
        super().do_GET()
    def log_message(self, *a): pass
http.server.HTTPServer(("127.0.0.1", puerto), H).serve_forever()
PYEOF
servir503() {   # servir503 <carpeta> <ruta> <K>
    [ -n "$PID" ] && kill "$PID" 2>/dev/null || true
    PUERTO=$((20000 + RANDOM % 20000)); rm -f "$TMP/hits.txt"
    sed -i.bak "s/PUERTO/$PUERTO/g" "$1/sitemap.xml"; rm -f "$1/sitemap.xml.bak"
    python3 "$TMP/servidor503.py" "$1" "$PUERTO" "$2" "$3" >/dev/null 2>&1 &
    PID=$!; sleep 1
}
export CHEQUEO_ESPERA=0
sitio "$TMP/r503"; servir503 "$TMP/r503" /privacidad.html 2
if salida="$(bash "$AQUI/chequeo-en-vivo.sh" "http://127.0.0.1:$PUERTO" 2>&1)" && grep -q CHEQUEO_EN_VIVO_OK <<<"$salida"; then echo "ok: un 503 que se recupera no falla el chequeo"; else echo "FALLO la prueba (503 que se recupera):"; echo "$salida"; exit 1; fi
sitio "$TMP/p503"; servir503 "$TMP/p503" /privacidad.html 99
if salida="$(bash "$AQUI/chequeo-en-vivo.sh" "http://127.0.0.1:$PUERTO" 2>&1)"; then echo "FALLO la prueba: un 503 permanente no debía pasar"; exit 1; fi
grep -q "privacidad.html responde 503" <<<"$salida" && echo "ok: un 503 permanente falla tras los reintentos" || { echo "FALLO la prueba (503 permanente):"; echo "$salida"; exit 1; }
sitio "$TMP/h404"; printf '<a href="/no-existe.html">x</a>' > "$TMP/h404/index.html"; servir503 "$TMP/h404" /nada 0
bash "$AQUI/chequeo-en-vivo.sh" "http://127.0.0.1:$PUERTO" >/dev/null 2>&1 && { echo "FALLO la prueba: un enlace roto debía fallar"; exit 1; }
[ "$(grep '^/no-existe.html ' "$TMP/hits.txt" | cut -d' ' -f2)" = 1 ] && echo "ok: un 404 no se reintenta (un solo pedido)" || { echo "FALLO la prueba: el 404 se reintentó"; cat "$TMP/hits.txt"; exit 1; }
echo CHEQUEO_EN_VIVO_PRUEBA_OK
