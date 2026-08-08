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
| Barrido detalle | proyecto, modelo | MD_flota · vista=vw_ObservadosBarridoMD · columna=DetalleTodosMD | no |
| Barrido filtrado | proyecto, modelo, **columna** | MD_flota · vista=vw_ObservadosBarridoMD | no |
| Triage MT | proyecto | MD_flota · vista=vw_TriageMD · modelo=todos · columna=MD | sí |

> **Barrido filtrado** es el ÚNICO que expone `columna` como Entrada (el modelo la infiere: «solo críticos»→
> `MD_Criticos`, «solo precauciones»→`MD_Precaucion`). En todos los demás, `columna` es FIJA en la Acción.

## Descripciones de trigger («El agente elige») — una por tema
- **Último análisis de componente:** "Último análisis de aceite de UN componente de un equipo. «último análisis del MT LH del CA3177», «cómo salió el hidráulico del X». Rellena equipo y compartimiento. ⛔ NO para el equipo completo (Diagnóstico) ni la flota."
- **Condición MT:** "Estado de los Motores de Tracción (MT LH y RH) de UN equipo. «condición del MT del X», «cómo están los motores de tracción del X». Rellena equipo. ⛔ NO otro componente ni flota."
- **Diagnóstico equipo:** "ESTADO ACTUAL de TODOS los componentes de UN equipo (matriz). «diagnóstico del X», «cómo está el equipo X», «último análisis general del X». ⛔ NO historial (cronológico), un componente, ni flota."
- **Tendencia paso 1:** "Evolución de las últimas muestras de UN componente, SIN nombrar metal. «tendencia del MT LH del X». Rellena equipo, compartimiento. ⛔ NO si nombran un metal."
- **Tendencia detalle:** "Detalle de la tendencia de UN componente: metales×fechas + LP/LC + Σvida + resumen estadístico. «detalle por elemento», «la matriz de metales». Rellena equipo, compartimiento."
- **Tendencia relevantes:** "Solo los parámetros fuera de umbral de la tendencia de UN componente. «solo los relevantes de la tendencia del X». Rellena equipo, compartimiento."
- **Tendencia de un metal:** "Tendencia de UN metal en TODOS los componentes de un equipo. «tendencia del cobre del X». Rellena equipo, parametro. ⛔ NO si nombran componente."
- **Gráfica de un metal:** "Gráfica de tendencia de UN metal específico en UN componente. «gráfica del Cromo del MT LH del X». Rellena equipo, compartimiento, parametro."
- **Gráficas de observados:** "Gráfica(s) de los metales observados de un componente, SIN nombrar metal. «la gráfica», «ahora la gráfica», «las gráficas». Toma equipo/compartimiento del contexto. NO preguntar metal."
- **Historial general del equipo:** "REGISTRO CRONOLÓGICO de UN equipo: todas las muestras de todos sus componentes por fecha. «historial del CA3171», «bitácora del equipo X». ⛔ NO estado actual (Diagnóstico)."
- **Historial (componente):** "Bitácora cronológica de UN componente. «historial del MT LH del X». Rellena equipo, compartimiento. ⛔ NO si nombran metal."
- **Historial de un metal (equipo):** "Historial de UN metal en TODOS los componentes de un equipo. «historial del Fe del X». Rellena equipo, parametro. ⛔ NO si nombran componente."
- **Historial de un metal en un componente:** "Historial de UN metal en UN componente. «historial del Cromo del MT LH del X». Rellena equipo, compartimiento, parametro."
- **Historial de observados de flota:** "Historial de análisis observados recientes de una flota/mina. «historial de observados de Antapaccay». Rellena proyecto."
- **Barrido resumen:** "Flota COMPLETA de una mina/proyecto (varios equipos), resumen. «barrido de Antapaccay», «la flota de X». Rellena proyecto, modelo. ⛔ NO un equipo (Diagnóstico) ni MT observados (Triage)."
- **Barrido detalle:** "Detalle del barrido de una flota, agrupado por componente (todos, críticos arriba). «detalle de todos», «el detalle del barrido», «completo». Rellena proyecto, modelo."
- **Barrido filtrado:** "Detalle del barrido SOLO de un tipo. «solo los críticos», «solo las precauciones». Rellena proyecto, modelo y columna (críticos→MD_Criticos, precauciones→MD_Precaucion)."
- **Triage MT:** "Motores de Tracción OBSERVADOS de una flota, críticos arriba (caso de uso principal). «MT observados de Antapaccay», «qué motores de tracción necesitan atención en X». Rellena proyecto. ⛔ NO un equipo (Condición)."

## Variables de entrada — descripciones (rellenar dinámicamente)
`equipo`="Código del equipo (ej. CA3177)." · `compartimiento`="Componente (MT LH, Sist. Hidr., Motor…).
Traduce apodos." · `parametro`="Símbolo del metal (Fe, Cu, Cr…). Traduce cobre→Cu." · `proyecto`="Proyecto/
mina (ej. Antapaccay)." · `modelo`="Modelo (ej. 980E)." · `columna` (solo Barrido filtrado)="MD_Criticos para
solo críticos; MD_Precaucion para solo precauciones."

## Temas NUEVOS a crear (ver ROADMAP)
- **Conteo de flota**, **Ranking**, **Tendencia incipiente** (#14). Descripciones en el ROADMAP.
