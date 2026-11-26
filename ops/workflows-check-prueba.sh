#!/usr/bin/env bash
# Prueba de ops/workflows-check.sh: acepta un flujo sano y rechaza el YAML inválido del 25-nov y WebKit fuera de ubuntu-24.04.
set -uo pipefail
aqui="$(cd "$(dirname "$0")" && pwd)"
d="$(mktemp -d)"
caso() {   # caso <rc esperado> <texto del flujo>
  printf '%s\n' "$2" > "$d/f.yml"
  ACTIONLINT="" PATH="/usr/bin:/bin" bash "$aqui/workflows-check.sh" "$d" >/dev/null 2>&1; rc=$?
  [ "$rc" = "$1" ] || { echo "WORKFLOWS_PRUEBA_FALLA: rc=$rc (se esperaba $1) con: $2"; rm -f "$d/f.yml"; rmdir "$d"; exit 1; }
}
caso 0 $'name: a\non: push\njobs:\n  j:\n    runs-on: ubuntu-24.04\n    steps:\n      - run: npx playwright install --with-deps chromium webkit'
caso 0 $'name: a\non: push\njobs:\n  j:\n    runs-on: ubuntu-latest\n    steps:\n      - run: npx playwright install --with-deps chromium'
caso 1 $'name: a\non: push\njobs:\n  j:\n    runs-on: ubuntu-24.04\n    steps:\n      - name: paso (code review: sin comillas)\n        run: true'
caso 1 $'name: a\non: push\njobs:\n  j:\n    runs-on: ubuntu-latest\n    steps:\n      - run: npx playwright install --with-deps chromium webkit'
rm -f "$d/f.yml"; rmdir "$d"
echo "WORKFLOWS_PRUEBA_OK"
