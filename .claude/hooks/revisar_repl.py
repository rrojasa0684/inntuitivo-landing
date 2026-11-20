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
    if any(re.search(r"(?<![a-z])ssh(?![a-z])", v) for v in vs[:2]) or "ssh" in letras[2]:
        out.append("ssh")
    for clave, etiqueta in PRIMERO.items():
        if clave != "ssh" and any(clave in r for r in letras):
            out.append(etiqueta)
    if any("ghapi" in r and ("reviews" in r or "merge" in r) for r in letras):
        out.append("gh api con reviews o merge")
    if any(".ssh" in v for v in vs):
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
