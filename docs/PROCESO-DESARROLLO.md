# Ciclo de desarrollo de Inntuitivo

Fecha: 5 de octubre de 2026 · **Versión liviana del 31 de octubre de 2026 (decisiones #121 a #123)** · Para Claude Code en los dos repos (outreach-engine e inntuitivo-landing)

**Todo trabajo pasa por el mismo ciclo:**

1. Se planifica, con todas las decisiones de producto juntas al empezar.
2. Se construye en una rama, con un test por criterio.
3. Lo revisa un agente de otro modelo que intenta romperlo.
4. Se publica y se prueba como lo usaría un cliente.

**El esfuerzo de cada etapa se ajusta al riesgo y al tamaño del cambio.** Lo pesado corre solo de noche o una vez por semana, no en cada corrida. Las únicas aprobaciones de Ricardo son las decisiones de producto. Un defecto se corrige y se publica sin esperar a nadie.

> **Por qué la versión liviana (31-oct):** la semana del 27 al 31 de octubre, cada funcionalidad tardó cerca de 24 horas. Esto fue lo que más tiempo se llevó:
> - el Ready to Release completo en cada cambio (de 25 a 60 minutos cada vez);
> - de 2 a 3 rondas de revisión con Opus, y hasta 15 agentes en paralelo;
> - el cierre pesado (contexto) en cada mini-corrida;
> - el UX descubierto después de construir;
> - decisiones que aparecían a mitad de la corrida;
> - alcance que se sumaba de madrugada.
>
> El ciclo se mantiene. Cambia cuánto se hace en cada etapa.

## 0. Punto de partida

Se relee desde disco al empezar cada sesión:

| Qué | Dónde |
| --- | --- |
| Visión, problema y estado del producto | `INNTUITIVO-CONTEXTO-<N>.md` en la raíz del repo del motor |
| Decisiones vigentes, pendientes y programado | `docs/ABIERTO-ENTRE-SESIONES.md` |
| Observaciones menores de la semana | `docs/LOTE-SEMANAL.md` |
| Historia, decisiones y notas | La bóveda de Obsidian, editada solo con `ops/boveda_escribir.py` |
| Mapa del código | Graphify |

Ninguna etapa contradice una decisión vigente. Si una parece mal, se le propone el cambio a Ricardo, pero no se cambia.

## 1. Tamaño, riesgo y camino

### Tamaño de la corrida

| Tamaño | Ejemplos | Meta de duración |
| --- | --- | --- |
| **Chico** | Un texto, un defecto acotado, un ajuste de un correo | 20 a 40 minutos |
| **Mediano** | Una pantalla, un correo nuevo, un control nuevo | 60 a 90 minutos |
| **Grande** | Una funcionalidad con varias partes | **Se parte en piezas medianas**, cada una con su despliegue. Nunca una cadena de toda la noche |

### Riesgo

| Nivel | Qué toca | Revisión adversarial | Prueba como cliente en la corrida |
| --- | --- | --- | --- |
| **Alto** | Envíos, a quién se le escribe, cobros, datos personales, borrado, infraestructura de producción, seguridad | 1 ronda, Opus | Recorrido focal de lo tocado y verificación en producción |
| **Medio** | Reportes, alertas, avisos, métricas, pantallas del cliente | 1 ronda, Sonnet | Recorrido focal o vista previa de lo tocado |
| **Bajo** | Textos internos, documentación, refactor sin cambio de comportamiento | No hace falta | La suite en verde alcanza |

Ante la duda, se sube un nivel de riesgo, no de tamaño.

### Camino por tipo de trabajo

| Tipo | Etapas | Quién aprueba |
| --- | --- | --- |
| **Funcionalidad o cambio de producto** | Todas | Ricardo aprueba la spec y, si es visible para el cliente, las pantallas |
| **Defecto** | Spec breve, desarrollo, revisión si el riesgo es medio o alto, publicación y recorrido focal | Nadie: se corrige ahora |
| **Code review de la etapa** | En el cierre semanal (sección 3) | Nadie |
| **Solo documentación** | Un commit de documentación | Nadie |

## 2. Las etapas

### 1 · Diseño antes de construir (si cambia algo visible para el cliente)

- Se usan los tokens de la landing: colores, Audiowide y Jost, espaciado. Nada nuevo sin decisión de Ricardo.
- **Copy bloqueado:** los 5 textos del hero y del banner, y los partners, no cambian.
- **Antes de escribir código, Ricardo ve las pantallas o el correo:** un mock, capturas de un prototipo o vistas previas, en celular y en computadora. Las aprueba o las corrige. Esto evita reconstruir después de grabar.
- **Sale:** pantallas aprobadas, o "sin cambio visible".

### 2 · Planificación, con todas las decisiones juntas

```
SPEC: <titulo>
TIPO: funcionalidad | defecto      RIESGO: alto | medio | bajo      TAMANO: chico | mediano
PROBLEMA: que pasa hoy, con evidencia
DECISIONES VIGENTES QUE TOCA: cuales, y como se respetan
DECISIONES DE RICARDO QUE HACEN FALTA: todas, juntas, con opciones y recomendada
CRITERIOS DE ACEPTACION (numerados, verificables)
ARCHIVOS: cuales cambian
PRUEBA: como se verifica cada criterio, sin cobrar ni enviar a nadie real
RECORRIDO FOCAL: que flujos del Ready to Release toca
RED DE SEGURIDAD: que pasa si vuelve a fallar sin nadie mirando
VUELTA ATRAS: como se revierte en un paso
COSTO: llamadas pagadas que agrega en produccion
FUERA DE ALCANCE: lo que no se toca
```

- **Las decisiones se responden todas antes de construir.** La corrida no se frena en el medio.
- Si al construir aparece una decisión nueva, se presenta y queda en ESPERANDO. La corrida sigue con lo que no depende de ella.
- La spec nunca toma decisiones de producto.
- Para un defecto alcanza con la causa, el arreglo y los criterios.
- **El alcance no crece a mitad de corrida.** Lo nuevo va a la corrida siguiente.

### ✓ Ready to Build

- **Funcionalidad:** Ricardo aprueba la spec y las pantallas.
- **Defecto:** pasa solo si no toca decisiones de producto.

### 3 · Desarrollo y tests

- Una rama aparte, `feat/<tema>` o `fix/<tema>`, desde `main` actualizado.
- Un test por criterio, más el test del caso exacto que originó el trabajo. Los tests recorren la lista real, nunca cuentan, para que no haya falsos positivos.
- Durante el desarrollo, **solo tests dirigidos**.
- **La suite completa corre una sola vez, al final.** Si falla, se arregla la causa y se repite una vez.
- **Por sesión, una sola suite: la paralela (`ops/test-linux.sh`).** La serial, la de orden normal y la de orden aleatorio (`PYTEST_OBJETIVO="tests/ --orden-semilla=N"`) corren solo en el cierre semanal (aleatoria con semilla nueva; si falla, se anota la semilla en ABIERTO) o si Ricardo las pide explícito. Ningún prompt anula esta regla. Para buscar un test que contamina se corre UNA vez el detector y se verifican solo los archivos marcados.
- **Antes de la única suite completa (3-nov-2026):** correr solo los tests de lo tocado y de lo que depende de ello. Si la suite completa falla por el cambio, se arregla, se corren solo los tests que fallaron y la suite completa se repite una sola vez.
- **Commit antes de la suite (4-nov-2026):** antes de la única suite completa, todo queda commiteado en la rama: una suite sobre un árbol sin commitear no escribe la marca y obliga a repetirla.
- **Prueba del buscador (#155, 4-nov-2026):** la prueba de las 35 empresas se remide sola cuando cambia el código que decide qué es un decisor válido (su «versión» es la huella de la lista `ELEMENTOS_QUE_DECIDEN` de `app/prospecting/buscador_decisores.py`) y cada 30 días; nunca se publica una cifra sin «verificacion vigente: si» en la línea «PRUEBA DECISORES» del deploy.
- **PROGRAMADO es solo para causas externas.** El trabajo propio con fecha se presenta a Ricardo con la opción de cerrarlo hoy (3-nov-2026, #142).
- Sin llamadas pagadas ni envíos reales en los tests.

### 4 · Revisión adversarial: una ronda

- Un agente de otro modelo revisa el diff en solo lectura, con el encargo de romperlo:
  - Opus para riesgo alto.
  - Sonnet para riesgo medio.
  - Nada para riesgo bajo.
- Preguntas obligatorias:
  - ¿Qué pasa si corre sin nadie mirando?
  - ¿Qué decide solo, y qué pasa si decide mal?
  - ¿Puede enviar, cobrar, borrar o mostrar algo que no debe?
  - ¿Hay un control que diga "OK" sin datos?
  - ¿Se cumple cada criterio, o solo el test?
- **Qué se arregla en la corrida:**
  - todo DEFECTO;
  - toda observación de impacto medio o alto;
  - toda observación menor que se resuelva en menos de 15 minutos.
- **Lote semanal (#121):** las observaciones menores que llevan más tiempo se anotan en `docs/LOTE-SEMANAL.md`, con archivo, propuesta y tiempo estimado, y se cierran en la sesión semanal. Nunca quedan abiertas más de una semana.
- **Segunda ronda, solo si se corrigió un defecto de severidad alta**, y solo sobre ese diff.
- Una observación que exige una decisión de producto va a ESPERANDO, con su recomendación.

### ✓ Ready to Merge

- Suite completa en 0 fallos.
- Nada abierto del revisor, salvo lo que fue al lote semanal.
- Diff limpio: sin código muerto, sin secretos, sin temporales.
- Merge a `main` con `--no-ff`.

### 5 · Publicación

| | Motor | Landing |
| --- | --- | --- |
| Cómo | Un solo deploy por `ops/deploy.sh`, con la verificación de producción incluida y nginx aplicado solo | Merge a `main` (GitHub Pages publica solo) |
| Después | El droplet igual a `origin/main` | `www.inntuitivo.com` responde 200 con lo nuevo |

- La limpieza de Docker del droplet se hace solo con `ops/docker-builder-prune.sh` y la del deploy (#134); la de la Mac, solo con `ops/mac-poda-docker.sh` (solo los volúmenes huérfanos de la suite, nunca uno con nombre propio ni en uso; se corre al cerrar la corrida).
- Nada de actualizaciones del sistema sin decisión de Ricardo.
- Las lecturas de producción solo pasan por la verificación del deploy y por el cron. Nunca se le piden comandos a Ricardo.

### ✓ Ready to Release: recorrido focal (#122)

- **En cada corrida de riesgo medio o alto:**
  - solo los flujos que tocó el cambio;
  - en Chromium, en celular y en computadora;
  - de 3 a 5 minutos.
  - Si es un correo o un reporte, la vista previa en los casos que importan.
- **El Ready to Release completo** (27 recorridos en Chromium, Firefox y WebKit) **no corre en cada cambio.**
  - Corre solo cada noche contra producción y apaga solo lo afectado si falla.
  - Corre también en el cierre semanal.
  - Si la corrida nocturna falla después de un cambio, el arreglo es un defecto y sigue el camino de defecto.
- Ricardo prueba a mano solo cuando el cambio es visible para los clientes y él lo pide.

### 🚀 Go live y cierre de la corrida (liviano)

- Se observa el primer ciclo real: el próximo cron, el próximo envío, el próximo reporte.
- **Cierre de la corrida, solo esto:**
  - commit de documentación;
  - ABIERTO releído y actualizado;
  - la nota del día en la bóveda;
  - limpieza de los dos entornos (Mac y droplet).
- **No van en cada corrida:**
  - el documento de contexto;
  - (el Graphify semántico de lo que cambió no está acá: va en cada cierre);
  - el code review de toda la etapa;
  - el Ready to Release completo.

Todo eso va al cierre semanal.

## 3. Cierre semanal (#123)

**Lo inicia Claude Code, nunca Ricardo (#127, 31-oct-2026).** Al empezar cualquier sesión, antes del pedido de Ricardo, Claude Code revisa en ABIERTO la fecha del último cierre semanal registrado y si hubo commits en el motor o en la landing desde entonces:

- si pasaron 7 días o más y hubo cambios, hace primero el cierre completo de abajo, sin preguntar, y después sigue con el pedido;
- si no hubo cambios, no hace nada y lo anota en una línea;
- respeta las reglas de siempre: una sola suite, un solo deploy si hace falta, y toda decisión de producto que aparezca va a ESPERANDO;
- también se hace al terminar una funcionalidad grande.

Contenido del cierre:

1. **Lote semanal:** se cierran todas las observaciones de `docs/LOTE-SEMANAL.md`. Al terminar queda vacío.
2. **Code review de la semana:**
   - una revisión adversarial con Opus sobre las costuras entre lo que cambió;
   - por área, solo en las áreas de riesgo alto que cambiaron;
   - un revisor por área tocada, no uno por área del producto.
3. **Ready to Release completo** contra producción.
4. **Documento de contexto** nuevo: lo arma Claude Code a partir del último, en la raíz del repo, y se copia a la bóveda y a `~/Downloads` con el mismo SHA-256. La bóveda queda al día.
5. **Comprobación del grafo:** 0 documentos sin caché (el Graphify semántico se hizo en cada cierre).
   - Antes, una corrida de la suite en **orden aleatorio con semilla nueva** (`--orden-semilla=N`, serial); si falla, la semilla va a ABIERTO y el arreglo es un defecto.
6. **Limpieza profunda** de la Mac y del droplet, incluida la caché de Docker, para que el snapshot no crezca.

## 4. Reglas que aplican siempre

- **Decisiones de producto:** son de Ricardo. Claude recomienda y Ricardo decide. "Sin depender de Ricardo" significa que el producto funciona solo.
- **Corridas cortas:** una funcionalidad por corrida, una suite, un deploy. Nada de cadenas de toda la noche.
- **Paralelismo con criterio:** subagentes en paralelo solo cuando el trabajo es grande e independiente. Una sola espera por proceso, nunca monitores duplicados.
- **Una sesión de Claude Code por repo.**
- **Secretos:** ningún secreto, token ni correo de una persona en pantalla, argumentos, logs, commits ni bóveda.
- **Llamadas pagadas:** cero en tests y verificaciones.
- **Releer desde disco** ABIERTO y la bóveda antes de editarlos.
- **Documento de contexto:** se copia de `~/Downloads` a la raíz del repo, nunca se mueve.
- **Cero pendientes reales:** lo que se encuentra se arregla en la corrida, va al lote semanal (solo observaciones menores) o queda en ABIERTO con su categoría.
- **Producción decide con el dato (#140, 2-nov-2026):** si un arreglo depende de datos de producción, el diagnóstico y el arreglo van en el mismo deploy: el código decide con el dato cuando corre, dentro del deploy o del cron. Nunca se despliega primero para leer y después para arreglar.
- **Tope por sesión:** una suite paralela y un deploy. Si un deploy falla, se arregla y se repite: es lo único que justifica un segundo deploy. Un cambio solo de documentación no corre la suite.
- **Un script temporal no se despliega con fecha de vencimiento:** se borra en la misma corrida o va al lote semanal con fecha.
- **Un cambio en la landing no está terminado hasta que el chequeo en vivo de lo publicado pasa** (`chequeo-en-vivo.sh` de la landing: 200 en cada página del sitemap, 0 enlaces internos rotos, las páginas retiradas dan 404, nada menciona lo retirado). Corre solo tras cada publicación de Pages y a diario.
- **Una decisión sin resolver siempre figura en ESPERANDO.** Nunca se saca de la categoría para que dé cero.

## 5. Decisiones vigentes de este proceso

- **#44:** ciclo adoptado en los dos repos.
- **#121:** observaciones menores al lote semanal, cerradas en una semana como máximo.
- **#127:** el cierre semanal lo inicia Claude Code solo, al empezar una sesión con 7 días o más desde el último y cambios en medio; Ricardo no lo pide.
- **#122:** recorrido focal en cada corrida; el Ready to Release completo, cada noche y en el cierre semanal.
- **#123:** el cierre pesado (contexto, code review de la etapa), una vez por semana; el Graphify semántico de lo que cambió va en cada cierre (regla del 3-nov, nunca se pasa al semanal).
- **#140:** el diagnóstico temporal del remate y la confirmación del conteo de tests se retiraron el 2-nov dentro del deploy del code review del día; nacen las tres reglas de producción-con-dato, tope por sesión y script temporal.
- **#141 (3-nov):** Claude Code decide con datos, sin preguntar, la prueba de «You should know» (#45); sin línea base del uso del plan, se retiró. Toda decisión anunciada en un reporte sale de una sola fuente.
- **#142 (3-nov):** el respaldo de los enlaces de cancelación antiguos se retiró; un enlace antiguo o vencido lleva al flujo actual, que identifica la cuenta con el correo de pago o con el del buzón conectado de una cuenta activa; «Cancelar mi agente» en Ajustes cancela directo (#36).
- **#144 (3-nov):** la confirmación de baja va SIEMPRE al correo de pago (el dueño), nunca al buzón conectado, aunque la persona haya escrito el del buzón; la pantalla responde igual exista o no la cuenta y el correo dice que alguien pidió cancelar desde la página pública y que, si no fue el dueño, se ignore.
- **#145 (3-nov):** los deploys con `ops/desplegar.sh` están autorizados de forma permanente; sus candados son la marca de suite, el push previo, el HEAD esperado, la verificación de producción y la vuelta atrás.
- **Log del deploy (4-nov):** el log del deploy se guarda completo en un archivo y se busca la línea que hace falta; nunca se corta con tail.
- **Regla de Graphify (3-nov):** prohibido el re-estampado a mano: si `graphify_docs_cambiados.py` no da 0 después del merge, es un defecto de la herramienta y se arregla; el cierre de cada sesión corre `graphify_docs_cambiados.py` y exige 0 en todo el repo (motor); lo excluido va en `.graphifyignore` con su motivo.
- **#143 (3-nov):** el correo inventado de gmail que llegó al remoto se deja en el historial; el pre-commit frena correos personales en `tests/` y `app/`.
- **Reglas del 3-nov:** tests de lo tocado antes de la única suite completa, con una sola repetición; «PROGRAMADO es solo para causas externas»; push antes de deploy y el deploy verifica el HEAD esperado (`ops/desplegar.sh`, motor); el Graphify semántico va en cada cierre; las decisiones viven solo en la sección ESPERANDO de ABIERTO (cerrarlas o abrirlas no requiere deploy).
- **Reglas del 4-nov:** un solo monitor por espera (mientras la tarea corre no se arman monitores nuevos); si `ssh-add -l` no tiene identidades, se carga la clave desde el Llavero con `ssh-add --apple-use-keychain` (comando exacto en `CLAUDE.md`; nunca se pide una frase de paso); el baseline de Umami de la landing lo escribe solo el hook de pre-commit con los números de `ops/desplegar.sh` (`out/umami-baseline.json`, solo de un deploy bueno y con la fecha de los números de a lo más 1 día) y el de pre-push exige que no pasen de 24 h, sin `--no-verify`; la prueba del buscador (#155) se remide sola cuando cambia la huella de `ELEMENTOS_QUE_DECIDEN` y cada 30 días.
- **#146 a #169 (3 al 5-nov):** Explee retirado y cancelado (#146); buscador de decisores propio en los cuatro caminos con tope de $0.02 por empresa (#147 a #156); borrado y lápida por persona (#153, #154); demo público como espejo anonimizado (#157 a #160); tarjeta «Decisores encontrados» (#165); listas subidas por el cliente, solo suyas (#161 a #164, #167, #168); enlaces como texto en los correos al cliente (#166); la landing dice «Inntuitivo es tu SDR con IA» (#169). Detalle en ABIERTO y en `docs/memoria/`.

## 6. Dónde vive este documento

- `docs/PROCESO-DESARROLLO.md` en los dos repos, referenciado desde `CLAUDE.md` y desde ABIERTO.
- Copia en la bóveda, en `30 Recursos/`.
- Toda sesión de Claude Code lo lee al empezar.
