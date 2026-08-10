# Config canónica — FLUJOS (Power Automate)

Parte de la config a aplicar en Copilot Studio. Ver también [CONFIG_TEMAS.md](CONFIG_TEMAS.md),
[CONFIG_PROMPTS.md](CONFIG_PROMPTS.md), auditoría [AUDITORIA_KOMFIA_2026-08.md](AUDITORIA_KOMFIA_2026-08.md).

**Reglas:** query FIJO por flujo (nunca cambia); solo cambia el valor de la entrada `vista` desde cada tema.
Toda vista `*MD` expone `MD`(+variantes)/`Observados`/`Recomendaciones`. Cada salida usa
`if(empty(outputs('Ejecutar_una_consulta_SQL_(V2)')?['body/resultsets/Table1']), '', first(outputs('Ejecutar_una_consulta_SQL_(V2)')?['body/resultsets/Table1'])?['Col'])`
(evita el BadGateway con 0 filas → devuelve `''` → el tema muestra el mensaje sin-data).

## 4 flujos reutilizables (retirar el legacy `Barrido_Detalle`, H2)

| Flujo | Entradas | Query fijo (query_sql) |
|---|---|---|
| **MD_equipo** | `vista`,`equipo`,`columna` | `SELECT ⟦columna⟧ AS MD, Observados, Recomendaciones FROM ⟦vista⟧ WHERE Equipo LIKE '%⟦equipo⟧%'` |
| **MD_equipo_comp** | `vista`,`equipo`,`compartimiento`,`columna` | `SELECT ⟦columna⟧ AS MD, Observados, Recomendaciones FROM ⟦vista⟧ WHERE Equipo LIKE '%⟦equipo⟧%' AND compAbbr LIKE '%⟦compartimiento⟧%'` |
| **MD_metal** | `vista`,`equipo`,`compartimiento`,`parametro`,`columna` | `SELECT ⟦columna⟧ AS MD, Observados, Recomendaciones FROM ⟦vista⟧ WHERE Equipo LIKE '%⟦equipo⟧%' AND compAbbr LIKE '%⟦compartimiento⟧%' AND Parametro='⟦parametro⟧'` |
| **MD_flota** | `vista`,`proyecto`,`modelo`,`columna` | `SELECT ⟦columna⟧ AS MD, Observados, Recomendaciones FROM ⟦vista⟧ WHERE Proyecto LIKE '%⟦proyecto⟧%' AND Modelo LIKE '%⟦modelo⟧%'` |

## Descripción de ENTRADAS (una línea, lista para pegar)
- `vista` — "Vista *MD a consultar (la fija cada tema; ej. vw_DiagnosticoMD)."
- `equipo` — "Código de equipo (ej. CA3177)."
- `compartimiento` — "Componente abreviado: MT LH / MT RH / RD LH / RD RH / Sist. Hidr. / Motor. Traduce apodos. `todos` = todos los componentes."
- `parametro` — "Símbolo del metal/parámetro: Fe, Cu, Cr, Pb, Sn, Si, Zn, PQ… Traduce cobre→Cu, hierro→Fe."
- `proyecto` — "Proyecto/mina (ej. Antapaccay)."
- `modelo` — "Modelo de equipo (ej. 980E); `todos` = todos los modelos."
- `columna` — "Variante/columna de la vista (la fija cada tema; ej. MD, MD_Completo, MD_Relevantes, DetalleTodosMD, MD_Criticos, MD_Precaucion)."

## Descripción de SALIDAS (una línea, lista para pegar)
- `md` — "Bloque markdown ya armado; se imprime tal cual."
- `observados` — "Componente:metales observados; insumo del análisis (NULL si no aplica)."
- `recomendaciones` — "Bloque verbatim de recomendaciones + cierre; se imprime tal cual (NULL si no aplica)."

> **H3:** `MD_metal` hoy solo mapea la salida `md`. Para uniformar el contrato, agregar también las salidas
> `observados` y `recomendaciones` (vienen NULL en sus vistas). Menor, pero deja los 4 flujos idénticos.

## Flujos NUEVOS a crear (ver [ROADMAP_KOMFIA_SQL_CONOCIMIENTOS.md](ROADMAP_KOMFIA_SQL_CONOCIMIENTOS.md))
- **(opcional) `MD_ranking`** — si el ranking necesita una firma propia (proyecto, compartimiento, parametro);
  si no, se resuelve con `MD_flota` + una vista `vw_RankingMD`. Conteo se resuelve con `MD_flota`.


## Flujo `MD_ranking` (nuevo — Ranking)
4 entradas: `proyecto`, `modelo`, `compartimiento` (tipo de componente), `parametro` (metal). Query FIJO:
```
SELECT [columna] AS MD, Observados, Recomendaciones
FROM [vista]
WHERE Proyecto LIKE '%'+proyecto+'%' AND Modelo LIKE '%'+modelo+'%'
  AND CompTipo LIKE '%'+compartimiento+'%' AND Metal LIKE '%'+parametro+'%'
```
En la Acción: `vista=vw_RankingMD`, `columna=MD`. El modelo la infiere de la frase (o `(todos)`); `compartimiento` = tipo (tracción/hidráulico/rueda/mando/transmisión/motor); `parametro` = metal (Fe, Cu, Cr…).
Salidas: `md` (tabla top-10), `observados` (NULL), `recomendaciones` (NULL).
**Descripciones:** proyecto="Proyecto/mina." · modelo="Modelo del equipo; (todos) si no lo nombran." · compartimiento="Tipo de componente a rankear (tracción, hidráulico, rueda, mando, transmisión, motor)." · parametro="Metal a rankear (Fe, Cu, Cr, Ni, Pb, Sn, Al, Si, PQ)."