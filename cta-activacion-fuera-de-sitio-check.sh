#!/usr/bin/env bash
# Candado, 17-sep-2026 (bug real, cazado por Ricardo): el bloque de alianza
# Mercately agregó un CTA "Activar mi agente" que apuntaba directo a
# https://api.inntuitivo.com/suscribir en vez de al ancla #activar. Estaba mal
# por dos razones: (1) saltaba la sección de precio -- la persona llegaba al
# checkout sin ver qué incluye ni cuánto cuesta; (2) salía del sitio, así que
# el evento de Umami del embudo (cta_ver_precio, ver el script de Analytics
# más abajo en index.html) nunca se disparaba.
#
# El ÚNICO lugar donde un link directo a /suscribir es correcto es DENTRO de
# la sección #activar misma -- ahí la persona ya tiene precio y qué incluye
# en pantalla, así que saltar directo al checkout es la intención. Cualquier
# CTA "Activar mi agente" que aparezca en OTRO bloque (como Mercately, o el
# próximo banner que se agregue) tiene que apuntar a "#activar", igual que el
# del hero (.btn-secundario, ~línea 510) -- nunca directo a /suscribir.
#
# Método: ubica las líneas de la sección #activar (por profundidad de
# <section>, no por número fijo -- sobrevive a que el archivo crezca), y
# falla si CUALQUIER href="https://api.inntuitivo.com/suscribir" aparece
# FUERA de ese rango.
set -euo pipefail

archivo="index.html"

# `|| true` a propósito (18-sep-2026): bajo `set -e`+`pipefail`, un grep sin
# match dentro de `$(...)` mata el script ACÁ, antes del `if [ -z "$inicio" ]`
# de abajo que existe justo para reportar este caso.
inicio=$(grep -n '<section id="activar"' "$archivo" | head -1 | cut -d: -f1 || true)
if [ -z "$inicio" ]; then
  echo "::error::No encontré <section id=\"activar\"> en $archivo -- el chequeo no puede ubicar la sección de referencia. Revisá a mano si el id cambió de nombre."
  exit 1
fi

fin=$(awk -v ini="$inicio" 'NR==ini{d=0} NR>=ini{ if ($0 ~ /<section/) d++; if ($0 ~ /<\/section>/) { d--; if (d==0) { print NR; exit } } }' "$archivo")
if [ -z "$fin" ]; then
  echo "::error::Encontré <section id=\"activar\"> en la línea $inicio pero no su </section> de cierre -- HTML roto o el chequeo no pudo seguirle el rastro. Revisá a mano."
  exit 1
fi

# `|| true`: el caso GOOD acá es que el grep no encuentre nada FUERA de rango
# -- pero un grep sin match del todo (el link desaparece del archivo entero)
# también mata bajo pipefail, y "$fuera" vacío es justo lo que decide el "OK"
# de abajo -- no puede depender de que el grep haya encontrado algo.
fuera=$(grep -n 'href="https://api.inntuitivo.com/suscribir"' "$archivo" | awk -F: -v ini="$inicio" -v fin="$fin" '{ if ($1 < ini || $1 > fin) print }' || true)

if [ -n "$fuera" ]; then
  echo "::error::Un CTA fuera de la sección #activar (líneas $inicio-$fin) apunta directo a /suscribir en vez de al ancla \"#activar\" -- salta la sección de precio y pierde el evento de Umami del embudo (cta_ver_precio). Cambiá el href a \"#activar\". Línea(s) con el problema:"
  echo "$fuera"
  exit 1
fi

echo "CTA_ACTIVACION_OK -- ningún CTA fuera de #activar (líneas $inicio-$fin) apunta directo a /suscribir."
