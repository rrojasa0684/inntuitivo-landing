---
name: verify
description: Verificación liviana antes de commitear la landing de Inntuitivo; corre sus chequeos locales y revisa los enlaces internos de las páginas, bajo 3 minutos. Se usa justo antes de cada commit que no sea solo de documentos.
---

# verify (landing): chequeos locales y enlaces, bajo 3 minutos

Ejecuta `bash .claude/skills/verify/verify.sh`: corre los `*-check.sh` locales de la landing (puntos de quiebre, CTA, países, precios, textos, pipefail, demo, nombres) y comprueba que cada enlace interno de las páginas apunte a un archivo que existe. Imprime comandos, resultado y duración.

**Prohibido aquí:** la red, `chequeo-en-vivo.sh` (corre al cerrar el cambio, una vez), el deploy y la medición de Umami (`baseline-umami-check.sh`). Tope 3 minutos. Con el resultado se escribe la línea `Verificado: ...` del commit.
