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

## Flujo `MD_ranking` (dedicado — Ranking; honra el top N)
Vista FIJA `vw_RankingMD` (formato largo: 1 fila por posición). El flujo ARMA la tabla y filtra `pos <= top`.
**5 entradas** (todas Texto): `proyecto`, `modelo`, `compartimiento`, `parametro`, `top` (opcional; vacío → 10).
Query (pégalo como expresión `fx`; cada nombre en ‹› = ficha de contenido dinámico de esa entrada):
```
concat('SELECT MAX(HeaderMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY pos) AS MD, CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones FROM dbo.vw_RankingMD WHERE Proyecto LIKE ''%', ‹proyecto›, '%'' AND Modelo LIKE ''%', ‹modelo›, '%'' AND CompTipo COLLATE Latin1_General_CI_AI LIKE ''%', ‹compartimiento›, '%'' AND Metal LIKE ''%', ‹parametro›, '%'' AND pos <= ', if(empty(‹top›),'10',‹top›))
```
Salidas: `md` (=`first(...)?['MD']`), `observados` (NULL), `recomendaciones` (NULL).
En el Tema 22: la Acción fija nada de vista/columna (el query ya apunta a vw_RankingMD); la IA llena
`proyecto`, `compartimiento`, `parametro`, `top`; `modelo` = `(todos)` por defecto.
**Descripciones de entradas:** proyecto="Proyecto/mina." · modelo="Modelo; (todos) si no lo nombran." ·
compartimiento="Tipo de componente (tracción/hidráulico/rueda/mando/transmisión/motor)." ·
parametro="Metal (Fe, Cu, Cr, Ni, Pb, Sn, Al, Si, PQ)." · top="Cuántos equipos mostrar; vacío = 10."


## Flujo `MD_metal_flota` (nuevo — Gap-fillers: tendencia-metal-flota y condición-componente)
4 entradas: `proyecto`, `modelo`, `compartimiento` (tipo de componente = CompTipo), `parametro` (metal; `(todos)` para condición-componente). Query FIJO (expresión `fx` `concat`, cada ‹x› = ficha de la entrada):
```
concat('SELECT [', ‹columna›, '] AS MD, Observados, Recomendaciones FROM [', ‹vista›, '] WHERE Proyecto LIKE ''%', ‹proyecto›, '%'' AND Modelo LIKE ''%', ‹modelo›, '%'' AND CompTipo COLLATE Latin1_General_CI_AI LIKE ''%', ‹compartimiento›, '%'' AND Metal LIKE ''%', ‹parametro›, '%''')
```
En la Acción: `columna=MD`; `vista=vw_TendenciaMetalFlotaMD` (tema 23) o `vw_CondicionCompMD` (tema 24); `modelo=(todos)`.
- Tema 23: la IA llena `proyecto`, `compartimiento`, `parametro`.
- Tema 24: la IA llena `proyecto`, `compartimiento`; `parametro=(todos)` fijo.
Salidas: `md`, `observados` (NULL), `recomendaciones` (NULL).
**Descripciones entradas:** proyecto="Proyecto/mina." · modelo="(todos) si no lo nombran." · compartimiento="Tipo de componente (tracción/hidráulico/rueda/mando/transmisión/motor)." · parametro="Metal (Fe, Cu, Cr…); (todos) en condición-componente."