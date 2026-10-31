#!/usr/bin/env bash
# Auditoría de la landing aprobada (#107, 30-oct-2026): el diff contra BASE debe ser EXACTAMENTE aplicar las parejas
# aprobadas (ops/auditoria-107-aprobados.json) sobre los archivos de BASE -- nada fuera de las líneas aprobadas
# (estructura, estilos, orden, texto bloqueado). Uso: bash auditoria-107-check.sh [BASE]
# PRUEBA DE UN SOLO USO (30-oct): solo es válida contra el commit previo a la #107 y mientras no haya otros cambios (#108-#117 y
# posteriores ya la vuelven roja a propósito). NO corre en CI ni se corre sobre main; se conserva como constancia de esa auditoría.
set -euo pipefail
BASE="${1:-81778c4}"   # último commit de main antes de los cambios de la #107
python3 - "$BASE" <<'PY'
import json, subprocess, sys
base = sys.argv[1]
pares = json.load(open("ops/auditoria-107-aprobados.json", encoding="utf-8"))
mal = []
for f, ps in pares.items():
    t = subprocess.run(["git", "show", f"{base}:{f}"], capture_output=True, text=True, check=True).stdout
    for old, new, n in ps:
        if t.count(old) != n:
            mal.append(f"{f}: el texto viejo aparece {t.count(old)} veces y se esperaban {n}: {old[:60]!r}")
        t = t.replace(old, new)
    if t != open(f, encoding="utf-8").read():
        mal.append(f"{f}: el archivo tiene cambios fuera de las líneas aprobadas")
cambiados = subprocess.run(["git", "diff", "--name-only", base], capture_output=True, text=True, check=True).stdout.split()
ajenos = [c for c in cambiados if c not in pares and not c.startswith(("auditoria-107", "ops/auditoria-107", "textos-actuales-check", ".github/workflows/textos-actuales"))]
if ajenos: mal.append("archivos fuera de lo aprobado: " + ", ".join(ajenos))
print("AUDITORIA_107_OK" if not mal else "\n".join(mal))
sys.exit(1 if mal else 0)
PY
