#!/usr/bin/env bash
# Chequeo de drift del README: cada nombre de archivo DE ESTE REPO entre backticks
# tiene que existir de verdad en el árbol -- si no, el README envejeció en silencio
# y nadie lo nota hasta que alguien sigue una instrucción que ya no es cierta.
# Gemelo del mismo script en outreach-engine (ops/readme-nombres-check.sh); acá vive
# en la raíz porque este repo no tiene convención de `ops/`.
#
# 7-sep-2026: nace junto con el primer README.md de este repo.
#
# QUÉ CUENTA COMO "REFERENCIA VERIFICABLE" (a propósito, no todo backtick):
#   1. Archivo suelto en la raíz con extensión (index.html, CNAME no aplica acá
#      porque no tiene extensión -- se agrega a mano si hace falta).
#   2. Ruta dentro de un directorio real de este repo (.githooks/, .github/,
#      mascota/, partners/).
# Las referencias cruzadas al repo outreach-engine (docs/memoria/*.md, ops/*.sh)
# se ignoran a propósito -- viven en OTRO árbol, no en este; deben estar marcadas
# como tales en el texto, no chequearse acá. Todo lo demás entre backticks
# (nombres de variables JS, rutas HTTP como /muestra, valores) tampoco se chequea.
#
# Uso: ./readme-nombres-check.sh [archivo.md]  (default: README.md)
# Salida: README_NOMBRES_OK, o README_NOMBRES_ROTOS seguido de la lista -- exit 1.

set -euo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARCHIVO="${1:-$REPO/README.md}"

cd "$REPO"

rotos=()
total=0

while IFS= read -r t; do
    [ -z "$t" ] && continue
    total=$((total + 1))

    # 1. Archivo suelto en la raíz: nombre.ext, sin "/", con una extensión real
    #    de este repo -- ".com"/".io"/etc quedan afuera a propósito (son dominios
    #    en prosa, como "api.inntuitivo.com", no archivos).
    if [[ "$t" =~ ^[A-Za-z0-9_.-]+\.(html|png|jpg|jpeg|ico|xml|txt|json|yml|yaml|md|css|js)$ ]]; then
        if [ ! -e "$t" ]; then
            rotos+=("archivo: $t")
        fi
        continue
    fi

    # 2. Ruta dentro de un directorio real de este repo.
    if [[ "$t" =~ ^(\.githooks|\.github|mascota|partners)/[^[:space:]]+$ ]]; then
        if [ ! -e "$t" ]; then
            rotos+=("archivo: $t")
        fi
        continue
    fi

    # Cualquier otra cosa (referencias al otro repo, rutas HTTP, nombres de
    # variables, valores) -- no se chequea a propósito.
done < <(grep -oE '`[^`]+`' "$ARCHIVO" | sed -E 's/^`//; s/`$//' | sort -u)

if [ "${#rotos[@]}" -eq 0 ]; then
    echo "README_NOMBRES_OK ($ARCHIVO, $total referencias entre backticks revisadas)"
    exit 0
fi

echo "README_NOMBRES_ROTOS (${#rotos[@]}):"
for r in "${rotos[@]}"; do
    echo "  $r"
done
exit 1
