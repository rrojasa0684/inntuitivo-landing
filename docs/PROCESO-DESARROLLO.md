# Ciclo de desarrollo de Inntuitivo

Fecha: 5 de octubre de 2026 (actualizado el 8 de octubre: "You should know") · Para Claude Code en los dos repos (outreach-engine e inntuitivo-landing) · Basado en el "Ciclo de desarrollo agéntico" y adaptado a cómo funciona Inntuitivo

**Todo trabajo en los repos pasa por el mismo ciclo: se planifica, se construye en una rama con un test por criterio, lo revisa un agente de otro modelo que intenta romperlo, se publica y se prueba como lo usaría un cliente antes de darlo por terminado.** Cuánto del ciclo se recorre depende del tipo de trabajo y de su nivel de riesgo (secciones 1 y 2). Las únicas aprobaciones que dependen de Ricardo son las decisiones de producto: un defecto se corrige y se publica sin esperar a nadie.

## 0. Punto de partida

El equivalente del PRD de Inntuitivo ya existe y se relee desde disco al empezar cada sesión:

| Qué | Dónde |
| --- | --- |
| Visión, problema y estado del producto | `INNTUITIVO-CONTEXTO-<N>.md` en la raíz del repo del motor |
| Decisiones vigentes, pendientes y programado | `docs/ABIERTO-ENTRE-SESIONES.md` |
| Historia, decisiones y notas | La bóveda de Obsidian, editada solo con `ops/boveda_escribir.py` |
| Mapa del código | Graphify |

Ninguna etapa contradice una decisión vigente. Si una parece mal, se propone el cambio a Ricardo; no se cambia.

## 1. Qué camino sigue cada tipo de trabajo

| Tipo de trabajo | Etapas | Quién aprueba |
| --- | --- | --- |
| **Funcionalidad nueva o cambio de producto** | Todas, de la 1 a Go live | Ricardo aprueba la spec (Ready to Build) |
| **Defecto** (algo no hace lo que ya se decidió) | 2 breve, 3, 4 si el riesgo es medio o alto, 5, Ready to Release, Go live | Nadie: se corrige ahora |
| **Code review o cierre de etapa** | 4 sobre el rango de commits; si aparece un DEFECTO, el camino de defecto | Nadie |
| **Auditoría** (por ejemplo, antes de un viaje) | Ready to Release sobre todo el producto | Nadie; lo que pida decisión va a ESPERANDO DECISION |
| **Solo documentación** | Un commit de documentación | Nadie |

La etapa 1 (Design System) solo aplica cuando cambia algo visual.

## 2. Niveles de riesgo

Se asignan en la planificación y deciden cuánta revisión hace falta.

| Nivel | Qué toca | Revisión adversarial | Ready to Release |
| --- | --- | --- | --- |
| **Alto** | Lo que decide solo frente a un cliente o un prospecto: envíos, a quién se le escribe, cobros, datos personales, borrado, infraestructura de producción (Docker, crons, nginx), seguridad | Obligatoria, con dos focos mínimo | Recorrido completo en navegadores reales y verificación en producción |
| **Medio** | Lo que decide si alguien se entera: reportes, alertas, avisos, métricas | Obligatoria | Vista previa del reporte o del aviso en los casos que importan |
| **Bajo** | Textos internos, comentarios, documentación, refactor sin cambio de comportamiento | Opcional | La suite en verde alcanza |

Ante la duda, se sube un nivel.

## 3. Las etapas

### 1 · Design System — solo si cambia algo visual

- Se usan los tokens existentes de la landing (colores, tipografías Audiowide y Jost, espaciado). Nada de colores ni fuentes nuevas sin decisión de Ricardo.
- **Copy bloqueado (decisión de Ricardo, 3-oct):** el hero, la sección de partners y el banner "Tu plataforma de agentes de IA más innovadora e inntuitiva" no cambian ni en texto ni en estructura.
- Para diseños nuevos: un mock (Claude Design o el tipo Design de artefactos) que Ricardo aprueba antes de construir.
- **Sale:** el mock aprobado, o "sin cambio visual".

### 2 · Planificación

La spec es corta y concreta. Para un defecto alcanza con la causa, el arreglo y sus criterios.

```
SPEC: <titulo>
TIPO: funcionalidad | defecto            RIESGO: alto | medio | bajo
PROBLEMA: que pasa hoy, con evidencia (reporte, log, dato)
DECISIONES VIGENTES QUE TOCA: cuales, y como se respetan
CRITERIOS DE ACEPTACION (numerados, cada uno verificable):
  1. ...
  2. ...
ARCHIVOS: cuales cambian
PRUEBA: como se verifica cada criterio, sin cobrar ni enviar a nadie real
RED DE SEGURIDAD: que pasa si vuelve a fallar sin nadie mirando
VUELTA ATRAS: como se revierte en un paso
COSTO: llamadas pagadas que agrega en produccion (0 si ninguna)
FUERA DE ALCANCE: lo que no se toca
```

- La arquitectura sigue a la existente; si hay que cambiarla, la spec lo dice y lo justifica.
- La spec nunca toma decisiones de producto (fechas, prioridades, precios, qué se construye o se descarta): las propone como opciones con recomendación.

### ✓ Ready to Build

- **Funcionalidad nueva:** Ricardo aprueba la spec.
- **Defecto:** pasa solo, si la spec no toca ninguna decisión de producto.
- Si al construir aparece algo que cambia la spec, se vuelve aquí.

### 3 · Desarrollo y tests

- **Rama aparte:** `feat/<tema>` o `fix/<tema>`, desde `main` actualizado. Nunca se trabaja directo sobre `main`.
- **Un test por criterio de aceptación**, más el test del caso exacto que originó el trabajo.
- Los tests no hacen llamadas pagadas ni envían nada a nadie real: los servicios externos se simulan.
- Se cumplen las reglas del producto: "la verdad mata, el encaje ordena", nada sin respaldo llega a un correo, nunca correos deducidos por patrón, nada de nombres de herramientas internas a la vista.
- La suite completa corre una sola vez, al final, en 0 fallos.

### 4 · Revisión adversarial

- **Un agente de otro modelo revisa el diff**, en solo lectura. Su encargo no es aprobar: es intentar romperlo.
- Preguntas obligatorias del revisor:
  - ¿Qué pasa si esto corre sin nadie mirando durante 17 días?
  - ¿Qué decide solo, y qué pasa si decide mal?
  - ¿Puede enviar, cobrar, borrar o mostrar algo que no debe?
  - ¿Hay un control que diga "OK" sin datos?
  - ¿Se cumple cada criterio de la spec, o solo el test?
- Reporte en tabla: clasificación (DEFECTO u observación), severidad, archivo:línea y propuesta.
- **Todo DEFECTO se arregla y toda observación se arregla con test** antes del merge. Si arreglar una observación exige una decisión de producto, va a ESPERANDO DECISION con recomendación.
- Después de los arreglos, el revisor mira solo el diff nuevo, una vez.

### ✓ Ready to Merge

- Suite completa en 0 fallos.
- Reporte del revisor sin nada abierto.
- Diff limpio: sin código muerto, sin secretos, sin archivos temporales.
- ABIERTO actualizado (releído desde disco antes de editarlo).
- **Merge a `main`** con un mensaje que nombra la spec.

### 5 · Publicación

| | Motor (outreach-engine) | Landing (inntuitivo-landing) |
| --- | --- | --- |
| Dónde | Droplet de DigitalOcean, en Docker | GitHub Pages |
| Cómo | Un solo deploy desde `main`; después, droplet igual a `origin/main` | Merge a `main` (GitHub Pages publica solo) |
| Entorno de prueba | Verificación en seco en producción (sin enviar ni cobrar) y tráfico interno marcado con el encabezado de prueba | Vista previa local y tráfico marcado con el encabezado de prueba |

- La limpieza de Docker del droplet se hace solo con `ops/docker-builder-prune.sh`.
- Nada de actualizaciones del sistema en el droplet sin decisión de Ricardo.

### ✓ Ready to Release — probado como lo usaría un cliente

En Inntuitivo esta prueba se automatiza para que no dependa de Ricardo:

- **Recorridos de punta a punta en navegadores reales** (Chromium, WebKit y Firefox) hasta el último paso seguro: sin cobrar, cancelar ni enviar a nadie real, con datos internos que se limpian después.
- **Vista previa** de cada correo, reporte o aviso que cambió, en los casos que importan (día hábil, fin de semana, sin datos, con datos).
- **Verificación en producción** de cada criterio de la spec.
- Ricardo prueba a mano solo cuando el cambio es visible para los clientes y él lo pide; si no, este paso pasa solo.

### 🚀 Go live

- Se observa el **primer ciclo real** (el próximo cron, el próximo envío, el próximo reporte) y se confirma que coincide con la prueba en seco.
- Si algo falla, la red de seguridad de la spec avisa una sola vez con la causa, y la vuelta atrás está escrita.
- **Cierre de sesión:** commit de documentación, bóveda al día (con `ops/boveda_escribir.py`), Graphify con `ops/graphify_cierre.sh`, limpieza de los dos entornos (Mac y droplet) y las categorías de ABIERTO copiadas del archivo releído.

## 4. Reglas que aplican siempre

- **Decisiones de producto:** son de Ricardo. Claude recomienda; Ricardo decide. "Sin depender de Ricardo" significa que el producto funciona solo, no que Claude decide por él.
- **Corridas cortas:** una suite, un deploy, sin re-escaneos innecesarios, sin loops ni despertares.
- **Una sesión de Claude Code por repo.**
- **Secretos:** ninguna contraseña, token ni correo de persona en pantalla, argumentos, logs, commits ni bóveda.
- **Llamadas pagadas:** cero en tests y verificaciones. En producción, solo las que la spec declara.
- **Releer desde disco** ABIERTO y la bóveda antes de editarlos, aunque parezcan conocidos.
- **Documento de contexto:** se copia de `~/Downloads` a la raíz del repo, nunca se mueve.
- **Cero pendientes:** lo que se encuentra se arregla en la misma sesión o queda en ABIERTO con su categoría.

## 5. Qué cambia respecto de cómo se trabaja hoy

| Hoy | Con este ciclo |
| --- | --- |
| Commits directos a `main` | Rama aparte y merge después de Ready to Merge |
| Prompt directo a Claude Code | Spec escrita con criterios numerados antes de construir |
| Revisores del mismo modelo | Un revisor de otro modelo, con encargo adversarial |
| Algunas observaciones quedaban "sin arreglo" | Toda observación se arregla con test antes del merge |
| La prueba como cliente, solo en auditorías | Ready to Release en cada cambio de riesgo medio o alto |

Ya se hace igual: un test por caso exacto, la suite completa en 0 fallos, la verificación en seco, el tráfico marcado, la red de seguridad y el cierre con limpieza.

## 6. Decisiones de Ricardo

**Resultado (27-oct-2026):** 1. Se adopta el 27-oct, en los dos repos (#44). 2. El revisor es otro modelo de Claude como subagente de Claude Code, sin proveedores externos (#44). 3. Entorno de prueba: en seco en producción con tráfico marcado, sin droplet de prueba hasta que haya clientes de pago (#44). 4. «You should know»: una semana de prueba, del 27-oct al 3-nov; lo activa Ricardo y el 3-nov decide si se queda comparando el uso del plan (#45).

1. **Cuándo se adopta.** Recomendación: a partir del 27-oct. Esta semana es de simulacro y auditoría antes del viaje; cambiar la forma de trabajar ahora suma riesgo. Lo que ya coincide sigue igual.
2. **Qué es "otro modelo" para el revisor.** Opciones: otro modelo de Claude como subagente de Claude Code (sin costo extra fuera del plan), o un modelo de otro proveedor (otra mirada, pero con costo por llamada y una clave más que cuidar). Recomendación: otro modelo de Claude, y de otro proveedor solo para riesgo alto si el costo lo justifica.
3. **Entorno de prueba separado.** Opciones: seguir con verificación en seco en producción y tráfico marcado (sin costo), o un droplet de prueba (costo mensual y otra máquina que mantener). Recomendación: seguir en seco hasta que haya clientes de pago que lo justifiquen.

4. **Activar "You should know" en Claude Code** (`/plugin enable cc-plugin-you-should-know@builtin`). Es un plugin oficial de Anthropic que viene dentro de Claude Code desde la versión 2.1.287 y está apagado por defecto. Mientras Claude Code trabaja en tareas largas, un agente lateral lee la conversación y, solo si encuentra algo importante que se te pudo pasar, muestra una nota corta arriba del prompt:
    - **Heads up:** una decisión que Claude tomó sin destacarla, o un resultado que puede estar mal. Es el caso del borrado del ancla antispam o del Estado.md que se vació.
    - **You should know:** algo que conviene entender porque afecta el trabajo.
    - Opciones de cada nota: 1 explica más, 2 hace una página de aprendizaje (un artefacto privado), 0 la descarta. "Turn off suggestions" la apaga.
    - **Qué puede y qué no:** el agente lateral no tiene herramientas; no lee archivos, no ejecuta comandos y no cambia nada. Solo ve la conversación de la sesión y tiene la orden de no repetir secretos, credenciales ni datos personales.
    - **Costo y requisitos:** cada revisión es una llamada extra al modelo que sale del plan de Claude ($20), sin precio publicado. Solo aparece en sesiones con la telemetría encendida. Requiere Claude Code 2.1.287 o más nuevo (`claude --version`).
    - **No reemplaza la revisión adversarial (etapa 4):** avisa durante la sesión; no revisa el diff.
    - Recomendación: activarlo desde el 27-oct en las sesiones abiertas con `claude-repo`, una semana de prueba, comparar el uso del plan con y sin el plugin, y apagarlo si las notas no ayudan. Se apaga con `/plugin disable cc-plugin-you-should-know@builtin`.

## 7. Dónde vive este documento

- `docs/PROCESO-DESARROLLO.md` en los dos repos, referenciado desde las instrucciones de cada uno (`CLAUDE.md`) y desde ABIERTO.
- Copia en la bóveda, en `30 Recursos/`.
- Toda sesión de Claude Code lo lee al empezar, junto con el contexto y ABIERTO.
