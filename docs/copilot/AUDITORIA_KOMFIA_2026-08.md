# Auditoría de fondo — KomfIA (post-migración a Tópicos) · 2026-08

Sistema actual: **KomfIA Central** (orquesta por intención + imprime {md} + nodo Solicitud de análisis) →
**Flujos** (SELECT determinístico a vistas `*MD`) → Azure SQL. **KomfIA SQL** (agente hijo) casi relegado.
**Conocimientos** vaciados (causaban baches). Diseño de referencia: `KOMFIA.drawio` (5 módulos + variantes),
formatos en `docs/gerencia/formatos 1`. Contrato: toda vista `*MD` expone `MD` + variantes, `Observados`,
`Recomendaciones`; el flujo NUNCA cambia su query, solo cambia la entrada `vista`.

Complementa este archivo: [CONFIG_FLUJOS.md](CONFIG_FLUJOS.md) / [CONFIG_TEMAS.md](CONFIG_TEMAS.md) / [CONFIG_PROMPTS.md](CONFIG_PROMPTS.md) (config canónica) y
[ROADMAP_KOMFIA_SQL_CONOCIMIENTOS.md](ROADMAP_KOMFIA_SQL_CONOCIMIENTOS.md) (nuevos roles + qué agregar).

## 🔴 Hallazgos transversales (prioridad)

### H1 — `columna` expuesta como ENTRADA del modelo → el tema PREGUNTA (recurrente)
Copilot pregunta cualquier Entrada de tema que no puede inferir. `columna` es constante en la mayoría de
temas (=`MD`) pero está como Entrada → el orquestador la interroga ("¿MD o MD_Completo?", "¿MD_Criticos?").
**Regla:** una variante que el modelo NO deduce de la frase se **FIJA en la Acción**, NUNCA se expone.
- **Fijar `columna` en la Acción (quitar de Entradas):** Diagnóstico equipo (`MD`), Último análisis (`MD`),
  Tendencia paso 1 (`MD`), Tendencia detalle (`MD`), Condición MT (`MD`), Barrido resumen (`MD`),
  Triage MT (`MD`), Historial* (`MD`), Tendencia relevantes (`MD_Relevantes`).
- **Excepción — sí puede ir como Entrada** (el modelo la infiere de la frase): **Barrido filtrado**
  ("solo críticos"→`MD_Criticos`, "solo precauciones"→`MD_Precaucion`) — con descripción explícita.
- Igual con **`vista`**: SIEMPRE fija en la Acción, NUNCA Entrada del modelo (ya está bien; verificar que
  ningún tema la tenga como Entrada marcada).

### H2 — Barrido detalle usa flujo LEGACY `Barrido_Detalle` (redundante)
`Barrido_Detalle` (entradas proyecto/modelo, salida `detalle_md`, query hardcodea `DetalleTodosMD`) hace lo
mismo que **`MD_flota`** con `vista=vw_ObservadosBarridoMD`, `columna=DetalleTodosMD`. Inconsistente: Barrido
filtrado ya usa `MD_flota`, Barrido detalle no. **Consolidar:** Barrido detalle → `MD_flota`
(`vista=vw_ObservadosBarridoMD`, `columna=DetalleTodosMD` fija) y **retirar** el flujo `Barrido_Detalle`.
→ 1 flujo de flota para resumen/detalle/filtrado/triage/historial-flota.

### H3 — `MD_metal` solo devuelve `md` (no `observados`/`recomendaciones`)
OK funcionalmente (gráfico/tendencia-metal/historial-metal no los usan), pero rompe el contrato de 3
columnas. **Alinear:** agregar salidas `observados`/`recomendaciones` a `MD_metal` (vienen NULL) → todos los
flujos idénticos en salidas (menos fricción al reusar).

### H4 — `todos`/`(todos)` como sentinela de "sin filtro"
`MD_flota` con `modelo=todos` (Triage, Historial-flota) y `MD_metal`/`MD_equipo_comp` con `compartimiento=todos`
(Tendencia-metal, Historial-metal-equipo) matchean la columna `'(todos)'` de la vista. **Frágil si alguien
cambia el literal.** Documentado y consistente hoy; mantener el literal `todos` fijo en la Acción (no vacío).

### H5 — Dinamismo desparejo (primeros vs últimos módulos)
Los primeros temas (barrido resumen, diagnóstico) exponen `columna` y usan flujo propio; los últimos
(tendencia detalle, gráfico) ya lo fijan. **Uniformar** todo al patrón: vista+columna fijas en Acción,
solo entran las variables que el modelo infiere (equipo/compartimiento/parametro/proyecto/modelo).

## 🟠 KomfIA SQL — relegado y LENTO
Hoy solo atiende conteo/ranking ad-hoc y tarda **30-45s** en consultas simples, cuando los temas resuelven
consultas pesadas en <30s (el hijo re-emite JSON + el central copia = doble LLM). **Urgente darle rol nuevo:**
→ Crear **temas deterministas de Conteo y Ranking** (vistas + `MD_flota`/nuevos) que hoy toman 30-45s por
KomfIA SQL. KomfIA SQL queda como **fallback mínimo** para lo verdaderamente imprevisto (o se elimina si nunca
aporta). Detalle en [ROADMAP_KOMFIA_SQL_CONOCIMIENTOS.md](ROADMAP_KOMFIA_SQL_CONOCIMIENTOS.md).

## 🟠 Conocimientos (Knowledge) — sin uso hoy
Se vaciaron para quitar baches (colisionaban con los temas + generaban placeholders). Con el sistema
determinístico, el core NO los necesita. **Opciones (elige):** (a) **nuevo uso** = glosario/contexto de
dominio SOLO para el nodo de análisis o para afinar el ruteo de apodos (component/metal synonyms), como
fuente de un nodo puntual, NO del central; (b) **eliminar** si no aportan. Recomendación en el ROADMAP.

## 🟡 Diseño (KOMFIA.drawio) vs implementación
| Módulo drawio | Implementado | Nota |
|---|---|---|
| Último análisis (equipo) → componente + general | Último análisis componente ✅; general = Diagnóstico ✅ | "es como" diagnóstico — OK |
| Diagnóstico: general (precau/completos) + componente (precau/completos) | Diagnóstico (MD=observados, MD_Completo) ✅; "diag de componente" = Último análisis componente | Falta variante "diag componente completo" separada (¿o es el último?) — aclarar |
| Tendencia general (equipo) → "debes elegir componente" | Tendencia paso 1 exige equipo+compartimiento ✅ | Si piden "tendencia del \<equipo\>" sin comp → debe pedir componente |
| Tendencia componente → ofrece metales → completa; tendencia de un metal (precau→todos los comp); tendencia metal en componente | Tendencia detalle ✅, Tendencia de un metal ✅, Gráfico ✅ | Cubierto |
| Barrido: observados → críticos → críticos+precau → detalle por equipos (cascada de ofertas) | Barrido resumen/filtrado/detalle ✅ | Las "ofertas" en cascada dependen del central; verificar reconocimiento del eco |
| Historial (con DDI) → 5 variantes | 5 variantes ✅ | Alineado |

## 🟡 Vistas / datos (pendientes de la alfa)
- **V100 (BLOQUE 53 = 239):** `Estado_V100` queda como columna informativa; **NO dispara `Estado_General`**
  (límites de viscosidad solo aterrizados en Antapaccay). Para flag real: cargar límites VISC correctos por
  proyecto/aceite. Ver [[pruebas-alfa-marcha-0807]].
- **Barrido #6b/#7:** mostrar V100/salud en `Mets_Obs` + **Grado + Horas Componente** en el barrido (pedido
  gerencia; Grado/HorasComp ya en la base). #11 críticos-arriba: YA lo hace la vista (`MIN(sev)`).
- **#14 Tendencia incipiente:** módulo nuevo (varió del promedio sin superar límite) — ver ROADMAP.

## Metodología de esta auditoría (5 tipos, sobre TODO el sistema)
1. **Sistemática:** contrato 3 columnas en TODA vista; flujo con query fijo; `vista`/`columna` fijas en Acción.
2. **Prompts:** análisis = 1 Solicitud universal sin conocimiento (evita alucinar); descripciones de tema por
   INTENCIÓN (no keywords).
3. **Tamaño:** instrucciones ≤8000 UTF-16 (se irán vaciando con el handoff limpio de cada módulo migrado).
4. **Gramática/consistencia:** emojis 🟥/🟨/🟢, `—`/`·` para sin-dato, compAbbr uniforme.
5. **Ciclo:** ningún fix contradice a otro; re-verificar tras aplicar.
