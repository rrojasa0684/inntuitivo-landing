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
> - el cierre pesado (contexto y Graphify semántico) en cada mini-corrida;
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

- La limpieza de Docker del droplet se hace solo con `ops/docker-builder-prune.sh`.
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
  - Graphify semántico;
  - el code review de toda la etapa;
  - el Ready to Release completo.

Todo eso va al cierre semanal.

## 3. Cierre semanal (#123)

Una sesión por semana, o al terminar una funcionalidad grande:

1. **Lote semanal:** se cierran todas las observaciones de `docs/LOTE-SEMANAL.md`. Al terminar queda vacío.
2. **Code review de la semana:**
   - una revisión adversarial con Opus sobre las costuras entre lo que cambió;
   - por área, solo en las áreas de riesgo alto que cambiaron;
   - un revisor por área tocada, no uno por área del producto.
3. **Ready to Release completo** contra producción.
4. **Documento de contexto** nuevo (se copia de `~/Downloads`, nunca se mueve). La bóveda queda al día.
5. **Graphify semántico** sobre los documentos de la semana.
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
- **Una decisión sin resolver siempre figura en ESPERANDO.** Nunca se saca de la categoría para que dé cero.

## 5. Decisiones vigentes de este proceso

- **#44:** ciclo adoptado en los dos repos.
- **#121:** observaciones menores al lote semanal, cerradas en una semana como máximo.
- **#122:** recorrido focal en cada corrida; el Ready to Release completo, cada noche y en el cierre semanal.
- **#123:** el cierre pesado (contexto, Graphify semántico, code review de la etapa), una vez por semana.

## 6. Dónde vive este documento

- `docs/PROCESO-DESARROLLO.md` en los dos repos, referenciado desde `CLAUDE.md` y desde ABIERTO.
- Copia en la bóveda, en `30 Recursos/`.
- Toda sesión de Claude Code lo lee al empezar.
