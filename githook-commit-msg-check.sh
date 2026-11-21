#!/usr/bin/env bash
# Prueba el hook commit-msg en un repo temporal: con la línea (pasa), «ninguna — porque ...» (pasa), sin la línea (rechaza), «ninguna» sin causa (rechaza) y un merge (pasa).
# Salida: OK/FALLA por caso y GITHOOK_COMMIT_MSG_OK; exit 1 si alguno falla.
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"; HOOK="$D/commit-msg"; [ -f "$HOOK" ] || HOOK="$D/.githooks/commit-msg"
T="$(mktemp -d)"; trap 'find "$T" -depth -delete' EXIT; fallos=0
g() { git -C "$T" -c user.name=t -c user.email=t@t.test "$@"; }
git -C "$T" init -q -b main; mkdir "$T/.githooks"; cp "$HOOK" "$T/.githooks/commit-msg"; chmod +x "$T/.githooks/commit-msg"
n=0; nuevo() { n=$((n+1)); echo "$n" > "$T/f$n"; g add "f$n"; }
g config core.hooksPath .githooks
pasa()    { nuevo; if g commit -q -m "$2" >/dev/null 2>"$T/e"; then echo "OK   $1"; else echo "FALLA $1: se rechazó: $(head -c 150 "$T/e")"; fallos=$((fallos+1)); fi; }
rechaza() { nuevo; if g commit -q -m "$2" >/dev/null 2>"$T/e"; then echo "FALLA $1: pasó y debía rechazarse"; fallos=$((fallos+1)); elif grep -q "COMMIT RECHAZADO" "$T/e"; then echo "OK   $1"; else echo "FALLA $1: falló pero no por el hook"; fallos=$((fallos+1)); fi; }
pasa    "con la línea Verificado" "feat: x

Verificado: verify (12 tests dirigidos ok, 48 s)

Co-Authored-By: a <a@a.test>"
pasa    "ninguna — porque ..." "docs: y

Verificado: ninguna — porque solo cambia un documento"
rechaza "sin la línea" "feat: z"
rechaza "ninguna sin causa" "feat: z

Verificado: ninguna"
# merge: los commits de preparación van sin hooks (core.hooksPath apagado solo para ellos)
sg() { g -c core.hooksPath=/dev/null "$@"; }
sg checkout -q -b rama; nuevo; sg commit -q -m base; sg checkout -q main; nuevo; sg commit -q -m otro
if g merge -q --no-ff rama >/dev/null 2>"$T/e"; then echo "OK   merge sin la línea (exento)"; else echo "FALLA merge: $(head -c 150 "$T/e")"; fallos=$((fallos+1)); fi
[ "$fallos" -eq 0 ] && echo "GITHOOK_COMMIT_MSG_OK" || { echo "GITHOOK_COMMIT_MSG_FALLA ($fallos)"; exit 1; }
