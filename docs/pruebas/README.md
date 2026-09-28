# pruebas/ — sets de prueba y registros de marcha

Dos cosas distintas viven acá, y conviene no confundirlas:

- **Set de prueba** = qué se va a probar. Hay **uno** vigente, y se actualiza.
- **Registro de marcha** = qué pasó el día que se probó. Se **congela** con su fecha y no se vuelve a tocar.

⛔ Los **pendientes** que salgan de una marcha se copian a [`../copilot/PENDIENTES.md`](../copilot/PENDIENTES.md).
Este directorio no lleva backlog.

## Vigente

| Archivo | Objetivo |
|---|---|
| `PRUEBAS_ALFA_COMANDOS.md` (25/09/26) | **El set de prueba.** 32 pruebas, cada consulta en lenguaje natural emparejada con su comando `/` equivalente, más una tabla de «qué cambió» y una sección de limitaciones conocidas. Es el que se corre. |

## Registros de marcha — congelados, uno por sesión

| Archivo | Qué registra |
|---|---|
| `MARCHA_ALFA_0918.md` | La **1ª alfa viva con gerencia** (18/09/26, Teams de desarrollo): formato, rendimiento y determinismo quedaron resueltos; salieron 5 pedidos. |
| `MARCHA_ALFA_0923.md` | La **ronda de feedback de Carlos** (23/09/26): 14 observaciones sobre los módulos «Por Equipo» → los 7 bloques A-G, cerrados el 27/09. |

## Evidencia de julio — la línea base «antes de los límites»

Los dos archivos de julio **no son sets de prueba reutilizables**: son la foto de cómo respondía KomfIA
*antes* de que entraran los límites oficiales del área (07/08/26) y antes del Tier 2 completo. Su objetivo
hoy es ser **el antes de la comparación antes/después**.

| Archivo | Objetivo actual |
|---|---|
| `KomfIA_Pruebas con imagenes (pre-cambios limites) 2026-07.xlsx` (18/07/26, 1,4 MB) | **Evidencia visual.** Capturas de la alfa de julio. El nombre ya avisa que es pre-cambios de límites. |
| `KomfIA_Preguntas y Respuestas 2.xlsx` (15/07/26) | **Evidencia escrita**, ya rellenada: 34 preguntas con su respuesta real de julio y el resultado esperado. ⚠ Sus valores y nombres de vista están **desfasados** (`vw_UltimoAnalisisAceite`, `vw_EstadoActualMT`, parámetros «inf» que ya no se imprimen): no se corre, se consulta. |

> **Lo reutilizable del segundo es su formato**, no su contenido: las columnas
> `TÓPICO · ITEM · PREGUNTA · RESPUESTA KOMFIA · RESULTADO ESPERADO` con celdas altas para pegar capturas.
> Si una marcha futura necesita evidencia en Excel, se copia el archivo y se vacían las filas.

## Cómo se agrega una marcha nueva

1. `MARCHA_ALFA_MMDD.md` con la fecha de la sesión y quién la corrió.
2. Una línea por consulta: qué se pidió, qué salió, ✅ / 🔴 y por qué.
3. Lo que haya que arreglar se copia a `../copilot/PENDIENTES.md` — el registro dice *qué pasó*, no *qué falta*.
4. Si el set de prueba cambió (comandos nuevos, otro comportamiento esperado), se actualiza
   `PRUEBAS_ALFA_COMANDOS.md`; no se crea un set nuevo.

> El primer banco formal —28 consultas en lenguaje natural, sellado el 22/06/26— está archivado en
> [`../../legado/02-copilot-multiagente/PRUEBAS_ALFA_PRODUCCION.docx`](../../legado/02-copilot-multiagente/PRUEBAS_ALFA_PRODUCCION.docx).
