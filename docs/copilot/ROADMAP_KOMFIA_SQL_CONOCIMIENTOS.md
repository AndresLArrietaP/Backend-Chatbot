# Roadmap — nuevos roles (KomfIA SQL, Conocimientos) + qué agregar

Complementa [AUDITORIA_KOMFIA_2026-08.md](AUDITORIA_KOMFIA_2026-08.md) y
[CONFIG_FLUJOS.md](CONFIG_FLUJOS.md) / [CONFIG_TEMAS.md](CONFIG_TEMAS.md) / [CONFIG_PROMPTS.md](CONFIG_PROMPTS.md). Enfoque nuevo, mismo objetivo: todo determinístico,
dinámico, consistente y adaptable; KomfIA SQL y Conocimientos con propósito o fuera.

## 1) KomfIA SQL — nuevo rol (urgente)
**Problema:** tarda 30-45s en consultas SIMPLES (conteo, ranking) que un tema+flujo resolvería en <30s (el
hijo re-emite JSON + el central lo copia = doble LLM).
**Solución — migrar lo simple a temas deterministas** y dejar KomfIA SQL como **fallback mínimo**:
- **Tema "Conteo de flota"** → vista `vw_ConteoFlotaMD` (por proyecto/modelo: nº equipos, nº observados,
  nº críticos, nº por componente). Flujo `MD_flota`, `vista=vw_ConteoFlotaMD`, `columna=MD`. Entradas
  `proyecto`,`modelo`.
- **Tema "Ranking"** → vista `vw_RankingMD` (top N por un metal en un componente/flota). Como el ORDER BY y
  TOP N son dinámicos, la vista pre-computa el ranking por (proyecto, componente, metal) y el flujo filtra;
  N fijo (ej. 5/10) o `columna` = variante Top5/Top10. Flujo nuevo `MD_ranking` (proyecto, componente,
  parametro) o reusar `MD_metal` a nivel flota. Entradas `proyecto`,`compartimiento`,`parametro`.
- **KomfIA SQL restante** = SOLO fallback de preguntas imprevistas sin tema. Su instrucción se **adelgaza**
  (quitar plantillas de módulos ya cubiertos). Si tras cubrir conteo/ranking nunca se dispara útilmente →
  **eliminar** (con el visto bueno; hoy no se limpia, pero queda marcado).
- **Descripciones (temas nuevos):** Conteo="Cuántos equipos/observados/críticos hay en una flota. «cuántos
  equipos observados en Antapaccay», «conteo de la flota». Rellena `proyecto`,`modelo`." · Ranking="Top
  equipos por un metal. «top 5 de hierro en motor de tracción de Antapaccay», «los de más cobre». Rellena
  `proyecto`,`compartimiento`,`parametro`."

## 2) Conocimientos (Knowledge) — propósito o baja
Hoy: vacíos (colisionaban). El core determinístico NO los necesita. **Decisión (elige):**
- **(A) Nuevo uso acotado** = un solo doc **"Glosario y contexto de dominio"** como fuente de UN nodo puntual
  (no del central, no del análisis): apodos/siglas de componentes y metales, tipos de aceite por proyecto,
  notas operativas. Útil solo si aparece una intención que necesite RAG (hoy no hay). ⛔ NUNCA como fuente del
  central ni del nodo de análisis (ahí alucina — lección [[komfia-analisis-nodo-sin-conocimiento]]).
- **(B) Baja** = mantener los .docx en el repo como referencia histórica, pero **sin cargarlos** en el agente.
- **Recomendación:** **(B) por ahora** — el sistema no los usa y cargarlos reintroduce colisiones. Reevaluar
  si surge una feature de "preguntas abiertas de dominio" que sí necesite conocimiento no-tabular.

## 3) Vistas / temas / flujos / prompts NUEVOS a crear
| Nuevo | Tipo | Para |
|---|---|---|
| `vw_ConteoFlotaMD` | vista | Tema Conteo (reemplaza KomfIA SQL en conteo) |
| `vw_RankingMD` (+ `MD_ranking`?) | vista (+flujo) | Tema Ranking (reemplaza KomfIA SQL en ranking) |
| `vw_TendenciaIncipienteMD` | vista | #14: MT que VARIARON del promedio sin superar límite (equipo afectado + params) |
| Barrido: **Grado + Horas Comp** + V100/salud en `Mets_Obs` | edición vistas | #6b/#7 (gerencia) — Grado/HorasComp ya en la base |
| Prompt "Análisis de tendencia incipiente" | ¿o reusar universal? | El universal ya interpreta tendencias; evaluar si basta |
| **Tarjetas adaptables (Adaptive Cards)** | render | Pendiente: control de ancho real (tablas anchas de tendencia detalle); cambio mayor, a futuro |

### #14 Tendencia incipiente (diseño)
Gerencia: "qué MT presentan tendencia incipiente = no superan límite pero variaron de su comportamiento
promedio". Vista `vw_TendenciaIncipienteMD` por proyecto: por equipo+componente MT, comparar última muestra
vs promedio histórico (`vw_TendenciaElemento.Prom`/`Sigma`); marcar los que se desvían > k·σ SIN superar LP.
Debe **mostrar el equipo afectado** y los params implicados (el bug reportado: no mostraba el equipo).
Firma `proyecto` (+modelo), flujo `MD_flota`. Análisis con el prompt universal.

## 4) Orden de archivos (actualizado 2026-09-20)
**`docs/copilot/` = configuración del agente + qué falta:**
- `PENDIENTES.md` — **backlog ÚNICO y vivo**. Si algo está pendiente, está ahí (nadie más lista pendientes).
- `CONFIG_TEMAS.md` / `CONFIG_FLUJOS.md` / `CONFIG_PROMPTS.md` / `CONFIG_COMANDOS.md` / `CONFIG_TIMEOUT.md`
  — config canónica (lo que se aplica en Copilot Studio).
- `AUDITORIA_KOMFIA_2026-08.md` — hallazgos de la auditoría de agosto (histórico).
- `ROADMAP_KOMFIA_SQL_CONOCIMIENTOS.md` — este (histórico de agosto).
- `prompts/` · `knowledge/` · `tarjetas/` — prompt universal, conocimientos (fuera del agente) y Adaptive Cards.

**`docs/pruebas/` = sets de prueba y registros de marcha:**
- `PRUEBAS_ALFA_PRODUCCION.pdf/.docx` (NL, sellado 22-jun) · `PRUEBAS_ALFA_COMANDOS.md` (comandos, 18-sep).
- `MARCHA_ALFA_0918.md` — registro de la 1ª marcha viva con gerencia.
- ⛔ Los backlogs NO van aquí: van a `docs/copilot/PENDIENTES.md`.
- Instrucciones `KomfIA_central.docx`/`KomfIA_SQL.docx` — se conservan; se **vacían** por handoff limpio a
  medida que cada módulo vive en su tema (liberar los 8000 chars). Conocimientos `.docx` — quedan en repo,
  sin cargar (opción B).

## 5) Pendientes priorizados (post-auditoría) — ⚠ HISTÓRICO, SUPERADO
> Esta lista es de **agosto 2026** y se conserva como registro. El backlog vigente es
> **[PENDIENTES.md](PENDIENTES.md)**; lo que de aquí siga abierto (H1, H2, H3, V100, consultas compuestas)
> está recogido allí en «Heredado de la auditoría de agosto».
1. **H1 — quitar `columna` de Entradas** en los temas listados (fijar en Acción). *(alto impacto, bajo esfuerzo)*
2. **H2 — Barrido detalle → MD_flota**, retirar flujo `Barrido_Detalle`. *(consistencia)*
3. **#6b/#7 — Grado + Horas Comp + V100/salud en el barrido** (gerencia). *(vistas)*
4. ~~**KomfIA SQL → Conteo + Ranking deterministas.**~~ ✅ HECHO — `vw_ConteoFlotaMD` (tema 21, flujo MD_flota) y `vw_RankingMD` (tema 22, flujo nuevo MD_ranking). Data-driven (CompTipo, límites por vista, modelo real+(todos)) → escala a otros proyectos/equipos no-camión. KomfIA SQL queda solo como fallback de lo imprevisto.
5. ~~**#14 Tendencia incipiente.**~~ ✅ HECHO — `vw_TendenciaIncipienteMD` (tema 20, flujo `MD_flota`, `vista=vw_TendenciaIncipienteMD`, `columna=MD`, entradas `proyecto`,`modelo='(todos)'`). Regla: última muestra ≥40% sobre su media de las 5 previas SIN superar LP; muestra equipo + params (prom→últ, +%). Análisis con prompt universal.
6. **H3 — MD_metal: agregar salidas observados/recomendaciones** (contrato). *(menor)*
7. **Adaptive Cards** — cuando el ancho sea crítico. *(futuro)*
8. **V100:** cargar límites de viscosidad correctos por proyecto si se quiere flag real (hoy display-only).


## 6) KomfIA SQL — descripción de FALLBACK (fix ruteo 2026-08-10)
Con Conocimientos fuera y generativas apagadas, KomfIA SQL quedó como fallback. Pero su descripción amplia («responder CUALQUIER consulta… triage… barrido… conteos… llama siempre») hacía que el orquestador lo eligiera ANTES que los temas en consultas ambiguas (ej. «barrido… de cada motor de tracción» caía a KomfIA SQL con JSON crudo). **Descripción correcta (angosta, aplicar en el agente conectado):**
> "Agente de RESPALDO (fallback). Genera y ejecuta SQL ad-hoc SOLO para consultas de datos que NINGÚN tema cubre (imprevistas/exploratorias). ⛔ NO usar para barrido/flota, triage MT, diagnóstico/estado de equipo, último análisis, condición MT, tendencia, gráfico, historial, conteo ni ranking — cada uno tiene su TEMA determinista. Úsalo solo cuando la consulta no encaje en ningún tema."
Regla general: cada agente/herramienta compite por descripción; el fallback debe describirse por lo que NO hace.