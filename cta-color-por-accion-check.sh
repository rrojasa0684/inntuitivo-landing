#!/usr/bin/env bash
# Candado, 17-sep-2026 (Ricardo, tras la causa raíz de un vaivén de 4 rondas en el
# bloque de alianza Mercately): el sitio tenía DOS botones "Activar mi agente" con
# estilos distintos entre sí (hero=morado, checkout real dentro de #activar=
# degradado) -- por eso "como los demás CTA de Activar" nunca se podía cumplir, cada
# corrección coincidía con uno de los dos y no con el otro.
#
# Regla, de una vez: el COLOR significa la ACCIÓN, no el lugar.
#   - .btn-primario (degradado rojo/rosa) = "activar" -- la acción que genera ingresos.
#   - .btn-secundario (morado sólido)     = todo lo demás -- muestra gratis, Mercately,
#     cualquier CTA de apoyo.
#
# Alcance: solo anchors con el token de clase "btn" (los CTA con estilo de botón real
# -- .btn.btn-primario/.btn.btn-secundario). nav-cta/nl-cta (clases propias, fuera de
# este barrido) quedan afuera a propósito -- no son .btn, y unificarlos es una
# decisión aparte, no de este candado.
set -euo pipefail

archivo="index.html"
fail=0

while IFS= read -r etiqueta; do
  # sed en vez de grep -P (Perl regex): -P no existe en el grep BSD de macOS, solo
  # en GNU grep (Linux/CI) -- mismo motivo que ops/test-linux.sh en outreach-engine,
  # portabilidad Mac/Linux, no una preferencia de estilo.
  clase=$(sed -E 's/^<a class="([^"]*)".*$/\1/' <<< "$etiqueta")
  texto=$(sed -E 's/^.*>([^<]*)<\/a>$/\1/' <<< "$etiqueta")
  [ -z "$clase" ] && continue
  grep -qwE 'btn' <<< "$clase" || continue

  if grep -q 'Activar' <<< "$texto"; then
    if ! grep -qw 'btn-primario' <<< "$clase"; then
      echo "::error::CTA \"$texto\" (class=\"$clase\") contiene \"Activar\" pero no usa btn-primario -- activar = degradado, no morado."
      fail=1
    fi
  fi
  if grep -qi 'muestra' <<< "$texto"; then
    if ! grep -qw 'btn-secundario' <<< "$clase"; then
      echo "::error::CTA \"$texto\" (class=\"$clase\") contiene \"muestra\" pero no usa btn-secundario -- apoyo = morado, no degradado."
      fail=1
    fi
  fi
done < <(grep -oE '<a class="[^"]*"[^>]*>[^<]*</a>' "$archivo")

if [ "$fail" = "1" ]; then
  exit 1
fi
echo "CTA_COLOR_POR_ACCION_OK -- todo CTA .btn con \"Activar\" usa btn-primario, todo CTA .btn con \"muestra\" usa btn-secundario."
