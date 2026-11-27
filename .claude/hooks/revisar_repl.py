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
from fnmatch import fnmatchcase
from pathlib import Path

REPO = str(Path(__file__).resolve().parents[2]).lower() + "/"      # la raíz del repo donde vive el hook (el motor o la landing: el mismo script en los dos)
# 21-nov-2026: ssh, scp, sftp y sus parientes se bloquean COMO COMANDO (inicio, tras ; | & ( = $ ! comilla, corchete, un salto escrito como \\n, una palabra de shell como sudo/timeout/if/eval, una asignación A=1, o -e de rsync),
# nunca dentro de un identificador ni de un texto corrido; «ssh-add -l» pasa. Aparte, un «ssh» armado con literales pegados se bloquea siempre (ver pegados).
ENVOLTURAS = r"(?:uv[ \t]+run|uvx|npx|sudo|doas|fakeroot|builtin|env|exec|command|nohup|xargs|time|timeout|nice|eval|if|elif|coproc|then|else|do|while|until|setsid|watch|stdbuf|sshpass|rsync|ionice|chroot|bash|sh|zsh|caffeinate|busybox|unbuffer|taskpolicy|arch|script|runuser|su|sg|strace|ltrace|tmux|screen|parallel|firejail|proxychains|torsocks|dtruss|chronic|nsenter)"
POSICIONAL = r"(?:flock|lockf|setpriv|cpulimit)"      # envolturas con un argumento posicional antes del comando (flock /tmp/l ssh h)
REDIR = r"(?:\d*[<>]+[&\w./-]*[ \t]+){0,130}"      # 24-nov noche: redirecciones antes del comando (2>/dev/null rm, >x rm, <x rm, &>x rm)
PREFIJO = (r"(?:^|[;|&(`\"'\[,{}=$!)]|\\[ntr]|\s-e\s)[ \t]*" + REDIR + r"(?:(?:[\w.~-]*/){0,20}" + ENVOLTURAS + r"[ \t]+(?:-\S+[ \t]+(?:(?!" + ENVOLTURAS + r"\b)[A-Za-z_]\w*[ \t]+)?|\d+(?:\.\d+)?[smhd]?[ \t]+){0,130}|" + POSICIONAL + r"[ \t]+(?:-\S+[ \t]+)*[\w./:-]+[ \t]+){0,130}(?:\w+=\S{0,1000}[ \t]+){0,130}(?:[\w.~-]*/)*")
COMANDO = re.compile(PREFIJO + r"(?!ssh-add\s+-l\s*(?:$|[;|&\n\"'`)\]]|\\n))(?:ssh(?:-[a-z]+)*|sshpass|autossh|scp|sftp)(?![\w-])(?!:(?![/\w]))", re.M)      # «ssh:» como clave de un objeto no es un comando
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
HOST_CON_OPCION = (r"\bssh[ \t]+[\w-]{1,63}(?:\.[\w-]{1,63}){1,10}(?![\w.-])", r"(?<![\w-])-[lo](?![a-z-])")      # «ssh host.dominio ... -l u», tras cualquier envoltorio
REPO_REMOTO = re.compile(r"\bgit(?:[ \t]+-c[ \t]+\S+)?[ \t,]+(?:(?:clone|push|pull|fetch|ls-remote)(?:[ \t,]+-[^\s,]+)*|remote[ \t,]+(?:add|set-url)(?:[ \t,]+-[^\s,]+)*[ \t,]+[\w.-]+)[ \t,]+[\w.-]{2,}:(?!//)")      # host:ruta sin usuario; un refspec (HEAD:main) va después del remoto

# 26-nov-2026, bloqueos indebidos. Dos órdenes de lectura exactas (las pide CLAUDE.md), solo dentro de $`...` (o en un registro que nadie usa).
LECTURAS = r"(?:ssh-add -l|ssh-add --apple-use-keychain -q ~/\.ssh/id_ed25519|git config (?:--get )?core\.hooksPath)"
EJEMPLO = re.compile(r"""(?<![\w-])platform\.env\.example(?=[\s"');|&]|\Z)""")
RECORTA_EJEMPLO = re.compile(r"\b(?:sed|cut|tr|awk|xargs|rev|basename)\b|%")
_AVISO = r"(?:--no-verify|escritura en ~/\.ssh|ssh, scp o sftp|rm -rf fuera del repo|platform\.env|montaje de / o de la carpeta personal en docker|gh pr merge|gh pr review|gh auth)"
AVISOS = re.compile(r"""(["'])""" + _AVISO + r"(?:, " + _AVISO + r""")+\1""")      # una lista de dos o más razones de este hook, copiada como dato
REGISTRO = re.compile(r"\bconst[ \t]+(\w+)[ \t]*=[ \t]*\[\s{0,20}\{")
# 27-nov-2026: el nombre del ejemplo se exime solo si su salida no puede volver a una orden: dentro de la plantilla sin variables, redirecciones ni intérpretes, y fuera de ella sin llamadas que ejecuten o lean.
CADENAS = {"slice", "substr", "substring", "split", "join", "trim"}      # ninguna recibe una función (map, filter o replace sí podrían llamar a bash)
SALE = re.compile(r"\$|`|<|>|--output|(?<![\w-])-(?:O|exec|ok)|(?<![\w.-])(?:(?:ba|z|da|k)?sh|xargs|eval|source|exec|python3?|node|perl|ruby|parallel|awk|read)(?![\w.-])|(?:\A|[;&|\n])[ \t]*\.[ \t]")
SIGUE_TUBO = re.compile(r"""[ \t]*(?:head(?:[ \t]+-n?[ \t]*\d+)?|wc(?:[ \t]+-[lwc])?|grep(?:[ \t]+-[nivEcwF]+)*[ \t]+(?:'[^']*'|"[^"]*"|[\w.]+))[ \t]*""")
# «sh» como ayudante propio que solo envuelve a $: únicamente la lectura de los hooks, y con otra orden detrás (nada agregado al final la vuelve un cambio)
PASO_SH = re.compile(r"(?<![\w$.])(?:const|let|var)[ \t]+sh[ \t]*=[ \t]*async[ \t]+(\w+)[ \t]*=>[ \t]*\(await[ \t]+\$\(\1\)(?:\.(?:nothrow|quiet)\(\))*\)(?:\.(?:output|stdout))?(?=\s*(?:;|\Z))")      # termina en «;»: en la línea siguiente puede seguir la misma expresión
# 27-nov-2026: comodines y expansiones que pueden resolver al archivo de entorno
ENTORNO_ARMADO = re.compile(r"""platform\.[?*\[{($@+!]|\$(?:\{\w+\}["']{0,2}[a-z]*|\w+(?:["']{1,2}[a-z]*)?)\.env(?![\w.])""")
LEE = re.compile(r"\b(?:cat|tac|head|tail|less|more|nl|od|xxd|base64|strings|sed|awk|cut|sort|cp|mv|dd|diff|source|grep|rg)\b")
# la salida de una búsqueda que puede acabar ejecutándose
SALIDA_EJECUTADA = re.compile(r"\|[ \t]*(?:[^\s|]{0,200}/)?(?:(?:ba|z|da|k)?sh|xargs|eval|source|python3?|node|perl|ruby)\b|\$`\s*\$\{|\beval\b|\$\(")
# Órdenes que solo valen dentro de una plantilla $`...` (se ejecuta en el acto: ninguna variable la guarda para recortarla), en posición de comando y fuera de comillas y comentarios.
POSICION = r"(?:\A|(?<=[;&|\n])(?<!\\[;&|\n]))([ \t]*)"
FIN_ORDEN = r"(?=(?:[ \t]+[12]?>(?:&[12]|/dev/null))*[ \t]*(?:[;&|\n]|\Z))"
RUTA = r"(?!-)(?![\w./-]*\.\.)(?:(?:/private)?/tmp/claude-[\w./-]+|[\w.][\w./-]*)"
CITADO = r"""|\\.|'[^']*'|"(?:[^"\\]|\\.)*"|(?<![^ \t\n;&|])#[^\n]*"""      # comillas y comentarios de la shell se saltan enteros
INOFENSIVAS = [(re.compile("(?:" + POSICION + a + ")" + CITADO), b) for a, b in (
    (r"rm(?:[ \t]+-[fv]+)+(?:[ \t]+" + RUTA + r")+" + FIN_ORDEN, r"\1true"),      # archivos sueltos, sin recursión y escritos enteros
    (r"docker(?:[ \t]+(?:network|container))?[ \t]+rm(?:[ \t]+(?:-f|--force))*(?:[ \t]+\w[\w.-]*)+" + FIN_ORDEN, r"\1true"),
    (r"git[ \t]+rm(?:[ \t]+(?:-q|-f|--quiet|--cached))*(?:[ \t]+" + RUTA + r")+" + FIN_ORDEN, r"\1true"),
    (r"(docker(?:[ \t]+compose|[ \t]+container)?[ \t]+run(?:[ \t]+-[itd]+)*[ \t]+)--rm(?![\w-])", r"\1\2--autoclean"),
    (LECTURAS + FIN_ORDEN, r"\1true"),
)]
HOOKS_SH = (re.compile("(?:" + POSICION + r"git config (?:--get )?core\.hooksPath(?=[ \t]*(?:;|&&|\|\|)[ \t]*[a-z]))" + CITADO), r"\1true")
BUSCA = (re.compile("(?:" + POSICION + r"""((?:git[ \t]+)?[ef]?grep(?:[ \t]+-[nrEiclwhvPFq]+)*[ \t]+)(?:"(?!-)[^"\\$`\n]*"|'(?!-)[^'\n]*'))""" + CITADO), r'\1\2"x"')      # el patrón de una búsqueda; sin -o ni rg, que devuelven el texto pedido. El citado nunca empieza con «-»: la shell le quita las comillas y sería una opción
# 27-nov-2026: la búsqueda del patrón con rg sobre archivos escritos enteros; sin «-o», «-r», «--pre», «-f» ni comodines en las rutas
BUSCA_RG = (re.compile("(?:" + POSICION + r"""(rg(?:[ \t]+-[niwFcl]+)*[ \t]+)(?:"(?!-)[^"\\$`\n]*"|'(?!-)[^'\n]*')(?=(?:[ \t]+""" + RUTA + r")+" + FIN_ORDEN + "))" + CITADO), r'\1\2"x"')
# Texto que solo es dato: el patrón de tools.Grep, el encargo de tools.Agent, lo que busca .includes() y lo que se escribe en un .md o .txt.
DATO = r"""(?:"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\$]|\\.|\$(?!\{))*`)"""
BUSQUEDA = re.compile(r"(\btools\.Grep\(\{\s{0,20}pattern\s{0,20}:\s{0,20}|\.includes\(\s{0,20})" + DATO + r"(?=\s*[,})])")
AGENTE = re.compile(r"\btools\.Agent\(\{")
CAMPO = re.compile(r"(\s*(\w+)\s*:\s*)(" + DATO + r")(?=\s*[,}])(\s*,)?")
DOCUMENTO = re.compile(r"""(\b(?:write|edit)\(\s{0,20}(?:[\w$]{1,60}\s{0,5}\+\s{0,5})?(?:"[^"\n]{0,300}\.(?:md|txt)"|'[^'\n]{0,300}\.(?:md|txt)'|`[^`\n]{0,300}\.(?:md|txt)`))((?:\s{0,20},\s{0,20}""" + DATO + r"""){1,2})(?=\s{0,20}\))""")
# Lo escrito en un documento solo es dato si TODO el resto del código está en estas dos listas cerradas: nada más puede copiarlo, moverlo, redirigirlo ni ejecutarlo.
LLAMADAS = {"write", "edit", "tools.Skill", "Promise.all", "console.log"}
METODOS = {"nothrow", "text", "timeout", "quiet"}
ORDEN_SEGURA = re.compile(r"(?:TZ=[\w/]+[ \t]+)?(?:cd|tail|head|cut|wc|ls|df|uptime|date|grep|git[ \t]+(?:status|log|diff|add|commit|rev-parse)|docker[ \t]+ps|docker[ \t]+run(?![^\n]*(?:[ \t]-v|--volume|--mount|--priv))"
                          r"|bash[ \t]+(?:ops/(?:mac-poda-docker|cierre-sin-pendiente|abierto-entre-sesiones-check|readme-nombres-check)\.sh|\.claude/skills/verify/verify\.sh)|python3[ \t]+ops/boveda_escribir\.py)(?![\w./-])")
# lector mínimo de JavaScript: comentarios, textos, plantillas y expresiones regulares; una comilla suelta significa que no se entendió
JS = re.compile(r"""//[^\n]*|/\*.*?(?:\*/|\Z)|"(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\]|\\.)*`|[(,=:\[!&|?{};][ \t]*/(?![/*])(?:[^/\\\n\[]|\\.|\[(?:[^\]\\\n]|\\.){0,100}\]){1,200}/|(["'`])""", re.S)


def textos(codigo: str) -> list[tuple[int, int]]:
    """Dónde empieza y termina cada comentario, texto o plantilla; lista vacía y None si no se puede asegurar (comilla suelta o plantilla anidada)."""
    out = []
    for m in JS.finditer(codigo):
        if m.group(1) or (m.group(0)[0] == "`" and m.group(0).count("{") != m.group(0).count("}")):
            return None
        out.append(m.span())
    return out


def _dentro(spans: list, inicios: list, pos: int) -> bool:
    i = bisect_right(inicios, pos) - 1      # 27-nov (Opus): recorrer todos los textos por cada coincidencia era cuadrático
    return i >= 0 and inicios[i] < pos < spans[i][1]


def _cambiar_codigo(patron: re.Pattern, nuevo, codigo: str) -> str:
    """patron.sub solo donde la coincidencia es código: nunca si empieza dentro de un texto, una plantilla o un comentario."""
    spans = textos(codigo)
    if spans is None:
        return codigo
    inicios = [a for a, _ in spans]

    def uno(m: re.Match) -> str:
        return m.group(0) if _dentro(spans, inicios, m.start()) else m.expand(nuevo) if isinstance(nuevo, str) else nuevo(m)

    return patron.sub(uno, codigo)


def _plantilla(cuerpo: str, patrones: list, ejemplo: bool) -> str:
    # una barra seguida de algo que JavaScript puede volver comilla, barra o salto cambia lo que ve la shell: no se exime nada
    if "<<" in cuerpo or "$'" in cuerpo or re.search(r"\\(?![sSdDwWbB.|()\[\]{}^*+?/ -])|\(\)\s*\{|\b(?:alias|function)\b", cuerpo) or re.search(r'"[^"\n]*\$\([^")\n]*"', cuerpo):
        return cuerpo
    for patron, nuevo in patrones:
        cuerpo = patron.sub(lambda x: x.expand(nuevo) if x.lastindex else x.group(0), cuerpo)
    if not ejemplo or SALE.search(re.sub(r"[\"']|\$\{\w+\}|2>(?:&1|/dev/null)", "", cuerpo)):
        return cuerpo
    # por orden (la tubería incluida): nada que lo recorte, y detrás del tubo solo head, wc o grep
    return "".join(t if RECORTA_EJEMPLO.search(t) or not all(SIGUE_TUBO.fullmatch(x) for x in re.sub(r"2>&1|2>/dev/null", "", t).split("|")[1:]) else EJEMPLO.sub("ejemplo-de-entorno", t)
                   for t in re.split(r"((?<!>)&|[;\n])", cuerpo))


def _fuera_de_textos(codigo: str, spans: list, comentario: str = "S") -> str:
    """El código con cada texto, plantilla o expresión reducido a su primer carácter, y cada comentario a «S» (así «bash/**/(x)» sigue siendo una llamada desconocida)
    o a lo que se pida: para buscar «$» y «sh» redefinidos va un espacio, porque la «S» pegada formaba otro nombre."""
    partes, previo = [], 0
    for a, b in spans:
        partes.append(codigo[previo:a] + (comentario if codigo[a:a + 2] in ("//", "/*") else codigo[a]))
        previo = b
    return "".join(partes) + codigo[previo:]


def _ejemplo_sin_salida(codigo: str) -> bool:
    """Fuera de los textos solo hay llamadas que no ejecutan ni leen, y cada ${x} es una variable que aquí solo recibe rutas escritas enteras."""
    spans = textos(codigo)
    if spans is None:
        return False
    nombres: set[str] = set()
    for a, b in spans:
        if codigo[a] == "`":
            cuerpo = codigo[a + 1:b - 1]
            if "${" in re.sub(r"\$\{\w+\}", "", cuerpo):
                return False
            nombres.update(re.findall(r"\$\{(\w+)\}", cuerpo))
    fuera = _fuera_de_textos(codigo, spans)
    if len(nombres) > 10:
        return False
    for n in nombres:
        valores = re.findall(r"(?<![\w$.])" + n + r"[ \t]*=[ \t]*([^;\n]+)", codigo)
        if not valores or len(re.findall(r"(?<![\w$.])" + n + r"(?![\w$])", fuera)) != len(valores) or any(not re.fullmatch(r"""(["'`])[\w./ ~-]*\1[ \t]*""", v) for v in valores):
            return False
    return all(n in LLAMADAS - {"write", "edit"} or ("." in n and n.rsplit(".", 1)[1] in METODOS | CADENAS) for n in re.findall(r"(?<![\w$.\])])([\w$.\])]+)\s*\(", fuera))


# 27-nov (Opus): las exenciones dan por hecho que «$» es la shell. Fuera de los textos solo vale como etiqueta o seguido de «.»: cualquier otro «$» (asignación, parámetro, método, getter o llamada,
# salvo el «$(c)» del ayudante sh) o un «$.x =» puede redefinirlo, y entonces no hay ninguna exención
PESOS_PROPIO = re.compile(r"(?<![\w$])\$(?![\w$`.])|\bfunction\b[\s*]*\$|(?<![\w$])\$\.[\w$]+\s*=(?!=)")


def _sin_ayudante(codigo: str, spans: list) -> str:
    return PASO_SH.sub("", _fuera_de_textos(codigo, spans, " "))


def _pesos_propio(codigo: str, spans: list) -> bool:
    # un nombre escrito con escape («\u0024», «s\u0068») fuera de los textos es el mismo nombre para JavaScript
    fuera = _sin_ayudante(codigo, spans)
    return bool("\\u" in fuera or PESOS_PROPIO.search(fuera) or re.search(r"""(["'`])\$\1""", codigo))


# 27-nov-2026, bloqueo estructural (se acabó perseguir variantes de «$»): se mira el código tal como lo lee JavaScript, interpolaciones de las plantillas incluidas, y todo lo que puede redefinir o sombrear «$» se rechaza.
FICHA = re.compile(r"""(?P<hueco>[\s\ufeff]+|//[^\n\r\u2028\u2029]*|/\*(?s:.*?)\*/)|(?P<texto>"(?:[^"\\\n\r]|\\(?s:.))*"|'(?:[^'\\\n\r]|\\(?s:.))*')|(?P<num>\.?\d(?:[\w.]|(?<=[eE])[+-])*)|(?P<id>(?:[^\W\d]|\$)(?:\w|\$)*)|(?P<op>\+\+|--|<!--|/\*|["']|(?s:.))""")
REGEX_JS = re.compile(r"/(?![/*])(?:[^/\\\n\r\[]|\\.|\[(?:[^\]\\\n\r]|\\.)*\])+/")
PLANTILLA_JS = re.compile(r"(?:[^`\\$]|\\(?s:.)|\$(?!\{))*(`|\$\{)")
ANTES_DE_REGEX = {"return", "typeof", "instanceof", "in", "new", "delete", "void", "throw", "case", "do", "else"}
GLOBALES = {"globalThis", "global", "self", "window", "this"}
PROHIBIDOS = {"Reflect", "eval", "Function"}


def fichas(codigo: str) -> list[str] | None:
    """Las piezas de código (textos y expresiones regulares quedan como «"»); None si no se puede leer con seguridad."""
    out: list[str] = []
    llaves: list[int] = []      # una cuenta por cada «${» abierto
    i, plantilla = 0, False
    while i < len(codigo):
        if plantilla:
            m = PLANTILLA_JS.match(codigo, i)
            if not m:
                return None
            i, plantilla = m.end(), False
            if m.group(1) == "${":
                llaves.append(0)
                out.append("(")
            else:
                out.append('"')
            continue
        c = codigo[i]
        if c == "`":
            out.append("`")
            i, plantilla = i + 1, True
            continue
        previa = out[-1] if out else ""
        if c == "/" and codigo[i + 1:i + 2] not in ("/", "*"):
            propiedad = len(out) > 1 and out[-2] == "."
            # tras «)», «}», «of», «yield» o «await» no se sabe si divide o abre una expresión: si como expresión escondería comillas o comentarios, no se lee
            dudoso = previa in (")", "}") or (previa in ("of", "yield", "await") and not propiedad)
            divide = previa in ('"', "]", "++", "--") or (previa[:1].isalnum() or previa[:1] in "_$") and (propiedad or previa not in ANTES_DE_REGEX)
            m = REGEX_JS.match(codigo, i)
            if dudoso:
                if m and re.search(r"""["'`]|//|/\*""", m.group(0)[1:-1]):
                    return None
            elif not divide:
                if not m:
                    return None
                out.append('"')
                i = m.end()
                continue
        m = FICHA.match(codigo, i)
        i = m.end()
        if m.lastgroup == "hueco":
            continue
        t = m.group(0)
        if t in ('"', "'", "/*", "<!--"):
            return None
        if llaves and t == "{":
            llaves[-1] += 1
        elif llaves and t == "}":
            if not llaves[-1]:
                llaves.pop()
                plantilla = True
                out.append(")")
                continue
            llaves[-1] -= 1
        out.append('"' if m.lastgroup in ("texto", "num") else t)
    return None if plantilla or llaves else out


def redefine_pesos(codigo: str) -> bool:
    """«$» solo vale como etiqueta ($`...`), como «await $(c)» o como método de otro objeto (page.$(x)); los objetos globales y «this», solo con «.nombre» fijo; «with», «eval», «Function», «Reflect» y los nombres con escape, nunca."""
    f = fichas(codigo)
    if f is None or any(a == "\\" and b[:1] == "u" for a, b in zip(f, f[1:])):      # un nombre escrito con escape; cualquier otra barra suelta no es JavaScript válido
        return True
    f = ["", ""] + f + ["", "", ""]
    for i in range(2, len(f) - 3):
        t, antes, sigue = f[i], f[i - 1], f[i + 1]
        if t == "$":
            if not (sigue == "`" or (sigue == "(" and (antes == "." or (antes == "await" and f[i + 2].isidentifier() and f[i + 3] == ")")))):
                return True
            continue
        if antes == "." or (sigue == ":" and antes in ("{", ",")):
            continue
        if (t == "with" and sigue == "(") or t in PROHIBIDOS:
            return True
        if t in GLOBALES and not (sigue == "." and f[i + 2].isidentifier() and f[i + 2] not in GLOBALES | PROHIBIDOS):
            return True
    return False


def _plantillas(codigo: str) -> str:
    spans = textos(codigo) or []
    if _pesos_propio(codigo, spans):
        return codigo
    busca = not SALIDA_EJECUTADA.search(codigo)
    ejemplo = "platform.env.example" in codigo and _ejemplo_sin_salida(codigo)
    sh = not (re.search(r"(?<![\w$])sh(?![\w$`])", _sin_ayudante(codigo, spans)) or re.search(r"""(["'`])sh\1""", codigo))      # tampoco «globalThis.sh» ni «["sh"]»
    partes, previo = [], 0
    for a, b in spans:
        if codigo[a] != "`":
            continue
        cuerpo = codigo[a + 1:b - 1]
        if codigo[a - 1:a] == "$" and not re.match(r"[\w$]", codigo[a - 2:a - 1]):
            nuevo = _plantilla(cuerpo, INOFENSIVAS + ([BUSCA, BUSCA_RG] if busca else []), ejemplo)
        elif sh and "$" not in cuerpo and re.search(r"(?<![\w$.])sh\Z", codigo[max(0, a - 3):a]):
            nuevo = _plantilla(cuerpo, [HOOKS_SH], False)
        else:
            continue
        partes.append(codigo[previo:a + 1] + nuevo)
        previo = b - 1
    return "".join(partes) + codigo[previo:]


def _registros_sin_uso(codigo: str) -> str:
    """const x = [{...}] que nada vuelve a nombrar: las órdenes de lectura y las listas de razones de este hook que guarde son solo dato."""
    spans = textos(codigo) or []
    inicios = [a for a, _ in spans]
    for m in reversed(list(REGISTRO.finditer(codigo))[:20]):
        if _dentro(spans, inicios, m.start()) or len(re.findall(r"\b" + m.group(1) + r"\b", codigo)) != 1:
            continue
        fin = next((f.start() for f in re.compile(r"\}\s{0,20}\]").finditer(codigo, m.end()) if not _dentro(spans, inicios, f.start())), None)
        if fin is not None:
            dentro = AVISOS.sub('"x"', re.sub(r"(?<=[;&|] )" + LECTURAS + r"(?=[ \t]*(?:;|&&|\|\|))", "true", codigo[m.end():fin]))
            codigo = codigo[:m.end()] + dentro + codigo[fin:]
    return codigo


def _campos_agente(codigo: str) -> str:
    spans = textos(codigo)
    if spans is None:
        return codigo
    partes, previo, inicios = [], 0, [a for a, _ in spans]
    for m in AGENTE.finditer(codigo):
        if _dentro(spans, inicios, m.start()):
            continue
        i = m.end()
        while i >= previo and (c := CAMPO.match(codigo, i)):
            if c.group(2) in ("prompt", "description"):
                partes.append(codigo[previo:c.start(3)] + '"x"')
                previo = c.end(3)
            i = c.end()
    return "".join(partes) + codigo[previo:]


def _cuerpo_seguro(cuerpo: str) -> bool:
    """Una plantilla sin expansiones ni redirecciones cuyas órdenes están todas en ORDEN_SEGURA."""
    if re.search(r"\\|\$|`|--output", cuerpo):
        return False
    cuerpo = re.sub(r"2>(?:&1|/dev/null)", "", re.sub(r"'[^']*'|\"[^\"]*\"", "q", cuerpo))
    return not ("<" in cuerpo or ">" in cuerpo or any(t.strip() and not ORDEN_SEGURA.match(t.strip()) for t in re.split(r"[;&|\n]", cuerpo)))


def solo_lo_seguro(codigo: str) -> bool:
    """El código (ya sin lo escrito en documentos) solo escribe, edita y corre órdenes de la lista cerrada en $`...`."""
    spans = textos(codigo)
    if spans is None or re.search(r"\b(?:write|edit|tools|Promise|console)\b\s*=", codigo) or _pesos_propio(codigo, spans):
        return False
    resto, previo, nombres = [], 0, set()
    for a, b in spans:
        resto.append(codigo[previo:a] + "S")
        previo = b
        if codigo[a] != "`":
            continue
        if codigo[a - 1:a] != "$":
            i = a - 1
            while i >= 0 and codigo[i].isspace():
                i -= 1
            if i >= 0 and codigo[i] not in "(,=:[?{;+>":      # «$ `x`», «bash\n`x`» o tras un comentario: puede ser una etiqueta
                return False
            continue
        cuerpo = codigo[a + 1:b - 1]
        nombres.update(re.findall(r"\$\{(\w+)\}", cuerpo))
        if not _cuerpo_seguro(re.sub(r"\$\{\w+\}", "V", cuerpo)):
            return False
    if len(nombres) > 10 or any(not re.match(r"""(["'`])[\w./ ~-]*\1""", v) for n in nombres for v in re.findall(r"\b" + n + r"[ \t]*=[ \t]*([^;\n]+)", codigo)):
        return False      # una variable armada aquí solo puede ser una ruta escrita entera
    fuera = "".join(resto) + codigo[previo:]
    return all(n in LLAMADAS or ("." in n and n.rsplit(".", 1)[1] in METODOS) for n in re.findall(r"(?<![\w$.\])])([\w$.\])]+)\s*\(", fuera))


def sin_datos(codigo: str) -> str:
    """El código sin lo que no puede hacer daño: texto que solo es dato y las pocas órdenes inofensivas de arriba. Todo lo demás pasa por las mismas reglas."""
    if not re.search(r"\btools(?:\.\w+)?\s*=(?!=)", codigo):
        codigo = _campos_agente(_cambiar_codigo(BUSQUEDA, r'\1"x"', codigo))
    if DOCUMENTO.search(codigo) and solo_lo_seguro(_cambiar_codigo(DOCUMENTO, lambda m: m.group(1) + ', "x"', codigo)):
        codigo = _cambiar_codigo(DOCUMENTO, lambda m: m.group(1) + ', "x"', codigo)
    return _plantillas(_registros_sin_uso(codigo))


def pegados(codigo: str) -> bool:
    """Un nombre de los de arriba que cruza el borde entre dos literales de texto (armado: «s» + «sh», «x» + «s» + «sh») se bloquea siempre; un literal suelto con la palabra no."""
    trozos = [a or b for a, b in re.findall(r"\"([^\"]*)\"|'([^']*)'", codigo.lower())]
    bordes, n = set(), 0
    for t in trozos:
        n += len(t)
        bordes.add(n)
    orden = sorted(bordes)
    return any((i := bisect_right(orden, m.start())) < len(orden) and orden[i] < m.end() for m in NOMBRES.finditer("".join(trozos)))


REDEFINE = "una forma de redefinir «$» (with, globalThis, self, window, this, Reflect, eval, asignar o declarar «$», o código que no se puede leer)"
PRIMERO = {"noverify": "--no-verify", "ghprreview": "gh pr review", "ghprmerge": "gh pr merge", "ghauth": "gh auth"}


def _letra(n: str, base: int = 10) -> str:
    v = int(n, base)
    return chr(v) if v < 0x110000 else ""


def decodificado(codigo: str) -> str:
    """El código con \\xNN, \\uNNNN, octal, chr(N) y String.fromCharCode(N, ...) ya resueltos."""
    t = re.sub(r"(?i)(?:string\.fromcharcode|\bchr)\(\s*((?:0x[0-9a-f]+|\d+)(?:\s*,\s*(?:0x[0-9a-f]+|\d+))*)\s*\)",
               lambda m: '"' + "".join(_letra(x.strip(), 16 if x.strip().lower().startswith("0x") else 10) for x in m.group(1).split(",")) + '"', codigo)
    return re.sub(r"(?<!\\)\\+(?:x([0-9a-fA-F]{2})|u([0-9a-fA-F]{4})|u\{([0-9a-fA-F]{1,6})\}|([0-7]{3}))", lambda m: _letra(m.group(4), 8) if m.group(4) else _letra(m.group(1) or m.group(2) or m.group(3), 16), t)


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


PEGADO = re.compile(r"(?:(?<![a-z0-9])|(?<=\\[ntr]))r[^a-z0-9]*m[^a-z0-9]*(?:r[^a-z0-9]*f|f[^a-z0-9]*r)(?![a-z])")      # «rm-rf/x» desde inicio de palabra: «platform from» no lo es


def rm_fuera_del_repo(codigo: str) -> bool:
    visto = False
    validos = set()      # (vista, posición) de cada rm recursivo ya revisado: no apaga la revisión de los demás
    vs = vistas(codigo)
    fuera = sale_del_repo(vs)
    concatena = CONCATENA.search(codigo) is not None
    if lista_rm_dinamica(vs):
        return True
    for k, txt in enumerate(vs):      # incluye los literales pegados (armado con variables)
        for m in RM_ARGS.finditer(txt):      # también la forma de lista: ["rm", "-rf", "/x"]
            tokens = [t for t in re.split(r"[\s,\[\]{}()]+", m.group(1)) if t]
            flags = [t for t in tokens if t.startswith("-")]
            if not any((f.startswith("--") and len(f) > 2 and "--recursive".startswith(f)) or (not f.startswith("--") and "r" in f) for f in flags):
                continue
            visto = True
            validos.add((k, m.start()))
            destinos = [t for t in tokens if not t.startswith("-")]
            if not destinos or fuera or any(_destino_fuera(d) for d in destinos) or re.search(r"\{[^}\s]*,", m.group(1)):
                return True
            if concatena and not DESCARTADO.search(txt[max(0, m.start() - 80):m.start()].rstrip("\"'\\`")):
                return True
    # rm -rf armado de modo que ningún rm completo se ve (rm-rf/x pegado): se bloquea salvo que ya se haya visto un rm recursivo bien formado
    # 22-nov: «rm -f archivo» bien formado no es «rm -rf pegado», PERO solo si el código no arma texto (+, chr, fromCharCode, join, plantillas, format): ahí cualquier resto de «rm -f» puede ser una opción -r escondida y se bloquea de más (revisión Opus, 3 rondas); 22-nov noche: también \\x2d, \\u002d, octal, $(...), printf, base64 y decodificadores
    armado = bool(re.search(r"\+|chr\(|fromcharcode|join|\{|`|\$\(|\\x[0-9a-f]{2}|\\u[0-9a-f]{4}|\\[0-7]{2,3}|printf|base64|atob|b64|unhexlify|fromhex|decode|bytes\(|\w\s*=\s*[\x27\x22]?-[a-z]*r|[\x27\x22]rm[\x27\x22]\s*,\s*\[?\s*[a-z_$]\w*\s*[,\]]|%[-#0 +\d.(]*[a-z]|\.format|(?<![\w-])f[\"']", codigo, re.I))
    resto = re.search(r"-rm\b", codigo)      # un «--rm» que no se eximió y trae después una opción con r: recortado queda «rm -rf»
    armado = armado or (resto is not None and re.compile(r"(?<![\w-])-(?:[a-z]*r|-recur)").search(codigo, resto.end()) is not None)
    if armado and any((k, m.start()) not in validos and not DESCARTADO.search(v[max(0, m.start() - 80):m.start()]) for k, v in enumerate(vs) for m in RM_SUELTO.finditer(v)):
        return True      # código que arma texto y menciona un rm sin recursión visible: puede esconder la opción -r (concatenación, chr, variables); se bloquea de más
    return not visto and any(PEGADO.search(v if armado else re.sub(r"\brm[ \t]+-[a-qs-z]+[ \t]+(?=(?!rf?(?:[\s\\\x27\x22]|$))[^-\s\\]|\\+[\x27\x22])", " ", v)) for v in vs)


# 25-nov-2026: «--rm» como opción de docker run / container run / compose run no borra archivos. Nada se decide por posición ni por recorte: se exime solo si TODO el código son llamadas que corren un literal entero
# (nada lo puede cortar ni reescribir) y cada «--rm» es una opción de un comando docker run único y bien parseado. El resto del comando pasa por las mismas reglas que cualquier otro.
LITERAL = re.compile(r""""(?:[^"\\\n]|\\.)*"|'(?:[^'\\\n]|\\.)*'|`(?:[^`\\\n$]|\\.|\$(?!\{))*`""")
SENTENCIA = re.compile(r"(?:(?:(?:const|let|var)[ \t]+)?\w+[ \t]*=[ \t]*)?(?:await[ \t]+)?(?:bash|run|os\.system|subprocess\.run|execSync)\([ \t]*\x00[ \t]*(?:,[ \t]*(?:shell|capture_output|text|check)[ \t]*=[ \t]*True[ \t]*)*\)|(?:print|console\.log)\([ \t]*\w+(?:\.\w+)*[ \t]*\)"
                       r"|(?:await[ \t]+)?edit\([ \t]*(?:\w+|\x00)(?:[ \t]*,[ \t]*\x00){2}[ \t]*\)|(?:await[ \t]+)?\$\x00(?:\.(?:text|nothrow|quiet)\(\))*")
SIN_VALOR = {"--init", "--privileged", "--read-only", "--no-deps", "--service-ports", "--build", "--quiet-pull", "--interactive", "--tty", "--detach", "--publish-all", "--remove-orphans", "-q", "-P"}
CON_VALOR = {"-v", "--volume", "-e", "--env", "--env-file", "--name", "-w", "--workdir", "-u", "--user", "-p", "--publish", "--network", "--net", "--entrypoint", "--mount", "--platform", "--pull", "-m", "--memory", "--cpus", "-l", "--label", "--tmpfs", "--add-host", "-h", "--hostname", "--shm-size", "--gpus"}


def forma_simple(codigo: str) -> bool:
    if "\x00" in codigo or not all(_cuerpo_seguro(c) for c in re.findall(r"\$`([^`]*)`", codigo)):      # una plantilla $`...` solo con órdenes de la lista cerrada
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
    if CONCATENA.search(PWD.sub(".", codigo)) and any(re.search(bandera, re.sub(r"\b(?:[ef]?grep|pgrep|rg)(?:[ \t]+-[a-uw-z]+)*[ \t]+-[a-z]*v", "grep", v)) for v in vs):
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
            if (n.startswith("/") and not (n + "/").startswith(REPO)) or n == ".." or n.startswith("../") or (salio and not n.startswith("/")):
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
        if any(juntos(v, r"(?<![\w.-])zip\b", r"(?<![\w-])(?:-[a-z]*m(?![\w-])|--move)")):      # zip -m borra los originales
            return True
        if any(juntos(v, r"\brsync\b", r"--(?:del|remove-source)")):
            return True
    return False


def comodin_entorno(vs: list[str]) -> bool:
    """Un comodín o una expansión que puede resolver al archivo de entorno cuenta como el archivo. Hace falta una letra del nombre tras una orden que lee, y dos en cualquier otro lugar."""
    for v in vs:
        if ENTORNO_ARMADO.search(v):
            return True
        for orden in re.split(r"[;&|\n]", v):
            lee = LEE.search(orden)
            for m in re.finditer(r"[^\s<>()\"'`=]+", orden):
                t = m.group(0).rsplit("/", 1)[-1]
                if not any(c in t for c in "?*[{"):
                    continue
                for _ in range(3):      # llaves con lista o rango: cualquier cosa
                    t = re.sub(r"\{[^{}]*\}", lambda x: "*" if "," in x.group(0) or ".." in x.group(0) else x.group(0), t)
                t = re.sub(r"\*+", "*", re.sub(r"\[[^\[\]]*\]", "?", re.sub(r"\[([\w.-])\]", r"\1", t)))
                if len(t) - t.count("*") <= 12 and len(re.findall(r"[a-z0-9]", t)) >= (1 if lee and lee.start() < m.start() else 2) and fnmatchcase("platform.env", t):
                    return True
    return False


def razones(codigo: str) -> list[str]:
    if len(codigo) > LARGO_MAXIMO:
        return ["más texto del que se puede analizar"]
    if CADENA_LARGA.search(codigo) or (re.search(r"\b(?:ssh|scp|sftp|rm)\b", codigo) and CADENA_CON_ARGUMENTOS.search(codigo)) or re.search(r"\w=\S{1001}", codigo) or any(len(re.findall(r"\w=", t)) > 12 for t in codigo.split()):
        return ["una cadena de envolturas o un valor demasiado largo"]
    out: list[str] = [REDEFINE] if redefine_pesos(codigo) else []      # sobre el código original, antes de cualquier exención
    codigo = sin_opcion_docker(sin_datos(codigo))
    vs = vistas(codigo)
    letras = [reducido(v) for v in vs]
    if any(COMANDO.search(v) or FORMA.search(v) or IP_USUARIO.search(v) or REPO_REMOTO.search(v) or any(juntos(v, *HOST_CON_OPCION)) for v in vs) or pegados(codigo) or pegados(decodificado(codigo)) or any(DROPLET in r for r in letras):
        out.append("ssh, scp o sftp")
    for clave, etiqueta in PRIMERO.items():
        if any(clave in r for r in letras):
            out.append(etiqueta)
    if any(re.search(r"platform.{0,4}env", r) for r in letras) or comodin_entorno(vs):      # también «platform.%s" % "env"»
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
