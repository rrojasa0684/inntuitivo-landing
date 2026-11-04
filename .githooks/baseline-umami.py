#!/usr/bin/env python3
"""4-nov-2026: el comentario «baseline» de index.html lo escribe el hook, con los números reales de Umami que deja ops/desplegar.sh del motor (out/umami-baseline.json).
Uso: baseline-umami.py verificar | escribir [index.html]. Archivo ausente o de más de 24 h: sale con 1 y dice qué correr. Nunca se salta (nunca --no-verify)."""
import json
import os
import re
import sys
from datetime import datetime, timezone

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ARCHIVO = os.environ.get("UMAMI_BASELINE_ARCHIVO") or os.path.join(RAIZ, "..", "outreach-engine", "out", "umami-baseline.json")
MAX_HORAS = 24
MARCA = "baseline-auto"


def leer():
    """(datos, error)"""
    try:
        with open(ARCHIVO, encoding="utf-8") as f:
            d = json.load(f)
        gen = datetime.strptime(d["generado"], "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=timezone.utc)
        float(d["scroll_precio_dia"]); float(d["cta_activar_semana"]); str(d["fecha"])
    except FileNotFoundError:
        return None, "no existe el archivo del baseline (" + ARCHIVO + ")"
    except Exception as ex:
        return None, "el archivo del baseline no se puede leer (" + type(ex).__name__ + ")"
    horas = (datetime.now(timezone.utc) - gen).total_seconds() / 3600
    if horas > MAX_HORAS:
        return None, "el baseline tiene %d h (máximo %d)" % (horas, MAX_HORAS)
    return d, None


def comentario(d):
    return "<!-- %s %s: baseline scroll_precio=%g/día, cta_activar=%g/semana (Umami, últimos 14 días, sin pruebas). -->" % (MARCA, d["fecha"], d["scroll_precio_dia"], d["cta_activar_semana"])


def escribir(ruta):
    d, err = leer()
    if err:
        return err
    with open(ruta, encoding="utf-8") as f:
        lineas = f.read().split("\n")
    nueva = comentario(d)
    idx = [i for i, l in enumerate(lineas) if MARCA in l and l.lstrip().startswith("<!--")]
    if idx:
        if lineas[idx[0]] == nueva:
            return None
        lineas[idx[0]] = nueva
    else:
        cuerpo = [i for i, l in enumerate(lineas) if re.match(r"\s*<body[\s>]", l)]
        if not cuerpo:
            return "index.html no tiene <body> donde poner el comentario"
        lineas.insert(cuerpo[0] + 1, nueva)
    with open(ruta, "w", encoding="utf-8") as f:
        f.write("\n".join(lineas))
    return None


if __name__ == "__main__":
    modo = sys.argv[1] if len(sys.argv) > 1 else ""
    err = leer()[1] if modo == "verificar" else escribir(sys.argv[2] if len(sys.argv) > 2 else "index.html") if modo == "escribir" else "uso: verificar | escribir [index.html]"
    if err:
        sys.stderr.write("\n🔴 BASELINE DE UMAMI NO DISPONIBLE: %s.\n   Corre ops/desplegar.sh en el motor para refrescar el baseline y vuelve a intentar. No se salta.\n\n" % err)
        sys.exit(1)
