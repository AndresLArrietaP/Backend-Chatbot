# Plan de ejecución — migración de módulos restantes (detallado)

Molde ya probado (barrido + diagnóstico): **vista `*MD` (pre-arma tabla + Recomendaciones
determinísticas + `Observados`) → flujo (`SELECT … AS MD …`) → tópico (Mensaje `{md}` + nodo
análisis SIN conocimiento con entrada `{md}` + Mensaje `{recomendaciones}`)**.

## CONTRATO DE COLUMNAS (clave para que sea dinámico)
**TODA vista `*MD` expone SIEMPRE las mismas 3 columnas:** `MD`, `Observados`, `Recomendaciones`
(+ variantes opcionales como `MD_Completo`). Cuando un módulo no usa observados/recomendaciones
(tendencia P1, historial, gráfico), la vista las devuelve como `CAST(NULL AS nvarchar(max))`.
→ Así el **query del flujo NUNCA cambia**; solo cambias el valor de la entrada `vista` en cada tópico.
El tópico simplemente **no imprime** las salidas que no usa. ⛔ NO editar el query por módulo
(rompería los módulos que ya usan ese flujo).

## Los 4 flujos reutilizables (config una sola vez — query FIJO)
Cada flujo: **Query** `SELECT ⟦columna⟧ AS MD, Observados, Recomendaciones FROM ⟦vista⟧ WHERE …`
· **Salidas** `md`, `observados`, `recomendaciones` (siempre las 3; el tópico usa las que necesite).
Descripciones de salidas (SIEMPRE): `md`="Bloque markdown ya armado; se imprime tal cual." ·
`observados`="Componentes:metales observados; insumo del análisis." · `recomendaciones`="Bloque de
recomendaciones verbatim (solo observados con indicio) + cierre; se imprime tal cual."

| Flujo | Entradas | WHERE | Lo usan |
|---|---|---|---|
| **MD_flota** | vista, proyecto, modelo, columna | `Proyecto LIKE '%⟦proyecto⟧%' AND Modelo LIKE '%⟦modelo⟧%'` | barrido✅, triage, historial-flota, conteo |
| **MD_equipo** ✅ | vista, equipo, columna | `Equipo LIKE '%⟦equipo⟧%'` | diagnóstico✅, condición, historial-equipo |
| **MD_equipo_comp** | vista, equipo, compartimiento, columna | `Equipo LIKE '%⟦equipo⟧%' AND compAbbr LIKE '%⟦compartimiento⟧%'` | último-comp, tendencia P1/detalle, historial-comp |
| **MD_metal** | vista, equipo, compartimiento, parametro, columna | `Equipo LIKE '%⟦equipo⟧%' [AND compAbbr LIKE '%⟦compartimiento⟧%'] AND Parametro='⟦parametro⟧'` | tendencia de un metal, gráfico |

> ⚠ **Filtrar por `compAbbr`, NO por `Compartimiento`.** En BD el valor real es `MOTOR DE TRACCION LH`;
> el orquestador manda la **abreviatura** (`MT LH`, `Sist. Hidr.`, `Motor`, `RD LH/RH`). Cada vista con
> compartimiento **expone la columna `compAbbr`** con esas abreviaturas (disjuntas → "Motor" no cae en MT).

**Descripciones de variables de tema** (rellenables por IA):
`equipo`="Código del equipo (ej. CA3177)." · `compartimiento`="Componente/compartimiento (ej. MT LH,
Sist. Hidr., Motor). Traduce apodos." · `parametro`="Metal/parámetro (ej. Fe, Cu, Na)." ·
`proyecto`="Proyecto/mina (ej. Antapaccay)." · `modelo`="Modelo (ej. 980E)." · `columna`="Variante:
`MD` por defecto; otra columna si piden variante (completo/mensual/etc.)."

---

## MÓDULOS (orden de ejecución)

### 1. Último análisis de 1 componente  ·  vista `vw_UltimoAnalisisMD` (yo)
- **Formato:** info general (Mod/Eqp, Comp, Hor, Hor.Ace, Hor.Comp, CM, Est.Gen, Fec) + tabla vertical
  **`| Par. | LP | LC | <valor> |`** agrupada (Met.Desg/Contam/Adit/Salud). Columnas: `MD`, `Observados`,
  `Recomendaciones` (MT-scoped, con aviso). Firma: **equipo + compartimiento**.
- **Flujo:** `MD_equipo_comp`, vista=`vw_UltimoAnalisisMD`.
- **Tópico "Último análisis de componente":**
  - Descripción: *"Último análisis de aceite de UN componente de un equipo. Se usa con «último análisis
    del MT LH del CA3177», «cómo salió el hidráulico del X», «última muestra del <componente> del <equipo>»
    (SÍ nombra un componente). Rellena `equipo` y `compartimiento` del contexto; `columna`=MD. NO usar
    para el equipo completo (eso es diagnóstico) ni la flota."*
  - Variables: `equipo`, `compartimiento`, `columna`. Nodos: Mensaje `{md}` → análisis (sin conocimiento,
    entrada `{md}`) → Mensaje `{recomendaciones}`.

### 2. Condición MT de 1 equipo  ·  vista `vw_CondicionMT_MD` (yo)
- **Formato:** los componentes MT (LH/RH) del equipo, última muestra, tabla compacta. `MD` + `Observados`
  + `Recomendaciones`. Firma: **equipo**.
- **Flujo:** `MD_equipo`, vista=`vw_CondicionMT_MD`.
- **Tópico "Condición MT":** Descripción *"Estado de los Motores de Tracción (MT) de UN equipo. Se usa
  con «condición del MT del X», «cómo están los motores de tracción del X». Rellena `equipo`. NO usar
  para otro componente ni la flota."* Variables `equipo`, `columna`. Mismos 3 nodos.

### 3. Tendencia PASO 1 (6 muestras)  ·  vista `vw_TendenciaP1MD` (yo)
- **Formato:** info general + **tendencia general** (filas Hor/Hor.Ace/Hor.Comp/CM/Est.Gen × 6 fechas en
  columnas) + oferta ("¿detalle por elemento o gráfica?"). Firma: **equipo + compartimiento**.
- **Flujo:** `MD_equipo_comp`, vista=`vw_TendenciaP1MD`. Solo `md` (sin recomendaciones en P1).
- **Tópico "Tendencia (paso 1)":** Descripción *"Tendencia de las últimas muestras de UN componente
  (sin nombrar metal). «tendencia del MT LH del X», «cómo ha evolucionado el hidráulico del X». Rellena
  equipo, compartimiento. NO usar si nombran un metal (eso es tendencia de un metal)."* Nodos: Mensaje `{md}`.

### 4. Tendencia detalle por elemento  ·  vista `vw_TendenciaMD` (yo) ✅
- **Formato:** params en filas (grupos) × **6 fechas** en columnas + **LP|LC** + **Σvida** (acumulado) +
  Spark. Firma: **equipo + compartimiento**. Variantes: **`MD` = TODOS los parámetros (DEFAULT)** /
  **`MD_Relevantes` = solo fuera de umbral (opt-in)**. ⚠ El default es la COMPLETA (lo que se espera de
  "detalle de todos"); relevantes solo si lo piden explícito. NO existe `MD_Completo`.
- **Flujo:** `MD_equipo_comp` (query fijo). **Tópico "Tendencia detalle":** entradas SOLO
  `equipo` + `compartimiento` (independiente, no necesita P1). En la Acción, `columna` = **texto fijo
  `MD`** (NO variable del modelo) → siempre matriz completa, sin pedir nada al usuario. Molde completo
  (análisis universal + recomendaciones sobre ÚLTIMA muestra). Tabla ancha (11 col) → scroll horizontal.
  `MD_Relevantes` queda en la vista sin usar (si se quiere a futuro, montar formato compacto, NO la
  matriz ancha de 2 filas que se ve mal).
  · **Regla general:** una variante que el modelo no puede inferir de la frase (como `columna`) NO se
  expone como entrada — se fija en la Acción; así el tópico no interroga al usuario.

### 5. Tendencia de un metal (todos los componentes)  ·  vista `vw_TendenciaMetalMD` (yo)
- **Formato:** 1 fila por COMPONENTE × fechas en columnas + Σvida + Spark (horizontal). Firma: **equipo +
  parametro**. **Flujo:** `MD_metal` (sin compartimiento). **Tópico "Tendencia de un metal":** Descripción
  *"Tendencia de UN metal en todos los componentes de un equipo. «tendencia del cobre del X», «cómo ha
  variado el Fe del X». Rellena equipo, parametro. NO arrastres componente del turno previo."*

### 6. Gráfico de tendencia  ·  vista `vw_TendenciaGrafico` (YA existe, columna `Grafico`)
- **Formato:** gráfico ASCII vertical pre-armado (ya lo trae la vista). Firma: **equipo + compartimiento
  + parametro**.
- **⚠ El ancho/ASCII:** va en **bloque de código ` ``` `** (monospace) — a diferencia de las tablas.
  **Opción A (recomendada):** tópico determinístico «Gráfico», Mensaje que imprime **entre ` ``` `** el
  `{grafico}`. **Opción B (tu idea):** dejarlo a **KomfIA SQL** (generativo) — solo si el ``` da problemas
  en el canal. Empezamos por A (el gráfico ya es pre-armado, no lo re-escribe nadie).
- **Flujo:** `MD_metal`, vista=`vw_TendenciaGrafico`, columna=`Grafico` (alias AS MD). **Tópico "Gráfico
  de tendencia":** Mensaje con el bloque ` ``` {md} ``` `.

### 7. Historial (5 variantes)  ·  vistas `vw_HistorialMD` + `vw_HistorialFlotaMD` (yo)
- **Formato:** filas cronológicas (fecha en FILAS, ⛔ no columnas). 5 variantes por firma:
  general (equipo) · un metal (equipo+parametro) · metal en comp (equipo+comp+parametro) · un componente
  (equipo+comp) · flota (proyecto+modelo). Sin recomendaciones (es histórico).
- **Flujos:** `MD_equipo` / `MD_equipo_comp` / `MD_metal` / `MD_flota` según variante.
- **Tópico "Historial":** Descripción cubre las 5 («historial del X», «historial del Fe del X»,
  «historial del MT LH del X», «historial de observados de la flota»). Rellena las variables que apliquen.

### 8. Triage MT  ·  vista `vw_TriageMD` (yo)
- **Formato:** MT-only del proyecto, críticos arriba, "X de N observados". Firma: **proyecto + modelo**.
- **Flujo:** `MD_flota`, vista=`vw_TriageMD`. **Tópico "Triage MT":** Descripción *"Motores de tracción
  observados de una flota. «MT observados de Antapaccay», «triage de motores de tracción». Rellena
  proyecto, modelo."* + recomendaciones (agrupadas por metal, equipos entre paréntesis).

### 9. Ranking / Conteo  →  **se quedan en KomfIA SQL** (generativo)
- Ranking (ORDER BY dinámico por metal + TOP N variable) y conteo son **paramétricos/dinámicos** → no
  encajan en una vista fija. **Los maneja KomfIA SQL** (su nuevo rol, abajo).

---

## Nuevo ROL de KomfIA SQL (ya no relegado)
Con los módulos en tópicos, KomfIA SQL deja de ser el camino principal y pasa a ser el **catch-all
dinámico**:
- **Ranking / conteo / consultas ad-hoc** (lo que no tiene tópico fijo).
- **Fallback** de cualquier módulo aún no migrado.
- Su instrucción **se adelgaza**: quita las plantillas de los módulos ya migrados (barrido ya lo hicimos
  en `_MD`); deja solo las vistas/plantillas de lo dinámico + reglas base.

## Ediciones de instrucciones (yo, por módulo, en copias `_MD`)
Regla de handoff limpio (ya establecida): al migrar cada módulo → **quitar su parte** de `KomfIA_central`
+ `KomfIA_SQL` + `Formatos` + `Esquema` (en las copias `_MD`), y desplegar. Esto **vacía progresivamente**
las instrucciones. El **análisis + recomendaciones** dejan de vivir en el central (van al nodo generativo
del tópico + `vw_Recomendaciones`). Al final, el central queda mínimo (routing) y KomfIA SQL = catch-all.

## Secuencia sugerida
Fase 2: Último-comp → Condición MT. · Fase 3: Tendencia P1 → detalle → un-metal → gráfico. · Fase 4:
Historial. · Fase 5: Triage (KomfIA SQL: ranking/conteo). · Cada módulo: yo armo vista(s) + valido bloque
SSMS → tú clonas flujo/firma + tópico con los strings de arriba → validamos → strip de instrucciones.

## Qué hago YO / qué haces TÚ (resumen)
- **YO:** vistas `*MD` (+ `Observados`/`Recomendaciones` donde aplique, MT-scoped), bloques VALIDACION,
  strip de instrucciones en `_MD`, ajuste del rol de KomfIA SQL.
- **TÚ:** los 4 flujos (una vez) + 1 tópico por módulo (descripción + variables + 3 nodos), con los strings
  exactos de este doc; validar cada bloque en SSMS; re-desplegar instrucciones `_MD` tras cada strip.
