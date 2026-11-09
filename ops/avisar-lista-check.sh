#!/usr/bin/env bash
# #219: todo flujo de .github/workflows debe estar en la lista `workflows:` de avisar-motor.yml (si no, su resultado nunca llega al motor). Sale 1 y dice cuáles faltan.
set -euo pipefail
cd "$(dirname "$0")/.."
faltan=0
lista=$(sed -n 's/^    workflows: \[\(.*\)\]$/\1/p' .github/workflows/avisar-motor.yml | tr ',' '\n' | sed 's/^ *//; s/ *$//')
for f in .github/workflows/*.yml; do
  n=$(sed -n 's/^name: *//p' "$f" | head -1)
  [ "$n" = "avisar-motor" ] && continue
  echo "$lista" | grep -qx "$n" || { echo "AVISAR_LISTA_FALTA: «$n» ($f) no está en avisar-motor.yml"; faltan=1; }
done
[ "$faltan" = "0" ] && echo "AVISAR_LISTA_OK"
exit "$faltan"
