"""20-nov-2026: revisa el código que Code Mode manda a la herramienta REPL (hook PreToolUse). Lee el JSON de la llamada por stdin; sale 2 (bloquea) si el código contiene algo prohibido,
aunque esté partido, concatenado o armado con variables: se mira el texto, el texto sin comillas ni «+», el texto reducido a letras y números y los literales de texto pegados en orden.
Prefiere bloquear de más. Las reglas deny y ask de Claude Code no cambian."""
from __future__ import annotations

import json
import os
import re
import shlex
import sys
from bisect import bisect_right
from pathlib import Path

REPO = str(Path(__file__).resolve().parents[2]).lower() + "/"      # la raíz del repo donde vive el hook (el motor o la landing: el mismo script en los dos)
# 21-nov-2026: ssh, scp, sftp y sus parientes se bloquean COMO COMANDO (inicio, tras ; | & ( = $ ! comilla, corchete, un salto escrito como \\n, una palabra de shell como sudo/timeout/if/eval, una asignación A=1, o -e de rsync),
# nunca dentro de un identificador ni de un texto corrido; «ssh-add -l» pasa. Aparte, un «ssh» armado con literales pegados se bloquea siempre (ver pegados).
ENVOLTURAS = r"(?:sudo|doas|fakeroot|builtin|env|exec|command|nohup|xargs|time|timeout|nice|eval|if|elif|coproc|then|else|do|while|until|setsid|watch|stdbuf|sshpass|rsync|ionice|chroot|bash|sh|zsh|caffeinate|busybox|unbuffer|taskpolicy|arch|script|runuser|su|sg|strace|ltrace|tmux|screen|parallel|firejail|proxychains|torsocks|dtruss|chronic|nsenter)"
POSICIONAL = r"(?:flock|lockf|setpriv|cpulimit)"      # envolturas con un argumento posicional antes del comando (flock /tmp/l ssh h)
REDIR = r"(?:\d*[<>]+[&\w./-]*[ \t]+){0,130}"      # 24-nov noche: redirecciones antes del comando (2>/dev/null rm, >x rm, <x rm, &>x rm)
PREFIJO = (r"(?:^|[;|&(`\"'\[,{}=$!)]|\\[ntr]|\s-e\s)[ \t]*" + REDIR + r"(?:" + ENVOLTURAS + r"[ \t]+(?:-\S+[ \t]+(?:(?!" + ENVOLTURAS + r"\b)[A-Za-z_]\w*[ \t]+)?|\d+(?:\.\d+)?[smhd]?[ \t]+){0,130}|" + POSICIONAL + r"[ \t]+(?:-\S+[ \t]+)*[\w./:-]+[ \t]+){0,130}(?:\w+=\S{0,1000}[ \t]+){0,130}(?:[\w.~-]*/)*")
COMANDO = re.compile(PREFIJO + r"(?!ssh-add\s+-l\s*(?:$|[;|&\n\"'`)\]]|\\n))(?:ssh(?:-[a-z]+)*|sshpass|autossh|scp|sftp)(?![\w-])", re.M)
# 24-nov-2026: rm cuenta solo COMO COMANDO (mismo prefijo que ssh, envolturas incluidas); «as rm», «rm.estado(...)» o un «rm» dentro de un grep ya no bloquean.
# 25-nov (code review): cuenta todo rm que no sea la cola de «--rm» u otra palabra, tras cualquier envoltorio (uv run, npx, docker exec); «)» y el acento grave también lo cierran ($(which rm) -r x)
RM_ARGS = re.compile(r"(?<![\w-])rm(?![\w.])[\s,\[)`]+([^;&|\n]*)", re.M)
RM_SUELTO = re.compile(r"\brm(?![\w.])[\s,\[)`]")      # 24-nov noche: en código que arma texto el rm cuenta sin prefijo, como antes del 24-nov
# texto que se concatena, interpola o recorta: con eso un destino que parece del repo puede acabar en otro lado
CONCATENA = re.compile(r"""\+|\.concat\(|join\(|\.format\(|(?<![\w-])r?f["']|%[-#0 +\d.(]*[sdrc]|\$\{|\.replace\(|\bre\.sub\(|\.slice\(|\.substr|\.split\(|\[[\s\w-]*:[\s\w-]*\]""")
# un literal que es exactamente «rm»: solo vale como arranque de una lista enteramente literal; asignado, agregado o concatenado esconde el comando
LISTA_RM = re.compile(r"""(?<!\\)(["'`])(?:[\w./~-]*/)?rm\1""")
SIGUE_LISTA = re.compile(r"\s*(?:\]\s*)?,")
ARGUMENTO = re.compile(r"""\(\s*(?:\[\s*)?(?:(?:"[^"\n]*"|'[^'\n]*')\s*,\s*(?:\[\s*)?)*$""")      # lo que va delante: «(», «([» y otros literales
LITERALES_SEGUIDOS = re.compile(r"""(?:[\s,\[]*(?:"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'))*[\s,]*\]?[ \t]*,?[ \t]*""")
CIERRE_LISTA = re.compile(r"$|[)};\n]|\{|[a-z_]\w*\s*=(?!=)")
IP_USUARIO = re.compile(r"\w@(?:\d{1,3}\.){3}\d")
DROPLET = "143198189178"
LARGO_MAXIMO = 40_000      # más texto no se analiza (un hook que agota su tiempo deja pasar todo): se bloquea
HOME = os.path.expanduser("~").lower()
PWD = re.compile(r"\$\(pwd\)|\$\{pwd\}|\$pwd\b|`pwd`", re.I)
DESCARTADO = re.compile(r"(?:\bas\s+|\b[eaf]?grep\s+(?:-\S+\s+)*)$")      # el prefijo solo descarta falsos positivos: «as rm», grep de rm; nunca deja pasar un rm real
CADENA_LARGA = re.compile(r"(?:(?<![^ \t])(?:" + ENVOLTURAS + r"|-(?![\d.]+,)[^ \t\n]*|\w+=[^ \t\n]*|\d*[<>]+[&\w./-]*)[ \t]+){121}")      # más largo que cualquier comando real y que el tope de PREFIJO: se bloquea
CADENA_CON_ARGUMENTOS = re.compile(r"(?:(?<![^ \t])(?:" + ENVOLTURAS + r"|\d+(?:\.\d+)?[smhd]?|-(?![\d.]+,)[^ \t\n]*(?:[ \t]+(?!(?:" + ENVOLTURAS + r")(?![\w-]))[A-Za-z_]\w*(?![^ \t]))?|\w+=[^ \t\n]*|\d*[<>]+[&\w./-]*)[ \t]+){121}")      # cuenta además los números y el argumento de cada opción; solo bloquea si el código nombra ssh, scp, sftp o rm
NOMBRES = re.compile(r"\.ssh|ssh|scp|sftp")
FORMA = re.compile(r"ssh://|ssh\s+(?:-[a-z]|[\w.-]+@|\d+\.\d+\.)")      # ssh con opción, usuario@host, IP o URL: en cualquier posición (caffeinate ssh h, git push ssh://...)


def pegados(codigo: str) -> bool:
    """Un nombre de los de arriba que cruza el borde entre dos literales de texto (armado: «s» + «sh», «x» + «s» + «sh») se bloquea siempre; un literal suelto con la palabra no."""
    trozos = [a or b for a, b in re.findall(r"\"([^\"]*)\"|'([^']*)'", codigo.lower())]
    bordes, n = set(), 0
    for t in trozos:
        n += len(t)
        bordes.add(n)
    orden = sorted(bordes)
    return any((i := bisect_right(orden, m.start())) < len(orden) and orden[i] < m.end() for m in NOMBRES.finditer("".join(trozos)))


PRIMERO = {"noverify": "--no-verify", "ghprreview": "gh pr review", "ghprmerge": "gh pr merge", "ghauth": "gh auth"}


def _letra(n: str, base: int = 10) -> str:
    v = int(n, base)
    return chr(v) if v < 0x110000 else ""


def decodificado(codigo: str) -> str:
    """El código con \\xNN, \\uNNNN, octal, chr(N) y String.fromCharCode(N, ...) ya resueltos."""
    t = re.sub(r"(?i)(?:string\.fromcharcode|\bchr)\(\s*((?:0x[0-9a-f]+|\d+)(?:\s*,\s*(?:0x[0-9a-f]+|\d+))*)\s*\)",
               lambda m: '"' + "".join(_letra(x.strip(), 16 if x.strip().lower().startswith("0x") else 10) for x in m.group(1).split(",")) + '"', codigo)
    return re.sub(r"\\+(?:x([0-9a-fA-F]{2})|u([0-9a-fA-F]{4})|u\{([0-9a-fA-F]{1,6})\}|([0-7]{3}))", lambda m: _letra(m.group(4), 8) if m.group(4) else _letra(m.group(1) or m.group(2) or m.group(3), 16), t)


def vistas(codigo: str) -> list[str]:
    """Las formas en que puede aparecer el texto (y su forma decodificada): normal, sin comillas/«+»/barras, y los literales pegados."""
    d = decodificado(codigo)
    return _vistas(codigo) + (_vistas(d) if d != codigo else [])


def _vistas(codigo: str) -> list[str]:
    bajo = codigo.lower().replace("\\\r\n", "").replace("\\\n", "")      # la continuación de línea de la shell une las dos mitades
    junto = re.sub(r"[\x27\"`+\\]|\$\{|\}", "", bajo)
    literales = "".join(a or b for a, b in re.findall(r"\"([^\"]*)\"|'([^']*)'", bajo))
    return [bajo, junto, literales]


def reducido(txt: str) -> str:
    return re.sub(r"[^a-z0-9]", "", txt)


def _destino_fuera(d: str) -> bool:
    """Un destino de rm es seguro solo si, normalizado (~ y «..» resueltos), queda bajo el repo o es relativo sin salir hacia arriba."""
    d = os.path.expanduser(d)
    if d.startswith("~") or any(c.startswith(".") and re.search(r"[?*\[]", c) for c in d.split("/")):
        return True
    if "$" in d or "`" in d:      # 25-nov: destino con variable o sustitución (rm -r "$D", foo/$D, `pwd`): no se resuelve con certeza, se bloquea
        return True
    n = os.path.normpath(d)
    if d.startswith("/"):
        return not ((n + "/").startswith(REPO) and n + "/" != REPO)      # la raíz del repo en sí no se borra
    return n == ".." or n.startswith("../")


def juntos(v: str, primero: str, despues: str):
    """Por cada orden (cortada en ; & | y salto de línea) que trae «primero» y más adelante «despues»: (lo de en medio, lo que sigue). Lineal: no retrocede en textos largos."""
    for orden in re.split(r"[;&|\n]", v):
        a = re.search(primero, orden)
        b = a and re.compile(despues).search(orden, a.end())
        if b:
            yield orden[a.end():b.start()], orden[b.end():]


def _carpeta_fuera(resto: str) -> bool:
    """La carpeta que sigue a «cd», «-C», «--directory»...: solo vale relativa sin «..», o absoluta bajo la raíz del repo."""
    d = re.match(r"""[ \t=,\\"'`]*([^\s,;&|"'`)\]\\]*)""", resto).group(1)
    return not d or d[0] in "-~$" or ".." in d.split("/") or (d.startswith("/") and not (os.path.normpath(d) + "/").startswith(REPO))


def sale_del_repo(vs: list[str]) -> bool:
    """pushd, chdir, cwd, CDPATH, env -C, la opción de carpeta de git/make/tar/uv o un «cd» que no vaya seguido de una ruta del repo."""
    for v in vs:
        if re.search(r"\b(?:pushd|chdir|cwd|cdpath|fchdir|git_dir|git_work_tree)\b|--chdir\b", v) or any(juntos(v, r"\benv\b", r"\s-c(?![\w-])")):
            return True
        for m in re.finditer(r"\bcd\b(?![-.])(?:[ \t]+-[a-z@]+)*(?:[ \t]+--(?![\w-]))?|--(?:directory|work-tree|git-dir)(?![\w-])", v):
            if _carpeta_fuera(v[m.end():]):
                return True
        for orden in re.split(r"[;&|\n]", v):
            a = re.search(r"\b(?:git|g?make|tar|pnpm)\b", orden)
            if a and any(_carpeta_fuera(orden[a.end():][m.end():]) for m in re.finditer(r"(?<![\w-])-c(?![\w-])", orden[a.end():])):
                return True
    return False


def lista_rm_dinamica(vs: list[str]) -> bool:
    """["rm", "-r", d]: en una lista que arranca en «rm», un argumento sin comillas es una variable. RM = "rm" o ["rm"] más tarde ampliada, igual: no se sabe qué borra."""
    for v in vs:
        validado = 0
        for m in LISTA_RM.finditer(v):
            if m.start() < validado:      # ya es un literal de una lista revisada
                continue
            if not ARGUMENTO.search(v[max(0, m.start() - 120):m.start()]) or not SIGUE_LISTA.match(v, m.end()):
                return True
            validado = LITERALES_SEGUIDOS.match(v, m.end()).end()
            if not CIERRE_LISTA.match(v, validado):
                return True
    return False


def rm_fuera_del_repo(codigo: str) -> bool:
    visto = False
    vs = vistas(codigo)
    fuera = sale_del_repo(vs)
    concatena = CONCATENA.search(codigo) is not None
    if lista_rm_dinamica(vs):
        return True
    for txt in vs:      # incluye los literales pegados (armado con variables)
        for m in RM_ARGS.finditer(txt):      # también la forma de lista: ["rm", "-rf", "/x"]
            tokens = [t for t in re.split(r"[\s,\[\]{}()]+", m.group(1)) if t]
            flags = [t for t in tokens if t.startswith("-")]
            if not any((f.startswith("--") and len(f) > 2 and "--recursive".startswith(f)) or (not f.startswith("--") and "r" in f) for f in flags):
                continue
            visto = True
            destinos = [t for t in tokens if not t.startswith("-")]
            if not destinos or fuera or any(_destino_fuera(d) for d in destinos) or re.search(r"\{[^}\s]*,", m.group(1)):
                return True
            if concatena and not DESCARTADO.search(txt[max(0, m.start() - 80):m.start()].rstrip("\"'\\`")):
                return True
    # rm -rf armado de modo que ningún rm completo se ve (rm-rf/x pegado): se bloquea salvo que ya se haya visto un rm recursivo bien formado
    # 22-nov: «rm -f archivo» bien formado no es «rm -rf pegado», PERO solo si el código no arma texto (+, chr, fromCharCode, join, plantillas, format): ahí cualquier resto de «rm -f» puede ser una opción -r escondida y se bloquea de más (revisión Opus, 3 rondas); 22-nov noche: también \\x2d, \\u002d, octal, $(...), printf, base64 y decodificadores
    armado = bool(re.search(r"\+|chr\(|fromcharcode|join|\{|`|\$\(|\\x[0-9a-f]{2}|\\u[0-9a-f]{4}|\\[0-7]{2,3}|printf|base64|atob|b64|unhexlify|fromhex|decode|bytes\(|\w\s*=\s*[\x27\x22]?-[a-z]*r|[\x27\x22]rm[\x27\x22]\s*,\s*\[?\s*[a-z_$]\w*\s*[,\]]|%[-#0 +\d.(]*[a-z]|\.format|\bf[\"']", codigo, re.I))
    resto = re.search(r"-rm\b", codigo)      # un «--rm» que no se eximió y trae después una opción con r: recortado queda «rm -rf»
    armado = armado or (resto is not None and re.compile(r"(?<![\w-])-(?:[a-z]*r|-recur)").search(codigo, resto.end()) is not None)
    if armado and not visto and any(not DESCARTADO.search(v[max(0, m.start() - 80):m.start()]) for v in vs for m in RM_SUELTO.finditer(v)):
        return True      # código que arma texto y menciona un rm sin recursión visible: puede esconder la opción -r (concatenación, chr, variables); se bloquea de más
    return not visto and any(re.search(r"rm(rf|fr)", reducido(v if armado else re.sub(r"\brm[ \t]+-[a-qs-z]+[ \t]+(?=(?!rf?(?:[\s\\\x27\x22]|$))[^-\s\\]|\\+[\x27\x22])", " ", v))) for v in vs)


# 25-nov-2026: «--rm» como opción de docker run / container run / compose run no borra archivos. Nada se decide por posición ni por recorte: se exime solo si TODO el código son llamadas que corren un literal entero
# (nada lo puede cortar ni reescribir) y cada «--rm» es una opción de un comando docker run único y bien parseado. El resto del comando pasa por las mismas reglas que cualquier otro.
LITERAL = re.compile(r""""(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\\n$]|\\.|\$(?!\{))*`""")
SENTENCIA = re.compile(r"(?:(?:(?:const|let|var)[ \t]+)?\w+[ \t]*=[ \t]*)?(?:await[ \t]+)?(?:bash|run|os\.system|subprocess\.run|execSync)\([ \t]*\x00[ \t]*(?:,[ \t]*(?:shell|capture_output|text|check)[ \t]*=[ \t]*True[ \t]*)*\)|(?:print|console\.log)\([ \t]*\w+(?:\.\w+)*[ \t]*\)")
SIN_VALOR = {"--init", "--privileged", "--read-only", "--no-deps", "--service-ports", "--build", "--quiet-pull", "--interactive", "--tty", "--detach", "--publish-all", "--remove-orphans", "-q", "-P"}
CON_VALOR = {"-v", "--volume", "-e", "--env", "--env-file", "--name", "-w", "--workdir", "-u", "--user", "-p", "--publish", "--network", "--net", "--entrypoint", "--mount", "--platform", "--pull", "-m", "--memory", "--cpus", "-l", "--label", "--tmpfs", "--add-host", "-h", "--hostname", "--shm-size", "--gpus"}


def forma_simple(codigo: str) -> bool:
    if "\x00" in codigo:
        return False
    return all(not t.strip() or SENTENCIA.fullmatch(t.strip()) for t in re.split(r"[;\n]", LITERAL.sub("\x00", codigo)))


def rm_de_docker(comando: str) -> int:
    """Cuántos «--rm» son opciones de un comando que es un solo docker run (sin tubería, varias órdenes, heredoc ni expansiones salvo pwd); 0 si no se puede asegurar."""
    limpio = PWD.sub(".", comando)
    if re.search(r"[;&|<>\n\r$`(){}#]", limpio):
        return 0
    try:
        t = shlex.split(limpio) + [""]
    except ValueError:
        return 0
    if t[0] == "docker-compose":
        i, compose = 1, True
    elif t[0] == "docker":
        compose = t[1] == "compose"
        i = 2 if t[1] in ("compose", "container") else 1
    else:
        return 0
    while compose and i + 2 < len(t) and t[i] in ("-f", "--file", "-p", "--project-name", "--profile", "--env-file"):
        i += 2
    if i >= len(t) or t[i] != "run":
        return 0
    i, n = i + 1, 0
    while i < len(t) and t[i].startswith("-"):
        o = t[i]
        if o == "--rm":
            n, i = n + 1, i + 1
        elif o in SIN_VALOR or re.fullmatch(r"-[itdT]+", o) or ("=" in o and o.split("=")[0] in CON_VALOR):
            i += 1
        elif o in CON_VALOR:
            i += 2
        else:
            return 0
    return n if i < len(t) and t[i] else 0      # sin imagen no es un docker run completo


def sin_opcion_docker(codigo: str) -> str:
    if "--rm" not in codigo or not forma_simple(codigo):
        return codigo
    opciones = 0
    for lit in LITERAL.findall(codigo):
        dentro = lit[1:-1]
        if not re.search(r"""\\(?![\\"'`])""", re.sub(r"""\\[\\"'`]""", "", dentro)):      # un literal con otros escapes no se interpreta
            opciones += rm_de_docker(re.sub(r"""\\([\\"'`])""", r"\1", dentro))
    return codigo.replace("--rm", "--autoclean") if opciones == codigo.count("--rm") else codigo


def montaje_peligroso(codigo: str, vs: list[str]) -> bool:
    """docker run con un volumen cuyo origen es /, la carpeta personal o un padre de ella, sale hacia arriba, o no se puede saber (variable distinta de pwd, texto armado)."""
    if not any("docker" in reducido(v) or "podman" in reducido(v) or "nerdctl" in reducido(v) for v in vs):
        return False
    bandera = r"(?<![\w-])(?:-[a-z]*v|--volume|--mount)"
    if CONCATENA.search(PWD.sub(".", codigo)) and any(re.search(bandera, v) for v in vs):
        return True
    if any(re.search(r"""["'`](?:-v|--volume|--mount)["'`]\s*,\s*[a-z_$*.]""", v) for v in vs):      # ["-v", variable]
        return True
    salio = sale_del_repo(vs)
    for v in vs[0::3] + vs[1::3]:      # normal y sin comillas; los literales pegados parten un «\"$PWD\"»
        for m in re.finditer(r"(?:(?<![\w-])-[a-z]*v[\s,=]*|--volume[\s,=]+)([^\s,]{0,1000}?):|\b(?:source|src|device)=([^\s,]*)", v):
            o = PWD.sub(".", m.group(1) if m.group(1) is not None else m.group(2)).strip("\"'`\\[]")
            if not o or "$" in o or "`" in o:
                return True
            n = os.path.normpath(os.path.expanduser(o)).lower()
            if (n.startswith("/") and (HOME + "/").startswith(n.rstrip("/") + "/")) or n == ".." or n.startswith("../") or (salio and not n.startswith("/")):
                return True
    return False


def borrado_por_otra_via(vs: list[str]) -> bool:
    """25-nov (code review, hallazgo 5): borrar sin escribir «rm -r»: la API de archivos, find, git clean y rsync."""
    letras = [reducido(v) for v in vs]
    if any("rmsync" in r or "rmdirsync" in r or "rmtree" in r or "rimraf" in r or "removetree" in r for r in letras):
        return True
    if any("recursive" in r for r in letras) and any(re.search(r"(?<![\w-])rm(?:dir)?(?!\w)", v) for v in vs):
        return True
    if any(re.search(r"rglob\(|\.walk\(|walksync|glob\([^)\n]{0,200}\*\*", v) for v in vs) and any(re.search(r"\bunlink|\bos\.remove\b|\brmdir\b", v) for v in vs):
        return True
    for v in vs:
        if any(re.search(r"(?<![\w-])rm(?![\w.])", sigue) for orden in re.split(r"[;&\n]", v) for a in [re.search(r"\bfind\b", orden)] if a for sigue in orden[a.end():].split("xargs")[1:]):
            return True
        if re.search(r"\bfind\b", v) and re.search(r"(?<![\w-])-delete(?![\w-])", v):
            return True
        if re.search(r"(?<![\w-])-(?:exec|ok)(?:dir)?[\s,]+(?:[^\s,]*/)?rm\b", v):
            return True
        for antes, sigue in juntos(v, r"\bgit\b", r"\bclean\b"):
            if re.search(r"(?<![\w-])-[a-z]*x", sigue) or (re.search(r"(?<![\w-])(?:-[a-z]*f|--force)", sigue) and (re.search(r"(?<!\w)-c\b|--work-tree|--git-dir", antes) or sale_del_repo(vs))):
                return True
        if any(juntos(v, r"\brsync\b", r"--(?:del|remove-source)")):
            return True
    return False


def razones(codigo: str) -> list[str]:
    if len(codigo) > LARGO_MAXIMO:
        return ["más texto del que se puede analizar"]
    if CADENA_LARGA.search(codigo) or (re.search(r"\b(?:ssh|scp|sftp|rm)\b", codigo) and CADENA_CON_ARGUMENTOS.search(codigo)) or re.search(r"\w=\S{1001}", codigo) or any(len(re.findall(r"\w=", t)) > 12 for t in codigo.split()):
        return ["una cadena de envolturas o un valor demasiado largo"]
    codigo = sin_opcion_docker(codigo)
    out: list[str] = []
    vs = vistas(codigo)
    letras = [reducido(v) for v in vs]
    if any(COMANDO.search(v) or FORMA.search(v) or IP_USUARIO.search(v) for v in vs) or pegados(codigo) or pegados(decodificado(codigo)) or any(DROPLET in r for r in letras):
        out.append("ssh, scp o sftp")
    for clave, etiqueta in PRIMERO.items():
        if any(clave in r for r in letras):
            out.append(etiqueta)
    if any(re.search(r"platform.{0,4}env", r) for r in letras):      # también «platform.%s" % "env"»
        out.append("platform.env")
    en_lista = [re.sub(r"""(["'])(-[a-z]*m)\1\s*,\s*(["'])(?:(?!\3)[^\n]){0,2000}\3""", r'"\2", "x"', v) for v in vs]
    sin_mensaje = [re.sub(r"""(?<![\w-])(-[a-z]*m)[ =]*(\\*["'])(?:(?!\2)[^\n]){0,2000}\2""", r"\1 x", v) for v in en_lista]      # un «;» dentro del mensaje no corta la orden
    if (any("--no-veri" in v or re.search(r"""hookspath(?![\s"'=,]*\.githooks(?![\w/.-]))|hookspath[^\n]{0,200}unset|unset[^\n]{0,200}hookspath|(?:remove|rename)-section[\s"'=,]+core\b""", v) for v in vs)
            or any(any(juntos(v, r"\bgit\b[^;&|\n]{0,200}?\b(?:commit|am)\b", r"(?<![\w-])-[a-z]*n[a-z]*(?![\w-])")) for v in vs + sin_mensaje)):
        out.append("--no-verify")      # también «git commit -n», la abreviatura y apagar los hooks por configuración
    for orden in ("merge", "review"):
        if any(re.search(r"\b" + orden + r"\b", sigue) for v in vs for _, sigue in juntos(v, r"\bgh\b", r"\bpr\b")):      # gh pr -R x merge
            out.append("gh pr " + orden)
    if any("ghapi" in r and ("review" in r or "merge" in r) for r in letras):
        out.append("gh api con reviews o merge")
    if any(re.search(r"\bchmod\b[^\n]{0,200}(?:\.githooks|\.git/hooks)", v) for v in vs):
        out.append("--no-verify")      # sin permiso de ejecución git salta los hooks
    if any(any(juntos(v, r"\brsync\b", r"(?<![\w/=.-])[\w.-]{2,}:(?!//)")) for v in vs):
        out.append("ssh, scp o sftp")      # host:ruta
    if any(re.search(r"\b(?:paramiko|asyncssh|node-ssh)\b|[\x27\x22]ssh2[\x27\x22]", v) or any(juntos(v, r"\b(?:rsync|git)\b", r"(?<![\w.-])(?!git@github\.com:)[\w.-]+@[\w.-]+:")) for v in vs):
        out.append("ssh, scp o sftp")      # usuario@nombre:ruta lanza ssh sin escribirlo; las librerías de ssh también
    if any(re.search(r"(?:~|\$home|\$\{home\}|\.\.|" + re.escape(HOME) + r")/\.\w*[*?\[{]", v) for v in vs):
        out.append("escritura en ~/.ssh")
    if any(re.search(r"(?<!\w)\.ssh(?!\w)", v) for v in vs):
        out.append("escritura en ~/.ssh")
    alias_rm = any(re.search(r"(?:\balias\s+\w+|\b\w+)=[\"']?(?:[\w./-]*/)?rm[\"']?(?:\s|[;&|)]|\\+[ntr]|$)|\b\w+=\s*[\"']?(?:\$\(|`)[^;\n)]{0,200}\brm(?![\w.])", v) for v in vs)      # 25-nov: un alias o variable que apunta a rm (también R=$(which rm), «R=rm&&», «R=rm\n») esconde el comando
    docker_rm = any(re.search(r"\brun\b", medio) for v in vs for medio, _ in juntos(v, r"\bdocker\b", r"\s(?:[^\s/]*/)*rm\s+(?:-\S+\s+)*?(?:-[a-z]*r|--recursive)"))      # 25-nov revisión Opus: «docker run -v /:/h img rm -r /h» borra el equipo a través del volumen
    docker_rm = docker_rm or any(re.search(r"""--entrypoint[\s=,"']+(?:[\w./-]*/)?rm(?![\w.])""", v) for v in vs)
    if rm_fuera_del_repo(codigo) or alias_rm or docker_rm or borrado_por_otra_via(vs):
        out.append("rm -rf fuera del repo")
    if montaje_peligroso(codigo, vs):
        out.append("montaje de / o de la carpeta personal en docker")
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
    try:
        r = razones(codigo)
    except Exception as e:      # falla cerrado
        r = ["algo que el hook no pudo analizar (" + type(e).__name__ + ")"]
    if r:
        sys.stderr.write("BLOQUEADO por ops/hooks/revisar-repl.sh: el código de Code Mode contiene " + ", ".join(r) + ". Usa la herramienta Bash con su regla deny o ask, o pídele a Ricardo.\n")
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
