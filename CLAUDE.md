# Reglas del repo `inntuitivo-landing` (www.inntuitivo.com, GitHub Pages)

## Ciclo de desarrollo (adoptado el 27-oct-2026, decisiones #44 y #45 de Ricardo)

El documento completo es `docs/PROCESO-DESARROLLO.md` (misma versión que en el motor); acá solo se resume y se apunta, no se duplica.

- Al empezar cada sesión se lee `docs/PROCESO-DESARROLLO.md` y se confirma que `git config core.hooksPath` vale `.githooks` (el hook es por clon; `bash githook-pre-commit-check.sh --clon` lo verifica).
- Antes de tocar nada se clasifica el trabajo (funcionalidad, defecto, code review, auditoría, documentación) y el riesgo (alto, medio, bajo; ante la duda, se sube un nivel).
- Una funcionalidad nueva lleva spec en `docs/specs/` (plantilla `docs/specs/PLANTILLA-SPEC.md`, archivo `AAAA-MM-DD-<tema>.md`) y espera la aprobación de Ricardo.
- **Cualquier cambio visual pasa por la etapa 1 (Design System) con un mock aprobado por Ricardo antes de tocar el sitio.**
- Ramas `feat/<tema>` o `fix/<tema>` desde `main` actualizado. Nunca cambios del sitio directo sobre `main`: el hook `.githooks/pre-commit` rechaza en `main` todo commit que no sea solo documentación (lo que está bajo `docs/` o termina en `.md`). Los merges no se bloquean. **Nunca se usa `--no-verify`** (el escape documentado del `pre-push`, para un cambio de `index.html` que no toca conversión, es solo de Ricardo: el agente le pide que lo use, no lo inventa ni fabrica una marca `baseline`).
- El merge a `main` se hace en local y se empuja `main`, para que el `pre-push` compare contra el `main` remoto real (un merge hecho en GitHub no pasa por ningún hook local).
- **Se publica con merge a `main`: GitHub Pages publica solo.** Un merge es un despliegue; tras él se confirma que `www.inntuitivo.com` responde 200 y que lo bloqueado de abajo no cambió.
- Riesgo medio o alto: revisor adversarial obligatorio (`.claude/agents/revisor-adversarial.md`, solo lectura, otro modelo que el de la sesión). Si la sesión corre en Opus, el revisor se lanza con `model: "sonnet"`; si corre en otro, con el `opus` de su definición. No tiene Bash: quien lo lanza le pega `git diff <rango>` y `git diff --stat <rango>` en el prompt (sin diff no revisa). Todo DEFECTO se arregla; toda observación se arregla con test o va a decisión de Ricardo con recomendación.
- Los `*-check.sh` de la raíz y sus workflows siguen siendo los candados de CI; el hook se prueba con `githook-pre-commit-check.sh`.
- «You should know» (plugin de Claude Code) es una prueba del 27-oct al 3-nov (#45); lo activa y apaga Ricardo, ningún agente ejecuta comandos de plugins.

## Copy bloqueado (decisión de Ricardo, 3-oct-2026): no se toca, ni en texto ni en estructura

1. **El hero completo, con su panel visual.**
2. **La sección de partners** (título, subtítulo y carrusel de logos).
3. **El banner «🪐 Tu plataforma de agentes de IA más innovadora e inntuitiva ✨»** y su línea de apoyo.

Ningún agente cambia ni reordena estos bloques. Los textos exactos están en `docs/memoria/copy-landing-bloqueado-3oct.md` del repo del motor (`outreach-engine`). El cumplimiento legal se resuelve con texto legal y cambios fuera de estos bloques.

## CI de main (decisión #48, 28-oct-2026)

En cada push a main, `githook-check.yml` corre `ci-solo-docs-en-main.sh`: marca en rojo un commit de código que llegó sin pasar por una rama (misma lista blanca del hook: docs/ y archivos .md). Avisa, no bloquea.
