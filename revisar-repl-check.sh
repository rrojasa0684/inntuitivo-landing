#!/usr/bin/env bash
# 20-nov-2026: comprueba el hook de Code Mode (REPL): deja pasar lo normal y bloquea lo prohibido aunque venga armado. Es la misma lógica que el motor (tests/test_hook_revisar_repl.py).
set -u
cd "$(dirname "$0")"
fallas=0
caso() {  # esperado codigo
  local json rc
  json=$(python3 -c 'import json,sys;print(json.dumps({"tool_input":{"code":sys.argv[1]}}))' "$2")
  echo "$json" | bash .claude/hooks/revisar-repl.sh 2>/dev/null; rc=$?
  if [ "$rc" != "$1" ]; then echo "FALLA: esperaba $1 y salió $rc: $2"; fallas=$((fallas+1)); fi
}
caso 0 'print(1+1)'
caso 0 'run("git status")'
caso 0 'run("rm -rf ./out/tmp")'
caso 2 'run("ssh root@host")'
caso 2 'a="s"; b="sh"; run(a+b)'
caso 2 'run("git commit --no-" + "verify")'
caso 2 'run("gh pr " + "merge 5")'
caso 2 'run("gh auth login")'
caso 2 'run("gh api repos/x/y/pulls/1/reviews")'
caso 2 'run("cat platform.env")'
caso 2 'open("~/.ssh/id_ed25519","w")'
caso 2 'run("rm -rf /tmp/x")'
[ "$fallas" = 0 ] && echo "REVISAR_REPL_OK" || exit 1
