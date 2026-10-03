# Config canónica — TEMAS (Tópicos de Copilot Studio)

> **Familia CONFIG** — lo que está aplicado en Copilot Studio:
> [CONFIG_TEMAS](CONFIG_TEMAS.md) (temas/tópicos) · [CONFIG_FLUJOS](CONFIG_FLUJOS.md) (Power Automate) ·
> [CONFIG_COMANDOS](CONFIG_COMANDOS.md) (atajos `/`) · [CONFIG_PROMPTS](CONFIG_PROMPTS.md) (nodos de IA) ·
> [CONFIG_TIMEOUT](CONFIG_TIMEOUT.md) (reintentos y cortes).
> Backlog único: [PENDIENTES](PENDIENTES.md). Historia del proyecto: [../BITACORA.md](../BITACORA.md).

**Reglas de tema:**
- ⚠ **La DESCRIPCIÓN del tema (ModelDescription) tiene tope de 1024 caracteres** (mídela en UTF-16, como el central; los astrales cuentan 2). Copilot rechaza al guardar si se pasa. Mantener margen; recortar ejemplos antes que anclas de ruteo (⛔…).
- `vista` y `columna` van **FIJAS en la Acción** (NUNCA como Entrada del modelo), salvo donde se indique
  «Entrada». El modelo solo llena `equipo/compartimiento/parametro/proyecto/modelo`.
### ⚠ Orden de nodos en los temas CON análisis (25/09)

**Hoy, en todos:** `Acción` → `Mensaje {md}` → `Solicitud` (Prompt) → `Mensaje {analisis.text}` →
`Condición md está en blanco` → mensaje sin-datos → `Finalizar`.

🔴 **El problema:** la condición va **al final**, así que cuando no hay datos el Prompt **ya corrió** con
una tabla vacía y escribe algo encima del mensaje real. Se vio en `/diagcompleto CA9999` y en
`/incipiente Cuajone`: el análisis decía «todos los parámetros dentro de límite» y justo debajo el módulo
decía «no hay datos» / «sin límites cargados». **Dos frases que se contradicen en la misma respuesta.**

**El orden correcto:**

```
Acción  →  Condición «md está en blanco»
                ├─ sí  → Mensaje sin-datos → Finalizar tema
                └─ no  → Mensaje {md} → Solicitud → Mensaje {analisis.text} → Finalizar
```

**Cómo se hace sin romper nada:** insertar la **Condición justo después de la Acción**. Los nodos que ya
existen quedan en la rama «Todas las demás condiciones»; en la otra rama va el mensaje de sin-datos y
`Finalizar`. La condición vieja del final queda muerta y se puede quitar después.

⚠ **No hace falta hacerlo en los 9 temas.** El parche del prompt (responder **un guion** cuando no hay
tabla) ya evita la contradicción en todos. El reorden solo vale la pena donde el caso vacío es **frecuente**:

| Tema | Por qué sí |
|---|---|
| **04 Diagnóstico completo** | equipo inexistente o mal escrito — es el error de tecleo más común |
| **20 Tendencia incipiente** | proyectos **sin límites cargados** (Cuajone, Toquepala) — pasa siempre |
| **19 Triage** | mismo caso que el 20 |

⛔ En el resto, dejar el parche del prompt y no tocar nodos: mover cosas en un tema que funciona tiene
más riesgo que la línea que ahorra.

- **Nodos estándar CON análisis:** Acción(flujo) → Mensaje `{md}` → Acción Prompt `Análisis de aceite`
  (`tabla={md}`) → Mensaje `{analisis.text}` → Mensaje `{recomendaciones}` → **Condición** `md está en blanco`
  → Mensaje sin-data → Finalizar. **SIN análisis:** omite los 2 nodos de Solicitud/análisis.
- **Condición sin-data SE MANTIENE** (probada, sí muestra el mensaje): la Condición `md está en blanco` →
  Mensaje "No encontré datos para esa consulta — verifica que el equipo/proyecto exista o tenga muestras." →
  Finalizar. (El `if(empty)` del flujo evita el crash; la Condición del tema muestra el mensaje.)

| Tema | Entradas (modelo) | Acción: flujo + fijos | Análisis |
|---|---|---|---|
| Último análisis de componente | equipo, compartimiento | MD_equipo_comp · vista=vw_UltimoAnalisisMD · columna=MD | sí |
| Condición MT | equipo | MD_equipo · vista=vw_CondicionMT_MD · columna=MD | sí |
| Diagnóstico equipo | equipo | MD_equipo · vista=vw_DiagnosticoMD · columna=MD | sí |
| Diagnóstico completo (nuevo) | equipo | MD_equipo · vista=vw_DiagnosticoMD · columna=MD_Completo | sí |
| ⛔ Tendencia paso 1 — **DESACTIVAR** (25/09, F1) | equipo, compartimiento | MD_equipo_comp · vista=vw_TendenciaP1MD · columna=MD | no |
| **Tendencia** (era «detalle»; absorbe el paso 1) | equipo, compartimiento | MD_equipo_comp · vista=vw_TendenciaMD · columna=MD | sí |
| **Tendencia resumen estadístico** — NUEVO (continuación) | equipo, compartimiento | MD_equipo_comp · vista=vw_TendenciaMD · **columna=MD_Estadistica** | **sí** |
| Tendencia relevantes | equipo, compartimiento | MD_equipo_comp · vista=vw_TendenciaMD · columna=MD_Relevantes | sí |
| ⛔ Tendencia de un metal — **DESACTIVADO** (30/09, lo absorbe la Gráfica) | equipo, parametro | MD_metal · vista=vw_TendenciaMetalMD · compartimiento=todos | sí |
| Gráfica de un metal | equipo, compartimiento, parametro | MD_metal · vista=vw_TendenciaGraficoMD | no |
| Gráficas de observados | equipo, compartimiento | MD_equipo_comp · vista=vw_TendenciaGraficoObsMD · columna=MD | no |
| Historial general del equipo | equipo | MD_equipo · vista=vw_HistorialEquipoMD · columna=MD | no |
| Historial (componente) | equipo, compartimiento | MD_equipo_comp · vista=vw_HistorialMD · columna=MD | no |
| Historial de un metal (equipo) | equipo, parametro | **MD_historial** · vista=vw_HistorialMetalEquipoFilasMD (confirmado en Teams 03/10: «200 muestras», el tope de las *FilasMD) | no |
| Historial de un metal en componente | equipo, compartimiento, parametro | **MD_historial** · vista=vw_HistorialMetalFilasMD | no |
| Historial de observados de flota | proyecto | MD_flota · vista=vw_HistorialFlotaMD · modelo=todos · columna=MD | no |
| Barrido → **Panel de flota** (I, 02/10) | proyecto, modelo | MD_flota · vista=**vw_PanelFlotaMD** · columna=MD | no |
| ⛔ Conteo de flota — **a desactivar** cuando el panel esté probado (lo absorbe el 16) | proyecto, modelo | MD_flota · vista=vw_ConteoFlotaMD · columna=MD (modelo default (todos)) | no |
| Barrido detalle | proyecto, modelo | MD_flota · vista=vw_ObservadosBarridoMD · columna=DetalleTodosMD | no |
| Barrido filtrado | proyecto, modelo, **columna** | MD_flota · vista=vw_ObservadosBarridoMD | no |
| Triage de componente (flota) | proyecto, **modelo (IA)**, **compartimiento** | MD_triage · vista=vw_TriageMD (fija) · modelo=IA/(todos) · compartimiento=tracción | sí (+ recos MT) |
| Tendencia incipiente | proyecto, **compartimiento**, **modelo** (03/10) | MD_incipiente · vista=vw_TendenciaIncipienteMD (fija) · compartimiento=tracción · modelo=(todos) | sí |
| Último análisis por metal (flota) | proyecto, **modelo (IA)**, compartimiento, **parametros** | MD_ultmetalflota · vista=vw_UltimoMetalFlotaMD (fija en concat) · modelo=IA (default (todos)) · compartimiento=tracción | sí (+ recos solo MT) |
| Ayuda / Glosario | — (usa la pregunta) | **SIN flujo** · Prompt `Ayuda KomfIA` | Prompt |
| Ranking de acumulados (flota) | proyecto | MD_acumflota · vista=vw_AcumuladosFlotaMD (fija) | no |
| Acumulados de un equipo | equipo | MD_acumequipo · vista=vw_AcumuladosEquipoMD (fija) | no |

> **`modelo` opcional (16/17/18 y 21, conectado el 30/09):** Entrada del tema con «Rellenar dinámicamente» y **sin**
> pregunta si falta; en la Acción, `If(IsBlank(Topic.modelo) || Topic.modelo = "", "todos", Topic.modelo)`.
> Estaba documentado pero en Copilot la Acción llevaba `todos` fijo: el filtro lo hacía el LLM (ley 1).
> Verificado en Teams: `/barrido antapaccay 980` → 10 · `d475` → `6116` · `pc1250` → `8108` · sin modelo → 12.

> **Barrido filtrado** es el ÚNICO que expone `columna` como Entrada (el modelo la infiere: «solo críticos»→
> `MD_Criticos`, «solo precauciones»→`MD_Precaucion`). En todos los demás, `columna` es FIJA en la Acción.

## H6 — Nombres NUMERADOS + descripciones FINALES (usar estas; renombrar el tema con su número)
Convención: prefijo `NN` en el NOMBRE del tema en Copilot (los diferencia de los temas por defecto y los ordena). "Historial" → "Historial de componente".

- **01 Último análisis de componente:** "Último análisis de aceite de UN componente de un equipo (SÍ se nombra el componente). «último análisis del MT LH del CA3177», «cómo salió el hidráulico del X», «la última muestra del <componente> del <equipo>». Rellena equipo y compartimiento. ⛔ NO el equipo completo (→ Diagnóstico) ni la flota (→ Barrido/Triage)."
- **02 Condición MT** (comando `/condicionmt`, alias `/condicion`; descripción **462** UTF-16 medidos el 24/09): "Estado/condición de los **Motores de Tracción** (MT LH y RH juntos) de UN equipo, parámetro por parámetro y lado a lado. «condición del MT del CA3177», «cómo están los motores de tracción del X», «condicionmt del \<equipo>», «compara los dos MT del \<equipo>». Rellena equipo. ⛑ SOLO Motor de Tracción y SOLO un equipo. ⛔ NO otros componentes ni todos los componentes (→ Diagnóstico completo), NO la flota (→ Triage), NO un componente suelto (→ Último análisis)."
- **03 Diagnóstico equipo:** "ESTADO ACTUAL de TODOS los componentes de UN equipo (matriz componentes×parámetros, SOLO los observados). «diagnóstico del CA3177», «cómo está el equipo X», «último análisis general del X». ⛔ NO cronológico (→ Historial), un componente (→ Último análisis), la flota (→ Barrido/Triage) ni «completo/todos los metales» (→ Diagnóstico completo)."
- **04 Diagnóstico completo:** "Como el Diagnóstico pero con TODOS los parámetros (incluidos los OK), matriz completa. «diagnóstico completo del X», «todos los metales del equipo X», «la matriz completa del X». Rellena equipo. ⛔ NO solo observados (→ Diagnóstico equipo)."
- ⛔ **05 Tendencia (paso 1)** — **DESACTIVAR** (25/09): su contexto vive ahora dentro del 06. Descripción que tenía: "Evolución de las últimas muestras de UN componente, SIN nombrar metal (panorama + oferta de detalle/gráfica). «tendencia del MT LH del CA3177», «cómo ha evolucionado el hidráulico del X», «las últimas muestras del <componente>». Rellena equipo y compartimiento. ⛔ NO si nombran un metal (→ Gráfica de un metal) ni el último puntual (→ Último análisis)."
- **06 Tendencia** (era «detalle»; comando `/tendencia`, alias `/tendenciadet`; descripción **590** UTF-16 medidos el 25/09): "TENDENCIA de UN componente de un equipo: cómo han evolucionado sus últimas muestras — contexto (horómetro, horas del componente, tipo de muestra, lubricante) y la matriz de TODOS los parámetros × fechas con sus límites. «tendencia del MT LH del CA3177», «cómo ha evolucionado el hidráulico del X», «las últimas muestras del \<componente>», «detalle de la tendencia del X», «la matriz de metales del \<componente>». Rellena equipo y compartimiento. ⛔ NO si nombran un metal (→ Gráfica de un metal), NO el último puntual (→ Último análisis), NO la bitácora completa (→ Historial)."
- **NUEVO Tendencia resumen estadístico** (continuación, sin comando, como el 07; descripción **462** UTF-16): "RESUMEN ESTADÍSTICO de la tendencia de UN componente: promedio, desviación σ, Σvida y nº de veces fuera de límite, parámetro por parámetro. Normalmente como CONTINUACIÓN tras ver la tendencia. «el resumen estadístico», «dame el promedio y la desviación», «las estadísticas de esa tendencia», «resumen estadístico del MT LH del X». Toma equipo y compartimiento del contexto. ⛔ NO la matriz por fechas (→ Tendencia) ni solo los observados (→ Tendencia relevantes)."
  > Acción: `MD_equipo_comp` · `vista=vw_TendenciaMD` · `columna=MD_Estadistica`. **CON análisis**.
  > ⚠ Corrección 25/09: había escrito «sin análisis» suponiendo que una tabla de promedios no daba para leer.
  > Probado con análisis, sí da: la σ y el nº de muestras permiten decir «Zn es el más volátil: prom 44.6
  > con σ 77.6» o «PQ ascendente estable», que la tabla sola no dice.
- **07 Tendencia relevantes:** "Solo los parámetros FUERA DE LÍMITE de la tendencia de UN componente. «solo los relevantes de la tendencia del X», «qué parámetros están fuera de límite en la tendencia del <componente>», «los observados de la tendencia». Rellena equipo y compartimiento."
- ⛔ **08 Tendencia de un metal** — **DESACTIVADO** (30/09, C3): lo absorbe **09 Gráfica de un metal**; el comando `/tendenciametal` responde con un mensaje que manda a `/grafica`.
- **09 Gráfica de un metal** (absorbe al 08 desde el 30/09; descripción **569** UTF-16): "Tendencia y gráfica (curva) de UN metal ESPECÍFICO en UN componente de un equipo: el valor del metal fecha a fecha bajo el encabezado de la muestra, su Σvida, promedio, σ y nº fuera de límite, los límites y la curva. «gráfica del Cromo del MT LH del CA3171», «tendencia del Fe del hidráulico del X», «cómo ha variado el cobre del MT RH del <equipo>», «la curva del PQ de la rueda LH del X». Rellena equipo, compartimiento y parametro: los TRES son obligatorios, si falta alguno PREGÚNTALO. ⛔ NO si no nombran metal (→ Tendencia del componente / Gráficas de observados)."
- **10 Gráficas de observados:** "Gráfica(s) de los metales OBSERVADOS de un componente, SIN nombrar metal — normalmente como CONTINUACIÓN tras ver una tendencia. «la gráfica», «las gráficas», «ahora la gráfica», «la gráfica de ello», «grafícame la tendencia». Toma equipo y compartimiento del contexto. Muestra automáticamente las gráficas de los metales fuera de límite; NO preguntes cuál metal."
- **11 Historial de componente:** "Bitácora cronológica de UN componente: todas las muestras en el tiempo (fecha, horómetro, horas comp., CM, estado, metales fuera de límite por muestra). «historial del MT LH del CA3171», «bitácora del hidráulico del X», «todas las muestras del <componente> en el tiempo». Rellena equipo y compartimiento. ⛔ NO la tendencia (→ Tendencia) ni el último puntual (→ Último análisis)."
- **12 Historial general del equipo:** "Bitácora cronológica de UN equipo COMPLETO: todas las muestras de todos sus componentes por fecha (recientes arriba). «historial del CA3171», «bitácora del equipo X», «las muestras del X en el tiempo», «cómo ha venido el equipo». Rellena equipo. ⛔ NO el estado actual (→ Diagnóstico) ni un componente (→ Historial de componente)."
- **13 Historial de un metal (en el equipo):** "Historial cronológico de UN metal en TODOS los componentes de un equipo (metal SIN componente). «historial del Fe del CA3171», «cómo ha venido el cobre en el equipo X», «evolución histórica del Cr del <equipo>». Rellena equipo y parametro. ⛔ NO si nombran un componente (→ Historial de un metal en un componente)."
- **14 Historial de un metal en un componente:** "Historial cronológico de UN metal en UN componente específico (metal Y componente). «historial del Cromo del MT LH del CA3171», «cómo ha venido el Fe del hidráulico del X». Rellena equipo, compartimiento y parametro."
- **15 Historial de observados de flota:** "Historial de los análisis OBSERVADOS recientes de toda una flota/mina (qué equipos y componentes se observaron últimamente, cronológico). «historial de observados de Antapaccay», «qué se ha observado en la flota de <mina>», «bitácora de observados de la mina». Rellena proyecto."
- **16 Panel de flota** (I, 02/10; vista `vw_PanelFlotaMD`; descripción **739** UTF-16; absorbe el 21 Conteo): "PANEL DE FLOTA de una mina: cómo está la flota en conjunto — cuántos equipos hay, cuántos están observados (con crítico / solo precaución) y cuántos sin novedad; por componente con lo que más se repite, por modelo y por dónde empezar. Cubre también los CONTEOS. ⚑ «barrido» o «panel» SIN pedir el detalle cae AQUÍ, aunque mencione «motor de tracción» o «condición». «barrido de Antapaccay», «panel de la flota de <mina>», «cómo está la flota de <mina>», «cuántos equipos 980 hay en Antapaccay», «cuántos observados hay en <mina>», «cuántos críticos hay en <proyecto>». Rellena proyecto y modelo (solo si lo nombran). ⛔ El detalle equipo por equipo → Barrido detalle. Un equipo → Diagnóstico. ⛔ Un mensaje que empieza con «/» → 00 Comandos."
- **17 Barrido detalle** (descripción **634** UTF-16, reescrita 02/10: solo cuando piden el DETALLE): "Detalle COMPLETO equipo por equipo de los observados de una flota, agrupado por componente (desgaste + SALUD (V100/TBN) + aditivos fuera de límite + cuadro de límites; críticos arriba). SOLO cuando piden el DETALLE: «detalle del barrido de Antapaccay», «barrido de cada motor de tracción con su detalle», o como CONTINUACIÓN tras el panel («detalle de todos», «detalle completo», «muéstrame todos con su detalle»). Rellena proyecto y modelo. ⛔ «barrido» A SECAS, «panel», «cómo está la flota» o «cuántos» → Panel de flota. ⛔ Un mensaje que empieza con «/» → 00 Comandos. ⛔ NO filtros «solo críticos/precauciones» (→ Barrido filtrado)."
- **18 Barrido filtrado:** "Detalle del barrido SOLO de un tipo: solo CRÍTICOS o solo PRECAUCIONES. «solo los críticos», «solo las precauciones», «únicamente en precaución». Rellena proyecto, modelo y columna (críticos→MD_Criticos, precauciones→MD_Precaucion). ⛔ NO el detalle completo (→ Barrido detalle) ni el resumen."
- **19 Triage de un componente en la flota** (EVOLUCIONADO 2026-08-19; descripción 832 UTF-16, reescrita 25/09): "TRIAGE de un componente de la flota: el ESTADO ACTUAL de TODOS los equipos de un tipo de componente en una mina — observados o no —, con sus metales FUERA DE LÍMITE (valor entre paréntesis), salud y horas; críticos primero. Se dispara con «triage» o con «estado/condición», «observados», «fuera de límite», «necesitan atención». «triage de Antamina», «qué ruedas están observadas», «estado de los MT de \<mina>», «hidráulicos fuera de límite de Antapaccay». Rellena proyecto, compartimiento (tracción/hidráulico/rueda/mando/transmisión/motor; default tracción) y modelo. ⛔ NO los que SUBEN sin haber superado el límite — «se están disparando», «vienen subiendo», «incipiente», «alerta temprana» → **Tendencia incipiente**. NO un equipo individual (→ Diagnóstico), NO «barrido» (→ Barrido), NO un metal específico en la flota (→ 25)."
  > **Evolución:** base ligera (`vw_MuestrasRankeadas` rn=1, 1 pasada → más rápido); flujo `MD_triage` (proyecto, modelo, compartimiento). Muestra TODOS (🟩 OK incluidos), metales como `Fe(199.0) · Cr(29.0)`. En `(todos)` sub-títulos `### <modelo>`. Nodos = CON análisis (Prompt) + recomendaciones bajo Condición «no está en blanco» (solo TRACCION las llena). Reemplaza el viejo «Triage MT» (solo observados, solo MT).
- **20 Tendencia incipiente** (descripción **910** UTF-16, reescrita 03/10: entra «cruzó» y el modelo): "ALERTA TEMPRANA de una flota: equipos que vienen subiendo fuerte (≥40% sobre la media de sus 6 muestras previas), aún bajo el límite o recién pasándolo en la última muestra («cruzó»). Es preventivo: lo que ya venía fuera de límite de antes es de Triage y Barrido. ⚑ Suyas son las frases de movimiento: «se están disparando», «vienen subiendo», «están subiendo sin pasar el límite», «antes de la alarma», «tendencia incipiente», «desgaste incipiente», «han variado de su comportamiento promedio», «qué saltó en la última muestra». Cualquier componente: tracción, rueda, motor, hidráulico… «qué hidráulicos se están disparando en Antapaccay», «tendencia incipiente de los 980E en <mina>». Rellena proyecto, compartimiento (default tracción) y modelo (solo si lo nombran). Muestra EQUIPO + parámetros (prom→últ, +%). ⛔ NO el estado actual de los observados (→ Triage / Barrido) ni un equipo puntual (→ Tendencia)."
- **21 Conteo de flota:** "CUÁNTOS: número de equipos de una flota y cuántos están observados/críticos/en precaución, con desglose por componente. Cubre los conteos: «cuántos equipos 980 hay en Antapaccay», «cuántos observados hay en <mina>», «cuántos MT críticos en <proyecto>», «conteo/resumen numérico de la flota», «cuántos equipos tiene <mina>». Rellena proyecto y modelo (si nombran un modelo como 980 lo filtra; si no, (todos)). Flujo MD_flota, vista=vw_ConteoFlotaMD. ⛔ NO el detalle equipo por equipo (→ Barrido), un ranking (→ Ranking) ni un equipo (→ Diagnóstico)."
- **22 Ranking** (descripción **678** UTF-16, reescrita 02/10 con `modelo`): "RANKING de UN metal en un tipo de componente de una flota: los equipos con MÁS de ese metal, de mayor a menor, con su LP/LC y estado. «top 5 de hierro en motor de tracción de Antapaccay», «los 3 de más cobre en el hidráulico de <mina>», «qué equipos tienen el cromo más alto en <proyecto>», «ranking de Fe en tracción de los 980E». Rellena proyecto (default Antapaccay), compartimiento con la palabra BASE (tracción, hidráulico, rueda, mando, transmisión o motor), parametro con el SÍMBOLO del metal, modelo SOLO si lo nombran (980E, 930E…) y top (el número que pidan; si no dicen, 10). ⛔ NO la evolución de un metal en un equipo (→ Gráfica de un metal / Historial de un metal)."
- ⛔ **23 Tendencia de un metal en la flota** — **DESACTIVADO** (lo cubre el fallback; sin comando propio, sin decisión aún). Descripción que tenía: "FLOTA: dirección (↑ sube / ↓ baja / → estable) de UN metal en un TIPO de componente de toda la flota/mina, equipo por equipo — cuando NO se nombra un equipo. «cómo evolucionó/ha variado el Fe en los motores de tracción de la flota», «el aluminio en tracción es ascendente o estable», «tendencia del Cu en los hidráulicos de Antapaccay», «cómo viene el cromo en las ruedas de la mina». Rellena proyecto, compartimiento (tracción/hidráulico/rueda/mando/transmisión/motor) y parametro (el metal). ⚑ Es de FLOTA (proyecto, sin equipo). ⛔ Si nombran UN equipo → 08 Tendencia de un metal."
- ⛔ **24 Condición de un componente en la flota** — **DESACTIVADO** (lo cubre el fallback; sin comando propio, sin decisión aún). Descripción que tenía: "FLOTA: qué equipos tienen UN tipo de componente OBSERVADO / que necesita atención en toda la flota/mina (críticos primero), con lubricante, horas y metales fuera de límite — para CUALQUIER componente. «qué sistemas hidráulicos necesitan atención», «cómo están los hidráulicos de la flota», «qué ruedas delanteras están fuera de límite», «mandos finales observados de Antapaccay», «qué motores están en condición». Rellena proyecto y compartimiento (tracción/hidráulico/rueda/mando/transmisión/motor). ⚑ FLOTA, UN tipo de componente. ⛔ NO solo MT (→ Triage), NO la flota completa por-componente (→ Barrido) ni un equipo (→ Diagnóstico)."
- **25 Último análisis por metal en la flota** (descripción ≤1024, medida 861 UTF-16): "FLOTA: el ÚLTIMO análisis de UN metal (o VARIOS) en un TIPO de componente de toda la flota/mina — el valor más reciente de ese metal en CADA equipo, ordenados de mayor a menor. El «barrido enfocado a un metal». Se dispara al NOMBRAR el/los metal(es) + la flota + el tipo de componente, SIN un equipo. «último análisis de hierro de todos los motores de tracción de Antamina», «el Fe de los MT de la flota», «hierro y cobre de los hidráulicos», «silicio, hierro y cromo de las ruedas de <mina>», «el cromo en cada MT». Con varios metales = UNA tabla por metal. Rellena proyecto, compartimiento (tracción/hidráulico/rueda/mando/transmisión/motor; default tracción) y parametros (metal(es), símbolo). ⛔ NO todos los metales observados (→ Barrido), NO la evolución/dirección del metal (no aquí), NO un solo equipo (→ 01/08), NO «qué necesita atención» sin nombrar metal (no aquí)."
- **27 Ranking de acumulados en la flota** (motor diésel; descripción **690** UTF-16, reescrita 30/09, C3): "RANKING DE ACUMULADOS de una flota/mina (motor diésel). ⚑ SOLO EXISTE PARA ANTAPACCAY: si piden otra mina, este tema responde que no hay datos; no busques la respuesta en otro lado. TODOS los motores ordenados por desgaste ACUMULADO ponderado (Fe, Cr, Pb, Cu, Na, K, Si), con serie, horas motor/metal y Estado (Monitoreo/Atención/Alerta/Crítico). Es el «ranking de atención» del dashboard. ⚑ Es el tema por defecto cuando dicen «acumulados» SIN nombrar un equipo. «acumulados», «ranking de atención de Antapaccay», «acumulados de la flota», «qué motores tienen más desgaste acumulado». Rellena proyecto. ⛔ NO un equipo nombrado (→ Acumulados de un equipo), NO la última muestra (→ Barrido)."
  > Flujo `MD_acumflota` (proyecto). SIN análisis (tabla determinista). Envuelve el Ranking de Atención (dashboard externo) — ver [../arquitectura/DEPENDENCIA_RankingAtencion.md](../arquitectura/DEPENDENCIA_RankingAtencion.md). Estado por score: <60 🟢 Monitoreo · 60-65 🟨 Atención · 65-70 🟧 Alerta · ≥70 🟥 Crítico.
- **28 Acumulados de un equipo** (motor diésel; descripción **599** UTF-16, reescrita 30/09, C3): "ACUMULADOS de UN equipo concreto (motor diésel). ⚑ SOLO EXISTE PARA ANTAPACCAY: un equipo de otra mina no tiene datos aquí. El desgaste ACUMULADO por metal (Fe, Cr, Pb, Cu, Na, K, Si sumados en la vida del motor actual), con serie del motor, horas motor/metal, score y Estado. ⛑ Requiere el código del equipo: si no lo nombran, NO es este tema. «acumulados del CA3177», «cuánto Pb lleva acumulado el motor del X», «el desgaste acumulado del motor del equipo X». Rellena equipo. ⛔ NO la flota ni un ranking, ni «acumulados» a secas (→ Ranking de acumulados). NO la última muestra (→ Último análisis)."
- 🅿 **30 Límites — APARCADO, no montado** (03/10, R12; descripción **564** UTF-16): "LÍMITES DE REFERENCIA (LP/LC) que KomfIA usa para el semáforo, por mina, modelo y componente: la TABLA de límites, no datos de equipos. «qué límites tiene el 980E en tracción», «cuál es el LC del Fe en el hidráulico de Antapaccay», «límites del motor del 930E», «qué parámetros tienen límite cargado en Antamina», «muéstrame la tabla de límites». Rellena proyecto, modelo (solo si lo nombran) y compartimiento (solo si lo nombran). ⛔ NO si piden valores de un equipo o de la flota (→ Último análisis / Triage / Panel) ni qué significa LP o LC (→ Ayuda / Glosario)."
  **Entradas** (las 4 Texto, «Se debe solicitar» desmarcado, sin entidad → vacío): `proyecto`, `modelo`, `compartimiento`, `columna`.
  **Acción** `MD_limites`, con defaults en fórmula: proyecto=`If(Len(Trim(Topic.proyecto)) = 0, "Antapaccay", Topic.proyecto)` · modelo=`If(Len(Trim(Topic.modelo)) = 0, "(todos)", Topic.modelo)` · compartimiento=`If(Len(Trim(Topic.compartimiento)) = 0, "(todos)", Topic.compartimiento)` · columna=`If(Topic.columna = "MD_Completo", "MD_Completo", "MD")`.
  **Después:** Condición `Len(Trim(Topic.md)) = 0` → Mensaje «No hay límites cargados para esa combinación. Prueba /limites ‹mina› para ver qué tiene.» · si no → Mensaje `{Topic.md}` → **Finalizar tema**. ⛔ **Sin Prompt de análisis**: es una tabla de referencia, no hay nada que interpretar.
  > Flujo `MD_acumequipo` (equipo). SIN análisis. Metales como filas + línea de contexto (serie/horas/ranking/estado).
- **26 Ayuda / Glosario** (tipo Prompt, SIN flujo/SQL; descripción medida 563 UTF-16): "AYUDA / GLOSARIO: preguntas CONCEPTUALES o de definición sobre el análisis de aceite y sobre qué hace KomfIA — SIN datos de un equipo o flota. «¿qué es el TBN?», «¿qué significa DDI/ADI?», «¿qué es LP y LC?», «¿qué metales indican desgaste?», «¿qué es el triage / el barrido / la tendencia incipiente?», «¿qué componentes analizan?», «¿qué puedo preguntarte? / ayuda / qué haces». Responde breve, desde el glosario. ⛔ NO si piden datos reales de un equipo o flota (valores, último análisis, conteo, estado…) → esos van a su módulo. ⛔ NO inventa cifras de equipos."


## Variables de entrada — descripciones (AUTORIDAD única; van SIEMPRE en el TEMA, no en el flujo)
Estas descripciones se pegan en cada **Entrada del tema** en Copilot (no en el flujo). `CONFIG_FLUJOS.md` solo
lista qué entradas consume cada flujo; el TEXTO de cada descripción vive aquí.
- `equipo` = "Código del equipo (ej. CAxxxx). Traduce apodos («el 3177»→CA3177)."
- `compartimiento` = "Tipo de componente. En temas por-equipo usa la abreviatura (MT LH, Sist. Hidr., Motor…); en temas de FLOTA usa la palabra BASE (tracción, hidráulico, rueda, mando, transmisión, motor). Traduce apodos y siglas."
- `parametro` = "Símbolo de UN metal/parámetro (Fe, Cu, Cr, Pb, Sn, Si, PQ…). Traduce cobre→Cu, hierro→Fe."
- `parametros` = "Uno o VARIOS metales en símbolo, separados por coma (ej. `Fe` o `Fe,Cu,Cr`). Traduce nombres→símbolo (cobre→Cu, potasio→K). Devuelve una tabla por metal." (solo Tema 25)
- `proyecto` = "Proyecto/mina (ej. Antapaccay). Si no lo nombran o dan algo que no es una mina válida, usa Antapaccay."
- `modelo` = "Modelo de equipo dentro de la flota consultada (ej. 980E, 930E, D475A, PC1250). Acepta el modelo abreviado (980, d475). Si el usuario no nombra ningún modelo, dejar vacío: se muestra la flota completa." — opcional: sin pregunta, y la Acción convierte el vacío en `todos`.
- `columna` (solo Barrido filtrado) = "MD_Criticos para solo críticos; MD_Precaucion para solo precauciones."

> ⚠ **El FORMATO de las tablas (orden y agrupación de parámetros) NO se decide aquí.** Es fuente de gerencia:
> [../arquitectura/FORMATO_POR_COMPONENTE.md](../arquitectura/FORMATO_POR_COMPONENTE.md), y los límites en
> [../arquitectura/LIMITES_FALLBACK.md](../arquitectura/LIMITES_FALLBACK.md). El tema solo imprime el `MD`.

## Nodos de un tema — cómo se arma (enseñar SIEMPRE, el orden importa)
El tema PARTE del flujo (ver [CONFIG_FLUJOS.md](CONFIG_FLUJOS.md)); el/los Prompt(s) son PARTE del tema. Orden de nodos:
1. **Disparo** = por DESCRIPCIÓN (el agente elige; no hay «Frases» en el modelo de agente).
2. **Preguntar entradas faltantes** — **con nodos propios, no confiando en la entrada** (receta abajo). Solo las
   REQUERIDAS; las de default (proyecto=Antapaccay, modelo=todos, compartimiento=tracción) NO se preguntan, se
   fijan en la Acción.
3. **Acción (flujo)** — pasa las entradas; fija `vista`/`columna`/defaults. Sale `md` (+`observados`,`recomendaciones`).
4. **Mensaje** `{md}` — imprime la tabla ya armada TAL CUAL.
5. **CON análisis** (temas que lo llevan): Acción **Prompt** `Análisis de aceite` (`tabla={md}`) → Mensaje `{analisis.text}` → Mensaje `{recomendaciones}`. El Prompt es SIN conocimiento (ver [CONFIG_PROMPTS.md](CONFIG_PROMPTS.md)). **SIN análisis:** omite estos 3 nodos.
6. **Condición** `md está en blanco` → Mensaje sin-data → **Finalizar** (el `if(empty)` del flujo evita el crash; la Condición muestra el mensaje).
> Tema 25 (Último análisis por metal en la flota) = **CON análisis** (nuestro pequeño análisis, como el fallback): Acción `MD_ultmetalflota` → Mensaje `{md}` → Prompt `Análisis de aceite` (`tabla={md}`) → Mensaje `{analisis.text}` → **Condición** `recomendaciones NO está en blanco` → Mensaje `{recomendaciones}` → **Condición** `md está en blanco` → Mensaje sin-data → Finalizar. Entradas: `proyecto`,`modelo`,`compartimiento`,`parametros`.
> - **`modelo` lo LLENA la IA** (honra el modelo que el usuario nombre: «980E», «D475A»…); default `(todos)` SOLO si no lo nombran. ⛔ NO fijarlo a `(todos)` en la Acción — eso ignoraba el modelo pedido y mezclaba equipos de OTROS modelos (sin límites cargados) → chips y header de límites inconsistentes. `compartimiento` default `tracción`, `proyecto` default Antapaccay, ambos en la Acción; el metal se pregunta si NO lo nombran.
> - **Límite de referencia por MODELO:** con un modelo nombrado, la tabla es de UN modelo → límite uniforme → chips y header cuadran. Con `(todos)` los límites pueden variar por modelo (p.ej. hidráulico) → el view NO cruza límites entre modelos (fila sin límite propio queda sin chip, no se juzga con el de otro modelo).
> - **Recomendaciones = SOLO MT:** el flujo solo llena `recomendaciones` cuando `CompTipo=TRACCION` y el metal salió observado (verbatim de vw_Recomendaciones); en no-MT o sin observados viene NULL → la Condición «no está en blanco» oculta ese Mensaje. Por eso la 2ª Condición.
> - **⚠️ en el valor:** el view marca con ⚠️ los valores del metal que dan **0.0** (muestras no-DDI que suelen ser falso positivo; el área lo revisa aparte). No es una alerta de límite, es un aviso de dato sospechoso.
> Tema 26 (Ayuda / Glosario) = **tipo Prompt, SIN flujo ni SQL**: Disparo (descripción) → **Solicitud** `Ayuda KomfIA` (entrada `pregunta` = el mensaje del usuario, p.ej. `System.Activity.Text`) → Mensaje `{ayuda.text}` → Finalizar. El glosario va DENTRO del prompt (sin conocimiento externo). Ver [prompts/ayuda_glosario.md](prompts/ayuda_glosario.md). Es el hogar de las consultas simples/conceptuales (antes caían al fallback y se sobre-explicaban).

## 🧩 Receta: el tema pregunta lo que falta — **6 piezas** (probada en 09 y 22, 01-02/10)

**Por qué hace falta:** cuando se llega a un tema por **«Ir a tema»** desde el Tema 00, las entradas vienen
fijadas y el tema **no pregunta** nada por sí solo. Y si se deja que pregunte el **orquestador**, pregunta con
textos inventados y se lleva la conversación a otro lado. ⇒ Las preguntas son **nuestras**, en nodos propios,
y el orquestador queda fuera de las tres puertas por donde se cuela (piezas 4, 5 y 6).

| # | Dónde | Qué | Si falta |
|---|---|---|---|
| 1 | **Tema 00**, rama del comando | Lo que falta va como **`Blank()`, nunca `""`**: `If(Topic.pN = "", Blank(), Topic.pN)`. Si un token es ambiguo (¿`Fe` es metal o componente?), una variable auxiliar calculada **antes** de la cascada lo decide (`Topic.esMetal2`) | con `""` el tema **ni entra**: responde el orquestador |
| 2 | **Tema destino**, entre Desencadenador y Acción | Por cada entrada obligatoria: **Condición en fórmula** `Len(Trim(Topic.x)) = 0` → **Pregunta** (Identificar: *Respuesta completa del usuario*). Rama «Todas las demás» vacía. Bloques en serie, en el orden del comando | `FlowActionBadRequest`, o «No encontré datos» |
| 3 | Cada **Pregunta** | **«Guardar respuesta del usuario como» = la misma variable de entrada** | la respuesta se pierde |
| 4 | **Detalles del tema → Entrada**, cada variable | *Configuración adicional* → **«Se debe solicitar al usuario» desmarcado** | el orquestador pregunta él con una sintaxis inventada y el tema no corre |
| 5 | Cada Pregunta → *Propiedades* → **Interrupciones** | **«Permitir el cambio a otro tema» desmarcado** | una respuesta corta (`Fe`) se toma como mensaje nuevo: el tema se corta antes de la Acción y cae en «Remitir a un superior» |
| 6 | Cada Pregunta → *Propiedades* → **Reconocimiento de entidades** | **«Acción si no se encuentra ninguna entidad»: dejar la variable vacía**, no «Remitir» | «La remisión a un representante no está configurada» |

*(Omitir pregunta se deja en «Permitir que se omita»: así se salta si la variable ya trae valor.)*

**Las trampas, en el orden en que aparecieron (01-02/10):**
1. `Blank()` sin preguntas en el tema → `FlowActionBadRequest`. *(Pieza 2.)*
2. Preguntas sin «Guardar como» → la respuesta no llega a la Acción. *(Pieza 3.)*
3. Fórmulas pegadas en la entrada equivocada del nodo «Tema» → preguntó el equipo que sí venía.
4. Fórmula de una versión vieja que empezaba igual → componente = `Fe`.
5. **«está en blanco» no detecta `""`**: Copilot usa Power Fx moderno, donde `IsBlank("")` es falso →
   `/ranking` corrió con `LIKE '%%'` («Ranking Sn — Transmisión», todas en posición 1). *(Pieza 2 en fórmula.)*
6. **`""` desde el Tema 00 → el tema ni entra** y el orquestador inventa la sintaxis del comando. *(Pieza 1.)*
7. **«Se debe solicitar al usuario» marcado** → lo mismo, aun con `Blank()`. *(Pieza 4.)*
8. **Interrupciones permitidas** → tras `traccion` respondió `Fe`, el orquestador se llevó la conversación y
   `MD_ranking` no tuvo ninguna ejecución. *(Piezas 5 y 6.)*
9. **El orquestador manda acentos como entidad HTML** (`hidr&#225;ulico`) → el flujo traduce con los Redactar
   `comp_in`/`comp_tipo` (buscan `hidr`, `tracc`… sin tilde). Aplica a todo flujo que reciba un componente.
   Caso 2 (02/10): `MD_ultmetalflota` recibía `MT` desde el Tema 00 (`comp2`) → 0 filas → `•` suelto y el
   orquestador re-llamó al tema: **dos ejecuciones** del flujo. Síntoma a reconocer: el tema responde dos veces.

**Cómo depurar sin adivinar** — tres miradas, en este orden:
1. **Panel de actividad** del chat de prueba: ¿aparece el tema destino después de **00 Comandos**? Si no, el
   orquestador lo interceptó (piezas 1 y 4).
2. **Historial de ejecuciones del flujo**: ¿hubo ejecución? Si no, el tema se cortó antes de la Acción
   (piezas 5 y 6).
3. **La consulta que llegó**, en esa ejecución: qué valor tuvo cada entrada (piezas 1-3, trampas 3 y 4).

**Temas que la necesitan** — seguimiento en [PENDIENTES](PENDIENTES.md) C5:

| Tema | Comando | Entradas obligatorias |
|---|---|---|
| ✅ 09 Gráfica | `/grafica` | equipo · compartimiento · parametro *(revisar piezas 4-6)* |
| ✅ **22 Ranking** — la plantilla | `/ranking` | compartimiento · parametro *(proyecto con default Antapaccay)* |
| 01 Último análisis | `/ultimo` | equipo · compartimiento |
| 06 Tendencia | `/tendencia` · `/tendenciadet` | equipo · compartimiento |
| 11 Historial componente | `/historial` | equipo · compartimiento |
| 13/14 Historial de un metal | `/historialmetal` | equipo · parametro |
| 25 Metal en flota | `/metalflota` | parametros |
| 02 Condición MT | `/condicionmt` | equipo |
| 04 Diagnóstico completo | `/diagcompleto` · `/diagnostico` | equipo |
| 12 Historial equipo | `/historialeq` | equipo |
| 28 Acumulados equipo | `/acumulados` | equipo |
| 🅿 30 Límites (aparcado 03/10) | `/limites` · `/limitesc` | — (todo con default) |

Los de flota con default (`/barrido`, `/triage`, `/conteo`, `/incipiente`, `/historialflota`, `/rankingacum`,
`/rankinggraf`) no la necesitan: su `If(p="","Antapaccay",p)` nunca deja el proyecto vacío.

## Intuitividad — plan (que el sistema NUNCA falle por un dato faltante)
Objetivo: cero errores; si falta algo REQUERIDO, se pide en el chat; si es inferible o tiene default, se resuelve solo.
- **Defaults no-restrictivos por tema:** proyecto→Antapaccay (si falta o es inválido, ej. «Lima»); **modelo→honra el que nombren, sino (todos)** (⛔ no lo ignores fijándolo a (todos)); en flota, compartimiento→tracción. ⛔ Nunca «sin datos» por un dato con default.
- **Pedir SOLO lo genuinamente requerido y no-inferible:** el metal en Tema 22/25, el equipo en los por-equipo. Una sola pregunta, clara, con ejemplos.
- **Traducción de apodos/siglas → keyword** antes de llamar al flujo (nunca pasar la sigla literal).
- **Pendiente de expansión a otras minas:** cuando se sume una mina, revisar TODAS las descripciones de tema para no quedar ancladas a Antapaccay (el default está bien; el TEXTO no debe excluir otras minas).
- **Follow-up ambiguo → re-delegar** al tema del turno previo (no al esqueleto genérico), conservando el scope.

## ⚠ Gotcha — añadir una entrada nueva a un tema ya referenciado (2026-09-20)
Cuando agregas una **entrada** a un tema que otro tema ya invoca con «Ir a otro tema» (típico: el dispatcher
«00 Comandos»), el nodo de redirección **conserva el esquema viejo** y avisa:
> *«Se ha eliminado la entrada ‹x› porque el tipo de datos de la variable no es apto para recibir o devolver
> valores»* · *«No se encuentra el enlace Input ‹x›; actualice este flujo para obtener los enlaces más recientes»*

**Orden correcto (la secuencia importa):**
1. **Guardar el tema DESTINO** con su entrada nueva. Hasta que no se guarda, el resto del agente no la ve.
2. En el tema que redirige, **re-seleccionar el tema destino** en el nodo «Ir a otro tema» (cambiarlo a otro y
   volver a elegirlo) → fuerza a releer sus entradas.
3. Recién entonces mapear la entrada.
4. Verificar que la variable de origen tenga **tipo String** en la lista de variables (el mismo aviso sale si
   quedó sin tipo definido).

Ocurrió al añadir `rango` a los Temas 12/13/14/15 en P4.


## Sub-agente de RESPALDO — «KomfIA SQL» (descripción canónica)

No es un tema: es el agente conectado que genera SQL ad-hoc. El orquestador elige **por descripción**, y
una descripción amplia («responder CUALQUIER consulta… triage… barrido… llama siempre») hacía que lo
eligiera **antes** que los temas en consultas ambiguas — «barrido… de cada motor de tracción» caía ahí y
devolvía JSON crudo (fix 10/08/26). **La descripción se escribe por lo que NO hace:**

> «Agente de RESPALDO (fallback). Genera y ejecuta SQL ad-hoc SOLO para consultas de datos que NINGÚN tema
> cubre (imprevistas/exploratorias). ⛔ NO usar para barrido/flota, triage MT, diagnóstico/estado de equipo,
> último análisis, condición MT, tendencia, gráfico, historial, conteo ni ranking — cada uno tiene su TEMA
> determinista. Úsalo solo cuando la consulta no encaje en ningún tema.»

Reglas que lo acompañan:
- **Nunca se niega** ni escala a un superior: siempre responde con un `SELECT`. Si se niega, Copilot dispara
  «Remitir a un superior» y la conversación muere.
- **Solo `SELECT` simple** (TOP N + WHERE + ORDER BY). Pre-agregar desde el fallback producía `BadGateway`.
- Formatea su propia salida con el prompt `Presentación de filas` (ver [prompts/formateo_fallback.md](prompts/formateo_fallback.md)); no devuelve JSON crudo.
- Instrucción desplegada: [KomfIA_SQL_MD.docx](KomfIA_SQL_MD.docx). Central: [KomfIA_central_MD.docx](KomfIA_central_MD.docx).
