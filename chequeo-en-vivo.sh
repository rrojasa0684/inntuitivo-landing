#!/usr/bin/env bash
# Chequeo EN VIVO de lo publicado (2-nov-2026): "un cambio en la landing no está terminado hasta que el chequeo en vivo de lo publicado pasa".
# Mira www.inntuitivo.com (lo que GitHub Pages sirve), nunca el repo. Falla (exit 1) si:
#   1. alguna página del sitemap (o onboarding.html y cancelar.html) no responde 200;
#   2. algún enlace interno de esas páginas está roto;
#   3. una página retirada (RETIRADAS) no da 404;
#   4. alguna página publicada, el sitemap o robots.txt menciona una página retirada o a un proveedor retirado (PROHIBIDOS).
# Uso: bash chequeo-en-vivo.sh [base]   (default https://www.inntuitivo.com). Salida: CHEQUEO_EN_VIVO_OK, o CHEQUEO_EN_VIVO_FALLA y la lista.
# Lo corre .github/workflows/chequeo-en-vivo.yml después de cada publicación de Pages y todos los días; el motor lo repite en su chequeo diario de SEO (lote del 8-nov).
set -euo pipefail

BASE="${1:-https://www.inntuitivo.com}"
BASE="${BASE%/}"
PAGINAS_EXTRA="onboarding.html cancelar.html"
RETIRADAS="activar.html"                 # páginas borradas: tienen que dar 404
PROHIBIDOS='activar\.html|paddle'        # no puede aparecer en nada publicado (sin distinguir mayúsculas)
fallas=()

codigo() { curl -s -o /dev/null -w '%{http_code}' --max-time 20 -L "$1" || true; }

# Una sola descarga por dirección: deja el código en CODIGO y el cuerpo en CUERPO (un 503 pasajero no puede dejar una página "revisada" con el HTML vacío)
pedir() {
    local tmp; tmp="$(mktemp)"
    CODIGO="$(curl -s -o "$tmp" -w '%{http_code}' --max-time 20 -L "$1" || true)"
    CUERPO="$(cat "$tmp")"; rm -f "$tmp"
}

pedir "$BASE/sitemap.xml"; sitemap="$CUERPO"
[ "$CODIGO" = "200" ] || fallas+=("sitemap.xml responde $CODIGO (se esperaba 200)")
pedir "$BASE/robots.txt"; robots="$CUERPO"
[ "$CODIGO" = "200" ] || fallas+=("robots.txt responde $CODIGO (se esperaba 200)")
paginas=()
while IFS= read -r loc; do
    [ -n "$loc" ] && paginas+=("$loc")
done < <(printf '%s\n' "$sitemap" | grep -Eo '<loc>[^<]*</loc>' | sed 's|<loc>||; s|</loc>||' || true)
[ "${#paginas[@]}" -gt 0 ] || fallas+=("el sitemap no trae ninguna dirección")
for p in $PAGINAS_EXTRA; do paginas+=("$BASE/$p"); done

# 1 y 2: cada página da 200 y sus enlaces internos también
enlaces=()
for url in "${paginas[@]}"; do
    pedir "$url"; c="$CODIGO"; html="$CUERPO"
    if [ "$c" != "200" ]; then fallas+=("$url responde $c (se esperaba 200)"); continue; fi
    [ -n "$html" ] || { fallas+=("$url responde 200 pero llegó vacía"); continue; }
    while IFS= read -r h; do
        h="${h%%#*}"; h="${h%%\?*}"
        case "$h" in ""|mailto:*|tel:*|javascript:*|data:*|//*) continue ;; esac
        case "$h" in *"'"*|*"+"*|*"{"*|*'$'*|*"<"*) continue ;; esac   # enlaces armados por el JavaScript de la página: no son una dirección fija
        case "$h" in
            /*) enlaces+=("$BASE$h") ;;
            "$BASE"*) enlaces+=("$h") ;;
            http*) continue ;;
            *) enlaces+=("$BASE/$h") ;;
        esac
    done < <(printf '%s' "$html" | grep -Eo 'href="[^"]*"' | sed 's/^href="//; s/"$//' || true)
    if printf '%s' "$html" | grep -Eiq "$PROHIBIDOS"; then fallas+=("$url menciona una página o proveedor retirado"); fi
done
while IFS= read -r e; do
    [ -n "$e" ] || continue
    c="$(codigo "$e")"
    [ "$c" = "200" ] || fallas+=("enlace roto: $e responde $c")
done < <(printf '%s\n' "${enlaces[@]:-}" | sort -u)

# 3: las retiradas dan 404
for r in $RETIRADAS; do
    c="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 "$BASE/$r" || true)"
    [ "$c" = "404" ] || fallas+=("$r debería dar 404 y responde $c")
done

# 4: sitemap y robots.txt
if printf '%s\n%s' "$sitemap" "$robots" | grep -Eiq "$PROHIBIDOS"; then fallas+=("el sitemap o robots.txt menciona una página o proveedor retirado"); fi

if [ "${#fallas[@]}" -gt 0 ]; then
    echo "CHEQUEO_EN_VIVO_FALLA"
    printf '  - %s\n' "${fallas[@]}"
    exit 1
fi
echo "CHEQUEO_EN_VIVO_OK ($BASE: ${#paginas[@]} páginas, $(printf '%s\n' "${enlaces[@]:-}" | sort -u | grep -c . || true) enlaces internos, retiradas en 404)"
