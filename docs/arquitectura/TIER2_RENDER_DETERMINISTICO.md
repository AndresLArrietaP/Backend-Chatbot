# Tier 2 — Render determinístico del barrido (vía flujo + tópico)

**Objetivo:** eliminar el cuello de ~1:30–2:00 del "detalle de todos" sin cortar data,
sin inflar instrucciones y sin romper lo funcional. Patrón GENERAL reutilizable, no parche.

## El problema (confirmado 2026-08-03)
El bloque grande (`DetalleTodosMD`, ~5000 chars) **se re-escribe por un LLM dos veces**:
1. **KomfIA SQL** corre el SELECT y **devuelve el JSON** (`Respond to the agent`) → re-teclea ~5000 chars (~50-63 s).
2. **El central** copia ese bloque verbatim.

La BD tarda **0.5 s**. El costo es la **re-emisión LLM**. Para que sea de segundos, el bloque
**no debe pasar por ningún LLM**: lo produce el flujo y se muestra directo.

## Principio de diseño (según pedido del usuario)
- **KomfIA SQL = solo SQL.** No arrastra/re-emite el bloque grande.
- **Central = orquesta + análisis corto** (resumen/recomendaciones). No re-teclea la tabla.
- **El flujo apoya el render**: entrega el bloque YA armado (de la vista) y se muestra determinístico.
- **Data siempre completa** (nunca se corta por defecto).
- **Un tópico NO consume el prompt de 8000** (es un constructo aparte) → incluso podemos QUITAR el
  cableo verbatim del central/SQL → instrucciones más simples.
- **General**: mismo patrón para cualquier tópico pesado a futuro (historial grande, etc.).
- **No rompe lo actual**: solo el barrido-detalle toma esta ruta; los 5 tópicos y el PASO 1 siguen igual.

## Arquitectura

**Antes (2 emisiones LLM):**
```
Usuario → Central(LLM) → KomfIA SQL(LLM) → Flujo(SQL) → JSON → KomfIA SQL re-emite → Central copia → chat
```
**Después (0 emisiones del bloque):**
```
Usuario → Central(orquesta) → [Tópico "Barrido detalle"] → Flujo(SQL, trae DetalleTodosMD)
                                        → nodo Mensaje imprime DetalleTodosMD TAL CUAL → chat (tabla)
   (el LLM solo rellena proyecto/modelo y, opcional, agrega el resumen corto)
```

## Componente 1 — Flujo dedicado: `Barrido_Detalle`
(Se puede clonar `TEST-SQL-V2`. Ventaja de uno dedicado: devuelve el bloque ya listo, sin que el
tópico parsee el JSON.)

- **Disparador:** "Cuando un agente/Copilot llama al flujo".
- **Entradas:** `proyecto` (texto), `modelo` (texto, opcional).
- **Paso "Ejecutar consulta SQL (V2)"** — `query`:
  ```sql
  SELECT TOP 1 DetalleTodosMD, NumEquipos, NumEquiposCriticos, NumEquiposSoloPrecau
  FROM vw_ObservadosBarridoMD
  WHERE Proyecto LIKE '%' + @proyecto + '%'
    AND (@modelo = '' OR Modelo LIKE '%' + @modelo + '%')
  ```
  (o compón el string como ya haces con `query_sql`; RetryPolicy igual).
- **Respuesta del flujo (Respond):** devuelve **campos separados**:
  - `detalle_md` = `ResultSets.Table1[0].DetalleTodosMD`  ← el bloque markdown
  - `num_equipos`, `num_criticos`, `num_precaucion` = las 3 cifras (para el resumen).

## Componente 2 — Tópico `Barrido detalle` (en el agente KomfIA Central)
1. **Frases de activación:** "detalle de todos", "detalle completo", "el detalle", "detalle de la flota".
2. **Parámetros de entrada del tópico:** `proyecto`, `modelo`.
   - ⭐ Márcalos para que **la orquestación generativa los rellene del contexto** (en Copilot Studio:
     el input del tópico "puede rellenarse con IA/desde la conversación"). Así el LLM SOLO extrae
     `Antapaccay` / `980E` del turno previo (tarea diminuta) — el bloque grande NO pasa por el LLM.
3. **Nodo Acción:** llama al flujo `Barrido_Detalle` pasando `proyecto`, `modelo`.
   Guarda las salidas en variables: `detalle_md`, `num_equipos`, `num_criticos`, `num_precaucion`.
4. **Nodo Mensaje (determinístico):** imprime **`{detalle_md}` tal cual** (markdown → se renderiza como
   tabla, al instante, sin LLM). ⛔ NO envolver en bloque de código.
5. **Resumen (elige una):**
   - (v1, simple) Un 2º Nodo Mensaje con una línea armada de las cifras:
     `⚠️ {num_criticos} equipos con crítico, {num_precaucion} solo precaución. Se recomienda seguimiento.`
   - (v2, análisis gerencial) Al final, **cede a la orquestación generativa** para que el central
     redacte el resumen + 🔧 recomendaciones (corto = rápido). El bloque grande ya salió determinístico.

## Cómo se pasa el contexto (proyecto/modelo) — la duda clave
El tópico declara `proyecto`/`modelo` como **inputs rellenables por IA**. Cuando el usuario dice
"detalle de todos" tras un barrido de Antapaccay 980E, el orquestador (que ve la conversación)
llena `proyecto=Antapaccay`, `modelo=980E` y dispara el tópico. Es una extracción mínima (2 palabras),
NO re-emite el bloque. Si algún día no hay contexto, el tópico puede preguntar "¿de qué proyecto?".

## Qué cambia en las instrucciones (se SIMPLIFICA)
- Se puede **quitar** de `KomfIA_SQL` y `KomfIA_central` el cableo verbatim del "detalle de todos"
  (el tópico lo maneja). Los filtrados (solo crít/precauc) pueden quedarse como están, o migrar
  después al mismo patrón. → menos texto en el prompt, más margen.
- La vista `vw_ObservadosBarridoMD` se mantiene (es la fuente del bloque). Nada de BD cambia.

## Rollout sin romper lo funcional
1. Crear el flujo `Barrido_Detalle` (clonando TEST-SQL-V2). Probarlo aislado (Test) con proyecto=Antapaccay.
2. Crear el tópico `Barrido detalle` con las frases y el nodo Mensaje. Probar "detalle de todos".
3. Verificar que sale la **tabla renderizada en segundos** y completa.
4. Solo cuando funcione: quitar el cableo verbatim de las instrucciones (opcional, para simplificar).
5. Los 5 tópicos, el PASO 1 (resumen) y los filtrados **no se tocan** hasta validar.

## Fallback
Si el tópico/nodo Mensaje diera problemas en algún canal, se revierte quitando las frases de
activación del tópico → vuelve al flujo generativo actual (verbatim, ~1:30). Cero pérdida.

## Extensión general (a futuro)
Cualquier respuesta pesada con una vista que pre-arme markdown (`vw_*MD`) puede usar este mismo
patrón: flujo trae el bloque → tópico lo muestra determinístico → LLM solo para el análisis corto.
