#!/usr/bin/env bash
# Candado, 18-sep-2026: el sitio tenía 5 valores de breakpoint distintos (520,
# 760, 767, 768, 840px) repartidos sin ningún criterio -- a ~800px de ancho
# algunas secciones ya mostraban layout mobile (las de 840) y otras todavía
# desktop (las de 760-768), inconsistente en la MISMA pantalla. Se unificó a
# dos: 840px (el corte principal de layout) y 520px (ajustes finos de celular
# chico). CSS no soporta variables dentro de una condición @media (custom
# media queries no está en ningún navegador todavía), así que la única forma
# real de que "no se pueda olvidar" es un chequeo que falle si aparece un
# tercer valor -- no una variable.
#
# Uso: breakpoints-check.sh
set -euo pipefail

PERMITIDOS="520 840"
ARCHIVOS="index.html onboarding.html geo-chips.css"

encontrados=$(grep -ohE '@media[^{]*max-width:[0-9]+px' $ARCHIVOS | grep -oE '[0-9]+px' | grep -oE '[0-9]+' | sort -un)

malos=""
for v in $encontrados; do
    match=0
    for ok in $PERMITIDOS; do
        [ "$v" = "$ok" ] && match=1
    done
    [ "$match" = "0" ] && malos="$malos $v"
done

if [ -n "$malos" ]; then
    echo "::error::Breakpoint(s) fuera del set permitido ($PERMITIDOS px) encontrado(s) en $ARCHIVOS:$malos -- usá 840px (corte principal de layout) o 520px (ajuste fino de celular chico), no un valor nuevo. Si de verdad hace falta un tercer corte, la decisión es de Ricardo, no una elección ad-hoc por archivo."
    exit 1
fi

echo "BREAKPOINTS_OK -- solo se usan los valores permitidos ($PERMITIDOS px) en $ARCHIVOS."
