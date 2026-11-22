"""20-nov-2026: revisa el código que Code Mode manda a la herramienta REPL (hook PreToolUse). Lee el JSON de la llamada por stdin; sale 2 (bloquea) si el código contiene algo prohibido,
aunque esté partido, concatenado o armado con variables: se mira el texto, el texto sin comillas ni «+», el texto reducido a letras y números y los literales de texto pegados en orden.
Prefiere bloquear de más. Las reglas deny y ask de Claude Code no cambian."""
from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

REPO = str(Path(__file__).resolve().parents[2]).lower() + "/"      # la raíz del repo donde vive el hook (el motor o la landing: el mismo script en los dos)
# 21-nov-2026: ssh, scp, sftp y sus parientes se bloquean COMO COMANDO (inicio, tras ; | & ( = $ ! comilla, corchete, un salto escrito como \\n, una palabra de shell como sudo/timeout/if/eval, una asignación A=1, o -e de rsync),
# nunca dentro de un identificador ni de un texto corrido; «ssh-add -l» pasa. Aparte, un «ssh» armado con literales pegados se bloquea siempre (ver pegados).
ENVOLTURAS = r"(?:sudo|doas|env|exec|command|nohup|xargs|time|timeout|nice|eval|if|then|else|do|while|until|setsid|watch|stdbuf|sshpass|rsync|ionice|chroot|bash|sh|zsh|caffeinate|busybox|unbuffer|taskpolicy|arch|script|runuser|su|sg|strace|ltrace|tmux|screen|parallel|firejail|proxychains|torsocks|dtruss|chronic|nsenter)"
POSICIONAL = r"(?:flock|lockf|setpriv|cpulimit)"      # envolturas con un argumento posicional antes del comando (flock /tmp/l ssh h)
COMANDO = re.compile(r"(?:^|[;|&(`\"'\[,{}=$!)]|\\[ntr]|\s-e\s)\s*(?:" + ENVOLTURAS + r"\s+(?:-\S+\s+(?:(?!" + ENVOLTURAS + r"\b)[A-Za-z_]\w*\s+)?|\d+(?:\.\d+)?[smhd]?\s+)*|" + POSICIONAL + r"\s+(?:-\S+\s+)*[\w./:-]+\s+)*(?:\w+=\S*\s+)*(?:[\w.~-]*/)*"
                     r"(?!ssh-add\s+-l\s*(?:$|[;|&\n\"'`)\]]|\\n))(?:ssh(?:-[a-z]+)*|sshpass|autossh|scp|sftp)(?![\w-])", re.M)
NOMBRES = re.compile(r"\.ssh|ssh|scp|sftp")
FORMA = re.compile(r"ssh://|ssh\s+(?:-[a-z]|[\w.-]+@|\d+\.\d+\.)")      # ssh con opción, usuario@host, IP o URL: en cualquier posición (caffeinate ssh h, git push ssh://...)


def pegados(codigo: str) -> bool:
    """Un nombre de los de arriba que cruza el borde entre dos literales de texto (armado: «s» + «sh», «x» + «s» + «sh») se bloquea siempre; un literal suelto con la palabra no."""
    trozos = [a or b for a, b in re.findall(r"\"([^\"]*)\"|'([^']*)'", codigo.lower())]
    bordes, n = set(), 0
    for t in trozos:
        n += len(t)
        bordes.add(n)
    return any(any(m.start() < b < m.end() for b in bordes) for m in NOMBRES.finditer("".join(trozos)))


PRIMERO = {"ssh": "ssh", "noverify": "--no-verify", "ghprreview": "gh pr review", "ghprmerge": "gh pr merge", "ghauth": "gh auth", "platformenv": "platform.env"}


def vistas(codigo: str) -> list[str]:
    """Las formas en que puede aparecer el texto: normal, sin comillas/«+»/barras, y los literales pegados."""
    bajo = codigo.lower()
    junto = re.sub(r"[\x27\"`+\\]|\$\{|\}", "", bajo)
    literales = "".join(a or b for a, b in re.findall(r"\"([^\"]*)\"|'([^']*)'", bajo))
    return [bajo, junto, literales]


def reducido(txt: str) -> str:
    return re.sub(r"[^a-z0-9]", "", txt)


def _destino_fuera(d: str) -> bool:
    """Un destino de rm es seguro solo si, normalizado (~ y «..» resueltos), queda bajo el repo o es relativo sin salir hacia arriba."""
    d = os.path.expanduser(d)
    if d.startswith("$"):
        return True
    n = os.path.normpath(d)
    if d.startswith("/"):
        return not ((n + "/").startswith(REPO) and n + "/" != REPO)      # la raíz del repo en sí no se borra
    return n == ".." or n.startswith("../")


def rm_fuera_del_repo(codigo: str) -> bool:
    visto = False
    for txt in vistas(codigo):      # incluye los literales pegados (armado con variables)
        sale_del_repo = re.search(r"\bcd\s+(?:~|/|\.\.|\$)", txt) is not None and re.search(r"\bcd\s+" + re.escape(REPO), txt) is None
        for m in re.finditer(r"\brm[\s,\[]+([^;&|\n]*)", txt):      # también la forma de lista: ["rm", "-rf", "/x"]
            tokens = [t for t in re.split(r"[\s,\[\]()]+", m.group(1)) if t]
            flags = [t for t in tokens if t.startswith("-")]
            if not any(f == "--recursive" or (not f.startswith("--") and "r" in f) for f in flags):
                continue
            visto = True
            destinos = [t for t in tokens if not t.startswith("-")]
            if not destinos or sale_del_repo or any(_destino_fuera(d) for d in destinos):
                return True
    # rm -rf armado de modo que ningún rm completo se ve (rm-rf/x pegado): se bloquea salvo que ya se haya visto un rm recursivo bien formado
    return not visto and any(re.search(r"rm(rf|fr)", reducido(v)) for v in vistas(codigo))


def razones(codigo: str) -> list[str]:
    out: list[str] = []
    vs = vistas(codigo)
    letras = [reducido(v) for v in vs]
    if any(COMANDO.search(v) or FORMA.search(v) for v in vs) or pegados(codigo):
        out.append("ssh, scp o sftp")
    for clave, etiqueta in PRIMERO.items():
        if clave != "ssh" and any(clave in r for r in letras):
            out.append(etiqueta)
    if any("ghapi" in r and ("reviews" in r or "merge" in r) for r in letras):
        out.append("gh api con reviews o merge")
    if any(re.search(r"(?<!\w)\.ssh(?!\w)", v) for v in vs):
        out.append("escritura en ~/.ssh")
    if rm_fuera_del_repo(codigo) or any("rmsync" in r or "rmtree" in r for r in letras):
        out.append("rm -rf fuera del repo")
    return sorted(set(out))


def main() -> int:
    try:
        d = json.load(sys.stdin)
    except ValueError:
        return 0
    ti = d.get("tool_input") if isinstance(d, dict) else None
    codigo = ti.get("code") if isinstance(ti, dict) else None
    if not isinstance(codigo, str):
        codigo = json.dumps(ti, ensure_ascii=False)
    r = razones(codigo)
    if r:
        sys.stderr.write("BLOQUEADO por ops/hooks/revisar-repl.sh: el código de Code Mode contiene " + ", ".join(r) + ". Usa la herramienta Bash con su regla deny o ask, o pídele a Ricardo.\n")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
