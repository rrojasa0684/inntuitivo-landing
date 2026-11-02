#!/usr/bin/env bash
# Prueba de chequeo-en-vivo.sh contra un sitio local de juguete (python3 -m http.server): el caso sano pasa y cada falla que el chequeo promete detectar, falla.
set -euo pipefail
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"; PID=""
trap '[ -n "$PID" ] && kill "$PID" 2>/dev/null || true; rm -rf "$TMP"' EXIT
PUERTO=0
sitio() {   # sitio <carpeta>: sano por defecto (el sitemap se arma en servir(), cuando ya se sabe el puerto)
    mkdir -p "$1"
    printf '<a href="/privacidad.html">p</a> <a href="onboarding.html">o</a> <a href="https://x.example/f">fuera</a> <a href="mailto:a@b.c">m</a>' > "$1/index.html"
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
sitio "$TMP/roto"; printf '<a href="/no-existe.html">x</a>' > "$TMP/roto/index.html"; espera falla "enlace roto" "$TMP/roto"
sitio "$TMP/retirada"; printf 'ok' > "$TMP/retirada/activar.html";            espera falla "activar.html debería dar 404" "$TMP/retirada"
sitio "$TMP/paddle"; printf 'Pago procesado por Paddle' > "$TMP/paddle/privacidad.html"; espera falla "menciona una página o proveedor retirado" "$TMP/paddle"
sitio "$TMP/sin200"; rm "$TMP/sin200/cancelar.html";                       espera falla "cancelar.html responde 404" "$TMP/sin200"
sitio "$TMP/mapa"; printf '<urlset><url><loc>http://127.0.0.1:PUERTO/activar.html</loc></url></urlset>' > "$TMP/mapa/sitemap.xml"; espera falla "sitemap" "$TMP/mapa"
sitio "$TMP/sinmapa"; rm "$TMP/sinmapa/sitemap.xml";                       espera falla "sitemap.xml responde 404" "$TMP/sinmapa"
sitio "$TMP/sinrobots"; rm "$TMP/sinrobots/robots.txt";                    espera falla "robots.txt responde 404" "$TMP/sinrobots"
sitio "$TMP/vacio"; printf '<urlset></urlset>' > "$TMP/vacio/sitemap.xml"; espera falla "el sitemap no trae ninguna dirección" "$TMP/vacio"
echo CHEQUEO_EN_VIVO_PRUEBA_OK
