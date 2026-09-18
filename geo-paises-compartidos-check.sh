#!/usr/bin/env bash
# Candado, 17-sep-2026: index.html (la muestra) y onboarding.html (activación)
# comparten la lista, el estilo y el comportamiento del selector de país en un solo
# lugar -- geo-chips.js + geo-chips.css. Antes cada página tenía su propia copia
# (GEO_OPCIONES local + su propio toggle + su propio CSS de checkboxes), y ya
# divergieron una vez sin que nadie lo notara antes de unificarlas (17-sep-2026).
#
# Este check falla si cualquiera de las dos páginas:
#   1. deja de citar geo-chips.js/.css, o
#   2. vuelve a traer su propia lista de países hardcodeada (GEO_OPCIONES/GEO_PAISES
#      local, o un país escrito a mano en el markup en vez de generado por
#      geoChipsHTML()).
set -euo pipefail

fail=0
paginas=(index.html onboarding.html)

for pagina in "${paginas[@]}"; do
  if ! grep -q '<script src="geo-chips.js"></script>' "$pagina"; then
    echo "::error::$pagina no cita <script src=\"geo-chips.js\"> -- dejó de usar el selector compartido."
    fail=1
  fi
  if ! grep -q '<link rel="stylesheet" href="geo-chips.css">' "$pagina"; then
    echo "::error::$pagina no cita <link rel=\"stylesheet\" href=\"geo-chips.css\"> -- dejó de usar el estilo compartido."
    fail=1
  fi
  if grep -qE 'GEO_OPCIONES|const[[:space:]]+GEO_PAISES' "$pagina"; then
    echo "::error::$pagina define su propia lista de países (GEO_OPCIONES/GEO_PAISES) -- esa lista vive solo en geo-chips.js."
    fail=1
  fi
  if grep -qE 'value="México"' "$pagina"; then
    echo "::error::$pagina tiene un país hardcodeado en el markup (value=\"México\") -- los chips se generan con geoChipsHTML(), no a mano."
    fail=1
  fi
done

if [ "$fail" = "1" ]; then
  exit 1
fi
echo "GEO_PAISES_COMPARTIDOS_OK -- index.html y onboarding.html citan geo-chips.js/.css y ninguna trae su propia lista de países."
