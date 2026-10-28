#!/usr/bin/env bash
# Decisión #48 (Ricardo, 28-oct-2026): la CI marca en rojo cualquier commit de código que llegue a main sin pasar por una rama (con --no-verify, desde la web de GitHub o desde un clon sin el hook).
# Avisa, no bloquea: corre después del push. Misma lista blanca que .githooks/pre-commit: lo que está bajo docs/ o termina en .md.
# Mira solo la línea principal de main (--first-parent) y se salta los merges: los commits de una rama mergeada con --no-ff no cuentan; el commit del merge tampoco (es el que une la rama).
# Límite conocido: una rama integrada por avance rápido (sin commit de merge) es indistinguible de un commit directo y sale en rojo.
# Uso: ci-solo-docs-en-main.sh revisar <sha_antes> <sha_despues>      |      ci-solo-docs-en-main.sh autoprueba
set -euo pipefail

revisar() {
    local antes="$1" despues="$2" rango c f malos=0 commits
    if [ -z "${antes//0/}" ]; then rango="$despues"; else
        git cat-file -e "$antes^{commit}" 2>/dev/null || { echo "SOLO_DOCS_EN_MAIN_SIN_DATOS: el commit anterior $antes no existe en este clon"; return 1; }
        rango="$antes..$despues"   # push que crea la rama: antes es 000...0 y se recorre todo
    fi
    commits="$(git log --first-parent --no-merges --format=%H "$rango")" || return 1
    for c in $commits; do
        # -z y quotePath=false: mismos nombres que ve el hook (tildes, espacios) sin comillas ni escapes octales
        while IFS= read -r -d '' f; do
            case "$f" in docs/*|*.md) ;; *)
                echo "::error::commit de código directo a main: $(git log -1 --format='%h %s' "$c") toca $f"
                malos=$((malos+1)) ;;
            esac
        done < <(git -c core.quotePath=false diff-tree -z --no-commit-id --name-only -r --root "$c")
    done
    [ "$malos" -eq 0 ] && echo "SOLO_DOCS_EN_MAIN_OK" || { echo "SOLO_DOCS_EN_MAIN_ROJO ($malos archivo(s) fuera de docs/ y *.md)"; return 1; }
}

autoprueba() {
    local T fallos=0 base
    T="$(mktemp -d)"; trap 'rm -rf "$T"' RETURN
    g() { git -C "$T" -c user.name=t -c user.email=t@t.test "$@"; }
    g init -q -b main; mkdir -p "$T/docs"; echo x > "$T/README.md"; g add .; g commit -q -m "docs: inicio"
    base="$(g rev-parse HEAD)"
    # 1. commit de código directo a main -> rojo
    echo a=1 > "$T/app.py"; g add app.py; g commit -q -m "feat: codigo directo"
    if (cd "$T" && revisar "$base" "$(git rev-parse HEAD)") >/dev/null 2>&1; then echo "FALLA caso 1: código directo debía ser rojo"; fallos=$((fallos+1)); else echo "OK   commit de código directo: rojo"; fi
    # 2. commit de docs directo -> verde (partiendo de un main sano)
    g reset -q --hard "$base"; echo n > "$T/docs/nota.md"; g add .; g commit -q -m "docs: nota"
    if (cd "$T" && revisar "$base" "$(git rev-parse HEAD)") >/dev/null 2>&1; then echo "OK   commit de docs directo: verde"; else echo "FALLA caso 2: docs directo debía ser verde"; fallos=$((fallos+1)); fi
    # 3. merge de una rama con código -> verde
    g reset -q --hard "$base"; g checkout -q -b feat/x; echo a=1 > "$T/app.py"; g add app.py; g commit -q -m "feat: en rama"
    g checkout -q main; g merge -q --no-ff -m "merge: x" feat/x
    if (cd "$T" && revisar "$base" "$(git rev-parse HEAD)") >/dev/null 2>&1; then echo "OK   merge de una rama con código: verde"; else echo "FALLA caso 3: el merge de una rama debía ser verde"; fallos=$((fallos+1)); fi
    # 4. docs directo con tilde y espacio en el nombre -> verde; código con espacio -> rojo
    g reset -q --hard "$base"; mkdir -p "$T/docs"; echo n > "$T/docs/á b.txt"; g add .; g commit -q -m "docs: nombre raro"
    if (cd "$T" && revisar "$base" "$(git rev-parse HEAD)") >/dev/null 2>&1; then echo "OK   docs con tilde y espacio: verde"; else echo "FALLA caso 4: docs/á b.txt debía ser verde"; fallos=$((fallos+1)); fi
    g reset -q --hard "$base"; echo a > "$T/a.md docs.js"; g add .; g commit -q -m "feat: nombre con espacio"
    if (cd "$T" && revisar "$base" "$(git rev-parse HEAD)") >/dev/null 2>&1; then echo "FALLA caso 5: 'a.md docs.js' debía ser rojo"; fallos=$((fallos+1)); else echo "OK   código con espacio en el nombre: rojo"; fi
    # 6. commit anterior inexistente -> falla, no da verde en silencio
    if (cd "$T" && revisar "1111111111111111111111111111111111111111" "$(git rev-parse HEAD)") >/dev/null 2>&1; then echo "FALLA caso 6: antes inexistente debía fallar"; fallos=$((fallos+1)); else echo "OK   commit anterior inexistente: falla"; fi
    [ "$fallos" -eq 0 ]
}

case "${1:-}" in
    revisar) revisar "${2:?sha_antes}" "${3:?sha_despues}" ;;
    autoprueba) autoprueba && echo "CI_SOLO_DOCS_AUTOPRUEBA_OK" || { echo "CI_SOLO_DOCS_AUTOPRUEBA_FALLA"; exit 1; } ;;
    *) echo "uso: $0 revisar <antes> <despues> | autoprueba" >&2; exit 2 ;;
esac
