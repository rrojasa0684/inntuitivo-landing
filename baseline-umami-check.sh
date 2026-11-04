#!/usr/bin/env bash
# 4-nov-2026: prueba del baseline automático. Repo temporal con los hooks reales: sin archivo o con archivo viejo el commit y el push de index.html se frenan;
# con archivo fresco el comentario se escribe solo (una vez) y el push pasa. Uso: bash baseline-umami-check.sh
set -uo pipefail
RAIZ=$(cd "$(dirname "$0")" && pwd)
T=$(mktemp -d); trap 'rm -rf "$T"' EXIT
fallas=0
ok() { echo "ok: $1"; }
mal() { echo "FALLA: $1"; fallas=$((fallas+1)); }

mkdir -p "$T/origen.git" "$T/repo/.githooks"
git init -q --bare -b main "$T/origen.git"
cp "$RAIZ"/.githooks/{pre-commit,pre-push,baseline-umami.py} "$T/repo/.githooks/"
cd "$T/repo" && git init -q -b main && git remote add origin "$T/origen.git" && git config core.hooksPath .githooks && git config user.name t && git config user.email t@t.test
printf '<html>\n<body>\n<p>uno</p>\n</body>\n</html>\n' > index.html
echo "# d" > README.md
git add README.md && git commit -q -m inicial && git push -q origin main
git checkout -q -b feat/x

export UMAMI_BASELINE_ARCHIVO="$T/b.json"
echo '<p>dos</p>' >> index.html; git add index.html

# 1. sin archivo: el commit se frena
if git commit -q -m uno 2>/dev/null; then mal "commit pasó sin archivo de baseline"; else ok "commit frenado sin archivo"; fi

# 2. archivo viejo: se frena
echo '{"scroll_precio_dia": 9, "cta_activar_semana": 0, "fecha": "2026-01-01", "generado": "2026-01-01T00:00:00Z"}' > "$T/b.json"
if git commit -q -m uno 2>"$T/err"; then mal "commit pasó con baseline viejo"; elif grep -q "refrescar el baseline" "$T/err"; then ok "commit frenado con baseline viejo y mensaje claro"; else mal "mensaje poco claro"; fi

# 3. archivo fresco: escribe el comentario y el commit pasa
ahora=$(date -u +%Y-%m-%dT%H:%M:%SZ)
echo "{\"scroll_precio_dia\": 10.3, \"cta_activar_semana\": 0, \"fecha\": \"2026-11-04\", \"generado\": \"$ahora\"}" > "$T/b.json"
if git commit -q -m uno 2>/dev/null; then ok "commit pasa con baseline fresco"; else mal "commit frenado con baseline fresco"; fi
[ "$(git show HEAD:index.html | grep -c 'baseline-auto 2026-11-04: baseline scroll_precio=10.3/día, cta_activar=0/semana')" = "1" ] && ok "comentario escrito una vez" || mal "comentario ausente o repetido"
git show HEAD:index.html | sed -n 3p | grep -q baseline-auto && ok "comentario justo después de <body>" || mal "comentario fuera de lugar"

# 4. otro commit con el mismo baseline no duplica el comentario
echo '<p>tres</p>' >> index.html; git add index.html; git commit -q -m dos
[ "$(git show HEAD:index.html | grep -c baseline-auto)" = "1" ] && ok "sin duplicados" || mal "comentario duplicado"

# 5. push con baseline fresco pasa; con baseline viejo se frena
if git push -q origin feat/x 2>/dev/null; then ok "push pasa con baseline fresco"; else mal "push frenado con baseline fresco"; fi
echo '{"scroll_precio_dia": 9, "cta_activar_semana": 0, "fecha": "2026-01-01", "generado": "2026-01-01T00:00:00Z"}' > "$T/b.json"
echo '<p>cuatro</p>' >> index.html; git commit -q -am cuatro 2>/dev/null && mal "commit pasó con baseline viejo (cuatro)" || true
rm "$T/b.json"; git -c core.hooksPath=/dev/null commit -q -am cuatro  # solo para preparar el escenario del push sin pasar por el commit
if git push -q origin feat/x 2>"$T/err"; then mal "push pasó sin baseline fresco"; elif grep -q "refrescar el baseline" "$T/err"; then ok "push frenado sin archivo, con mensaje claro"; else mal "push frenado sin mensaje claro"; fi

# 6. segundo push del mismo dia (comentario sin cambios, sin linea agregada): pasa si lleva el baseline vigente
echo "{\"scroll_precio_dia\": 10.3, \"cta_activar_semana\": 0, \"fecha\": \"2026-11-04\", \"generado\": \"$ahora\"}" > "$T/b.json"
git reset -q --hard origin/feat/x; echo '<p>cinco</p>' >> index.html; git add index.html; git commit -q -m cinco
echo '<p>seis</p>' >> index.html; git add index.html; git commit -q -m seis
git push -q origin feat/x 2>/dev/null && ok "segundo push del dia pasa con el comentario vigente" || mal "segundo push del dia frenado"

[ "$fallas" = "0" ] && echo "BASELINE_UMAMI_OK" || { echo "BASELINE_UMAMI_FALLA ($fallas)"; exit 1; }
