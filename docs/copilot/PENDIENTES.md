# Pendientes KomfIA — backlog único

> **Este es EL backlog.** Si algo está pendiente, está aquí. Nadie más lista pendientes.
> Reescrito limpio el **01/10/2026**. Lo cerrado de la ronda 28/09 (Fase 1 SQL, los timeouts, BLOQUES
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

# ▶ EMPIEZA AQUÍ — viernes 02/10

> ⚠ **Presentación interna con Franco: hoy, 19:30.** Lo de abajo está ordenado para que lo que se vea sea lo
> que más se nota. El PASO 5 es Copilot puro; el PASO 6 es una conversación con Carlos.

## Dónde quedamos (01/10, noche)

| Paso | Qué | Estado | Verificado en Teams |
|---|---|---|---|
| **C1** | `‹modelo›` llega al flujo (temas 16/17/18/21) | ✅ | `/barrido antapaccay 980` → 10 · `d475` → 6116 · «solo los críticos» → solo CA · conteo sin duplicar |
| **C2** | El fallback y el análisis no dibujan tablas | ✅ | La central no añade resúmenes; el fallback responde con 🔎 y viñetas |
| **BLOQUE 188** | Barrido de Antamina: Ca/Zn/Mg salían 🟥 en el 100 % | ✅ | El barrido lee `Estado_*` de la fundación; el triage pinta 🟨 |
| **C3** | `/grafica` absorbe `/tendenciametal` · `/ranking` con modelo · descripciones | ✅ | `/grafica 3160 mt lh Fe` · `/ranking antapaccay tracción Fe 980 5` · incipiente por NL |
| **C4** | Tarjeta de **19** comandos | ✅ | `/comandos` |
| **Receta** | El tema pregunta lo que falta | ✅ **solo Tema 09** | `/grafica 3160 Fe` pregunta el componente · `3160 mtlh` el metal |

---

## PASO 5 · **C5** — paso a paso

### 5.1 · La receta «el tema pregunta lo que falta» en los otros temas ⭐ **primero**

Cura de una vez el **N2** (el «No encontré datos» que sale antes de la respuesta) y el **H1**.
✅ **Tema 22 Ranking terminado (02/10)** — `/ranking` → `traccion` → `Fe` = top 10 de Fe en tracción, con
ejecución correcta del flujo. **Es la plantilla:** copiar sus bloques a cada tema de la tabla.
La receta son **6 piezas** y las 6 tienen que estar → [CONFIG_TEMAS § Receta](CONFIG_TEMAS.md): `Blank()` en el
Tema 00 · Condición `Len(Trim(...)) = 0` + Pregunta · «Guardar como» la misma variable · «Se debe solicitar»
desmarcado · Interrupciones desmarcadas · «sin entidad» ≠ Remitir.
⚠ Revisar también el **Tema 09**: funciona, pero aún no tiene las piezas 4-6 verificadas.

**Orden sugerido** — primero los que más se usan y el que cierra el H1:

| # | Tema | Comando | Bloques a agregar (en este orden) | Prueba |
|---|---|---|---|---|
| ✅ | **22 Ranking** | `/ranking` | compartimiento · parametro (proyecto con default) | hecho 02/10 |
| ✅ | **01 Último análisis** | `/ultimo` | equipo · compartimiento | hecho 02/10 |
| ✅ | **06 Tendencia** | `/tendencia` | equipo · compartimiento | hecho 02/10 |
| ✅ | **11 Historial componente** | `/historial` | equipo · compartimiento | hecho 02/10 — preguntas ANTES de los «Establecer valor» de `rango`; `5 meses` sigue filtrando |
| 5 | **13 y 14 Historial de un metal** | `/historialmetal` | 13: equipo · parametro — 14: equipo · compartimiento · parametro | `/historialmetal 3160` |
| 6 | **25 Metal en flota** | `/metalflota` | parametros | `/metalflota antapaccay tracción` |
| 7 | **02 Condición MT** | `/condicionmt` | equipo | `/condicionmt` |
| 8 | **04 Diagnóstico completo** | `/diagcompleto` | equipo | `/diagcompleto` |
| 9 | **12 Historial equipo** | `/historialeq` | equipo | `/historialeq` |
| 10 | **28 Acumulados equipo** | `/acumulados` | equipo | `/acumulados` |

**Textos de las preguntas** (los mismos en todos los temas):
- equipo → «¿De qué equipo? Por ejemplo: 3160 o CA3160»
- compartimiento → «¿De qué componente? Por ejemplo: MT LH, MT RH, RD LH, Hidr, Motor»
- parametro → «¿Qué metal? Escribe el símbolo: Fe, Cu, Cr, Pb, Si, PQ…»
- parametros (25) → «¿Qué metal o metales? Símbolos separados por coma: Fe,Cu»
- proyecto (22) → «¿De qué mina? Por ejemplo: Antapaccay, Antamina»

**Criterio de terminado:** en cada tema, el comando a secas pregunta **todo** lo que falta, en orden, y
**nunca** aparece «No encontré datos» antes de la pregunta. Con todo completo, responde directo.
⚠ Si algo sale raro: el **historial de ejecuciones del flujo** muestra la consulta con los valores que
llegaron. Mirarlo antes de teorizar (así se encontró la trampa 4).

### 5.2 · H6 — `/triage mtrh antapaccay 980` sale con columnas descuadradas

Solo esa variante (`mtrh` pegado). Traer la captura y el `md` del historial del flujo `MD_triage`: ver si el
descuadre está en la tabla (vista) o en un mensaje que se coló entre filas.

### 5.3 · L6 — «0 observados» se lee como error

`/barrido antapaccay 930E` no devuelve filas porque el 930E no tiene observados (y además no tiene límites):
el tema dice «No encontré datos». Se arregla **en el tema**, no en SQL (cambiar la cardinalidad de la vista
afecta a todas las flotas sanas): el mensaje sin-datos de los temas de flota pasa a *«No hay equipos
observados con esos criterios. Si el modelo no tiene límites cargados, sus equipos no se pueden evaluar.»*
*(Origen: BLOQUE 151.)*

### 5.4 · H2 — `/ayuda` responde dos cosas distintas

Aleatoriedad abierta desde el 17/09. Mirar en el Tema 00 si `/ayuda` va a la tarjeta (`/comandos`) **y**
el orquestador además dispara el Tema 26 (Ayuda/Glosario). Si es eso: `/ayuda` → solo la tarjeta, y el
glosario queda para las preguntas en lenguaje natural.

### 5.5 · N3 — `/triage` entra por el tema 19 directo, no por el Tema 00

El mapa de actividad lo mostró: el orquestador elige el tema por su descripción antes de que el Tema 00
lea el `/`. Funciona, pero se salta los defaults del comando. Mirar si la descripción del 00 ancla bien
«mensaje que empieza con `/`».

### 5.6 · N4 — `T3160` (código de Cummins) no encuentra el camión

Probado en SQL (BLOQUE 176.3): quitar la `T` **solo si le siguen 4+ dígitos** → `T3160` → `CA3160`;
`T1`/`T11`/`HT079` quedan intactos. **Falta ponerlo en los flujos por equipo** (`MD_equipo`,
`MD_equipo_comp`, `MD_metal`), como acción **Redactar** antes de la consulta (ley 3: traducir es del flujo).

### 5.7 · Retoque — el mensaje de `/tendenciametal` muestra `**` literales

Dejarlo en texto plano: *«/tendenciametal se unió a /grafica. Usa /grafica ‹equipo› ‹componente› ‹metal›,
por ejemplo /grafica 3160 mt lh Fe.»*

---

## PASO 6 · Para **Carlos** — no es Copilot, es carga y límites

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
| **N1** | `/tendencia` y `/grafica` en **una sola tabla**: una cabecera de fechas y todas las filas debajo; en `/grafica`, **la fila del metal primero** | SQL. ⚠ `/tendencia` es la vista más cara (35,8 s): medir con `LIKE` antes de darlo por bueno |
| **I** | `/barrido` → **Panel de flota**, absorbe `/conteo` (`/conteo` queda como alias; luego se desactiva el 21) | Vista nueva `vw_PanelFlotaMD`, una sola lectura. Si no convence: se desactiva `/barrido` y `/barridodet` pasa a llamarse `/barrido`. Diseño completo en el archivo de legado, «Bloque I» |
| **F** | Historial **vertical** con todos los parámetros del formato | Se prueba al llegar |
| **G** | Acumulados por componente (MT, ruedas, hidráulico) + renombre `/rankingacum` → `/rankingmod` | Depende de C (cerrado) |

## Rendimiento (skill `komfia-doctor`)

| Vista | Hoy | Siguiente paso |
|---|---|---|
| `vw_TendenciaMD` (`/tendencia`) | **35,8 s** — la de menos margen (2,8× bajo el corte) | Atacar su base `vw_TendenciaElemento`; el filtro abajo la **empeora** (une varias fuentes) |
| `vw_DiagnosticoMD` (`/diagcompleto`) | 6,6 s tras el filtro abajo, pero `LaboratoryData` sigue en **7 scans** (uno por referencia a `base`) | Consolidar a 1 lectura; éxito = `Scan count`, no tiempo |
| `vw_HistorialFlotaMD` | el radar lista `s ×2` | medir antes de tocar |
| `vw_TendenciaMetalMD` | ~30 s con el operador real | — |

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
