#!/usr/bin/env bash
# Prueba de datos-plan-limite-publicar.sh con repositorios git locales (un "origin" desnudo): datos sin cambios, datos nuevos, un rerun que parte de un commit viejo, una carrera sin choque y una carrera con choque.
set -euo pipefail
AQUI="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
json() { printf '{"correos_por_dia":%s,"generado":"%s"}' "$1" "$2"; }
nuevo_origin() {   # nuevo_origin <carpeta> <entero inicial>
    git init -q --bare -b main "$1/origin.git"
    git clone -q "$1/origin.git" "$1/sem" 2>/dev/null
    ( cd "$1/sem" && git checkout -q -b main && json "$2" t0 > datos-plan-limite.json && cp "$AQUI/datos-plan-limite-publicar.sh" . && git add -A && git commit -q -m base && git push -q origin main )
}
avanzar_origin() {   # avanzar_origin <carpeta> <archivo> <contenido>: otro push a main
    ( cd "$1/sem" && printf '%s' "$3" > "$2" && git add -A && git commit -q -m otro && git push -q origin main )
}
correr() {   # correr <carpeta> <entero nuevo> <commit del que parte la corrida>: clona origin en ese commit (como un rerun) y publica
    local d="$1"; rm -rf "$d/runner"; git clone -q "$d/origin.git" "$d/runner" 2>/dev/null
    ( cd "$d/runner" && git checkout -q --detach "$3" && json "$2" t1 > nuevo.json && : > "$d/salida" && GITHUB_OUTPUT="$d/salida" bash "$AQUI/datos-plan-limite-publicar.sh" nuevo.json )
}
valor() { git -C "$1/origin.git" show main:datos-plan-limite.json | sed -E 's/.*"correos_por_dia":([0-9]+).*/\1/'; }
commits() { git -C "$1/origin.git" rev-list --count main; }
falla() { echo "FALLO la prueba: $1"; exit 1; }

# 1. sin cambios: verde, sin commit
d="$TMP/a"; mkdir -p "$d"; nuevo_origin "$d" 7; base="$(git -C "$d/origin.git" rev-parse main)"; antes="$(commits "$d")"
correr "$d" 7 "$base" > "$d/log" || falla "sin cambios debía terminar en verde"
[ "$(commits "$d")" = "$antes" ] && ! grep -q publicado "$d/salida" || falla "sin cambios no debía commitear ni marcar publicado"
echo "ok: datos sin cambios (verde, sin commit)"

# 2. datos nuevos: commit, push y publicado=1
d="$TMP/b"; mkdir -p "$d"; nuevo_origin "$d" 6; base="$(git -C "$d/origin.git" rev-parse main)"
correr "$d" 7 "$base" > "$d/log" || falla "datos nuevos debía publicar"
[ "$(valor "$d")" = 7 ] && grep -q "publicado=1" "$d/salida" || falla "datos nuevos: origin no quedó en 7 o no marcó publicado"
echo "ok: datos nuevos (publicados)"

# 3. rerun: parte del commit viejo (6) cuando origin ya publicó 7 (con otra hora de generación): verde, sin commit repetido
d="$TMP/c"; mkdir -p "$d"; nuevo_origin "$d" 6; viejo="$(git -C "$d/origin.git" rev-parse main)"
avanzar_origin "$d" datos-plan-limite.json "$(json 7 t-otra-corrida)"; antes="$(commits "$d")"
correr "$d" 7 "$viejo" > "$d/log" || falla "el rerun sobre datos ya publicados debía terminar en verde"
[ "$(commits "$d")" = "$antes" ] && ! grep -q publicado "$d/salida" || falla "el rerun repitió el commit o marcó publicado"
echo "ok: rerun sobre un commit viejo con los datos ya publicados (verde, sin commit repetido)"

# 4. carrera sin choque: otro push (otro archivo) entre el clon y el push
d="$TMP/d"; mkdir -p "$d"; nuevo_origin "$d" 6; viejo="$(git -C "$d/origin.git" rev-parse main)"
avanzar_origin "$d" otra-cosa.txt "x"
correr "$d" 7 "$viejo" > "$d/log" || falla "la carrera sin choque debía publicar"
[ "$(valor "$d")" = 7 ] && grep -q "publicado=1" "$d/salida" || falla "la carrera sin choque no dejó 7 en origin"
echo "ok: carrera sin choque (rebase y publicado)"

# 5. carrera con choque: otra corrida publicó 8 en el mismo archivo; ésta trae 7 -> descarta lo propio, vuelve a main y publica 7 encima
d="$TMP/e"; mkdir -p "$d"; nuevo_origin "$d" 6; viejo="$(git -C "$d/origin.git" rev-parse main)"
avanzar_origin "$d" datos-plan-limite.json "$(json 8 t-otra)"
correr "$d" 7 "$viejo" > "$d/log" || falla "la carrera con choque debía recuperarse"
[ "$(valor "$d")" = 7 ] && grep -q "publicado=1" "$d/salida" || falla "la carrera con choque no dejó 7 en origin"
echo "ok: carrera con choque (un reintento sobre main al día)"

# 6. JSON nuevo ilegible: falla ruidoso, no toca nada
d="$TMP/f"; mkdir -p "$d"; nuevo_origin "$d" 6; base="$(git -C "$d/origin.git" rev-parse main)"; antes="$(commits "$d")"
if ( rm -rf "$d/runner"; git clone -q "$d/origin.git" "$d/runner" 2>/dev/null; cd "$d/runner" && printf 'no es json' > nuevo.json && bash "$AQUI/datos-plan-limite-publicar.sh" nuevo.json ) >/dev/null 2>&1; then falla "un JSON ilegible no debía publicar"; fi
[ "$(commits "$d")" = "$antes" ] || falla "un JSON ilegible tocó origin"
echo "ok: JSON ilegible (falla y no toca nada)"
echo PUBLICAR_PRUEBA_OK
