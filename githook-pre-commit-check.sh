#!/usr/bin/env bash
# Ciclo de desarrollo (decisión #44, 27-oct-2026): prueba el hook .githooks/pre-commit en un repo temporal (código sobre main rechazado, docs sobre main permitido,
# código en feat/ permitido, un renombre de código a docs/ rechazado, un merge no bloqueado) y, con --clon, falla si core.hooksPath no es .githooks en este clon.
# Uso: bash githook-pre-commit-check.sh [--clon]
set -euo pipefail
RAIZ="$(cd "$(dirname "$0")" && pwd)"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fallos=0
ok()  { echo "OK   $1"; }
mal() { echo "FALLA $1"; fallos=$((fallos+1)); }
g() { git -C "$T" -c user.name=t -c user.email=t@t.test "$@"; }

git -C "$T" init -q -b main
mkdir "$T/.githooks"; cp "$RAIZ/.githooks/pre-commit" "$T/.githooks/pre-commit"; chmod +x "$T/.githooks/pre-commit"
g config core.hooksPath .githooks
echo x > "$T/README.md"; g add README.md; g commit -q -m "docs: inicio" && ok "docs sobre main permitido (README.md)" || mal "docs sobre main permitido"

mkdir -p "$T/js"; echo "a=1" > "$T/js/a.js"; echo "a=1" > "$T/index.html"
g add js/a.js
if g commit -q -m "feat: codigo" 2>"$T/err"; then mal "codigo sobre main rechazado (js/a.js pasó)"; else grep -q "js/a.js" "$T/err" && ok "codigo sobre main rechazado (js/a.js)" || mal "rechazo sin nombrar el archivo"; fi
g reset -q; g add index.html
if g commit -q -m "feat: html" 2>/dev/null; then mal "index.html sobre main rechazado"; else ok "index.html sobre main rechazado"; fi
g reset -q; rm -f "$T/index.html"

mkdir -p "$T/docs"; echo n > "$T/docs/nota.md"; g add docs/nota.md
g commit -q -m "docs: nota" && ok "docs/ sobre main permitido" || mal "docs/ sobre main permitido"

g checkout -q -b feat/tema; g add js/a.js
g commit -q -m "feat: codigo" && ok "codigo en feat/ permitido" || mal "codigo en feat/ permitido"
g checkout -q main
g merge -q --no-ff -m "merge: tema" feat/tema && [ -f "$T/js/a.js" ] && ok "merge a main no bloqueado" || mal "merge a main no bloqueado"

# merge con conflicto cerrado a mano: es el único camino que ejecuta pre-commit con MERGE_HEAD
g checkout -q -b feat/a; echo "linea-a" >> "$T/js/a.js"; g commit -q -am "feat: a"
g checkout -q main; echo "linea-main" >> "$T/js/a.js"; g checkout -q -b feat/b; g commit -q -am "feat: b"
g checkout -q main; g merge -q feat/b; g merge -q feat/a 2>/dev/null || true
echo "resuelto" > "$T/js/a.js"; g add js/a.js
g commit -q --no-edit && ok "merge con conflicto cerrado a mano sobre main permitido" || mal "merge con conflicto cerrado a mano sobre main permitido"

g mv js/a.js docs/a.js
if g commit -q -m "docs: movido" 2>"$T/err"; then mal "renombre de codigo a docs/ rechazado"; else grep -q "js/a.js" "$T/err" && ok "renombre de codigo a docs/ rechazado" || mal "renombre rechazado sin nombrar el origen"; fi

if [ "${1:-}" = "--clon" ]; then
    hp="$(git -C "$RAIZ" config core.hooksPath || true)"
    [ "$hp" = ".githooks" ] && ok "core.hooksPath activo en este clon" || mal "core.hooksPath no es .githooks en este clon; actívalo con: git config core.hooksPath .githooks"
fi
[ "$fallos" -eq 0 ] && echo "GITHOOK_OK" || { echo "GITHOOK_FALLA ($fallos)"; exit 1; }
