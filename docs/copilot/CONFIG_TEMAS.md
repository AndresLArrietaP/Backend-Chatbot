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
- **08 Tendencia de un metal:** "Tendencia de UN metal en TODOS los componentes de un equipo (comparar el metal entre compartimientos). «tendencia del cobre del CA3171», «cómo ha variado el Fe en el X», «el Cu en todos los componentes del <equipo>». Rellena equipo y parametro. ⛔ NO si nombran un componente (→ Tendencia detalle / Gráfica)."
- **09 Gráfica de un metal:** "Gráfica (curva) de la tendencia de UN metal ESPECÍFICO en UN componente. «gráfica del Cromo del MT LH del CA3171», «la curva del Fe del hidráulico del X», «el gráfico del cobre del <componente> del <equipo>». Rellena equipo, compartimiento y parametro. ⛔ NO si no nombran metal (→ Gráficas de observados)."
- **10 Gráficas de observados:** "Gráfica(s) de los metales OBSERVADOS de un componente, SIN nombrar metal — normalmente como CONTINUACIÓN tras ver una tendencia. «la gráfica», «las gráficas», «ahora la gráfica», «la gráfica de ello», «grafícame la tendencia». Toma equipo y compartimiento del contexto. Muestra automáticamente las gráficas de los metales fuera de límite; NO preguntes cuál metal."
- **11 Historial de componente:** "Bitácora cronológica de UN componente: todas las muestras en el tiempo (fecha, horómetro, horas comp., CM, estado, metales fuera de límite por muestra). «historial del MT LH del CA3171», «bitácora del hidráulico del X», «todas las muestras del <componente> en el tiempo». Rellena equipo y compartimiento. ⛔ NO la tendencia (→ Tendencia) ni el último puntual (→ Último análisis)."
- **12 Historial general del equipo:** "Bitácora cronológica de UN equipo COMPLETO: todas las muestras de todos sus componentes por fecha (recientes arriba). «historial del CA3171», «bitácora del equipo X», «las muestras del X en el tiempo», «cómo ha venido el equipo». Rellena equipo. ⛔ NO el estado actual (→ Diagnóstico) ni un componente (→ Historial de componente)."
- **13 Historial de un metal (en el equipo):** "Historial cronológico de UN metal en TODOS los componentes de un equipo (metal SIN componente). «historial del Fe del CA3171», «cómo ha venido el cobre en el equipo X», «evolución histórica del Cr del <equipo>». Rellena equipo y parametro. ⛔ NO si nombran un componente (→ Historial de un metal en un componente)."
- **14 Historial de un metal en un componente:** "Historial cronológico de UN metal en UN componente específico (metal Y componente). «historial del Cromo del MT LH del CA3171», «cómo ha venido el Fe del hidráulico del X». Rellena equipo, compartimiento y parametro."
- **15 Historial de observados de flota:** "Historial de los análisis OBSERVADOS recientes de toda una flota/mina (qué equipos y componentes se observaron últimamente, cronológico). «historial de observados de Antapaccay», «qué se ha observado en la flota de <mina>», «bitácora de observados de la mina». Rellena proyecto."
- **16 Barrido resumen:** "Barrido de la flota COMPLETA de una mina/proyecto (VARIOS equipos): resumen por equipo (críticos, precauciones, componentes y metales observados) + cuadro de límites, y ofrece el detalle. ⚑ La palabra «barrido» SIEMPRE cae en Barrido (resumen o detalle), NUNCA en Triage. «barrido de Antapaccay», «dame un barrido de sus últimos análisis y señala cuáles tienen condición», «barrido de cada motor de tracción de <mina>», «la flota de <mina>», «todos los equipos observados de <proyecto>». Rellena proyecto y modelo. ⛔ NO un equipo (→ Diagnóstico)."
- **17 Barrido detalle:** "Detalle COMPLETO de todos los equipos observados de una flota, agrupado por componente (desgaste + SALUD (V100/TBN) + aditivos fuera de límite + cuadro de límites; críticos arriba). Directo («detalle del barrido de Antapaccay», «barrido de cada motor de tracción con su detalle») o como CONTINUACIÓN tras el barrido resumen («detalle de todos», «detalle completo», «muéstrame todos con su detalle»). Rellena proyecto y modelo. ⚑ «barrido» cae en Barrido, nunca en Triage. ⛔ NO filtros «solo críticos/precauciones» (→ Barrido filtrado)."
- **18 Barrido filtrado:** "Detalle del barrido SOLO de un tipo: solo CRÍTICOS o solo PRECAUCIONES. «solo los críticos», «solo las precauciones», «únicamente en precaución». Rellena proyecto, modelo y columna (críticos→MD_Criticos, precauciones→MD_Precaucion). ⛔ NO el detalle completo (→ Barrido detalle) ni el resumen."
- **19 Triage MT:** "Triage de los Motores de Tracción OBSERVADOS de una flota completa (qué equipos tienen su MT fuera de límite, críticos primero) — CASO DE USO PRINCIPAL. «MT observados de Antapaccay», «triage de motores de tracción de <mina>», «qué motores de tracción necesitan atención en <proyecto>». Rellena proyecto. ⛔ NO un equipo individual (→ Condición MT), otros componentes (→ Barrido), NI cuando digan «barrido» (→ Barrido resumen/detalle) aunque mencionen motores de tracción — la palabra «barrido» SIEMPRE es Barrido, no Triage."
- **20 Tendencia incipiente:** "Motores de Tracción de una flota que se DISPARARON respecto a su propio promedio histórico (subida ≥40% sobre su media) SIN superar todavía el límite — alerta TEMPRANA, aún no observados. «tendencia incipiente en Antapaccay», «qué MT están subiendo sin pasar el límite», «qué motores de tracción por ahora no sobrepasan los límites pero han variado de su comportamiento promedio», «desgaste incipiente de la flota de <mina>», «cuáles se están disparando antes de la alarma». Rellena proyecto (modelo=(todos)). Muestra el EQUIPO afectado + parámetros (prom→últ, +%). ⛔ NO los ya fuera de límite (→ Triage MT / Barrido) ni un equipo puntual (→ Tendencia)."
- **21 Conteo de flota:** "CUÁNTOS: número de equipos de una flota y cuántos están observados/críticos/en precaución, con desglose por componente. Cubre los conteos: «cuántos equipos 980 hay en Antapaccay», «cuántos observados hay en <mina>», «cuántos MT críticos en <proyecto>», «conteo/resumen numérico de la flota», «cuántos equipos tiene <mina>». Rellena proyecto y modelo (si nombran un modelo como 980 lo filtra; si no, (todos)). Flujo MD_flota, vista=vw_ConteoFlotaMD. ⛔ NO el detalle equipo por equipo (→ Barrido), un ranking (→ Ranking) ni un equipo (→ Diagnóstico)."
- **22 Ranking:** "Los equipos con MÁS de un metal en un tipo de componente, en orden descendente. «top 5 de hierro en motor de tracción de Antapaccay», «los 3 de más cobre en el hidráulico de <mina>», «qué equipos tienen el cromo más alto en <proyecto>», «ranking de Fe en <componente>». Rellena proyecto, compartimiento (tracción/hidráulico/rueda/mando/transmisión/motor), parametro (el metal) y top (el número que pidan, p.ej. 5; si no dicen número, 10). ⛔ NO la evolución de un metal en un equipo (→ Tendencia/Historial de un metal)."


## Variables de entrada — descripciones (rellenar dinámicamente)
`equipo`="Código del equipo (ej. CA3177)." · `compartimiento`="Componente (MT LH, Sist. Hidr., Motor…).
Traduce apodos." · `parametro`="Símbolo del metal (Fe, Cu, Cr…). Traduce cobre→Cu." · `proyecto`="Proyecto/
mina (ej. Antapaccay)." · `modelo`="Modelo (ej. 980E)." · `columna` (solo Barrido filtrado)="MD_Criticos para
solo críticos; MD_Precaucion para solo precauciones."

## Temas NUEVOS a crear (ver ROADMAP)
- **Conteo de flota**, **Ranking**, **Tendencia incipiente** (#14). Descripciones en el ROADMAP.
