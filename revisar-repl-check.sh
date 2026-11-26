#!/usr/bin/env bash
# 20-nov-2026: comprueba el hook de Code Mode (REPL) de esta landing: está registrado en .claude/settings.json con matcher REPL, el script corre y la lógica deja pasar lo normal y bloquea lo prohibido aunque
# venga armado (concatenación, variables, plantillas). Corre TODAS las listas de casos de tests/test_hook_revisar_repl.py del motor desde su copia idéntica (.claude/hooks/casos_del_motor.py; el test del motor
# exige que sea igual) y además los casos sueltos de abajo. Salida: REVISAR_REPL_OK.
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
caso 0 'run("rm -f out/respaldo.dump")'      # 22-nov: un borrado sin recursión pasa
caso 0 'run("rm -f \\"$RESPALDO\\"")'      # 22-nov: «rm -f» más un nombre que empieza con «r» no es el recursivo pegado
caso 0 'run("mv -f a b; rm -f /tmp/x")'
caso 0 'run("docker run --rm -v \"$(pwd)\":/x img")'      # 25-nov: --rm de docker run no es un borrado
caso 0 'run("docker compose run --rm app pytest")'
caso 2 'run("docker run --rm -rf /")'
caso 2 'run("docker run --rm -v /:/h img rm -r /h")'
caso 2 'run("rm -r foo/$D")'
caso 2 'run("rm -r `pwd`")'
caso 2 'run("alias d=rm; d -rf /")'
caso 2 'run("R=$(which rm); $R -rf /")'
caso 2 'run("ssh root@host ls")'
for c in 'timeout -s KILL ssh h' 'timeout -s KILL 5 ssh h' 'timeout -k 5 10 ssh h' 'timeout 5s ssh h' 'nice -n 10 ssh h' 'ionice -c 3 ssh h' 'env -u VAR ssh h' 'nohup nice -n 5 timeout -s KILL 9 ssh h'; do caso 2 "run(\"$c\")"; done      # 21-nov noche: opciones con argumento antes del comando
caso 0 'run("timeout -s KILL 5 ls")'
caso 0 'run("env -u VAR printenv")'
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
caso 2 'const n=String.fromCharCode(10), sp=String.fromCharCode(32); await $("rm -f a.txt"+n+"rm"+sp+"-rf"+sp+"/Users/x")'      # revisión Opus 22-nov: un rm -f no esconde el recursivo armado después
caso 2 'subprocess.run("rm -f " + chr(45) + "rf /Users/x", shell=True)'      # revisión Opus 22-nov (2): la opción -r armada después de «rm -f»
caso 2 'd="-"; run("rm -f "+d+"rf /x")'
caso 2 'subprocess.run("rm -f " + chr(45) + "fr /Users/x", shell=True)'      # revisión Opus 22-nov (ronda 2): opciones cuya primera letra no es r
caso 2 'subprocess.run("rm -f  " + chr(45) + "rf /Users/x", shell=True)'
caso 2 'subprocess.run("rm -v " + chr(45) + "rf /Users/x", shell=True)'
caso 2 'os.system("""rm -f\
r /etc""")'      # revisión Opus 22-nov (ronda 3): continuación de línea de la shell
caso 2 'os.system("""rm -f -\
r /etc""")'
caso 2 'os.system("rm -f%c /etc" % 114)'
caso 2 'run("rm -f {-r,} /tmp/x")'      # revisión Opus 22-nov (ronda 4): expansión de llaves
caso 2 'R=-r; run("rm -f $R /tmp/x")'      # opción escondida en una variable
caso 2 'run("rm \\x2dr /etc")'      # 22-nov noche: opción -r escondida en hex, unicode, octal, subshell o base64
caso 2 'run("rm \\u002dr /etc")'
caso 2 'run("rm \\055r /etc")'
caso 2 'run("rm $(printf '"'"'\\055r'"'"') /etc")'
caso 2 'run("rm $(echo LXI= | base64 -d) /etc")'
caso 0 'run("rm -f out/x.dump")'
caso 2 'spawnSync("rm", [o, "/x"])'      # 22-nov noche (revisión Opus): identificador suelto en la lista, variable con espacios y opción larga abreviada
caso 2 'run("rm --recur /Users/x")'
caso 2 'flag = "-r"
subprocess.run(["rm", flag, "/Users/x"])'
python3 - <<'PY' || fallas=$((fallas+1))
# las listas de casos del motor, evaluadas con la raíz de esta landing (pytest se sustituye: aquí solo interesan las listas)
import json, subprocess, sys
from pathlib import Path
from unittest.mock import MagicMock
sys.modules["pytest"] = MagicMock()
m = {"__file__": str(Path.cwd() / "tests" / "casos.py"), "__name__": "casos"}
exec(compile(Path(".claude/hooks/casos_del_motor.py").read_text(encoding="utf-8"), "casos_del_motor", "exec"), m)
listas = {0: ["DEBEN_PASAR", "FALSOS_POSITIVOS_RM", "DOCKER_RM_PASA", "REVIEW_25NOV_PASA"],
          2: ["DEBEN_BLOQUEARSE", "SIGUEN_BLOQUEADOS_RM", "HUECOS_RM_24NOV", "DOCKER_RM_BLOQUEA", "REVISION_25NOV_BLOQUEA", "REVIEW_25NOV_BLOQUEA"]}
sin_lista = {k for k, v in m.items() if k.isupper() and isinstance(v, list)} - {n for v in listas.values() for n in v}
mal, n = [f"lista del motor que este chequeo no corre: {k}" for k in sorted(sin_lista)], 0
for esperado, nombres in listas.items():
    for nombre in nombres:
        for caso in m[nombre]:
            codigo = caso if isinstance(caso, str) else caso[0]
            rc = subprocess.run(["bash", ".claude/hooks/revisar-repl.sh"], input=json.dumps({"tool_input": {"code": codigo}}), capture_output=True, text=True, timeout=30).returncode
            n += 1
            if rc != esperado:
                mal.append(f"esperaba {esperado} y salió {rc}: {codigo[:150]!r}")
print("\n".join("FALLA: " + x for x in mal) or f"casos del motor: {n} ok")
sys.exit(1 if mal or n < 200 else 0)
PY
[ "$fallas" = 0 ] && echo "REVISAR_REPL_OK" || exit 1
