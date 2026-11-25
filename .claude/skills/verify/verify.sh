#!/usr/bin/env bash
# verify de la landing (21-nov-2026): sus chequeos locales y los enlaces internos de sus páginas, bajo 3 min. NUNCA: red, chequeo en vivo (eso lo corre el cierre del cambio), deploy ni la medición de Umami.
set -uo pipefail
cd "$(git rev-parse --show-toplevel)"
T0=$(date +%s); fallos=0
for c in breakpoints-check.sh cta-activacion-fuera-de-sitio-check.sh cta-color-por-accion-check.sh geo-paises-compartidos-check.sh precio-competencia-check.sh textos-actuales-check.sh pipefail-grep-check.sh demo-onboarding-check.sh readme-nombres-check.sh ops/avisar-lista-check.sh; do
  t=$(date +%s); echo "$ bash $c"; if bash "$c" >/tmp/verify.$$ 2>&1; then echo "  -> rc=0 ($(( $(date +%s) - t )) s)"; else echo "  -> FALLA ($(( $(date +%s) - t )) s)"; tail -n 5 /tmp/verify.$$ | sed 's/^/    /'; fallos=$((fallos+1)); fi
done
echo "$ python3 ops/version-cache.py --check"; if python3 ops/version-cache.py --check >/tmp/verify.$$ 2>&1; then echo "  -> rc=0"; else echo "  -> FALLA"; sed 's/^/    /' /tmp/verify.$$; fallos=$((fallos+1)); fi
echo "$ enlaces internos de las páginas (href locales deben existir)"; n=0
for p in $(ls *.html panel/*.html 2>/dev/null | LC_ALL=C sort); do
  for h in $(grep -oE 'href="[^"#?]+' "$p" | sed 's/href="//' | grep -vE '^(https?:|mailto:|tel:|javascript:|data:|//)|[+{}$\x27]' | LC_ALL=C sort -u); do
    case "$h" in /*) d=".$h";; *) d="$(dirname "$p")/$h";; esac; n=$((n+1))
    [ -e "$d" ] || [ -e "$d/index.html" ] || [ -e "$d.html" ] || { echo "  ROTO: $p -> $h"; fallos=$((fallos+1)); }
  done
done
echo "  -> $n enlaces revisados"
D=$(( $(date +%s) - T0 )); echo "VERIFY duración=$D s tope=180 s"
[ "$D" -le 180 ] || fallos=$((fallos+1))
[ "$fallos" -eq 0 ] && echo "VERIFY OK" || { echo "VERIFY FALLA ($fallos)"; exit 1; }
