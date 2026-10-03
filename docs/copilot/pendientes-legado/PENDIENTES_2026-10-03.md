> 🗄 **ARCHIVADO el 03/10/2026.** Ronda de la presentación del 02/10 (R1-R16), cerrada y verificada en Teams el
> 03/10. BLOQUES 194-199. **No es el backlog**: el vivo es [../PENDIENTES.md](../PENDIENTES.md).

# ▶ EMPIEZA AQUÍ — ronda 03/10 (lo que se vio en la presentación del 02/10)

> Primera presentación de la alfa a gerencia (02/10). Testigo: **CA3195 MT LH** (PQ 233.2 🟥 en la última muestra).
> Lo cerrado de la ronda 01-02/10 (C5, H6, L6, N3, N4) está en
> [pendientes-legado/PENDIENTES_2026-10-02.md](pendientes-legado/PENDIENTES_2026-10-02.md).

## Qué se vio y por qué

| # | Síntoma (02/10) | Causa | Cura | Estado |
|---|---|---|---|---|
| **R1** ⭐ | `/ultimo 3195 mt`: P, B, V100 sin LP/LC y el ISO en `—`, **aunque Antapaccay sí tiene esos límites** (el error que más se notó) | El 29/09 la fundación pasó a leer los 38 límites, pero `vw_UltimoAnalisisMD` seguía con su lista de 18 (P/B/V100 en `NULL` fijo, sin ISO) | La vista lee los 30 parámetros con su límite y su `Estado_*`; la viscosidad se muestra como banda (`a–b`, `≥ a`, `≤ b`) | ✅ SQL (194.1): P 280/240, V100 70.1–85.7, ISO enteros · falta Teams |
| **R2** | `/tendencia` y `/grafica`: lo mismo (P con LP=240 **escrito a mano**, ISO en `·` aunque el historial sí tiene el dato) | `vw_TendenciaElemento`, la misma lista vieja, y recalculaba el semáforo por su cuenta | Igual que R1 + el semáforo sale de `Estado_*` | ✅ SQL (194.2) · **19,0 s** (antes 32,4) · ✅ Teams 03/10 |
| **R3** | «Cosas que no cuadran» en `/tendencia`: el 16-Sep sale 🟢 y en `/historial` 🟥; Zn 🟥 con la fila Estado en 🟢 | La fila Estado salía de `Estado_General` (no mira ISO); el historial y el triage usan la peor celda con `Inf = 0`. Zn en MT es **informativo** (`Inf = 1`) y la tendencia no lo explicaba | Estado = peor celda con `Inf = 0`, como el historial; + el pie de informativos del triage. (El pie del triage nombraba a `Mo` como informativo en MT: no lo es, corregido) | ✅ SQL (194.2): Estado 🟥🟢🟥🟢🟥🟥 = el historial · falta Teams |
| **R4** | Los códigos de limpieza (ISO) salían con decimal (`20.0`) | Se formateaban como un metal | **Regla: el ISO va siempre entero**, valor y límite. Aplicada en las 7 vistas que lo muestran | ✅ SQL (194.1/194.2) |
| **R5** ⭐ | `/incipiente` no listó al CA3195 (PQ ≈50 → 233) y tardó 8 min | (a) El criterio **descartaba lo que ya pasó el LP**. (b) La vista leía el proyecto **3 veces**. (c) `MD_incipiente` con **reintentos** (8 min 22 s = 4 intentos de 2 min) | Reescrita en **1 lectura**; nueva categoría 🟥/🟨 **cruzó** (pasó el límite viniendo de un historial bajo él; lo crónico sigue siendo del barrido); por **modelo** | ✅ SQL (194.3): **1,9 s** (antes 10,0), CA3195 🟥 cruzó LC · ⏳ Copilot (PASO 1 y 3) |
| **R6** | `/incipiente antapaccay 980` → «Sin datos suficientes» | `980` llegaba como componente; la vista no tenía modelo | Tema 00: `esComp2` + modelo (un modelo siempre lleva dígito) · entrada `modelo` en Tema 20 y `MD_incipiente` | ✍ escrito en CONFIG |
| **R7** | `/historial 3195 MTLH 6 meses` → «No encontré datos» | No era el rango: `MD_historial` compara `LIKE '%MTLH%'` contra `MT LH`. El bug del componente pegado (24/09) nunca llegó a este flujo | Redactar `comp_key` en el flujo + comparar sin espacios ([CONFIG_FLUJOS](CONFIG_FLUJOS.md) § MD_historial) | ✍ escrito en CONFIG |
| **R8** | `/triage 3195 antapaccay` → «No encontré datos» + ayuda improvisada | El triage es de flota; `3195` llegaba como mina | Tema 00: si `p1` es un equipo → mensaje + **Ir a tema 04 Diagnóstico completo** | ✍ escrito en CONFIG |
| **R13** | Teams 03/10, `/incipiente antapaccay hidr`: «CA3191 Si 13.3 🟥 cruzó LC» con la tabla de límites diciendo Si LC 60 | La tabla tomaba el MAX de cada metal **mezclando modelos** (980E y D475A). El 🟥 era correcto | Límites por (modelo, metal); con más de un modelo, columna Modelo en las dos tablas | ✅ **SQL (197.2)**: Si 980E 9/10 vs D475A 30/60; el CA3191 cuadra con su tabla · falta Teams |
| **R14** | Tracción: 5 de 5 en MT LH, ninguno en MT RH | Sospecha: el typo `MOTORO DE TRACCION RH` parte la serie de un motor en dos nombres y ninguno junta 3 muestras | — | ✅ **descartado (195.1)**: MT LH y MT RH con 36 equipos y ≥3 muestras cada uno, ningún `MOTORO` en Antapaccay. Casualidad |
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
4. Tarjeta: `/incipiente ‹proj› [comp] [modelo]` + `/limites` y `/limitesc` (20 filas) — los 3 archivos ya están editados; pegar el JSON en el nodo.
4b. (03/10, tras el 196) `MD_historial`: metal sin comodines (R15) · flujo `MD_limites` + Tema 30 + rama del Tema 00 (R12).
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
| **R10** ✅ SQL (196) | `/historialmetal` (4 vistas): P y B con límite (`LP 280 · LC 240`) y marca de `Estado_*` — **hecho**. La columna Estado con la regla del historial se **revirtió**: llevó el tema 13 de 8,3 s a 211 s. Vuelve cuando estas vistas filtren abajo |
| **R16** ⭐ | `/historialmetal ‹eq› ‹metal› ‹comp›` (tema 14) tardaba **80 s** ya antes de tocarlo (196.0), a 40 s del corte del conector | Filtro abajo en `vw_HistorialMetalFilasMD` (una sola fuente), skill komfia-doctor · **BLOQUE 197**. Si cura, es la receta para los otros dos historiales (34 s). ✅ **197.0: 79,8 s → 9,1 s** (CPU 7,3 → 1,8). **198:** `/historial` 34,4 → 10,2 s y `/historialeq` 34,0 → **0,46 s**, salida idéntica (huella). **199:** tema 13 9,6 → **0,54 s** · `/historialflota` 34,7 → **1,9 s** · misma huella en las cuatro. `/historial` y tema 14 quedan en ~10 s: usan `rn_hist` como columna y esa ventana pasa por la flota → **micro-pendiente**: numerar en la propia vista (como `grn` del tema 13) | **No basta pasar el límite**: estas vistas recalculan el semáforo siempre «por arriba», y con el LP de P (280, invertido) marcarían 🟥 un P sano. Pasarlas a `Estado_*` primero |
| **R11** ✅ SQL (196) | Gráfica ASCII de un ISO: las marcas salen con decimal (`×20.0`) — **hecho**: marcas y LP/LC enteros, «(código)» | Cosmético; `vw_TendenciaGrafico` es un bloque de 12 líneas generadas |
| **R12** 🅿 **ÚNICO pendiente a largo plazo** (decisión 03/10) | **`/limites` y `/limitesc`** — la vista ya está desplegada y medida (196.4: 0,3 s, forma bien); **no se monta en Copilot por ahora**. Hecho en SQL: `vw_LimitesMD`; Copilot = flujo `MD_limites` (copia de `MD_incipiente`) + **Tema 30** + rama del Tema 00 + tarjeta (20 filas) | Ver plan abajo y [CONFIG_TEMAS](CONFIG_TEMAS.md) § 30 |
| **R15** ⭐ | `/historialmetal 3195 P` trae P, **PQ y Pb** mezclados; `B` trae Pb | `MD_historial` filtra `Parametro LIKE '%P%'`. Cura en el flujo: sin comodines ([CONFIG_FLUJOS](CONFIG_FLUJOS.md) § MD_historial, consulta lista) | 196.1 lo demuestra |

