# Plan de evolución KomfIA — Pivote a multiagente (sub-agente genera SQL)

> ESTADO (2026-06-06): ✅ VARIANTE B IMPLEMENTADA Y VALIDADA EN PRODUCCIÓN para Motor de Tracción.
> Sub-agente "KomfIA SQL" (Claude Sonnet 4.6) genera el SQL → flujo TEST SQL V2 ejecuta directo en
> Azure → KomfIA Central presenta + recomendaciones (Knowledge). Validación cruzada contra BD (SSMS):
> Antapaccay triage=7 (exacto), universo=54; Cerro Verde=108 tras corregir el TOP del triage
> (TOP 100 truncaba → ahora TOP 500). Instrucciones <8000 con datos movidos a Conocimientos.
> Artefactos vivos en docs/copilot/ (KomfIA_central_slim.md, KomfIA_SQL_slim.md, knowledge/*.docx).
> Pendiente: escalar a otros componentes (textos de recomendación del área) y corregir Pb LP/LC de
> Cerro Verde en [Eqpcare].[lc]. El backend Python queda RETIRABLE (no participa en Ruta A).

> Documento de decisión arquitectónica. Fecha: 2026-06-05.
> Contexto: tras múltiples iteraciones de parches sobre la capa de heurísticas regex,
> los fallos persisten (ver auditoría). La causa raíz no es código mal escrito, sino
> una arquitectura que depende de (a) ~25 regex frágiles y (b) Gemini Flash haciendo
> dos trabajos para los que es débil: generar SQL e interpretar/renderizar.

---

## 1. Diagnóstico (por qué los parches no convergen)

Los tres bugs reportados el 05/06 son **el mismo bug** con tres caras:

| Síntoma | Causa raíz |
|---|---|
| "tendencia del MT RH" → 24 meses de promedios | "MT RH" no matcheaba el regex → fallback al LLM con hint de AVG mensual (contradictorio con el path directo) |
| Cr=3.95 (>LC=3) no alertado | Copilot-Flash interpretó "Alerta MT: Fe y PQ primero" como "solo mira Fe"; además leyó el campo Condicion en vez de comparar LP/LC |
| Recomendaciones no salen | El backend SÍ las genera en `analisis.recomendaciones_mt`; Copilot-Flash las descarta pese a la instrucción |

**Patrón común:** cada frase nueva ("MT RH" vs "motor de tracción", con/sin tildes) es un
regex nuevo = cola infinita de bugs. Y aunque el path acierte, el Flash de Copilot arruina
la interpretación. Se está peleando contra el modelo, no contra el código.

---

## 2. Qué CONSERVAR (funciona y es valioso)

Estas piezas son determinísticas, rápidas y correctas. **No se tocan en el pivote:**

- `src/database.py` — validación de seguridad SQL (solo SELECT/CTE, allowlist, MAX_ROWS), ejecución, timeout anyio.
- `src/analitica.py` — métricas, `limites_referencia`, `_recomendaciones_mt` (fuente única determinística de recomendaciones).
- Conocimiento de dominio: patrón **CROSS JOIN LimitesLC** con `ISNULL(LP, fallback)`, exclusión DDI, fallback Fe LP por proyecto.
- Warmup de cold-start, gestión de contexto conversacional con TTL.

## 3. Qué RETIRAR (la fuente de fragilidad)

- La capa de heurísticas regex de `src/llm.py` (~25 `_RE_PISTA_*`, ~18 `_es_intencion_*`).
- Los generadores de SQL en Python (`intentar_*_directo`) — útiles como *fallback rápido* opcional, pero ya no como el camino principal.
- La dependencia de Gemini Flash para generar SQL e interpretar.

---

## 4. Arquitectura objetivo

Dos variantes. Recomendación: **B** si solo hay acceso a Opus dentro de Copilot Studio;
**A** si se consigue API key de un modelo fuerte para el backend.

### Variante A — Backend con modelo fuerte (un solo endpoint)
```
Usuario (Teams/Copilot)
  → /human_query (backend FastAPI)
      → Opus/Sonnet vía API genera SQL (reemplaza Gemini Flash + heurísticas)
      → database.py valida y ejecuta
      → analitica.py enriquece (límites + recomendaciones determinísticas)
      → respuesta JSON
```
- **Pro:** toda la lógica server-side, un solo lugar, recomendaciones determinísticas garantizadas.
- **Contra:** requiere API key de Opus/Sonnet para el backend (hoy solo hay Gemini).

### Variante B — Multiagente en Copilot Studio (tu idea)
```
Agente KomfIA (orquestador, instrucción de dominio + formato)
  → Sub-agente "SQL-Gen" (Opus) genera el SQL desde la pregunta + esquema
  → Herramienta TEST-SQL-V2 (backend /sql) valida y ejecuta
  → analitica.py enriquece → KomfIA formatea la respuesta
```
- **Pro:** usa el Opus que YA tienes en Copilot Studio; el backend queda como ejecutor seguro (lo que mejor funciona hoy: TEST SQL V2 ya lo demostró).
- **Contra:** lógica repartida entre config de Copilot y backend; vigilar timeout 240s (Opus SQL-gen ~6-8s + ejecución ~10s = holgado).

---

## 5. El esquema y reglas de dominio que el agente SQL-Gen necesita (system prompt)

Ya está casi todo escrito en la **Instrucción 2 (TEST SQL V2)** del `.docx`. Ese prompt
es el núcleo reutilizable. Puntos críticos que DEBE incluir:

- Esquema: `[Oil].[LaboratoryData]`, `[Mine].[MiningEquipment/MiningProject/EquipmentFleet]`, `[Eqpcare].[lc]`.
- **Columnas inexistentes prohibidas:** `EquipmentCode`, `EquipmentId` (usar `ME.[Code]`, `ME.[Id]`).
- Compartimiento por LIKE keyword corto: `%TRACCION%`, `%HIDRAUL%`, `%RUEDA%` (nunca frase con "DE").
- Último análisis: `ROW_NUMBER() PARTITION BY MiningEquipmentId,Compartimiento ORDER BY FechaMuestreo DESC → rn=1`.
- Triage/estado: comparar metales vs `[Eqpcare].[lc]` con `ISNULL(LP, fallback)`; **CROSS JOIN** (no LEFT JOIN exact-match).
- TBN invertido: bajo TBN = malo (`< LP`).
- Excluir DDI/DIALIZADO en triage/tendencia/ranking; incluir en historial.
- Tendencia default = últimas 8 muestras individuales; mensual solo si lo piden.

## 6. Interpretación y recomendaciones (independiente del modelo)

Mantener `analitica.py` como **fuente única determinística**:
- Estado por metal = comparación matemática vs LP/LC (NUNCA el campo Condicion).
- Recomendaciones técnicas: tabla fija por metal (las de las imágenes), agrupando metales con
  cuerpo idéntico (Fe+PQ, Pb+Sn). Ya implementado en `_recomendaciones_mt`.
- **Pendiente:** textos de recomendación para componentes no-MT (Hidráulico, Rueda, Motor)
  — hoy solo existe el cuerpo de Motor de Tracción. Requiere que el área entregue esos textos.

## 7. Pasos concretos

> **DECISIÓN (2026-06-05): Variante B.** El usuario NO tiene API key de Opus/Sonnet para el
> backend, solo acceso a esos modelos dentro de Copilot Studio. Por tanto el camino es el
> sub-agente Opus en Copilot que genera SQL y lo pasa al backend `/sql` (como TEST SQL V2).
> Alcance inicial: SOLO Motor de Tracción (MT). Escalará a otros componentes en versiones futuras.

1. [x] Decidir Variante A vs B → **B**.
2. [ ] Extraer el system prompt de SQL-Gen desde la Instrucción 2 del `.docx` (ya tiene esquema, CROSS JOIN, lado LH/RH, columnas prohibidas).
3. [ ] (B) Crear sub-agente Opus en Copilot Studio + conectar a `/sql`. (A) Añadir cliente Opus al `provider factory`.
4. [ ] Smoke test con el set de 18 consultas de `pruebas_definitivas` + las que fallaron el 05/06.
5. [ ] Mantener los `intentar_*_directo` como fast-path opcional (consultas idénticas y frecuentes) — degradación elegante.
6. [ ] Recolectar textos de recomendación de Hidráulico/Rueda/Motor del área de confiabilidad.
7. [ ] Cuando el pivote esté validado, retirar la capa de heurísticas regex de `llm.py`.

---

## 8. Parches aplicados (2026-06-05, antes del pivote) — VALIDADOS en producción

Sobre el código actual, para que producción deje de fallar de inmediato:
- **Tendencia unificada:** default = 8 muestras individuales (antes forzaba AVG mensual de 24 meses contradiciendo el path directo). ✅ validado.
- **Abreviaturas de compartimiento:** "MT RH", "MT LH", "EMT", "MTLH" → `%TRACCION%`. ✅
- **Insensibilidad a tildes:** `_buscar()` + `_regex_sin_tildes()` matchean patrón y texto sin tildes en ambas direcciones → "ultimo analisis", "traccion", "condicion", "cuantos" funcionan igual que con tilde. ✅
- **Path nuevo `intentar_ultimo_analisis_con_limites_directo`:** "condición del MT del 3171" / "último análisis + cuál está fuera de límites" en UNA consulta con columna Estado (NORMAL/PRECAUCIÓN/CRÍTICO) y LP/LC reales. Disparadores: equipo+condicion_eval, o ultimo+triage. ✅ validado (CA3171 LH Cr CRÍTICO correcto).
- **Conteo de flota `intentar_conteo_flota_directo`:** "cuántos 980 tiene Antapaccay" sin inventar columnas. ✅
- **Extracción LP/LC sin umbral (analitica.py):** las columnas LP/LC se extraen por nombre, no gated por el umbral ≥3 de `_buscar_columnas_numericas`. Antes, consultas de 1-2 filas vaciaban `limites_referencia` → sin recomendaciones → Copilot inventaba. ✅
- **Filtro de lado LH/RH en las 6 rutas directas:** `_detectar_lado` + `_where_lado`, aplicado SOLO a las muestras (LaboratoryData), NUNCA a LimitesLC (LP/LC iguales por lado). Antes "MT izquierdo" traía LH+RH y el RH contaminaba las recomendaciones del LH con max(). ✅
- **Orden de despacho:** conteo → condición+límites → historial → flota → tendencia → triage → ranking.

Instrucción Copilot (aplicada por el usuario 2026-06-05): evaluación de TODOS los metales vs LP/LC,
prohibido usar Condicion, recomendaciones_mt verbatim, columna Estado del backend, FALLBACK con CROSS JOIN.

## 8b. Cómo ejecuta el SQL el sub-agente — DOS sub-rutas

CORRECCIÓN IMPORTANTE (2026-06-06): el flujo **TEST SQL V2 se conecta DIRECTO a Azure SQL**
(conector SQL Server de Power Automate), NO pasa por el backend Python `/sql`. Por tanto, en ese
camino `analitica.py` (recomendaciones, limites_referencia) NO participa. Lo que SÍ llega es lo que
va dentro del SELECT: columnas LP/LC y la columna **Estado** (CASE WHEN), porque se computan en el
propio SQL que genera el sub-agente.

Sub-agente configurado: **"KomfIA SQL"** (Claude Sonnet 4.6), system prompt = Instrucción 2,
herramienta = flujo TEST SQL V2.

### Ruta A — Puro Copilot + Azure (RECOMENDADA)
- El sub-agente genera el SQL (con Estado + LP/LC dentro del SELECT) → TEST SQL V2 ejecuta directo
  en Azure → filas crudas → el agente principal KomfIA formatea.
- Las **recomendaciones técnicas** van en la instrucción del agente principal (ver
  `docs/copilot/KomfIA_recomendaciones_MT.md`); Sonnet 4.6 las renderiza verbatim cuando un metal > LP.
- **Infra cero**: sin Render, sin Python. El backend Python queda RETIRABLE por completo.
- Seguridad: la cuenta de BD es **solo-lectura** (sin DDL/DML) → la ejecución directa es segura.

### Ruta B — Con backend Python (si se quiere determinismo en recomendaciones)
- Reemplazar/añadir en el flujo una acción HTTP que llame a `POST /sql` del backend Render en vez
  del conector directo. El backend valida, ejecuta y enriquece (analitica → recomendaciones_mt).
- Pro: recomendaciones 100% determinísticas. Con: depende de Render arriba + un hop extra.

**Decisión sugerida: Ruta A.** BD solo-lectura cubre la seguridad; Sonnet 4.6 rinde verbatim;
elimina toda la infra del backend. El conocimiento de dominio (CROSS JOIN, lado LH/RH, columnas
prohibidas, Estado) ya está en la Instrucción 2; las recomendaciones en la instrucción del principal.

Tareas de arranque (Ruta A):
1. Sub-agente KomfIA SQL: instrucción = Instrucción 2 ✅; herramienta = TEST SQL V2 ✅; búsqueda web OFF.
2. Agente principal KomfIA: agregar KomfIA SQL como agente conectado + pegar el bloque de
   recomendaciones (`KomfIA_recomendaciones_MT.md`) y las reglas de formato/Estado.
3. Validar con las consultas del set de pruebas. Si todo OK, el backend Python/Render se puede apagar.

## 9. Lección transversal (refuerza la decisión de pivote)

Cada bug de esta ronda fue una variante de phrasing o un acoplamiento frágil:
- "MT RH" vs "motor de tracción" (abreviatura) — regex nuevo.
- "ultimo" vs "último" (tilde) — helper nuevo.
- "condición" no era trigger de LP/LC — routing nuevo.
- LP/LC vaciados por umbral estadístico — acoplamiento oculto entre analitica y nº de filas.
- LH/RH no filtrado — 6 ediciones en 6 rutas.

**Patrón:** N rutas × M variantes de lenguaje × K detalles de dominio = superficie de bugs que
crece multiplicativamente. Un modelo fuerte (Opus) con UN system prompt de dominio colapsa esa
matriz a una sola superficie razonada. Por eso el pivote (Variante B) no es opcional a mediano
plazo: es el único camino que no escala en bugs. Los parches de esta ronda compran tiempo y dejan
el backend (seguridad + analitica + recomendaciones) listo como ejecutor del modelo fuerte.
