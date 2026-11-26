#!/usr/bin/env bash
# 25-nov-2026: ningún flujo queda con YAML inválido (datos-plan-limite-sync no corría) ni pidiendo WebKit en un runner que no puede instalarlo (en ubuntu-26.04, Playwright 1.47.2 pide libicu74, libvpx9, libx264-164 y
# libxml2, que no existen). Sin red ni instalar nada: lector de YAML de Ruby; con actionlint a mano (en workflows-check.yml, versión y huella fijas; o ACTIONLINT=ruta) revisa además la sintaxis de los flujos.
# Uso: bash ops/workflows-check.sh [carpeta]. Sale 1 y dice cuál.
set -euo pipefail
dir="${1:-$(cd "$(dirname "$0")/.." && pwd)/.github/workflows}"
fallas=0
for f in "$dir"/*.yml; do
  ruby -ryaml -e 'Psych.parse_stream(File.read(ARGV[0], encoding: "utf-8"))' "$f" >/dev/null 2>&1 || { echo "WORKFLOWS_FALLA: $f no es YAML válido"; fallas=1; }
  if grep -Eq 'playwright install.*webkit' "$f" && grep -E '^[[:space:]]*runs-on:' "$f" | grep -qv 'ubuntu-24\.04'; then
    echo "WORKFLOWS_FALLA: $f instala WebKit y no fija runs-on: ubuntu-24.04"; fallas=1
  fi
done
al="${ACTIONLINT:-$(command -v actionlint || true)}"
if [ -n "$al" ]; then "$al" -shellcheck= -pyflakes= "$dir"/*.yml || { echo "WORKFLOWS_FALLA: actionlint"; fallas=1; }; fi
[ "$fallas" -eq 0 ] && echo "WORKFLOWS_OK${al:+ (con actionlint)}"
exit "$fallas"
