#!/usr/bin/env python3
"""#219: aviso de GitHub Actions al motor (POST firmado con HMAC-SHA256). Lo corre el flujo `avisar-motor` de cada repo; el mismo archivo vive en los dos repos.
Entra por variables de entorno (nunca por argumentos: la clave no debe verse en `ps`): AVISO_CLAVE (secreto del repositorio), AVISO_URL (opcional), GITHUB_REPOSITORY, GH_TOKEN (el token del propio flujo, solo para
leer qué paso falló), y los datos de la corrida (AVISO_FLUJO, AVISO_RESULTADO, AVISO_RAMA, AVISO_SHA, AVISO_HORA, AVISO_RUN_ID). Si falla cualquier cosa sale con 0: un aviso que no llega nunca pone un flujo en rojo (el reporte diario
detecta el silencio a las 48 h). Nunca imprime la clave."""
from __future__ import annotations

import hashlib
import hmac
import json
import os
import sys
import urllib.request
from datetime import datetime, timezone

URL = "https://api.inntuitivo.com/github/aviso"


def cuerpo(env, ahora: datetime, error: str | None) -> bytes:
    d = {"repo": env.get("GITHUB_REPOSITORY", ""), "flujo": env.get("AVISO_FLUJO", ""), "rama": env.get("AVISO_RAMA", ""), "resultado": env.get("AVISO_RESULTADO", ""),
         "sha": env.get("AVISO_SHA", ""), "hora": env.get("AVISO_HORA") or ahora.strftime("%Y-%m-%dT%H:%M:%SZ"), "enviado": ahora.strftime("%Y-%m-%dT%H:%M:%SZ")}
    if error:
        d["error"] = error[:300]
    return json.dumps(d, ensure_ascii=False, separators=(",", ":")).encode("utf-8")


def firma(clave: str, datos: bytes) -> str:
    return "sha256=" + hmac.new(clave.encode("utf-8"), datos, hashlib.sha256).hexdigest()


def causa(env, abrir=urllib.request.urlopen) -> str | None:
    """Trabajo y paso que fallaron en la corrida (solo si el resultado es malo y hay token y número de corrida); None si no se puede leer."""
    if env.get("AVISO_RESULTADO") not in ("failure", "timed_out", "startup_failure") or not env.get("AVISO_RUN_ID") or not env.get("GH_TOKEN"):
        return None
    try:
        req = urllib.request.Request(f"https://api.github.com/repos/{env['GITHUB_REPOSITORY']}/actions/runs/{env['AVISO_RUN_ID']}/jobs", headers={"Authorization": f"Bearer {env['GH_TOKEN']}", "Accept": "application/vnd.github+json", "User-Agent": "inntuitivo-aviso"})
        for j in json.loads(abrir(req, timeout=10).read().decode("utf-8")).get("jobs", []):
            if j.get("conclusion") == "failure":
                paso = next((s.get("name") for s in j.get("steps", []) if s.get("conclusion") == "failure"), None)
                return f"trabajo «{j.get('name')}»" + (f", paso «{paso}»" if paso else "")
    except Exception:  # noqa: BLE001
        return None
    return None


def avisar(env=os.environ, ahora: datetime | None = None, abrir=urllib.request.urlopen) -> int:
    ahora = ahora or datetime.now(timezone.utc)
    clave = env.get("AVISO_CLAVE", "")
    if not clave:
        print("aviso: sin clave en este repositorio; no se avisa")
        return 0
    datos = cuerpo(env, ahora, causa(env, abrir))
    req = urllib.request.Request(env.get("AVISO_URL") or URL, data=datos, method="POST", headers={"Content-Type": "application/json", "X-Aviso-Firma": firma(clave, datos), "User-Agent": "inntuitivo-aviso"})
    try:
        r = abrir(req, timeout=15)
        print(f"aviso: enviado ({getattr(r, 'status', '?')})")
    except Exception as ex:  # noqa: BLE001 -- el motor no responde, rechaza la firma o no hay red: el flujo no se pone en rojo por eso
        print(f"aviso: no llegó ({type(ex).__name__}); el reporte diario avisa si el silencio dura 48 h")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(avisar())
    except Exception as ex:  # noqa: BLE001
        print(f"aviso: error inesperado ({type(ex).__name__})")
        sys.exit(0)
