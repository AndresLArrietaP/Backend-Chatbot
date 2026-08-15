# Config canónica — TEMAS (Tópicos de Copilot Studio)

Parte de la config a aplicar. Ver [CONFIG_FLUJOS.md](CONFIG_FLUJOS.md), [CONFIG_PROMPTS.md](CONFIG_PROMPTS.md),
[AUDITORIA_KOMFIA_2026-08.md](AUDITORIA_KOMFIA_2026-08.md).

**Reglas de tema:**
- `vista` y `columna` van **FIJAS en la Acción** (NUNCA como Entrada del modelo), salvo donde se indique
  «Entrada». El modelo solo llena `equipo/compartimiento/parametro/proyecto/modelo`.
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
| Tendencia paso 1 | equipo, compartimiento | MD_equipo_comp · vista=vw_TendenciaP1MD · columna=MD | no |
| Tendencia detalle | equipo, compartimiento | MD_equipo_comp · vista=vw_TendenciaMD · columna=MD | sí |
| Tendencia relevantes | equipo, compartimiento | MD_equipo_comp · vista=vw_TendenciaMD · columna=MD_Relevantes | sí |
| Tendencia de un metal | equipo, parametro | MD_metal · vista=vw_TendenciaMetalMD · compartimiento=todos · columna=MD | sí |
| Gráfica de un metal | equipo, compartimiento, parametro | MD_metal · vista=vw_TendenciaGraficoMD · columna=MD | no |
| Gráficas de observados | equipo, compartimiento | MD_equipo_comp · vista=vw_TendenciaGraficoObsMD · columna=MD | no |
| Historial general del equipo | equipo | MD_equipo · vista=vw_HistorialEquipoMD · columna=MD | no |
| Historial (componente) | equipo, compartimiento | MD_equipo_comp · vista=vw_HistorialMD · columna=MD | no |
| Historial de un metal (equipo) | equipo, parametro | MD_metal · vista=vw_HistorialMetalEquipoMD · compartimiento=todos · columna=MD | no |
| Historial de un metal en componente | equipo, compartimiento, parametro | MD_metal · vista=vw_HistorialMetalMD · columna=MD | no |
| Historial de observados de flota | proyecto | MD_flota · vista=vw_HistorialFlotaMD · modelo=todos · columna=MD | no |
| Barrido resumen | proyecto, modelo | MD_flota · vista=vw_ObservadosResumenMD · columna=MD | no |
| Conteo de flota | proyecto, modelo | MD_flota · vista=vw_ConteoFlotaMD · columna=MD (modelo default (todos)) | no |
| Barrido detalle | proyecto, modelo | MD_flota · vista=vw_ObservadosBarridoMD · columna=DetalleTodosMD | no |
| Barrido filtrado | proyecto, modelo, **columna** | MD_flota · vista=vw_ObservadosBarridoMD | no |
| Triage MT | proyecto | MD_flota · vista=vw_TriageMD · modelo=todos · columna=MD | sí |
| Último análisis por metal (flota) | proyecto, modelo, compartimiento, **parametros** | MD_ultmetalflota · vista=vw_UltimoMetalFlotaMD (fija en concat) · modelo=(todos) · compartimiento=tracción | no |

> **Barrido filtrado** es el ÚNICO que expone `columna` como Entrada (el modelo la infiere: «solo críticos»→
> `MD_Criticos`, «solo precauciones»→`MD_Precaucion`). En todos los demás, `columna` es FIJA en la Acción.

## H6 — Nombres NUMERADOS + descripciones FINALES (usar estas; renombrar el tema con su número)
Convención: prefijo `NN` en el NOMBRE del tema en Copilot (los diferencia de los temas por defecto y los ordena). "Historial" → "Historial de componente".

- **01 Último análisis de componente:** "Último análisis de aceite de UN componente de un equipo (SÍ se nombra el componente). «último análisis del MT LH del CA3177», «cómo salió el hidráulico del X», «la última muestra del <componente> del <equipo>». Rellena equipo y compartimiento. ⛔ NO el equipo completo (→ Diagnóstico) ni la flota (→ Barrido/Triage)."
- **02 Condición MT:** "Estado/condición de los Motores de Tracción (MT LH y RH juntos) de UN equipo. «condición del MT del CA3177», «cómo están los motores de tracción del X», «los MT del <equipo>». Rellena equipo. ⛔ NO un solo lado/componente (→ Último análisis) ni la flota (→ Triage)."
- **03 Diagnóstico equipo:** "ESTADO ACTUAL de TODOS los componentes de UN equipo (matriz componentes×parámetros, SOLO los observados). «diagnóstico del CA3177», «cómo está el equipo X», «último análisis general del X». ⛔ NO cronológico (→ Historial), un componente (→ Último análisis), la flota (→ Barrido/Triage) ni «completo/todos los metales» (→ Diagnóstico completo)."
- **04 Diagnóstico completo:** "Como el Diagnóstico pero con TODOS los parámetros (incluidos los OK), matriz completa. «diagnóstico completo del X», «todos los metales del equipo X», «la matriz completa del X». Rellena equipo. ⛔ NO solo observados (→ Diagnóstico equipo)."
- **05 Tendencia (paso 1):** "Evolución de las últimas muestras de UN componente, SIN nombrar metal (panorama + oferta de detalle/gráfica). «tendencia del MT LH del CA3177», «cómo ha evolucionado el hidráulico del X», «las últimas muestras del <componente>». Rellena equipo y compartimiento. ⛔ NO si nombran un metal (→ Tendencia de un metal / Gráfica) ni el último puntual (→ Último análisis)."
- **06 Tendencia detalle:** "Detalle de la tendencia de UN componente: cada metal por fecha + LP/LC + Σvida + mini-gráfico + resumen estadístico. Directo («detalle de la tendencia del MT LH del X», «la matriz de metales del <componente>») o como CONTINUACIÓN tras la tendencia general («detalle por elemento», «muéstrame todos los parámetros»). Rellena equipo y compartimiento."
- **07 Tendencia relevantes:** "Solo los parámetros FUERA DE LÍMITE de la tendencia de UN componente. «solo los relevantes de la tendencia del X», «qué parámetros están fuera de límite en la tendencia del <componente>», «los observados de la tendencia». Rellena equipo y compartimiento."
- **08 Tendencia de un metal:** "Tendencia de UN metal en TODOS los componentes de un equipo (comparar el metal entre compartimientos). «tendencia del cobre del CA3171», «cómo ha variado el Fe en el X», «el Cu en todos los componentes del <equipo>». Rellena equipo y parametro. ⛔ NO si nombran un componente (→ Tendencia detalle / Gráfica) NI si es a nivel FLOTA sin equipo (→ 23 Tendencia de un metal en la flota)."
- **09 Gráfica de un metal:** "Gráfica (curva) de la tendencia de UN metal ESPECÍFICO en UN componente. «gráfica del Cromo del MT LH del CA3171», «la curva del Fe del hidráulico del X», «el gráfico del cobre del <componente> del <equipo>». Rellena equipo, compartimiento y parametro. ⛔ NO si no nombran metal (→ Gráficas de observados)."
- **10 Gráficas de observados:** "Gráfica(s) de los metales OBSERVADOS de un componente, SIN nombrar metal — normalmente como CONTINUACIÓN tras ver una tendencia. «la gráfica», «las gráficas», «ahora la gráfica», «la gráfica de ello», «grafícame la tendencia». Toma equipo y compartimiento del contexto. Muestra automáticamente las gráficas de los metales fuera de límite; NO preguntes cuál metal."
- **11 Historial de componente:** "Bitácora cronológica de UN componente: todas las muestras en el tiempo (fecha, horómetro, horas comp., CM, estado, metales fuera de límite por muestra). «historial del MT LH del CA3171», «bitácora del hidráulico del X», «todas las muestras del <componente> en el tiempo». Rellena equipo y compartimiento. ⛔ NO la tendencia (→ Tendencia) ni el último puntual (→ Último análisis)."
- **12 Historial general del equipo:** "Bitácora cronológica de UN equipo COMPLETO: todas las muestras de todos sus componentes por fecha (recientes arriba). «historial del CA3171», «bitácora del equipo X», «las muestras del X en el tiempo», «cómo ha venido el equipo». Rellena equipo. ⛔ NO el estado actual (→ Diagnóstico) ni un componente (→ Historial de componente)."
- **13 Historial de un metal (en el equipo):** "Historial cronológico de UN metal en TODOS los componentes de un equipo (metal SIN componente). «historial del Fe del CA3171», «cómo ha venido el cobre en el equipo X», «evolución histórica del Cr del <equipo>». Rellena equipo y parametro. ⛔ NO si nombran un componente (→ Historial de un metal en un componente)."
- **14 Historial de un metal en un componente:** "Historial cronológico de UN metal en UN componente específico (metal Y componente). «historial del Cromo del MT LH del CA3171», «cómo ha venido el Fe del hidráulico del X». Rellena equipo, compartimiento y parametro."
- **15 Historial de observados de flota:** "Historial de los análisis OBSERVADOS recientes de toda una flota/mina (qué equipos y componentes se observaron últimamente, cronológico). «historial de observados de Antapaccay», «qué se ha observado en la flota de <mina>», «bitácora de observados de la mina». Rellena proyecto."
- **16 Barrido resumen:** "BARRIDO de una flota/mina: resumen por equipo de cuáles están observados (nº críticos y precauciones + sus componentes y metales) + cuadro de límites; ofrece el detalle. ⚑ CUALQUIER consulta que diga «barrido» cae AQUÍ (o en Barrido detalle), AUNQUE mencione «motor de tracción» o «señala cuáles tienen condición». «barrido de Antapaccay», «dame un barrido de sus últimos análisis y señala cuáles tienen condición», «barrido de cada motor de tracción de <mina>», «la flota de <mina>». Rellena proyecto y modelo. ⛔ Un equipo → Diagnóstico."
- **17 Barrido detalle:** "Detalle COMPLETO de todos los equipos observados de una flota, agrupado por componente (desgaste + SALUD (V100/TBN) + aditivos fuera de límite + cuadro de límites; críticos arriba). Directo («detalle del barrido de Antapaccay», «barrido de cada motor de tracción con su detalle») o como CONTINUACIÓN tras el barrido resumen («detalle de todos», «detalle completo», «muéstrame todos con su detalle»). Rellena proyecto y modelo. ⚑ «barrido» cae en Barrido, nunca en Triage. ⛔ NO filtros «solo críticos/precauciones» (→ Barrido filtrado)."
- **18 Barrido filtrado:** "Detalle del barrido SOLO de un tipo: solo CRÍTICOS o solo PRECAUCIONES. «solo los críticos», «solo las precauciones», «únicamente en precaución». Rellena proyecto, modelo y columna (críticos→MD_Criticos, precauciones→MD_Precaucion). ⛔ NO el detalle completo (→ Barrido detalle) ni el resumen."
- **19 Triage MT:** "TRIAGE de los Motores de Tracción OBSERVADOS de una flota (qué equipos tienen su MT fuera de límite, críticos primero). Se dispara SOLO con «triage» o «MT/motores de tracción observados / que necesitan atención» — y SIN la palabra «barrido». ⛔ Si la consulta dice «barrido» NO es triage (→ Barrido resumen/detalle), aunque mencione motores de tracción. ⛔ NO un equipo individual (→ Condición MT) ni otros componentes (→ Barrido)."
- **20 Tendencia incipiente:** "Motores de Tracción de una flota que se DISPARARON respecto a su propio promedio histórico (subida ≥40% sobre su media) SIN superar todavía el límite — alerta TEMPRANA, aún no observados. «tendencia incipiente en Antapaccay», «qué MT están subiendo sin pasar el límite», «qué motores de tracción por ahora no sobrepasan los límites pero han variado de su comportamiento promedio», «desgaste incipiente de la flota de <mina>», «cuáles se están disparando antes de la alarma». Rellena proyecto (modelo=(todos)). Muestra el EQUIPO afectado + parámetros (prom→últ, +%). ⛔ NO los ya fuera de límite (→ Triage MT / Barrido) ni un equipo puntual (→ Tendencia)."
- **21 Conteo de flota:** "CUÁNTOS: número de equipos de una flota y cuántos están observados/críticos/en precaución, con desglose por componente. Cubre los conteos: «cuántos equipos 980 hay en Antapaccay», «cuántos observados hay en <mina>», «cuántos MT críticos en <proyecto>», «conteo/resumen numérico de la flota», «cuántos equipos tiene <mina>». Rellena proyecto y modelo (si nombran un modelo como 980 lo filtra; si no, (todos)). Flujo MD_flota, vista=vw_ConteoFlotaMD. ⛔ NO el detalle equipo por equipo (→ Barrido), un ranking (→ Ranking) ni un equipo (→ Diagnóstico)."
- **22 Ranking:** "Los equipos con MÁS de un metal en un tipo de componente, en orden descendente. «top 5 de hierro en motor de tracción de Antapaccay», «los 3 de más cobre en el hidráulico de <mina>», «qué equipos tienen el cromo más alto en <proyecto>», «ranking de Fe en <componente>». Rellena proyecto, compartimiento (tracción/hidráulico/rueda/mando/transmisión/motor), parametro (el metal) y top (el número que pidan, p.ej. 5; si no dicen número, 10). ⛔ NO la evolución de un metal en un equipo (→ Tendencia/Historial de un metal)."
- **23 Tendencia de un metal en la flota:** "FLOTA: dirección (↑ sube / ↓ baja / → estable) de UN metal en un TIPO de componente de toda la flota/mina, equipo por equipo — cuando NO se nombra un equipo. «cómo evolucionó/ha variado el Fe en los motores de tracción de la flota», «el aluminio en tracción es ascendente o estable», «tendencia del Cu en los hidráulicos de Antapaccay», «cómo viene el cromo en las ruedas de la mina». Rellena proyecto, compartimiento (tracción/hidráulico/rueda/mando/transmisión/motor) y parametro (el metal). ⚑ Es de FLOTA (proyecto, sin equipo). ⛔ Si nombran UN equipo → 08 Tendencia de un metal."
- **24 Condición de un componente en la flota:** "FLOTA: qué equipos tienen UN tipo de componente OBSERVADO / que necesita atención en toda la flota/mina (críticos primero), con lubricante, horas y metales fuera de límite — para CUALQUIER componente. «qué sistemas hidráulicos necesitan atención», «cómo están los hidráulicos de la flota», «qué ruedas delanteras están fuera de límite», «mandos finales observados de Antapaccay», «qué motores están en condición». Rellena proyecto y compartimiento (tracción/hidráulico/rueda/mando/transmisión/motor). ⚑ FLOTA, UN tipo de componente. ⛔ NO solo MT (→ Triage), NO la flota completa por-componente (→ Barrido) ni un equipo (→ Diagnóstico)."
- **25 Último análisis por metal en la flota:** "FLOTA: el ÚLTIMO análisis de UN metal (o VARIOS) en un TIPO de componente de toda la flota/mina — el valor más reciente de ESE metal en CADA equipo, con su límite de referencia y estado, ordenados de mayor a menor. Es el «barrido enfocado a un metal». Se dispara cuando NOMBRAN el/los metal(es) + la flota + el tipo de componente (SIN nombrar un equipo). «dame el último análisis de hierro de todos los motores de tracción de Antamina», «el Fe de los MT de la flota», «hierro y cobre de todos los hidráulicos», «silicio, hierro y cromo de las ruedas de <mina>», «cómo está el cromo en cada motor de tracción». Con VARIOS metales devuelve UNA tabla por metal. Rellena proyecto, compartimiento (tracción/hidráulico/rueda/mando/transmisión/motor; default tracción) y parametros (el/los metal(es), símbolo). ⚑ FLOTA, UN metal (o varios) mostrando su ÚLTIMO valor por equipo. ⛔ NO todos los metales observados (→ 16/17 Barrido), NO la DIRECCIÓN/evolución del metal (→ 23 Tendencia de un metal en la flota), NO un solo equipo (→ 01 Último análisis / 08 Tendencia de un metal), NO «qué necesita atención» sin metal (→ 24 Condición de un componente en la flota)."


## Variables de entrada — descripciones (AUTORIDAD única; van SIEMPRE en el TEMA, no en el flujo)
Estas descripciones se pegan en cada **Entrada del tema** en Copilot (no en el flujo). `CONFIG_FLUJOS.md` solo
lista qué entradas consume cada flujo; el TEXTO de cada descripción vive aquí.
- `equipo` = "Código del equipo (ej. CAxxxx). Traduce apodos («el 3177»→CA3177)."
- `compartimiento` = "Tipo de componente. En temas por-equipo usa la abreviatura (MT LH, Sist. Hidr., Motor…); en temas de FLOTA usa la palabra BASE (tracción, hidráulico, rueda, mando, transmisión, motor). Traduce apodos y siglas."
- `parametro` = "Símbolo de UN metal/parámetro (Fe, Cu, Cr, Pb, Sn, Si, PQ…). Traduce cobre→Cu, hierro→Fe."
- `parametros` = "Uno o VARIOS metales en símbolo, separados por coma (ej. `Fe` o `Fe,Cu,Cr`). Traduce nombres→símbolo (cobre→Cu, potasio→K). Devuelve una tabla por metal." (solo Tema 25)
- `proyecto` = "Proyecto/mina (ej. Antapaccay). Si no lo nombran o dan algo que no es una mina válida, usa Antapaccay."
- `modelo` = "Modelo de equipo (ej. 980E). `(todos)` si no lo nombran — NUNCA vacío."
- `columna` (solo Barrido filtrado) = "MD_Criticos para solo críticos; MD_Precaucion para solo precauciones."

## Nodos de un tema — cómo se arma (enseñar SIEMPRE, el orden importa)
El tema PARTE del flujo (ver [CONFIG_FLUJOS.md](CONFIG_FLUJOS.md)); el/los Prompt(s) son PARTE del tema. Orden de nodos:
1. **Disparo** = por DESCRIPCIÓN (el agente elige; no hay «Frases» en el modelo de agente).
2. **Preguntar entradas faltantes** (intuitividad): solo las REQUERIDAS que el modelo no infirió; las de default (proyecto=Antapaccay, modelo=(todos), compartimiento=tracción en Tema 25) NO se preguntan, se fijan en la Acción.
3. **Acción (flujo)** — pasa las entradas; fija `vista`/`columna`/defaults. Sale `md` (+`observados`,`recomendaciones`).
4. **Mensaje** `{md}` — imprime la tabla ya armada TAL CUAL.
5. **CON análisis** (temas que lo llevan): Acción **Prompt** `Análisis de aceite` (`tabla={md}`) → Mensaje `{analisis.text}` → Mensaje `{recomendaciones}`. El Prompt es SIN conocimiento (ver [CONFIG_PROMPTS.md](CONFIG_PROMPTS.md)). **SIN análisis:** omite estos 3 nodos.
6. **Condición** `md está en blanco` → Mensaje sin-data → **Finalizar** (el `if(empty)` del flujo evita el crash; la Condición muestra el mensaje).
> Tema 25 (Último análisis por metal en la flota) = **SIN análisis**: Acción `MD_ultmetalflota` → Mensaje `{md}` → Condición sin-data → Finalizar. Entradas: `proyecto`,`modelo`,`compartimiento`,`parametros` (defaults fijados en la Acción; solo se pregunta el metal si NO lo nombran).

## Intuitividad — plan (que el sistema NUNCA falle por un dato faltante)
Objetivo: cero errores; si falta algo REQUERIDO, se pide en el chat; si es inferible o tiene default, se resuelve solo.
- **Defaults no-restrictivos por tema:** proyecto→Antapaccay (si falta o es inválido, ej. «Lima»); modelo→(todos); en flota, compartimiento→tracción. ⛔ Nunca «sin datos» por un dato con default.
- **Pedir SOLO lo genuinamente requerido y no-inferible:** el metal en Tema 22/25, el equipo en los por-equipo. Una sola pregunta, clara, con ejemplos.
- **Traducción de apodos/siglas → keyword** antes de llamar al flujo (nunca pasar la sigla literal).
- **Pendiente de expansión a otras minas:** cuando se sume una mina, revisar TODAS las descripciones de tema para no quedar ancladas a Antapaccay (el default está bien; el TEXTO no debe excluir otras minas).
- **Follow-up ambiguo → re-delegar** al tema del turno previo (no al esqueleto genérico), conservando el scope.
