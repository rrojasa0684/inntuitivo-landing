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
caso 0 '{"ssh_key_id": 5, "nombre": "llave"}'      # 21-nov: la cadena dentro de un identificador o de un texto pasa
caso 0 'ssh_key_id = 3; droplet.ssh_keys = []'
caso 0 'print("la clave ssh del servidor")'
caso 0 'run("ssh-add -l")'
caso 0 'print("la clave ssh del servidor", "ssh_key_id")'
caso 0 'run("echo hola; ssh-add -l")'
caso 0 'run("rm -rf ./out/../out/tmp")'
caso 2 'run("ssh root@host ls")'
caso 2 'run("scp x root@host:/tmp")'      # 21-nov: scp pasó de «debe pasar» a «bloquea»
caso 2 'run("ls; ssh h")'
caso 2 'run("x && scp a b")'
caso 2 'run("echo $(ssh h)")'
caso 2 'run("a | sftp h")'
caso 2 'execFileSync("ssh", ["h"])'
caso 2 'subprocess.run(["scp", "a", "b"])'
caso 2 'run("sudo ssh h")'
caso 2 'run("/usr/bin/ssh h")'
caso 2 'run("ssh-add ~/k")'
caso 2 'run("ssh-add -D")'
caso 2 'run("ssh-add -l; ssh-add k")'
caso 2 'run("ssh-keygen -t ed25519")'
caso 2 'run("ls\\nssh root@host")'      # revisión Opus 21-nov
caso 2 'run("ls\\tssh h")'      # revisión Opus 21-nov
caso 2 'run("env A=1 ssh h")'      # revisión Opus 21-nov
caso 2 'run("A=1 ssh h")'      # revisión Opus 21-nov
caso 2 'run("p=ssh; $p root@host")'      # revisión Opus 21-nov
caso 2 'run("GIT_SSH_COMMAND=ssh git fetch")'      # revisión Opus 21-nov
caso 2 'run("ssh-copy-id root@host")'      # revisión Opus 21-nov
caso 2 'run("sshpass -p clave ssh root@host")'      # revisión Opus 21-nov
caso 2 'print("x"); a="s"; b="sh"; run(a+b+" h")'      # revisión Opus 21-nov
caso 2 'run("echo"); c=["s","sh"].join("")'      # revisión Opus 21-nov
caso 2 'run("timeout 5 ssh h")'      # revisión Opus 21-nov
caso 2 'run("sudo -u root ssh h")'      # revisión Opus 21-nov
caso 2 'run("nice -n 10 ssh h")'      # revisión Opus 21-nov
caso 2 'run("eval ssh h")'      # revisión Opus 21-nov
caso 2 'run("if ssh h; then ls; fi")'      # revisión Opus 21-nov
caso 2 'run("! ssh h")'      # revisión Opus 21-nov
caso 2 'run("rsync -e ssh x root@host:/srv")'      # revisión Opus 21-nov
caso 2 'run("autossh h")'      # revisión Opus 21-nov
caso 2 'run("cd ~/.ssh;echo k>>authorized_keys")'      # revisión Opus 21-nov
caso 2 'run("cd ~/.ssh\\necho k >> authorized_keys")'      # revisión Opus 21-nov
caso 2 'os.path.join(h, ".s"+"sh", "authorized_keys")'      # revisión Opus 21-nov
caso 2 'Path.home()/(".s"+"sh")/"authorized_keys"'      # revisión Opus 21-nov
caso 2 'run("ssh-add -l -D")'      # revisión Opus 21-nov
caso 2 'run("ssh-add -l;ssh-add x")'      # revisión Opus 21-nov
caso 2 'os.system(f"{x}ssh root@143.198.189.178 uptime")'      # revisión Opus 21-nov, segunda ronda
caso 2 'run(`${x}ssh host`)'      # revisión Opus 21-nov, segunda ronda
caso 2 'os.path.join(os.path.expanduser("~"), "." + "ssh", "authorized_keys")'      # revisión Opus 21-nov, segunda ronda
caso 2 'run("caffeinate ssh root@h uptime")'      # revisión Opus 21-nov, segunda ronda
caso 2 'run("flock /tmp/l ssh root@h")'      # revisión Opus 21-nov, segunda ronda
caso 2 'run("find . -maxdepth 0 -exec ssh root@h x \\;")'      # revisión Opus 21-nov, segunda ronda
caso 2 'run("script -q /dev/null ssh root@h")'      # revisión Opus 21-nov, segunda ronda
caso 2 'run("git push ssh://root@143.198.189.178/srv/repo main")'      # revisión Opus 21-nov, segunda ronda
caso 2 'run("git clone ssh://h/r")'      # revisión Opus 21-nov, segunda ronda
caso 2 'run("timeout 5 ssh h")'      # revisión Opus 21-nov, segunda ronda
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
