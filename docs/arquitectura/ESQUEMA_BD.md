# Esquema de la base de datos — `ESQUEMA_BD.xlsx`

**Fuente canónica de columnas de `bd_kmmp_osconfiabilidad`.** Toda columna se cruza contra este archivo
**antes** de escribir SQL. Es la regla que evita el `Msg 207 Invalid column name`, el error más repetido del
proyecto (caso típico: `Mets_Obs` ≠ `Met_Obs`).

> Antes se llamaba `schemaaceites 1 (1).xlsx` y vivía suelto en la raíz de `docs/`. Se renombró y se movió
> acá el **27/09/2026**: su sitio es `arquitectura/`, junto al DDL y a la validación, que es donde se lo
> consulta.

## Qué contiene

Un volcado de `INFORMATION_SCHEMA.COLUMNS`. Una hoja (`schemaaceites`), **1964 filas**, 7 columnas:

| Columna | Qué es |
|---|---|
| `Esquema` | `dbo`, `Oil`, `Eqpcare`, `Mine`, `report`, `general`, `module`, `Invertex`, `Finance`, `sys` |
| `Tabla` | tabla **o vista** (106 objetos distintos) |
| `Columna` | el nombre exacto — esto es lo que se viene a verificar |
| `Posicion` | orden ordinal dentro del objeto |
| `Tipo de Datos` | `uniqueidentifier`, `varchar`, `decimal`, `datetime`, … |
| `Longitud Maxima` | `NULL` cuando no aplica |
| `Acepta Nulos` | `YES` / `NO` |

Reparto de filas por esquema: `dbo` 1389 · `Eqpcare` 217 · `Oil` 107 · `Finance` 76 · `report` 76 ·
`general` 36 · `Mine` 23 · `module` 21 · `Invertex` 13 · `sys` 6.

## Por qué este archivo y no otro

**Incluye las vistas `vw_*`** (49 de ellas, todas en `dbo`). El `schema_bd.json` que se usaba antes solo
traía tablas, así que no servía para verificar una consulta a una vista — que es el 100 % de lo que consulta
KomfIA. Ese `.json` se retiró el 27/09/2026.

## ⚠ Es una INSTANTÁNEA, no un espejo

El volcado se tomó **alrededor del 23/09/2026**. Si una columna o una vista no aparece, puede ser que no
exista… o que se haya creado después. Al 03/10/2026 faltan **12 vistas nuestras** (cruce de `DDL_vistas.sql`
contra el Excel), creadas entre el 24/09 y el 03/10:

```
vw_AcumuladoVida             vw_FormatoParametro          vw_InvPorComponente
vw_ModeloConLimites          vw_RankingGrafMD             vw_PanelFlotaMD
vw_LimitesMD                 vw_HistorialFilasMD          vw_HistorialEquipoFilasMD
vw_HistorialFlotaFilasMD     vw_HistorialMetalFilasMD     vw_HistorialMetalEquipoFilasMD
```

Para esas doce, la fuente es [`DDL_vistas.sql`](DDL_vistas.sql). **Cuando se vuelva a tomar el volcado,
actualizar esta sección** (o borrarla, si ya no falta nada).

Regenerarlo es una consulta de lectura:

```sql
SELECT TABLE_SCHEMA AS Esquema, TABLE_NAME AS Tabla, COLUMN_NAME AS Columna,
       ORDINAL_POSITION AS Posicion, DATA_TYPE AS [Tipo de Datos],
       CHARACTER_MAXIMUM_LENGTH AS [Longitud Maxima], IS_NULLABLE AS [Acepta Nulos]
FROM INFORMATION_SCHEMA.COLUMNS
ORDER BY TABLE_SCHEMA, TABLE_NAME, ORDINAL_POSITION;
```

## 9 vistas del Excel que NO son nuestras

Están en la misma base y las escribió otra gente. Conviene reconocerlas para no tocarlas ni confundirlas
con las de KomfIA:

| Vista | Nota |
|---|---|
| `vw_RankingAtencion` · `vw_RankingHistorico` | Las del dashboard **Ranking de Atención**. El módulo Acumulados **envuelve** `vw_RankingHistorico` (la última foto), no `vw_RankingAtencion`. Ver [DEPENDENCIA_RankingAtencion.md](DEPENDENCIA_RankingAtencion.md). |
| `vw_MuestrasElementos` | Define la línea base de Na/K/Si **por Grado**; la reusa la herramienta «Cambios de Metal» de INVERTEX. |
| `vw_AlertaTendencia` · `vw_HistoricoAcumulados` · `vw_HistoricoMotores` | Vistas de terceros sobre los mismos datos de aceite. |
| `vw_ComparativoAceites` · `vw_ComparativoAceitesCamion` | Comparativos ajenos al proyecto. |
| `vw_SolpedWithBalance` | Del dominio de `Finance`. |

⛔ Ninguna de las nueve se despliega desde [`DDL_vistas.sql`](DDL_vistas.sql). Si una consulta de KomfIA las
necesita, se documenta la dependencia; no se editan.

## Recordatorios de esquema que cuestan un `Msg 207`

- Las vistas `*_MD` exponen **`compAbbr`** (`MT LH`, `Sist. Hidr.`), **no** `Compartimiento`. Leer el
  `SELECT` final de la vista antes de consultarla.
- `[Mine].[MiningEquipment]` **no** tiene columna `Model`: el modelo está en
  `[Mine].[EquipmentFleet].[Model]`.
- `[dbo].[OilAnalysis]` está **congelada desde 2025-10-20**. La tabla viva es `[Oil].[LaboratoryData]`.
- Columnas con espacios o guiones necesitan corchetes: `[FIERRO - LP]`, `[TBN - LP]`.
