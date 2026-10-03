# Pendientes KomfIA — backlog único

> **Este es EL backlog.** Si algo está pendiente, está aquí. Nadie más lista pendientes.
> Reescrito limpio el **01/10/2026**; ronda 03/10 arriba. Lo cerrado de la ronda 28/09 (Fase 1 SQL, los timeouts, BLOQUES
> 147-188, C1-C4) se archivó en
> [pendientes-legado/PENDIENTES_2026-09-28_a_2026-10-01.md](pendientes-legado/PENDIENTES_2026-09-28_a_2026-10-01.md)
> — ahí está el *cómo se resolvió*; aquí solo *qué falta*.
> Config canónica → [CONFIG_TEMAS](CONFIG_TEMAS.md) · [CONFIG_FLUJOS](CONFIG_FLUJOS.md) · [CONFIG_PROMPTS](CONFIG_PROMPTS.md) · [CONFIG_COMANDOS](CONFIG_COMANDOS.md) · [CONFIG_TIMEOUT](CONFIG_TIMEOUT.md)

**Reglas permanentes:** (1) auditar TODO el sistema **antes** de cambiar · (2) editar un comando = su módulo
completo + los 3 archivos de la tarjeta · (3) nunca SQL sin cruzar `../arquitectura/ESQUEMA_BD.xlsx` · (4) SQL
de prueba → `VALIDACION_SSMS.sql` en bloques numerados, la **medición primero** · (5) medir con el operador de
producción (`LIKE '%x%'`) · (6) tras desplegar DDL, smoke test (BLOQUE 89) · (7) vista lenta → skill
`komfia-doctor` · (8) al revisar capturas, **mirar la insignia «Generado por la IA»** antes de creerse una tabla.

---

# ▶ EMPIEZA AQUÍ — ronda 03/10 (lo que se vio en la presentación del 02/10)

> Primera presentación de la alfa a gerencia (02/10). Testigo: **CA3195 MT LH** (PQ 233.2 🟥 en la última muestra).
> Lo cerrado de la ronda 01-02/10 (C5, H6, L6, N3, N4) está en
> [pendientes-legado/PENDIENTES_2026-10-02.md](pendientes-legado/PENDIENTES_2026-10-02.md).

## Qué se vio y por qué

| # | Síntoma (02/10) | Causa | Cura | Estado |
|---|---|---|---|---|
| **R1** ⭐ | `/ultimo 3195 mt`: P, B, V100 sin LP/LC y el ISO en `—`, **aunque Antapaccay sí tiene esos límites** (el error que más se notó) | El 29/09 la fundación pasó a leer los 38 límites, pero `vw_UltimoAnalisisMD` seguía con su lista de 18 (P/B/V100 en `NULL` fijo, sin ISO) | La vista lee los 30 parámetros con su límite y su `Estado_*`; la viscosidad se muestra como banda (`a–b`, `≥ a`, `≤ b`) | ✅ SQL (194.1): P 280/240, V100 70.1–85.7, ISO enteros · falta Teams |
| **R2** | `/tendencia` y `/grafica`: lo mismo (P con LP=240 **escrito a mano**, ISO en `·` aunque el historial sí tiene el dato) | `vw_TendenciaElemento`, la misma lista vieja, y recalculaba el semáforo por su cuenta | Igual que R1 + el semáforo sale de `Estado_*` | ✅ SQL (194.2) · ⏳ falta el tiempo de 194.M (corte 40,5 s) |
| **R3** | «Cosas que no cuadran» en `/tendencia`: el 16-Sep sale 🟢 y en `/historial` 🟥; Zn 🟥 con la fila Estado en 🟢 | La fila Estado salía de `Estado_General` (no mira ISO); el historial y el triage usan la peor celda con `Inf = 0`. Zn en MT es **informativo** (`Inf = 1`) y la tendencia no lo explicaba | Estado = peor celda con `Inf = 0`, como el historial; + el pie de informativos del triage. (El pie del triage nombraba a `Mo` como informativo en MT: no lo es, corregido) | ✅ SQL (194.2): Estado 🟥🟢🟥🟢🟥🟥 = el historial · falta Teams |
| **R4** | Los códigos de limpieza (ISO) salían con decimal (`20.0`) | Se formateaban como un metal | **Regla: el ISO va siempre entero**, valor y límite. Aplicada en las 7 vistas que lo muestran | ✅ SQL (194.1/194.2) |
| **R5** ⭐ | `/incipiente` no listó al CA3195 (PQ ≈50 → 233) y tardó 8 min | (a) El criterio **descartaba lo que ya pasó el LP**. (b) La vista leía el proyecto **3 veces**. (c) `MD_incipiente` con **reintentos** (8 min 22 s = 4 intentos de 2 min) | Reescrita en **1 lectura**; nueva categoría 🟥/🟨 **cruzó** (pasó el límite viniendo de un historial bajo él; lo crónico sigue siendo del barrido); por **modelo** | ✅ SQL (194.3): **1,9 s** (antes 10,0), CA3195 🟥 cruzó LC · ⏳ Copilot (PASO 1 y 3) |
| **R6** | `/incipiente antapaccay 980` → «Sin datos suficientes» | `980` llegaba como componente; la vista no tenía modelo | Tema 00: `esComp2` + modelo (un modelo siempre lleva dígito) · entrada `modelo` en Tema 20 y `MD_incipiente` | ✍ escrito en CONFIG |
| **R7** | `/historial 3195 MTLH 6 meses` → «No encontré datos» | No era el rango: `MD_historial` compara `LIKE '%MTLH%'` contra `MT LH`. El bug del componente pegado (24/09) nunca llegó a este flujo | Redactar `comp_key` en el flujo + comparar sin espacios ([CONFIG_FLUJOS](CONFIG_FLUJOS.md) § MD_historial) | ✍ escrito en CONFIG |
| **R8** | `/triage 3195 antapaccay` → «No encontré datos» + ayuda improvisada | El triage es de flota; `3195` llegaba como mina | Tema 00: si `p1` es un equipo → mensaje + **Ir a tema 03 Diagnóstico** | ✍ escrito en CONFIG |
| **R9** ⭐ | `/panel antapaccay 980` > 120 s dos veces; `/rankingacum` con el aviso de tiempo y luego la tabla; triage e historial «se colgaron y luego corrieron» | **Hipótesis: la BD saturada.** El BLOQUE 191 midió 2,9 s; el 193 dio **35 s de reloj con 4 s de CPU** (el servidor espera, no calcula). Una consulta que el conector abandona a los 120 s **sigue corriendo** en el servidor, y con reintentos se apilan | Medir: **L9** (forense del 02/10 en Query Store) + 194.M (panel 980 con el DDL viejo). Auditar **reintentos = Ninguno en TODOS los flujos** ([CONFIG_TIMEOUT](CONFIG_TIMEOUT.md) Capa A) | ✅ **medido (194.M, 03/10)**: panel 980 = **3,3 s** sin carga → el panel está sano, el 02/10 fue la BD. Patrón en las 4: **reloj = 4-8 × CPU** sin lecturas físicas = cada consulta espera su turno de CPU (tope del tier S1); dos a la vez tardan el doble. L9 sin permiso (Msg 262): **pedir al DBA `VIEW DATABASE PERFORMANCE STATE`** (solo métricas) |

## Orden de trabajo

**PASO 1 · Power Automate, antes del DDL** (sin esto el incipiente nuevo se rompe)
1. `MD_incipiente`: entrada `modelo` + `AND Modelo LIKE '%…%'` (default `todos`) — [CONFIG_FLUJOS](CONFIG_FLUJOS.md) § MD_incipiente.
   Con la vista vieja devuelve lo mismo que hoy.
2. En **cada** flujo con «Ejecutar una consulta SQL (V2)»: ··· → Configuración → **Directiva de reintentos = Ninguno**.
   `MD_flota` ya lo tiene (visto en la captura); `MD_incipiente` **no** (8 min). Anotar cuáles se cambiaron.

**PASO 2 · SSMS** — [BLOQUE 194](../arquitectura/VALIDACION_SSMS.sql) y [L9](../arquitectura/DIAGNOSTICO_LATENCIA.sql)
1. **L9.0-L9.3** (forense; no depende del DDL).
2. **194.M** con el DDL viejo → desplegar `DDL_vistas.sql` → **BLOQUE 89** → **194.M** otra vez → 194.1, 194.2, 194.3.
   Los cortes para revertir están escritos en el bloque.

**PASO 3 · Copilot** (después de que el 194 quede)
1. Tema 00 `/incipiente` (fórmulas en [CONFIG_COMANDOS](CONFIG_COMANDOS.md)) + Tema 20 entrada `modelo`.
2. `MD_historial`: Redactar `comp_key` (R7). Luego el mismo en `MD_equipo_comp` y `MD_metal` (mapa de abajo).
3. Tema 00 `/triage` con equipo → Diagnóstico (R8). ⛔ Ley 8: se **agrega** una Condición dentro de la rama, no se borra nada.
4. Tarjeta: `/incipiente ‹proj› [comp] [modelo]` — los 3 archivos ya están editados; pegar el JSON en el nodo.
5. Prueba en Teams con el testigo: `/ultimo 3195 mt lh` · `/tendencia 3195 mt lh` · `/grafica 3195 mt lh PQ` ·
   `/incipiente antapaccay` · `/incipiente antapaccay 980` · `/historial 3195 MTLH 6 meses` · `/triage 3195`.

**PASO 4 · Decisiones de Andrés**
- **T (sigue abierta, ahora más visible):** con R3 el ISO cuenta para el Estado en **tendencia, historial y triage**;
  **no** en panel, barrido y conteo (`Estado_General`). ¿Se unifica? Recomendación: que cuente en todos — el área
  cargó límites de ISO, y un componente con ISO>6 🟥 que el panel da por sano es el mismo fallo silencioso de G0.
- **«Acum» del PQ** (2489 en el CA3195): el PQ es un índice, no ppm. ¿El área lo suma? Si no, sale de la lista de Acum.
- ¿Qué más «no cuadraba» en la tendencia? (lo encontrado: R2, R3, R4).

## Después

| | Qué | Nota |
|---|---|---|
| **R10** | `/historialmetal` (4 vistas) con P/B/V100 sin límite | **No basta pasar el límite**: estas vistas recalculan el semáforo siempre «por arriba», y con el LP de P (280, invertido) marcarían 🟥 un P sano. Pasarlas a `Estado_*` primero |
| **R11** | Gráfica ASCII de un ISO: las marcas salen con decimal (`×20.0`) | Cosmético; `vw_TendenciaGrafico` es un bloque de 12 líneas generadas |
| **R12** | **`/limites` y `/limitesc`** — el menos prioritario (pedido 03/10) | Ver plan abajo |

### R12 · Plan de `/limites` y `/limitesc`
- **Qué:** como `/comandos` o `/ayuda`, pero con la tabla de límites. `/limites ‹proj› [modelo] [comp]` = solo los
  parámetros **con** límite cargado; `/limitesc …` = el formato completo del componente, con `—` donde no hay.
- **Fuente:** `vw_LimitesPorComponente` (lo que KomfIA **realmente** compara, ya agregado por `CompTipo`), no `[Eqpcare].[lc]`
  crudo: así lo que se ve es exactamente lo que dispara el semáforo. El orden y los grupos, de `vw_FormatoParametro`.
- **Forma:** una tabla por componente — `| Par. | LP | LC |` agrupada por familia, como `/ultimo`; la viscosidad
  como banda; el ISO entero; y una marca para los invertidos («la alerta es por debajo»).
- **Tamaño:** un proyecto entero son ~3 modelos × 4-6 componentes × ~30 filas (~20 KB): roza el tope de Teams. Sin
  `comp` → un resumen (componente × nº de parámetros con límite) y la invitación a pedir uno; con `comp` → la tabla.
- **Módulo completo:** vista `vw_LimitesMD` + flujo (`MD_flota` sirve: proyecto/modelo + vista + columna) + tema +
  Tema 00 + los 3 archivos de la tarjeta. Sin SQL de prueba nuevo hasta que se decida empezar.

### Mapa de propagación (5.1b) — flujos que reciben un componente

La trampa 9 (el componente llega en otro vocabulario: `MT`, `tracción`, `hidr&#225;ulico`) ya mordió dos veces
(`MD_ranking`, `MD_ultmetalflota`). Estado de **cada** flujo que filtra por componente:

| Flujo | Temas | Filtra por | Traduce en el flujo | Estado |
|---|---|---|---|---|
| `MD_ranking` | 22 | `CompTipo` | ✅ Redactar (02/10) | sano |
| `MD_ultmetalflota` | 25 | `CompTipo` | ✅ Redactar (02/10) | sano |
| `MD_triage` | 19 | `CompTipo` | ✅ Redactar (verificado 02/10) | sano |
| `MD_incipiente` | 20 | `CompTipo` | ✅ Redactar (verificado 02/10) | sano |
| `MD_equipo_comp` | 01 · 06 · 07 · 10 | `compAbbr` (`REPLACE … LIKE`) | ✗ — tolera `mt lh`/`mtlh`, **no** `hidráulico` ni la entidad HTML | riesgo por lenguaje natural |
| `MD_metal` | 09 | `compAbbr` | ✗ | riesgo por lenguaje natural |
| `MD_historial` | 11 · 13 · 14 | `compAbbr` (`COLLATE CI_AI`) | ✗ — tolera tildes, no la entidad HTML | riesgo por lenguaje natural |
| `MD_tendmetalflota` · `MD_condcomp` | 23 · 24 | `CompTipo` | ✗ | temas **desactivados** |

**Del lado del Tema 00:** ✅ (02/10) `comp1`/`comp2`/`comp3` traducen a la **abreviatura** (`MT LH`, `Sist. Hidr.`, `RD`, `Motor`):
correcto para los flujos por equipo, y los de flota ya traducen `MT` → `TRACCION`. Antes: `comp2` le mandó `MT` a un flujo de `CompTipo`. ⇒ Revisar **qué rama usa cuál** y que cada una
vaya a un flujo del mismo vocabulario.
**Síntoma a reconocer:** el tema responde **dos veces** (la primera vacía, con un `•` suelto) o el historial del
flujo muestra **dos ejecuciones** para una sola consulta.

---

## PASO 6 · Para **Carlos** — no es Copilot, es carga y límites

> ⏸ **Aplazado (decisión de Andrés, 02/10):** se lleva en el **siguiente feedback**, no ahora.
> **Orden de trabajo vigente:** terminar **C5** → **N1** → **I** → **F**.

**El SQL ya no miente; la carga sigue incompleta.** Llevar esta tabla tal cual.

| # | Hallazgo | Cifra / caso | Origen |
|---|---|---|---|
| 1 | **Ruedas de Antapaccay con límite de otro aceite** | Corren `SHELL SPIRAX S5 CFD M 60`; el límite de Ca se escribió para `Mobiltrans HD`. Tras el 188 se **ve** en el barrido (`CA3164 RD LH Ca=173.2 🟥`), igual que ya se veía en el triage y el diagnóstico | 157.2 · 158.4 · 188 |
| 2 | **885 componentes sin ningún límite** | Antamina 930E **441** · Cerro Verde 930E **216** · … Salen verdes pase lo que pase | 164.3 |
| 3 | **347 componentes con `ISO` en `0`** | Leídos como «sin medir». Incluye los 158 motores de Antamina | 159.2 |
| 4 | **1 579 muestras de Cerro Verde sin componente** | 62 equipos, 6 meses seguidos | 161.1 |
| 5 | **`Ca_LP`, `Zn_LP`, `Mg_LP` de Antamina en NULL** (hidráulico y ruedas: 100 %) | Sin LP, la **precaución** de un aditivo no puede saltar nunca: pasa de verde a crítico sin aviso | 160.1 · 188.1 |
| 6 | **Typo `MOTORO DE TRACCION RH`** | 72 equipos, 215 muestras, sigue entrando → 3 motores de tracción por camión | 165.3 |
| 7 | **`Compartimiento = 'nan'`** (texto, no vacío) | Sale como fila `nan` en `/conteo antapaccay` | conteo 01/10 |
| 8 | **`HT301 RD LH` (10-Sep), probable muestra mal rotulada** | `V100=77.2`, Ca 47.9, Zn 17.4 contra ~3 400 / ~1 000 del resto: es la firma del aceite del **motor de tracción** (Mobilgear SHC 680) | barrido Antamina 30/09 |
| 9 | **`V100` 🟥 en casi todas las ruedas de Antamina** (~18 cSt) | ¿Límite o aceite? | barrido Antamina 30/09 |
| 10 | **Decisión T: ¿el código de limpieza (ISO) cuenta como observado?** | Hoy el triage lo cuenta y el barrido no: Antapaccay hidráulicos 4 vs 3 (`CA3163` solo por `ISO>6`). Es **un valor** (`Inf=1` en `vw_FormatoParametro`) | 162.2b |

⛔ El typo **no** se normaliza en SQL: envolver `Compartimiento` en un `CASE` costó 17 min de cuelgue
(ley 3). *(BLOQUE 168.)*

---

# Después del 02/10

## Módulos nuevos (decididos el 28/09)

| | Qué | Nota |
|---|---|---|
| **N1** ✅ **CERRADO (01/10)** — BLOQUES 189-190; visto en Teams | `/tendencia` y `/grafica` en **una sola tabla**: una cabecera de fechas y todas las filas debajo; en `/grafica`, **la fila del metal primero** | SQL. ⚠ `/tendencia` es la vista más cara (35,8 s): medir con `LIKE` antes de darlo por bueno |
| **D1** ✅ **CERRADO (02/10)** — BLOQUE 190 + visto en Teams | `/diagcompleto` y `/diagnostico`: SMR en texto bajo el título + grupo «Muestra» (Fec. últ. · H. Comp. · T. muestra) sobre «Salud» — pedido de gerencia de último momento | Solo columnas en las copias que ya existían; ninguna referencia nueva |
| **I** ✅ **CERRADO (02/10)** — BLOQUE 191 + Teams: `/panel` (alias `/barrido`, `/conteo`), Tema 21 desactivado, el lenguaje natural «barrido»/«cuántos» → panel y «detalle» → 17 · observado = `Estado_General` (como /conteo y /barridodet) · reemplaza a /barrido cambiando la vista del Tema 16 | `/barrido` → **Panel de flota**, absorbe `/conteo` (`/conteo` queda como alias; luego se desactiva el 21) | Vista nueva `vw_PanelFlotaMD`, una sola lectura. Si no convence: se desactiva `/barrido` y `/barridodet` pasa a llamarse `/barrido`. Diseño completo en el archivo de legado, «Bloque I» |
| **F** ✅ **CERRADO (02/10)** — BLOQUE 192 + visto en Teams (`/historial`, `/historialeq`, `/historialflota`) · **vertical confirmado** (Teams no hace scroll horizontal: aprieta columnas) | Historial **vertical** con las 5 familias del formato (`Fe (232.6) 🟥`); `/historialflota` con valores y componente en mayúsculas | `/historialmetal` no cambia |
| **G** | Acumulados por componente (MT, ruedas, hidráulico) + renombre `/rankingacum` → `/rankingmod` | Depende de C (cerrado) |

## Detalles vistos en Teams al cerrar el F (02/10)

| Qué | Dónde | Cura probable |
|---|---|---|
| Tras los **historiales** la central agrega un resumen de varias viñetas («Patrones destacados…», «Resumen del último mes…»). Usa cifras de la tabla, no inventa, pero es la fuga del C2: tras un tema, como mucho **una** línea | `/historial`, `/historialeq`, `/historialflota` | Revisar si los temas 11/12/15 terminan con «Finalizar tema» y si la regla CIERRES de la central basta; si no, línea explícita «tras un historial, nada» |
| `/historialflota`: una fila observada con **Observados = —** (`CA3171 MOTOR 15-Sep`, 🟨) | `vw_HistorialFlotaFilasMD` | ✅ **CERRADO (02/10), BLOQUE 193** + Teams: familias del formato según el componente; 0 filas sin observados |

## Rendimiento (skill `komfia-doctor`)

| Vista | Hoy | Siguiente paso |
|---|---|---|
| `vw_TendenciaMD` (`/tendencia`) | **35,8 s** — la de menos margen (2,8× bajo el corte) | Atacar su base `vw_TendenciaElemento`; el filtro abajo la **empeora** (une varias fuentes) |
| `vw_DiagnosticoMD` (`/diagcompleto`) | 6,6 s tras el filtro abajo, pero `LaboratoryData` sigue en **7 scans** (uno por referencia a `base`) | Consolidar a 1 lectura; éxito = `Scan count`, no tiempo |
| `vw_HistorialFlotaMD` | el radar lista `s ×2` | medir antes de tocar |
| `vw_TendenciaMetalMD` | ~30 s con el operador real | — |
| `vw_HistorialFilasMD` · `vw_HistorialEquipoFilasMD` · `vw_HistorialFlotaFilasMD` | 34 / 34 / **35,4 s** tras el F (la de flota pasó el corte de 30 s del BLOQUE 193; se dejó por decisión de Andrés); **las tres leen la flota entera** (LaboratoryData 18 284) | Filtro abajo (CROSS APPLY sobre `MiningEquipment`): una sola fuente, el caso donde funcionó. Medir antes/después (BLOQUE 192.0 como base) |

## Heredado y backlog de fondo

- **`730E-` vs `730E`** en `lc` (BLOQUE 103): Cerro Verde 730E queda sin límites aunque el dato existe.
- **3 de las 4 fórmulas de componente** del Tema 00 (`comp1`, `comp2`, `comp3`) sin confirmar.
- **G2 modo B** y **G3**.
- **`Disponible`**: bandera mal planteada (depende de la mina, no del `CompTipo`); nadie la consume.
- **`/condicionmt`**: las celdas ISO nunca entran en su `VALUES` (preexistente).
- **Tarjetas con datos** → [tarjetas/PLAN_TARJETAS_DATOS.md](tarjetas/PLAN_TARJETAS_DATOS.md). Sin scroll: la palanca es paginar.
- **Gráfico ASCII opcional en Historial**, solo en variantes con serie limpia.
- **Consultas compuestas.**
- **Preguntas simples = respuesta directa** (una cifra, no la tabla completa).
- **`V100` y `Estado_General`**: decidir si la viscosidad dispara el estado (hoy no).

---

# Decisiones vigentes

| Tema | Decisión |
|---|---|
| Fallback | **Nunca dibuja tablas**: viñetas con prefijo 🔎. Una tabla en KomfIA significa «salió de una vista» (C2) |
| Central | Tras un tema, como mucho **una** línea de cierre; nunca tablas de resumen ni «hallazgos» (C2) |
| Semáforo | Ningún módulo lo recalcula: todos leen `Estado_*` de la fundación (188) |
| `Inf` | Es criterio de conteo, **nunca** una etiqueta visible al lado del dato |
| `‹modelo›` | Opcional; vacío = `todos` (los modelos con límites cargados); nombrado = solo ese |
| Límites (`lc`) | Los regula Carlos: nosotros leemos, mostramos y **reportamos** |
| `/tendenciametal` | Retirado; lo cubre `/grafica` (C3). El nodo del Tema 00 se queda (ley 8) |
