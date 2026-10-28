# Plantilla de spec (etapa 2 de `docs/PROCESO-DESARROLLO.md`)

Las specs se guardan en `docs/specs/AAAA-MM-DD-<tema>.md`. Una funcionalidad nueva espera la aprobación de Ricardo antes de construir; para un defecto alcanza con la causa, el arreglo y sus criterios.

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
