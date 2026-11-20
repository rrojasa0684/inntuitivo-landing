#!/usr/bin/env bash
# 20-nov-2026: comprueba el hook de Code Mode (REPL) de esta landing: está registrado en .claude/settings.json con matcher REPL, el script corre y la lógica deja pasar lo normal y bloquea lo prohibido aunque
# venga armado (concatenación, variables, plantillas). Mismos casos que tests/test_hook_revisar_repl.py del motor. Salida: REVISAR_REPL_OK.
set -u
cd "$(dirname "$0")"
RAIZ=$(pwd)
fallas=0
caso() {  # esperado(0 pasa, 2 bloquea) codigo
  local json rc
  json=$(python3 -c 'import json,sys;print(json.dumps({"tool_name":"REPL","tool_input":{"code":sys.argv[1]}}))' "$2")
  echo "$json" | bash .claude/hooks/revisar-repl.sh >/dev/null 2>&1; rc=$?
  if [ "$rc" != "$1" ]; then echo "FALLA: esperaba $1 y salió $rc: $2"; fallas=$((fallas+1)); fi
}
python3 - <<'PY' || fallas=$((fallas+1))
import json
cfg = json.load(open(".claude/settings.json", encoding="utf-8"))
ok = any(h.get("matcher") == "REPL" and ".claude/hooks/revisar-repl.sh" in h["hooks"][0]["command"] for h in cfg.get("hooks", {}).get("PreToolUse", []))
assert ok and "Bash(gh pr review *)" in cfg["permissions"]["deny"], "FALLA: el hook REPL no está registrado en .claude/settings.json"
PY
[ -f .claude/hooks/revisar_repl.py ] || { echo "FALLA: falta .claude/hooks/revisar_repl.py"; fallas=$((fallas+1)); }
echo 'no es json' | bash .claude/hooks/revisar-repl.sh >/dev/null 2>&1 || { echo "FALLA: una entrada que no es JSON no debe bloquear"; fallas=$((fallas+1)); }
caso 0 'print(1 + 1)'
caso 0 'const r = await bash("ls out")'
caso 0 'run("git status")'
caso 0 'run("rm -rf ./out/tmp")'
caso 0 "run(\"rm -rf $RAIZ/out/tmp\")"
caso 0 'run("git commit -m \"cambio\"")'
caso 0 'run("gh pr view 5")'
caso 0 'run("gh api repos/x/y/issues")'
caso 0 'const environment = process.env.HOME'
caso 0 'class Handler: pass'
caso 0 'glass_house = press_hold = 1'
caso 0 'run("scp x root@host:/tmp")'
caso 0 'run("rm -rf ./out/../out/tmp")'
caso 2 'run("ssh root@host ls")'
caso 2 'a="s"; b="sh"; run(a+b+" host")'
caso 2 'run("s" + "sh root@host")'
caso 2 'run("git commit --no-verify -m x")'
caso 2 'run("git commit --no-" + "verify")'
caso 2 'flag = ["--no", "verify"].join("-")'
caso 2 'run("gh pr review 5 --approve")'
caso 2 'run("gh pr merge 5")'
caso 2 'run("gh pr " + "merge 5")'
caso 2 'run("gh auth login")'
caso 2 'run("gh api repos/x/y/pulls/1/reviews")'
caso 2 'run("gh api -X PUT repos/x/y/pulls/1/merge")'
caso 2 'run("cat /srv/outreach-engine/platform.env")'
caso 2 'const n = ["platform", ".env"].join("")'
caso 2 'open(os.path.expanduser("~/.ssh/authorized_keys"), "w")'
caso 2 'run("rm -rf /tmp/x")'
caso 2 'run("rm -rf ~/Documents")'
caso 2 'run("rm -rf ../otro")'
caso 2 'p = "r" + "m -r" + "f /"; run(p)'
caso 2 'run("rm -rf ./../../Documents")'
caso 2 "run(\"rm -rf $RAIZ/../Library\")"
caso 2 'run("rm --recursive --force /tmp/x")'
caso 2 'run("rm -rf ./out; cd ~; rm -rf Documents")'
caso 2 'subprocess.run(["rm", "-rf", "/Users/ricardorojasaraya/Documents"])'
caso 2 'execFileSync("rm", ["-rf", "/x"])'
caso 2 'run("rm-rf/users/x")'
caso 2 'run(`${"s"}sh root@host`)'
caso 2 "run(\"rm -rf $RAIZ\")"
caso 2 'require("fs").rmSync("/Users/x",{recursive:true})'
caso 2 'shutil.rmtree("/Users/x")'
[ "$fallas" = 0 ] && echo "REVISAR_REPL_OK" || exit 1
