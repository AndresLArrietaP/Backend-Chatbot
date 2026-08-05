# Migración de KomfIA a Tópicos determinísticos — Plan de mudanza

**Meta:** que cada módulo (y sus variantes) de KomfIA **viva en un Tópico/Tema** con render
**determinístico** (0 emisiones LLM del bloque) → de ~2 min a segundos, sin cortar data, sin inflar
instrucciones. Probado ya con el barrido-detalle (12s vs 2 min del generativo).

**Principio:** *módulos en su casa.* El LLM solo **enruta** (por intención) y **rellena params**
(proyecto/equipo/…) del contexto; los **datos + formato** salen de una **vista `*MD`** vía **flujo**,
y los pinta un **nodo Mensaje** (determinístico). El análisis/recomendaciones (cuando toca) queda como
un pequeño add-on generativo.

---

## Arquitectura de 3 capas

```
Usuario → [Tópico]  (orquestador enruta por intención + rellena params)
              │ pasa params limpios (proyecto, equipo, comp, metal…)
              ▼
          [Flujo reutilizable]  → arma SELECT → vista *MD → devuelve la columna MD (string)
              │
              ▼
          [Nodo Mensaje] imprime {MD} tal cual → tabla renderizada al instante
```

### Convenciones (para que TODO sea reutilizable)
1. **Cada vista `*MD` expone su bloque en una columna llamada `MD`** (nombre estándar) → un solo
   patrón de extracción en el flujo.
2. **Columnas de filtro con nombres estándar** en todas las `*MD`: `Equipo`, `Compartimiento`,
   `Proyecto`, `Modelo`, `Parametro` → el flujo arma el WHERE genérico.
3. **Coexistencia:** las vistas actuales **se quedan** (son la fuente de datos; la ruta generativa
   sigue viva hasta migrar). Las `*MD` son **calcadas en lógica + formato**, al lado. ≈ el doble de vistas.
4. **Emojis en las `*MD`:** al crearlas, **abrir/ejecutar el .sql desde archivo** (UTF-8), no re-tipear.

---

## Capa 1 — Vistas `*MD` (yo las armo, gated a tu validación SSMS)

| # | Módulo / variante | Vista actual (datos) | Vista nueva `*MD` | Filtros (params) | Notas de formato / límite |
|---|---|---|---|---|---|
| 1 | Barrido — detalle de todos | vw_ObservadosDetalle | **vw_ObservadosBarridoMD** ✅ *hecha* | Proyecto, Modelo, [filtro] | secciones por comp + cuadro límites |
| 2 | Barrido — resumen (PASO 1) | vw_ObservadosResumen | vw_ObservadosResumenMD ⏳ *próxima* | Proyecto, Modelo | tabla 1 fila/equipo (Crít/Prec, Comp.Obs, Met.Obs) + límites |
| 3 | Barrido — filtrados | vw_ObservadosDetalle | (columnas extra en BarridoMD: `MD_Criticos`, `MD_Precaucion`) | Proyecto, Modelo | mismo patrón, subconjunto |
| 4 | Diagnóstico / estado completo 1 equipo | vw_DiagnosticoEquipo | vw_DiagnosticoMD | Equipo, [todos] | tabla ancha, todos comps; default observados |
| 5 | Último análisis de 1 componente | vw_UltimoAnalisisAceite | vw_UltimoAnalisisMD | Equipo, Compartimiento | tabla vertical Par\|LP\|LC\|valor |
| 6 | Condición MT de 1 equipo | vw_EstadoActualMT | vw_CondicionMT_MD | Equipo, [lado] | MT-only |
| 7 | Tendencia PASO 1 (6 muestras) | vw_MuestrasRankeadas | vw_TendenciaP1MD | Equipo, Compartimiento | info general + tendencia; ofrece detalle/gráfico |
| 8 | Tendencia detalle por elemento | vw_TendenciaElemento | vw_TendenciaMD | Equipo, Compartimiento | Spark, Σvida |
| 9 | Tendencia de un metal (todos comps) | vw_TendenciaElemento | vw_TendenciaMetalMD | Equipo, Parametro | 1 fila/comp horizontal |
| 10 | Gráfico de tendencia | vw_TendenciaGrafico | *(ya pre-armado)* → vw_GraficoMD (envoltura) | Equipo, Compartimiento, Parametro | ⚠ ESTE **sí** va en bloque ``` (es ASCII) |
| 11 | Historial equipo/comp/metal | vw_HistorialMuestra | vw_HistorialMD | Equipo, [Compartimiento], [Parametro] | filas cronológicas |
| 12 | Historial flota observados | vw_HistorialFlotaObs | vw_HistorialFlotaMD | Proyecto, Modelo | por fecha |
| 13 | Triage MT | vw_EstadoActualMT | vw_TriageMD | Proyecto, Modelo | MT-only, críticos arriba |
| 14 | Ranking / Conteo | vw_EstadoActualMT / Mine | *(fase final; ver notas)* | Proyecto, Modelo, Parametro, TopN | ⚠ ORDER BY dinámico por metal + TOP N — puede quedar generativo |

> **≈ 12-13 vistas `*MD`** sobre las ~14 actuales → “el doble”, coexistiendo. Todas leen las vistas/base
> ya existentes (nada de datos cambia; solo se agrega la capa de formato).

**Límites conocidos (por qué algunas cosas no son 100% determinísticas):**
- Una vista **no toma parámetros** → el **flujo** filtra por WHERE. El bloque `MD` se **pre-agrega** en su
  clave natural (equipo, equipo+comp, proyecto…).
- **Columnas dinámicas por-metal** no son posibles en vista estática → se usa **columna “Observado” uniforme**
  (como en el barrido). Formato: `metal=valor 🟥/🟨`.
- **🔧 Recomendaciones** (indicios VERBATIM de «Recomendaciones MT») **no salen de SQL** → se quedan como
  **add-on generativo corto** al final del tópico (o segundo nodo). Es la única parte que sigue tocando el LLM,
  y es chica (rápida).
- **Ranking/Conteo** (ORDER BY dinámico por metal, TOP N variable) → fase final; puede quedar generativo.

---

## Capa 2 — Los flujos (pocos, reutilizables)

**Recomendación: 4 flujos por “firma” de parámetros** (tú pasas params limpios; el flujo arma el SQL y
extrae la columna `MD`). Reutilizables entre varios módulos con la misma firma:

| Flujo | Entradas | Lo usan |
|---|---|---|
| `MD_flota` | `vista`, `proyecto`, `modelo`, `filtro?` | barrido resumen, detalle, filtrados, triage, historial-flota, conteo |
| `MD_equipo` | `vista`, `equipo` | diagnóstico, condición MT, historial-equipo |
| `MD_equipo_comp` | `vista`, `equipo`, `compartimiento` | último-comp, tendencia P1, tendencia detalle, historial-comp |
| `MD_metal` | `vista`, `equipo`, `compartimiento?`, `parametro` | tendencia de un metal, gráfico |

Cada flujo hace: `SELECT [TOP @topn] MD FROM @vista WHERE 1=1 [AND Equipo='@equipo'] [AND Compartimiento LIKE '%@comp%'] …`
(solo agrega la cláusula del param que llega) → devuelve `md = first(resultsets.Table1)?['MD']`.

> **Alternativa aún más simple: 1 solo flujo** `KomfIA_MD(query_sql) → md` (como `Barrido_Detalle` pero
> recibiendo el SELECT completo). El tópico compone `SELECT MD FROM vw_X WHERE…`. Menos flujos (1), pero el
> SQL se arma en el tópico (fórmula Power Fx). **Elige tú:** 4 flujos = tópicos simples; 1 flujo = tópicos
> con una fórmula. Recomiendo los **4 por firma** (más fácil de mantener para ti).

`TEST-SQL-V2` actual **se queda** (la ruta generativa lo usa hasta terminar la mudanza).

---

## Capa 3 — Los tópicos (uno por módulo/variante)

Patrón idéntico al barrido-detalle que ya montaste:
1. **Desencadenador “El agente elige”** + **descripción** clara (enruta por intención; cubre variantes).
   Indica en la descripción los **params que toma del contexto** y cuándo NO usarlo (evita solapes).
2. **Params rellenables por IA** (proyecto/equipo/comp/metal) → el orquestador los saca del contexto.
3. **Nodo Acción** → el flujo de su firma, pasando `vista` + params.
4. **Nodo Mensaje** → `{md}` tal cual (⛔ nunca en ``` — salvo el **gráfico**, que sí va en ```).
5. **(Opcional) Recomendaciones** → un cierre generativo corto si el módulo lo pide (último análisis, tendencia).

---

## Orden de migración (fases — empezar por el cuello)

- **Fase 0 ✅** Barrido-detalle (hecho y probado).
- **Fase 1 — Barrido completo:** `vw_ObservadosResumenMD` (PASO 1, el cuello de ~2 min actual) + variantes
  filtradas. Flujo `MD_flota`. Tópicos: “Barrido resumen”, “Barrido filtrado”. → **el barrido entero en segundos.**
- **Fase 2 — 1 equipo:** Diagnóstico + Último análisis + Condición MT. Flujos `MD_equipo`, `MD_equipo_comp`.
- **Fase 3 — Tendencias:** PASO 1 + detalle + un-metal + gráfico. Flujos `MD_equipo_comp`, `MD_metal`.
- **Fase 4 — Historial:** equipo/comp/metal + flota. Flujos `MD_equipo`, `MD_flota`.
- **Fase 5 — Triage / Ranking / Conteo** (lo más dinámico; evaluar cuáles quedan generativos).
- **Fase 6 — Limpieza:** a medida que cada módulo queda en tópico, **quitar su cableo de las instrucciones**
  → el prompt de central/SQL se **vacía progresivamente** (más margen, más simple).

---

## Quién hace qué

**Yo (repo, gated a tu SSMS):**
- Armo cada vista `*MD` (calcada + formato), con su BLOQUE de validación en `VALIDACION_SSMS.sql`.
- Doy el SELECT exacto que va en cada flujo/tópico.
- Ajusto/limpio las instrucciones cuando cada módulo ya esté migrado.

**Tú (Copilot Studio + Power Automate):**
- Corres cada vista en SSMS (abrir .sql desde archivo por los emojis) y confirmas.
- Creas los **4 flujos** (una vez) y **un tópico por módulo** (patrón repetido).
- Marcas los params como **rellenables por IA**.

---

## No romper lo funcional
- Viejas vistas + `TEST-SQL-V2` + ruta generativa **siguen vivas** durante toda la mudanza.
- Cada tópico nuevo convive; si uno falla, se **desactiva su descripción** → vuelve al generativo. Cero pérdida.
- Migramos **de a un módulo**, validando cada uno antes del siguiente.

---

## Checklist inmediato (Fase 1)
- [ ] **Yo:** armo `vw_ObservadosResumenMD` (PASO 1) + BLOQUE de validación.
- [ ] **Tú:** la corres en SSMS y confirmas el bloque.
- [ ] **Tú:** creas el flujo `MD_flota` (o generalizas `Barrido_Detalle`).
- [ ] **Tú:** creas el tópico “Barrido resumen” (mismo patrón).
- [ ] **Tú:** haces **dinámico** el detalle ya montado (params rellenables por IA).
- [ ] Probar el barrido entero (resumen + detalle) → segundos.
