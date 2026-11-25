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

# 15-nov-2026: un 5xx o un tiempo agotado (código 000) de GitHub Pages es pasajero (el 15-nov un 503 sobre un favicon puso en rojo datos-plan-limite-sync con los datos ya publicados): se reintenta hasta 3 veces con espera
# creciente (CHEQUEO_ESPERA segundos, por defecto 3, luego el doble y el doble). Un 4xx NO se reintenta: es un enlace roto de verdad.
ESPERA="${CHEQUEO_ESPERA:-3}"
pasajero() { case "$1" in 5??|000) return 0 ;; *) return 1 ;; esac; }
codigo() {   # codigo <url> [-L]: imprime el código HTTP final
    local c e="$ESPERA" i
    for i in 0 1 2 3; do
        c="$(curl -s -o /dev/null -w '%{http_code}' --max-time 20 ${2:-} "$1" || true)"
        pasajero "$c" && [ "$i" -lt 3 ] || break
        sleep "$e"; e=$((e * 2))
    done
    printf '%s' "$c"
}

# Una sola descarga por dirección: deja el código en CODIGO y el cuerpo en CUERPO (un 503 pasajero no puede dejar una página "revisada" con el HTML vacío)
pedir() {
    local tmp e="$ESPERA" i; tmp="$(mktemp)"
    for i in 0 1 2 3; do
        CODIGO="$(curl -s -o "$tmp" -w '%{http_code}' --max-time 20 -L "$1" || true)"
        pasajero "$CODIGO" && [ "$i" -lt 3 ] || break
        sleep "$e"; e=$((e * 2))
    done
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
    c="$(codigo "$e" -L)"
    [ "$c" = "200" ] || fallas+=("enlace roto: $e responde $c")
done < <(printf '%s\n' "${enlaces[@]:-}" | sort -u)

# 3: las retiradas dan 404
for r in $RETIRADAS; do
    c="$(codigo "$BASE/$r")"
    [ "$c" = "404" ] || fallas+=("$r debería dar 404 y responde $c")
done

# 4: sitemap y robots.txt
if printf '%s\n%s' "$sitemap" "$robots" | grep -Eiq "$PROHIBIDOS"; then fallas+=("el sitemap o robots.txt menciona una página o proveedor retirado"); fi

# 5 (#227): el día de ejemplo no lleva una cifra escrita a mano y datos-plan-limite.json, si existe, trae un entero de 1 a 1000
pedir "$BASE/"; home="$CUERPO"
if printf '%s' "$home" | grep -Eq '[0-9]+ emails personalizados enviados en tu nombre'; then fallas+=("el día de ejemplo trae una cifra fija (#227)"); fi
pedir "$BASE/datos-plan-limite.json"
if [ "$CODIGO" = "200" ]; then
    printf '%s' "$CUERPO" | grep -Eq '"correos_por_dia"[[:space:]]*:[[:space:]]*[0-9]+[[:space:]]*[,}]' || fallas+=("datos-plan-limite.json no trae correos_por_dia como entero")
fi

# 6 (25-nov-2026): la tabla de «Cifras públicas de terceros» se quitó y no puede volver a convivir con la página nueva. Se pide la portada SIN caché (parámetro único y Cache-Control: no-cache) y no puede traer esa tabla, su texto ni su JSON;
# la sección 2 tiene que traer «Ver las fuentes». Después, la misma revisión con un navegador de contexto nuevo (la tabla vieja la dibujaba JavaScript): chequeo-en-vivo-navegador.mjs, si hay Playwright (CHEQUEO_NAVEGADOR=no la salta, solo para la prueba con un sitio de juguete).
sc="$(curl -s --max-time 20 -L -H 'Cache-Control: no-cache' -H 'Pragma: no-cache' "$BASE/?nc=$(date +%s)" || true)"
for prohibido in 'Cifras públicas de terceros' 'De dónde sale el decisor' 'datos-decisores-publicos'; do
    printf '%s' "$sc" | grep -Fq "$prohibido" && fallas+=("la portada publicada trae «${prohibido}» (quitado el 25-nov)")
done
printf '%s' "$sc" | grep -Fq 'Ver las fuentes' || fallas+=("la portada publicada no trae «Ver las fuentes» en la sección 2")
if [ "${CHEQUEO_NAVEGADOR:-si}" != "no" ]; then
    AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [ -d "$AQUI/node_modules/playwright" ] && command -v node >/dev/null 2>&1; then
        if ! nav="$(cd "$AQUI" && node chequeo-en-vivo-navegador.mjs "$BASE" 2>&1)"; then
            while IFS= read -r l; do case "$l" in "  - "*) fallas+=("navegador: ${l#  - }") ;; esac; done <<<"$nav"
            [ "${#fallas[@]}" -gt 0 ] || fallas+=("el chequeo con navegador falló: $nav")
        fi
    else
        fallas+=("no hay Playwright para el chequeo con navegador (npm ci y npx playwright install chromium)")
    fi
fi

if [ "${#fallas[@]}" -gt 0 ]; then
    echo "CHEQUEO_EN_VIVO_FALLA"
    printf '  - %s\n' "${fallas[@]}"
    exit 1
fi
echo "CHEQUEO_EN_VIVO_OK ($BASE: ${#paginas[@]} páginas, $(printf '%s\n' "${enlaces[@]:-}" | sort -u | grep -c . || true) enlaces internos, retiradas en 404)"
