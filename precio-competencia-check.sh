#!/usr/bin/env bash
# Candado, 18-sep-2026: la tabla "costo real de hacer outbound" (#activar en
# index.html) cita precios públicos de Apollo, Lusha y Hunter -- una tabla de
# precios desactualizada es PEOR que no tenerla (un visitante que la compara
# contra el precio real y encuentra que mentimos, o que quedamos caros/baratos
# por error, pierde confianza en todo el sitio). Este chequeo no verifica los
# precios en sí (eso requiere a un humano mirando cada página) -- verifica que
# no pasó demasiado tiempo desde la última vez que alguien lo hizo, leyendo la
# marca `precio-competencia-verificado: AAAA-MM-DD` del propio archivo.
#
# Uso: precio-competencia-check.sh [dias_umbral]  (default 90)
# Al reverificar los precios: actualizar la fecha de la marca en index.html
# (buscar "precio-competencia-verificado") al mismo tiempo que cualquier
# cambio en la tabla -- la marca es la fuente de verdad de "cuándo se miró
# por última vez", no un timestamp de git (un commit que solo toca redacción,
# sin tocar el precio, no cuenta como reverificación).
set -euo pipefail

ARCHIVO="index.html"
UMBRAL_DIAS="${1:-90}"

marca=$(grep -oE 'precio-competencia-verificado: [0-9]{4}-[0-9]{2}-[0-9]{2}' "$ARCHIVO" | head -1 | awk '{print $2}')

if [ -z "$marca" ]; then
    echo "::error::No encontré la marca 'precio-competencia-verificado: AAAA-MM-DD' en $ARCHIVO -- la tabla de precios de la competencia no tiene fecha de verificación. Agregala junto al bloque .tabla-real."
    exit 1
fi

# Portable Mac/Linux (el mismo motivo que ops/test-linux.sh en outreach-engine):
# `date -d` es GNU, `date -j -f` es BSD/macOS -- se intenta GNU primero, BSD si falla.
if fecha_epoch=$(date -d "$marca" +%s 2>/dev/null); then
    :
elif fecha_epoch=$(date -j -f "%Y-%m-%d" "$marca" +%s 2>/dev/null); then
    :
else
    echo "::error::La marca 'precio-competencia-verificado: $marca' no es una fecha válida (AAAA-MM-DD)."
    exit 1
fi

hoy_epoch=$(date +%s)
dias_pasados=$(( (hoy_epoch - fecha_epoch) / 86400 ))

if [ "$dias_pasados" -lt 0 ]; then
    echo "::error::La marca 'precio-competencia-verificado: $marca' está en el futuro -- ¿typo?"
    exit 1
fi

if [ "$dias_pasados" -gt "$UMBRAL_DIAS" ]; then
    echo "::error::La tabla de precios de la competencia (#activar en $ARCHIVO) se verificó por última vez hace $dias_pasados días (umbral: $UMBRAL_DIAS) -- $marca. Revisá apollo.io/pricing, lusha.com/pricing y hunter.io/pricing de nuevo, actualizá los números que cambiaron, y mové la marca a la fecha de hoy."
    exit 1
fi

echo "PRECIO_COMPETENCIA_VIGENTE_OK -- verificado hace $dias_pasados días ($marca), dentro del umbral de $UMBRAL_DIAS."
