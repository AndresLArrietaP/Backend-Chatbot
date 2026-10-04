# Pendientes KomfIA — backlog único

> **Este es EL backlog.** Si algo está pendiente, está aquí. Nadie más lista pendientes.
> Reescrito limpio el **01/10/2026**; la ronda 03/10 se archivó el mismo día. Lo cerrado de la ronda 28/09 (Fase 1 SQL, los timeouts, BLOQUES
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

# ▶ EMPIEZA AQUÍ — después de la ronda 03/10

> **La ronda de la presentación del 02/10 está CERRADA** (R1-R16, verificada en Teams el 03/10): límites completos en
> `/ultimo` y `/tendencia`, ISO entero, Estado de la tendencia igual al historial, `/incipiente` con «cruzó» y modelo,
> historiales de 34-80 s a 0,5-10 s con la misma salida, `/historialmetal` de P/B sin mezclar metales. El detalle
> (síntoma → causa → cura → bloque) está en
> [pendientes-legado/PENDIENTES_2026-10-03.md](pendientes-legado/PENDIENTES_2026-10-03.md).

## ▶ Cableado del flujo de uso (04/10) — lo que queda, en orden

El recorrido de Carlos (MACRO **`/barridodet`** → `/incipiente` → `/ranking`·`/triage` → `/historialflota` · MICRO `/diagcompleto` →
`/condicionmt` → `/triage`·`/ultimo` → `/tendencia` → `/grafica` → `/historial*`) está en
[CONFIG_COMANDOS § Flujo de uso](CONFIG_COMANDOS.md). Auditado paso a paso **y módulo por módulo contra el formato**
(lo del 3195: que ninguno muestre «—» donde hay dato). El flujo manda, pero ningún otro comando queda comprometido: se
completan respetando su forma actual. Esto es lo que falta:

| # | Dónde | Qué | Paso del flujo | Estado |
|---|---|---|---|---|
| **W1** | SQL · `vw_CondicionMT_MD` | + V40, Mo, Agua, **ISO>4/6/14** (salían «—» con dato) | 6 (LH vs RH) | ✍ DDL · **BLOQUE 200** |
| **W1b** | SQL · `/barridodet` | La celda «Observado» nombra también P, B, Mo, Agua, Hollín, Diésel, TAN, V40, oxidación, sulfatación, nitración e **ISO**. Quién entra al barrido **no** cambia (`Estado_General`, decisión T) | 1 | ✍ DDL · **BLOQUE 201** |
| **W1c** | SQL · `/metalflota` | + Mo, TAN, V40, Agua, ISO; P y B con su límite. Las 14 filas de siempre, igual | 3 (variante) | ✍ DDL · **BLOQUE 201** |
| **W1d** | SQL · `/ranking` | + Na, K e ISO (alertan por arriba). Los aditivos no: el ranking descendente los leería al revés. Tema 22 con la descripción nueva (700) | 3 | ✍ DDL · **BLOQUE 201** + Copilot (descripción) |
| **W2** | SQL · `/historial` y tema 14 | numerar `rn_hist` en la vista: ~10 s → ~0,5 s, misma huella | 10 | ✍ DDL · **BLOQUE 200** |
| **W3** | Copilot · **Tema 00** | **Pases** cuando un comando de flota recibe un equipo: `/barridodet` e `/incipiente` (alta), `/panel` y `/historialflota` (media), `/rankingacum`·`/rankinggraf` (baja) + la regex de `/triage` ampliada a `HT079`. Fórmulas, mensajes y destinos en [CONFIG_COMANDOS § Pases](CONFIG_COMANDOS.md) | 1→5, 2→8, 4→10 | ⏳ Copilot |
| **W4b** | Copilot · flujo `MD_ranking` | El metal se compara **sin comodines** (como `MD_historial`): con `LIKE '%P%'`, «ranking de P» mezcla Pb y PQ en una sola tabla | 3 | ⏳ Copilot |
| **W4** | Copilot · **flujos** `MD_equipo_comp` y `MD_metal` | `comp_key` (el mismo de `MD_historial`): solo hace falta por **lenguaje natural** («el último del hidráulico del 3195»). 3 pasos en [CONFIG_FLUJOS](CONFIG_FLUJOS.md), arriba del § Descripción de entradas | 7-9 por NL | ⏳ Copilot |
| **W5** | Copilot · comprobar | Tema 20 con la descripción nueva (910) · «Reintentos = Ninguno» en **todos** los flujos · el Mensaje de `/triage` sin `'` al inicio · Tema 09 piezas 4-6 de la receta | — | ⏳ verificar |
| ✅ | — | El resumen de varias viñetas tras los historiales: en Teams 03/10 ya es **una** línea («📈 Tendencia registrada…») | 10 | cerrado |

Prueba de cierre: [PRUEBAS_ALFA_COMANDOS § N12](../pruebas/PRUEBAS_ALFA_COMANDOS.md), el flujo entero con el CA3195.

## Abierto, en orden

| # | Qué | Nota |
|---|---|---|
| 1 | **Ponderación por parámetro** (en estudio, 03/10) | Idea de Andrés, emparentada con el ranking de acumulados. La **decisión T** (¿el ISO cuenta en el Estado de panel, barrido y conteo?) queda **dentro** de esto: hoy el ISO cuenta en historial, triage y tendencia, y no en panel/barrido/conteo |
| 2 | **«Acum» del PQ** | El PQ es un índice, no ppm: ¿el área lo suma? Si no, sale de la lista de Acum (`vw_TendenciaMD`, `vw_TendenciaGraficoMD`). Preguntar a Carlos |
| 3 | **`comp_key` en `MD_equipo_comp` y `MD_metal`** → **W4** | El mismo Redactar de `MD_historial` ([CONFIG_FLUJOS](CONFIG_FLUJOS.md)); hoy toleran `mtlh` pero no `hidráulico` ni la entidad HTML. Ver el mapa de abajo |
| 4 | **`/historial` y tema 14 en ~10 s** (micro) → **W2** | Usan `rn_hist` como columna y esa ventana pasa por la flota entera. Numerar en la propia vista (como `grn` del tema 13) → ~0,5 s. Medir con huella (BLOQUE 199) |
| 5 | **`vw_DiagnosticoMD`: 7 lecturas de `base`** | Recordatorio de cada ronda. Consolidar a 1 lectura; éxito = `Scan count` |
| 6 | **`/tendencia` 19 s, de los cuales 7,6 s son compilar** | El flujo manda el equipo escrito en el texto → cada equipo recompila. La parametrización forzada es un ajuste de BD (DBA) |
| 7 | **Pedir al DBA** | `GRANT VIEW DATABASE PERFORMANCE STATE` (solo métricas: la forense L9 no corre sin él) y evaluar el tier: el 194 midió **reloj = 4-8 × CPU** |
| 8 | 🅿 **A largo plazo: `/limites` y `/limitesc` + el «siguiente paso sugerido»** | `vw_LimitesMD` desplegada y medida (196.4); Copilot sin montar y fuera de la tarjeta. Plan abajo. **Siguiente paso sugerido** (ex W6, 04/10): una línea al pie de `/barridodet` e `/incipiente` con el comando listo para el primer equipo; aparcado por Andrés |

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

> ⏸ **Aplazado (decisión de Andrés, 02/10):** se lleva en el **siguiente feedback** con Carlos. El #10 (ISO) quedó
> dentro del estudio de ponderación (Abierto #1).

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
| `vw_TendenciaMD` (`/tendencia`) | **19,0 s** (03/10, BLOQUE 194; antes 32-36 s): sin derrame a disco; 7,6 s son compilar | Ver «Abierto» #6 |
| `vw_DiagnosticoMD` (`/diagcompleto`) | 6,6 s tras el filtro abajo, pero `LaboratoryData` sigue en **7 scans** (uno por referencia a `base`) | Consolidar a 1 lectura; éxito = `Scan count`, no tiempo |
| `vw_HistorialFlotaMD` | el radar lista `s ×2` | medir antes de tocar |
| `vw_TendenciaMetalMD` | ~30 s con el operador real | — |
| Familia de historiales (`*FilasMD`) | ✅ **03/10, BLOQUES 197-199** con filtro abajo y la misma huella: `/historialeq` 34 → 0,46 s · `/historialflota` 35 → 1,9 s · tema 13 9,6 → 0,54 s · tema 14 80 → 9,6 s · `/historial` 34 → 10,2 s | Los dos de ~10 s: «Abierto» #4 |

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
| ISO | **Siempre entero** (valor y límite): es un código, no una medida (03/10) |
| Estado de una fila | Peor celda con `Inf = 0` en historial, triage y tendencia. Panel, barrido y conteo siguen con `Estado_General` hasta resolver la ponderación (Abierto #1) |
| Reintentos de los flujos | **Ninguno**, siempre: con el tier al tope, cada reintento apila otra consulta pesada (02/10: 4 × 2 min) |
| `/incipiente` | Lista lo que **sube** (≥40 %) y lo que **cruzó** el límite en la última muestra viniendo de valores normales; lo crónico es del barrido |
