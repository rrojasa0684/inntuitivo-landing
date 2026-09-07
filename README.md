# inntuitivo-landing

> Última verificación de este README contra el repo real: 7 de septiembre de 2026.

Sitio estático de Inntuitivo (`www.inntuitivo.com`). **GitHub Pages, servido
detrás de Fastly** (la CDN de GitHub Pages) — sin build, sin package.json,
sin dependencias. HTML/CSS/JS plano en cada archivo, cero framework.

## Deploy

**`git push origin main` es producción.** No hay Action de deploy: GitHub
Pages sirve directo desde la rama `main` (configurado en Settings → Pages del
repo), así que un push aterriza en el sitio real apenas GitHub lo procesa —
sin paso intermedio, sin aprobación, sin CI que bloquee el push (no hay
branch protection pagado; ver `.githooks/README.md` para el porqué).

`CNAME` fija el dominio custom (`www.inntuitivo.com`) — sin ese archivo, GitHub
Pages serviría desde `*.github.io`.

## Qué NO se toca sin decisión explícita

**Hero, CTAs y el modal** de la página principal son intocables por decisión
del equipo — son la parte que convierte, y un cambio sin medir ya costó una
semana de datos una vez (ver `docs/memoria/copy-de-conversion-sin-medir-17-ago.md`
en `outreach-engine`, el repo hermano). Cualquier cambio a esas piezas necesita
una marca de `baseline` en el commit — ver CI, abajo.

## Páginas

| Archivo | Qué es |
|---|---|
| `index.html` | La landing: hero, precio, CTAs, formulario de muestra gratis, modal |
| `onboarding.html` | Alta self-service tras el pago — llama a los endpoints de `/onboarding/*` en `api.inntuitivo.com` |
| `activar.html` | Checkout de Paddle — **código inerte hoy**: Paddle rechazó el dominio definitivamente, el gateway activo es PayPal (ver `docs/memoria/paddle-rechazo-definitivo-mor-vs-psp.md` en `outreach-engine`) |
| `cancelar.html` | Cancelación de suscripción, doble opt-in — la página solo renderiza; la baja la confirma un POST tras clic humano |
| `terminos.html` / `privacidad.html` | Legales |
| `404.html` | Página de error |

## El formulario de muestra gratis

`index.html` postea directo a **`https://api.inntuitivo.com/muestra`** (fetch,
sin backend propio en este repo) — el motor de `outreach-engine` recibe la
solicitud, la encola, y un cron la procesa. Este repo no tiene ninguna lógica
de servidor: es el `fetch()` y nada más.

## CI

Dos chequeos, en dos repos distintos, sobre el mismo riesgo (copy que cambia
sin que nadie lo mida ni lo note):

- **`.github/workflows/index-baseline-check.yml`** (este repo): en cada push a
  `main`, si `index.html` cambió, exige que el diff traiga una línea con la
  palabra `baseline` (típicamente un comentario HTML con el número real de
  Umami del día). No bloquea el push — dejaría el commit con el check en rojo,
  visible en Actions.
- **`ops/landing-fixture-sync-check.sh`** (en `outreach-engine`, no acá): clona
  este repo y compara `index.html`/`onboarding.html` reales contra las copias
  vendored en `tests/` de ese otro repo, que los tests de voseo/geo usan como
  fuente de verdad. Corre en el CI de `outreach-engine`, no en el de acá — un
  cambio que toque SOLO este repo no lo dispara; se detecta en el próximo push
  del otro repo.

## Verificación de este README

`readme-nombres-check.sh` (raíz del repo, corre en CI) falla si algún nombre
de archivo entre backticks de ESTE repo ya no existe en el árbol. Las
referencias cruzadas a `outreach-engine` (marcadas en el texto como tal) no se
chequean acá — viven en el árbol del otro repo.
