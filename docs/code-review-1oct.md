# Code review de la landing, 1-oct-2026 (PR #1, #2 y #3)

**Resumen:** de lo cambiado hoy hay 2 defectos de dureza en el workflow semanal y 1 chequeo faltante del formato de precio (los 3 arreglados en el PR de esta revisión) y 1 punto decidido por Ricardo (archivos internos servidos por GitHub Pages, ya excluidos); botones, anclas, métricas de Umami y móvil/escritorio sin hallazgos.

Commits de main del 1-oct: `d601baf` (sección de precio unificada), `d6edde1` (npm install en la acción), `c4200b6` (columna Inntuitivo: borde, cohete, total), `e917a44` (separadores de fila).

| # | Clasificación | Severidad | Archivo:línea | Estado |
|---|---|---|---|---|
| 1 | DEFECTO: el Issue pegaba `resultado.json`/`error.txt` (que pueden traer texto de un tercero) sin limpiar: unas comillas invertidas cerraban el bloque de código y dejaban markdown, HTML o menciones | media-baja | `.github/workflows/precios-competencia-semanal.yml` (paso del Issue) | CORREGIDO: se quitan comillas invertidas, `<`, `>`, `@`, `[`, `]`, `(`, `)` y todo lo no imprimible, se rompe `//` (sin autoenlaces) y hay tope de 1.500 caracteres; nunca se enlaza ni se ejecuta (probado con HTML, mención y enlace markdown) |
| 2 | DEFECTO: si fallaba un paso anterior a la verificación (npm, navegador) el workflow terminaba en rojo pero no abría ningún Issue (el paso del Issue solo corría con código de salida ≠ 0 de la verificación) | media-baja | mismo archivo, `if` del paso del Issue | CORREGIDO: `always() && codigo != '0'`; código vacío cuenta como falla. La fecha sigue sin tocarse en cualquier falla |
| 3 | DEFECTO (falta de chequeo): nada en el repo impedía que `precios-competencia.json` llevara algo distinto de "$" + número como precio | baja | `precio-competencia-check.sh` | CORREGIDO: el chequeo falla si `entrada_mensual` no cumple `^\$[0-9]+(\.[0-9]{1,2})?$`; probado con `<b>65</b>` |
| 4 | DECISIÓN DE RICARDO: GitHub Pages servía toda la raíz del repo (script, verificador, `design/`, `*.sh`, etc. públicos por URL, sin enlaces y sin datos sensibles) | baja | raíz del repo | CORREGIDO por decisión de Ricardo: Pages publica con Jekyll (`build_type: legacy`, rama main), así que `_config.yml` con `exclude:` deja fuera `*.sh`, `*.mjs`, `design/`, `ops/`, `docs/`, `README.md`, `package*.json`, `node_modules` y carpetas de herramientas; siguen publicados el sitio, sus páginas, `robots.txt`, `sitemap.xml` y `precios-competencia.json` |

Verificado sin hallazgos:
- **Contenido de terceros:** el verificador no escribe nada; solo lee y compara con regex numérica estricta (`\d+(\.\d+)?`) contra el JSON. La acción únicamente reescribe el campo `verificado` con `date -u +%F`. La página pinta fecha y rango con `textContent` y `parseFloat` (no hay `innerHTML` en ese código); la fecha solo se usa si cumple `AAAA-MM-DD`.
- **Workflow:** permisos `contents: write` e `issues: write` y nada más; sin secretos (`GITHUB_TOKEN` de la corrida); solo `schedule` y `workflow_dispatch`, y un commit con `GITHUB_TOKEN` no dispara otros workflows; el paso de la fecha solo corre con código 0.
- **Botones y anclas:** un solo `btn-primario` en `#precio` (línea del plan → `/suscribir`); nav, hero y Mercately a `#activar`; `#precio` y `#activar` verificados en vivo (posición bajo el encabezado fijo); el JSON-LD no usa anclas.
- **Enlaces:** 0 en `index.html` al script ni a `github.com/rrojasa0684`.
- **Umami:** un solo enlace a `/suscribir` (`cta_activar` una vez por clic); `scroll_precio` con un observador sobre `#activar` que se desconecta tras disparar; `cta_ver_precio` en los `#activar`; sin doble conteo. La definición de `scroll_precio` cambió el 1-oct (ahora mide el plan) y el reporte semanal del motor lo aclara.
- **Móvil y escritorio:** sin desbordes a 390 y 1280 px (medido en la rama y en vivo tras cada PR).
