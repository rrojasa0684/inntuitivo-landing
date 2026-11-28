#!/usr/bin/env bash
# Prueba el hook commit-msg en un repo temporal: con la línea (pasa), «ninguna — porque ...» (pasa), sin la línea (rechaza), «ninguna» sin causa (rechaza) y un merge (pasa).
# Salida: OK/FALLA por caso y GITHOOK_COMMIT_MSG_OK; exit 1 si alguno falla.
set -uo pipefail
D="$(cd "$(dirname "$0")" && pwd)"; HOOK="$D/commit-msg"; [ -f "$HOOK" ] || HOOK="$D/.githooks/commit-msg"
T="$(mktemp -d)"; trap 'find "$T" -depth -delete' EXIT; fallos=0
g() { git -C "$T" -c user.name=t -c user.email=t@t.test "$@"; }
git -C "$T" init -q -b main; mkdir "$T/.githooks"; cp "$HOOK" "$T/.githooks/commit-msg"; chmod +x "$T/.githooks/commit-msg"
n=0; nuevo() { n=$((n+1)); echo "$n" > "$T/f$n"; g add "f$n"; }
nuevo_doc() { n=$((n+1)); echo "$n" > "$T/d$n.md"; g add "d$n.md"; }
prepara=nuevo
g config core.hooksPath .githooks
pasa()    { $prepara; if g commit -q -m "$2" >/dev/null 2>"$T/e"; then echo "OK   $1"; else echo "FALLA $1: se rechazó: $(head -c 150 "$T/e")"; fallos=$((fallos+1)); fi; }
rechaza() { $prepara; if g commit -q -m "$2" >/dev/null 2>"$T/e"; then echo "FALLA $1: pasó y debía rechazarse"; fallos=$((fallos+1)); elif grep -q "COMMIT RECHAZADO" "$T/e"; then echo "OK   $1"; else echo "FALLA $1: falló pero no por el hook"; fallos=$((fallos+1)); fi; g reset -q 2>/dev/null; }
pasa    "con la línea Verificado" "feat: x

Verificado: verify (12 tests dirigidos ok, 48 s)

Co-Authored-By: a <a@a.test>"
prepara=nuevo_doc
pasa    "ninguna — porque ..." "docs: y

Verificado: ninguna — porque solo cambia un documento"
prepara=nuevo
rechaza "sin la línea" "feat: z"
rechaza "ninguna sin causa" "feat: z

Verificado: ninguna"
rechaza "asunto que empieza con Merge pero no es un merge" "Merge de cosas varias"
NINGUNA="feat: z

Verificado: ninguna — porque no se corrió nada"
rechaza "ninguna con un archivo de código" "$NINGUNA"
mixto() { nuevo_doc; nuevo; }; prepara=mixto
rechaza "ninguna con documento y código juntos" "$NINGUNA"
rechaza "Ninguna con mayúscula y código" "feat: z

Verificado:  Ninguna — porque no se corrió nada"
en_docs() { n=$((n+1)); mkdir -p "$T/docs"; echo "$n" > "$T/docs/f$n.txt"; g add "docs/f$n.txt"; }; prepara=en_docs
pasa    "ninguna con un archivo bajo docs/" "$NINGUNA"
movido() { nuevo; g -c core.hooksPath=/dev/null commit -q -m base; mkdir -p "$T/docs"; g mv "f$n" "docs/m$n"; }; prepara=movido
rechaza "ninguna al mover código a docs/" "$NINGUNA"
prepara=nuevo
# merge: los commits de preparación van sin hooks (core.hooksPath apagado solo para ellos)
sg() { g -c core.hooksPath=/dev/null "$@"; }
sg checkout -q -b rama; nuevo; sg commit -q -m base; sg checkout -q main; nuevo; sg commit -q -m otro
if g merge -q --no-ff rama >/dev/null 2>"$T/e"; then echo "OK   merge sin la línea (exento)"; else echo "FALLA merge: $(head -c 150 "$T/e")"; fallos=$((fallos+1)); fi
[ "$fallos" -eq 0 ] && echo "GITHOOK_COMMIT_MSG_OK" || { echo "GITHOOK_COMMIT_MSG_FALLA ($fallos)"; exit 1; }
