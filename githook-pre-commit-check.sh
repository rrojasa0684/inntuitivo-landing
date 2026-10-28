#!/usr/bin/env bash
# Ciclo de desarrollo (decisión #44, 27-oct-2026): prueba el hook .githooks/pre-commit en un repo temporal (código sobre main rechazado, docs sobre main permitido,
# código en feat/ permitido, un renombre de código a docs/ rechazado, un merge no bloqueado) y, con --clon, falla si core.hooksPath no es .githooks en este clon.
# 28-oct-2026: un rechazo solo cuenta si el que rechazó es el hook (su mensaje «COMMIT RECHAZADO...» y el archivo ofensor listado); cualquier otro fallo de git es FALLA con su causa.
# Ningún paso corta en silencio: cada caso imprime OK o FALLA <caso>: <por qué>.
# Uso: bash githook-pre-commit-check.sh [--clon]      (GITHOOK_RUTA=<ruta> prueba otro hook, p. ej. uno desactivado, para comprobar que este chequeo falla)
set -uo pipefail
RAIZ="$(cd "$(dirname "$0")" && pwd)"
HOOK="${GITHOOK_RUTA:-$RAIZ/.githooks/pre-commit}"
MSG="COMMIT RECHAZADO: sobre main solo se commitea documentación"
T="$(mktemp -d)"; trap 'rm -rf "$T"' EXIT
fallos=0
ok()  { echo "OK   $1"; }
mal() { echo "FALLA $1"; fallos=$((fallos+1)); }
g() { git -C "$T" -c user.name=t -c user.email=t@t.test "$@"; }
# preparación: si falla, se dice cuál comando y qué dijo git (antes `set -e` cortaba sin mensaje)
paso() { g "$@" >/dev/null 2>"$T/paso.err" || mal "preparación: git $* -- $(head -c 200 "$T/paso.err")"; }
# commit que debe pasar
permitido() { local caso="$1"; shift; if g commit -q "$@" >/dev/null 2>"$T/err"; then ok "$caso"; else mal "$caso: el commit se rechazó: $(head -c 200 "$T/err")"; fi; }
# commit que debe rechazar EL HOOK, nombrando el archivo ofensor
rechazado() {
    local caso="$1" archivo="$2"; shift 2
    if g commit -q "$@" >/dev/null 2>"$T/err"; then mal "$caso: el commit pasó y debía rechazarse"; return; fi
    if grep -qF "$MSG" "$T/err" && grep -qxF "  $archivo" "$T/err"; then ok "$caso"
    else mal "$caso: git falló, pero NO por el hook (falta su mensaje o el archivo '$archivo'): $(head -c 200 "$T/err")"; fi
}

[ -f "$HOOK" ] || { echo "FALLA no existe el hook a probar: $HOOK"; exit 1; }
git -C "$T" init -q -b main || { echo "FALLA no se pudo crear el repo temporal"; exit 1; }
mkdir "$T/.githooks"; cp "$HOOK" "$T/.githooks/pre-commit"; chmod +x "$T/.githooks/pre-commit"
paso config core.hooksPath .githooks
echo x > "$T/README.md"; paso add README.md
permitido "docs sobre main permitido (README.md)" -m "docs: inicio"

mkdir -p "$T/js"; echo "a=1" > "$T/js/a.js"; echo "a=1" > "$T/index.html"
paso add js/a.js
rechazado "codigo sobre main rechazado (js/a.js)" "js/a.js" -m "feat: codigo"
paso reset -q; paso add index.html
rechazado "index.html sobre main rechazado" "index.html" -m "feat: html"
paso reset -q; rm -f "$T/index.html"

mkdir -p "$T/docs"; echo n > "$T/docs/nota.md"; paso add docs/nota.md
permitido "docs/ sobre main permitido" -m "docs: nota"

paso checkout -q -b feat/tema; paso add js/a.js
permitido "codigo en feat/ permitido" -m "feat: codigo"
paso checkout -q main
if g merge -q --no-ff -m "merge: tema" feat/tema >/dev/null 2>"$T/err" && [ -f "$T/js/a.js" ]; then ok "merge a main no bloqueado"
else mal "merge a main no bloqueado: $(head -c 200 "$T/err")"; fi

# merge con conflicto cerrado a mano: es el único camino que ejecuta pre-commit con MERGE_HEAD
paso checkout -q -b feat/a; echo "linea-a" >> "$T/js/a.js"; paso commit -q -am "feat: a"
paso checkout -q main; echo "linea-main" >> "$T/js/a.js"; paso checkout -q -b feat/b; paso commit -q -am "feat: b"
paso checkout -q main; paso merge -q feat/b
g merge -q feat/a >/dev/null 2>&1 || true      # el conflicto es el objetivo
if [ -f "$(git -C "$T" rev-parse --absolute-git-dir)/MERGE_HEAD" ]; then
    echo "resuelto" > "$T/js/a.js"; paso add js/a.js
    permitido "merge con conflicto cerrado a mano sobre main permitido" --no-edit
else mal "merge con conflicto cerrado a mano: no se generó el conflicto de preparación"; fi

paso mv js/a.js docs/a.js
rechazado "renombre de codigo a docs/ rechazado" "js/a.js" -m "docs: movido"

if [ "${1:-}" = "--clon" ]; then
    hp="$(git -C "$RAIZ" config core.hooksPath || true)"
    [ "$hp" = ".githooks" ] && ok "core.hooksPath activo en este clon" || mal "core.hooksPath no es .githooks en este clon; actívalo con: git config core.hooksPath .githooks"
fi
[ "$fallos" -eq 0 ] && echo "GITHOOK_OK" || { echo "GITHOOK_FALLA ($fallos)"; exit 1; }
