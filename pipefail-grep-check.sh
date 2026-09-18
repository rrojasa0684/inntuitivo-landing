#!/usr/bin/env bash
# Candado, 18-sep-2026: cierra la CLASE de bug completa -- 4 scripts distintos
# (2 repos) tenían el mismo patrón: una asignación `VAR=$(... | grep ... | ...)`
# sin `|| true`, en un archivo con `set -e` + `pipefail` activos. Bajo esa
# combinación, un grep SIN MATCH (un resultado legítimo y esperado -- "no hay
# marca", "no encontré la sección") mata el script ENTERO en esa línea, antes
# de llegar a cualquier `if [ -z "$VAR" ]` escrito a propósito para reportarlo.
# Probado en vivo, no supuesto -- ver los 4 casos reproducidos el mismo día.
# Encontrado y arreglado en:
#   - ops/feriados-cr-check.sh (nuevo, lo cazó su propio test antes de deploy)
#   - inntuitivo-landing/precio-competencia-check.sh
#   - inntuitivo-landing/cta-activacion-fuera-de-sitio-check.sh (2 veces)
#   - inntuitivo-landing/breakpoints-check.sh
# "Si mordió cuatro veces, va a morder una quinta" (Ricardo, 18-sep) -- este
# chequeo es la versión "no depender de acordarse" de esa frase.
#
# LÍMITE explícito, para no prometer más de lo que hace (barato, no
# exhaustivo -- mismo criterio que memoria-index-check.sh): solo mira
# asignaciones de UNA LÍNEA (`VAR=$(...)` completo en la misma línea) en
# archivos con AMBOS `-e` y `pipefail` activos -- si falta `-e`, un grep que
# falla NO aborta el script (confirmado en vivo contra ops/contexto-
# numeros.sh, que usa el mismo patrón de pipe pero SIN `-e`, y es seguro).
# Una asignación MULTILÍNEA (con `\` de continuación) no se detecta -- ese
# caso queda para revisión manual si alguna vez combina `-e` con un pipe así.
#
# Solo mira `grep` -- probado en vivo (no supuesto) que `awk` y `sed -n` NO
# fallan con exit≠0 cuando su patrón no matchea nada (corren normal, imprimen
# vacío, exit 0); grep SÍ falla con exit 1 en ese caso, incluida la variante
# `grep -c` (imprime "0" pero igual sale con 1). Marcar awk/sed acá sería un
# falso positivo real -- se probó y se descartó, no es un olvido.
#
# Uso: ops/pipefail-grep-check.sh <directorio> [<directorio> ...]
set -euo pipefail

problemas=()

for dir in "$@"; do
    for f in "$dir"/*.sh; do
        [ -f "$f" ] || continue
        nombre="$f"

        # Solo arriesgan esto los scripts con -e Y pipefail activos a la vez.
        tiene_pipefail=0
        tiene_e=0
        while IFS= read -r linea; do
            case "$linea" in
                *pipefail*) tiene_pipefail=1 ;;
            esac
            if echo "$linea" | grep -qE '^set +-[a-zA-Z]*e[a-zA-Z]*($| )'; then
                tiene_e=1
            fi
        done < <(grep -E '^set +-' "$f" || true)

        if [ "$tiene_pipefail" -ne 1 ] || [ "$tiene_e" -ne 1 ]; then
            continue
        fi

        # Asignaciones de UNA línea "VAR=$(...)" que contienen grep en algún
        # punto de la tubería y no terminan en "|| true".
        while IFS=: read -r num linea; do
            case "$linea" in
                *'|| true'*) continue ;;
            esac
            problemas+=("$nombre:$num: ${linea# }")
        done < <(grep -nE '^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*=\$\(.*\)[[:space:]]*$' "$f" | grep -E '\bgrep\b' || true)
    done
done

if [ "${#problemas[@]}" -eq 0 ]; then
    echo "PIPEFAIL_GREP_OK -- ningún script tiene el patrón grep-sin-fallback bajo set -e+pipefail."
    exit 0
fi

echo "PIPEFAIL_GREP_PROBLEMA (${#problemas[@]}):"
for p in "${problemas[@]}"; do
    echo "  $p"
done
exit 1
