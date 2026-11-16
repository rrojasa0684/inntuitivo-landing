#!/usr/bin/env bash
# Publica datos-plan-limite.json si el límite diario cambió (#227). Lo corre .github/workflows/datos-plan-limite-sync.yml con el JSON ya validado en nuevo.json.
# 15-nov-2026: IDEMPOTENTE. Una corrida repetida (rerun) parte del commit ORIGINAL de la corrida, no de main: antes volvía a commitear el mismo dato (72a0bb9), el rebase chocaba con el commit que la primera pasada ya había
# publicado (e28e549) y la corrida quedaba en rojo con los datos ya publicados. Ahora: (1) se pone al día con main antes de comparar; (2) si el entero ya está publicado, termina en verde SIN commit;
# (3) si otro push gana la carrera, rebase; si el rebase choca, se descarta el commit propio, se vuelve a main y se compara otra vez (un solo reintento).
# Salida: escribe publicado=1 en $GITHUB_OUTPUT solo si hizo push. Uso: bash datos-plan-limite-publicar.sh [nuevo.json]   (sin red de por medio: remoto "origin", rama main)
set -euo pipefail
NUEVO="${1:-nuevo.json}"
ARCHIVO="datos-plan-limite.json"
SALIDA="${GITHUB_OUTPUT:-/dev/null}"

entero() { node -e "try{console.log(JSON.parse(require('fs').readFileSync('$1','utf8')).correos_por_dia)}catch(e){console.log('')}"; }
n="$(entero "$NUEVO")"
[ -n "$n" ] || { echo "El JSON nuevo no trae correos_por_dia: no se publica nada." >&2; exit 1; }

git fetch -q origin main
git merge --ff-only -q origin/main 2>/dev/null || git reset -q --hard origin/main      # un rerun arranca del commit original: se pone al día con lo ya publicado
v="$(entero "$ARCHIVO")"
if [ "$n" = "$v" ]; then echo "Sin cambios ($n por día, ya publicado): nada que publicar."; exit 0; fi

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
publicar() {
    cp "$NUEVO" "$ARCHIVO"
    git add "$ARCHIVO"
    git commit -q -m "chore: límite diario del plan actualizado por el motor ($n por día, $(date -u +%F))"
}
publicar
if ! git pull --rebase -q origin main 2>/dev/null; then       # otro push a main entre el clon y el nuestro, y el rebase chocó
    git rebase --abort 2>/dev/null || true
    git fetch -q origin main
    git reset -q --hard origin/main
    v="$(entero "$ARCHIVO")"
    if [ "$n" = "$v" ]; then echo "Otra corrida ya publicó $n por día: nada que publicar."; exit 0; fi
    publicar                                                  # el único reintento: sobre main al día
fi
if ! git push -q origin HEAD:main 2>/dev/null; then
    sleep 5; git pull --rebase -q origin main && git push -q origin HEAD:main
fi
echo "publicado=1" >> "$SALIDA"
echo "Publicado: $n por día."
