# Hooks versionados

Git no activa `.githooks/` solo por existir en el repo — hace falta apuntar
`core.hooksPath` acá, una vez por clon:

```
git config core.hooksPath .githooks
```

## `pre-push`

Bloquea un push que toca `index.html` (la página que convierte) sin una
marca de `baseline` en el diff. Motivo: el 17-ago-2026, 14 commits de copy
a `index.html` se pushearon el mismo día sin que nadie anotara el número de
ANTES — dos semanas después, comparar era imposible. Ver
`docs/memoria/copy-de-conversion-sin-medir-17-ago.md` en el repo
`outreach-engine`.

**Convención:** cualquier línea agregada en el diff de `index.html` que
contenga la palabra `baseline` (sin importar mayúsculas) cuenta como marca
— típicamente un comentario HTML cerca del cambio, con el número real del
día (no un placeholder):

```html
<!-- 1-sep: baseline scroll_precio=9/día, cta_activar=0/semana. Comparar en 2 semanas. -->
```

**Escape a propósito** (un typo, un link roto, nada que toque conversión):
`git push --no-verify`.

**⚠️ Límite, desde el día uno:** es un hook LOCAL. Protege un push hecho
desde una máquina con este `core.hooksPath` configurado — NO protege un
push desde otra máquina sin el mismo config, ni una edición hecha directo
en el editor web de GitHub (que commitea sin pasar por ningún hook local).
No es un gate de CI porque este repo no tiene CI.
