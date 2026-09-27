# Config canónica — MANEJO DE TIMEOUT (que ninguna consulta pase de ~2min y nunca dé 504)

> **Familia CONFIG** — lo que está aplicado en Copilot Studio:
> [CONFIG_TEMAS](CONFIG_TEMAS.md) (temas/tópicos) · [CONFIG_FLUJOS](CONFIG_FLUJOS.md) (Power Automate) ·
> [CONFIG_COMANDOS](CONFIG_COMANDOS.md) (atajos `/`) · [CONFIG_PROMPTS](CONFIG_PROMPTS.md) (nodos de IA) ·
> [CONFIG_TIMEOUT](CONFIG_TIMEOUT.md) (reintentos y cortes).
> Backlog único: [PENDIENTES](PENDIENTES.md). Historia del proyecto: [../BITACORA.md](../BITACORA.md).

Ver [CONFIG_FLUJOS.md](CONFIG_FLUJOS.md), [CONFIG_TEMAS.md](CONFIG_TEMAS.md), [../arquitectura/DIAGNOSTICO_LATENCIA.sql](../arquitectura/DIAGNOSTICO_LATENCIA.sql).

## Causa raíz confirmada (2026-08-19)
En la traza del flujo, la acción **«Ejecutar una consulta SQL (V2)»** mostró **«Se han realizado 5 reintentos»**.
Cada reintento **re-corre el query lento** → 5 × ~1min = **5-8min** (exactamente la varianza que se vio). El **504
Gateway Timeout** salta en «Responder al agente» cuando el flujo total excede el tiempo de respuesta síncrona.
→ El problema NO es solo la lentitud de la vista: es la **política de reintentos multiplicándola**.

## Solución en 3 capas (de mayor a menor impacto)

### Capa A — Reintentos = Ninguno (⭐ el arreglo grande, hazlo primero)
En el flujo **TEST-SQL-V2**, acción **«Ejecutar una consulta SQL (V2)»** → menú **···** → **Configuración**
(«Settings») → **Directiva de reintentos / Retry Policy** → cambiar de *Predeterminado (4-5 reintentos)* a
**«Ninguno»** (o «Fijo», 1 reintento). Efecto: un solo intento de ~68s en vez de 5× → **de 5-8min a ~1min**.
⚠ Es el cambio de mayor impacto y de cero riesgo. Aplica a TODOS los flujos SQL (MD_flota, MD_triage, MD_equipo…).

### Capa B — Timeout corto + mensaje amable en el flujo (que falle rápido y guíe)
En la MISMA acción SQL → **Configuración** → **Tiempo de espera / Timeout** (campo ISO-8601 de duración):
poner **`PT100S`** (100s). Así, si el query se pasa, la acción **falla rápido** en vez de colgar.
Luego, para que el flujo devuelva un mensaje en vez de un 504:
1. Envuelve la acción SQL en un **Ámbito** («Scope»), llámalo `EjecutarSQL`.
2. Agrega una acción **«Responder al agente»** de respaldo, y en su **«Configurar la ejecución tras…»**
   («Configure run after») marca **«se agotó el tiempo de espera» (has timed out)** y **«error» (failed)**.
3. En esa respuesta de respaldo, `md` = el **mensaje amable** de abajo (texto fijo).
4. La «Responder al agente» normal queda con run-after = **«es correcto» (is successful)**.
Resultado: éxito → tabla; timeout/error → mensaje amable. Nunca 504.

### Capa C — Tópico de sistema «Error» en Copilot (última red)
En Copilot Studio, tópicos de **sistema** → **«Error de conversación» / «Conversational error»** (o «Error»):
edita su mensaje para que, ante cualquier fallo no controlado, muestre el **mensaje amable**. Es el cinturón
por si el 504 igual escapa. No lleva flujo; solo el nodo Mensaje con el texto.

### ⚠ Gotcha al publicar: «ActionSchemaInvalid» (esquemas 200 deben coincidir)
Con DOS «Responder al agente» (éxito + respaldo), Power Automate exige que **ambos tengan el MISMO
esquema de salida** (mismo nombre y tipo de campos). Si el de éxito devuelve `respuesta`=`body/resultsets/Table1`
(array/objeto) y el de respaldo `respuesta`=texto → error `The schema definitions for actions with same status
code must match`. **Fix:** que ambos devuelvan **una sola salida `respuesta` de tipo Texto**. En el de éxito,
serializa el resultado a texto: `respuesta = string(outputs('Ejecutar_una_consulta_SQL_(V2)')?['body/resultsets/Table1'])`.
El de respaldo ya es texto. Sin salidas extra en ninguno.
**Plan B (a prueba de balas):** UNA sola «Responder al agente» con `respuesta`=variable `salida`; dos ramas previas
(éxito / timeout+error, por run-after) que SETEAN `salida`. Una sola respuesta = un solo esquema, no puede chocar.

## Mensaje amable (texto fijo, listo para pegar en Capa B y C)
```
⏱️ Esa consulta de toda la flota tardó más de lo esperado. Para que salga al instante, acótala:
• nombra el **modelo** (ej. «980E») o un **equipo** (ej. «CA3177»),
• o pide un **conteo** de la flota, o el **triage/estado de un solo componente** (ej. «ruedas de Antamina»).
Con eso la respuesta es inmediata.
```

## Notas
- **No aplica `DB_QUERY_TIMEOUT`** del backend Python: la arquitectura viva es Copilot Studio → flujo → Azure SQL
  (Ruta A, sin Python). El único timeout que manda es el de la **acción del conector SQL** (Capa B).
- **Complemento de fondo (no es de este archivo):** subir el **tier S1 (20 DTU)** reduciría el tiempo base de las
  consultas de flota grande (elapsed 68s vs CPU 15s = I/O-bound). Con reintentos apagados + tier mayor, el timeout
  deja de ser un problema. Ver DIAGNOSTICO_LATENCIA.sql (L8).
- Tras aplicar Capa A, **re-mide** una consulta de flota grande (Antamina): debería bajar de 5-8min a ~1min.
