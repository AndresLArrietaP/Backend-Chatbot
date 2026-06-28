/* ============================================================================
   KomfIA — VALIDACIÓN EN SSMS  (bd_kmmp_osconfiabilidad, Azure SQL)
   Corre cada BLOQUE por separado (selecciona y F5). Son SOLO lecturas.
   Objetivo: probar las 13 vistas, el barrido/diagnóstico/tendencia/historial, y — sobre todo — diagnosticar la
   COBERTURA de [Eqpcare].[lc], que es el único cuello para escalar a otros
   proyectos / modelos / componentes.
   Requisito previo: haber corrido DDL_vistas.sql (F5) y DDL_indices.sql.
   ============================================================================ */


/* ----------------------------------------------------------------------------
   BLOQUE 0 — ¿Existen las 13 vistas? (deben aparecer las 13)
   ---------------------------------------------------------------------------- */
SELECT s.name AS esquema, v.name AS vista, v.modify_date
FROM sys.views v JOIN sys.schemas s ON s.schema_id = v.schema_id
WHERE v.name IN (
    'vw_LimitesPorComponente','vw_MuestrasEstado','vw_MuestrasRankeadas',
    'vw_UltimoAnalisisAceite','vw_EstadoActualMT','vw_ObservadosFlota',
    'vw_ObservadosResumen','vw_ObservadosDetalle',
    'vw_UltimoAnalisisFlota','vw_TendenciaElemento','vw_HistorialMuestra','vw_DiagnosticoEquipo',
    'vw_HistorialFlotaObs')
ORDER BY v.name;
GO


/* ============================================================================
   BLOQUE 1  ★ EL MÁS IMPORTANTE ★  — COBERTURA DE LÍMITES
   Cruza las combinaciones (Proyecto × Modelo × CompTipo) que TIENEN muestras
   recientes contra las que TIENEN límites en lc.
   - 'SIN LIMITES EN lc'  => ese componente NUNCA disparará observado (falso
     negativo silencioso). Es lo que el área debe cargar.
   - 'OK' => tiene al menos un límite cargado.
   ============================================================================ */
WITH combos AS (
    SELECT DISTINCT Proyecto, Modelo, CompTipo
    FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
    WHERE EsDDI = 0 AND rn_recencia = 1
)
SELECT
    c.Proyecto, c.Modelo, c.CompTipo,
    CASE WHEN l.CompTipo IS NULL THEN '>>> SIN LIMITES EN lc <<<' ELSE 'OK' END AS Cobertura,
    l.Fe_LP, l.Fe_LC, l.Cu_LP, l.Cu_LC, l.PQ_LP, l.PQ_LC, l.TBN_LP
FROM combos c
LEFT JOIN [dbo].[vw_LimitesPorComponente] l
       ON l.ProyKey   = UPPER(LTRIM(RTRIM(c.Proyecto)))
      AND l.ModeloKey = UPPER(LTRIM(RTRIM(c.Modelo)))
      AND l.CompTipo  = c.CompTipo
ORDER BY Cobertura DESC, c.Proyecto, c.Modelo, c.CompTipo;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 2 — Componentes que el CASE NO reconoce (caen en 'OTRO')
   Si aparece algo aquí, ese Compartimiento no matchea lc y necesita un WHEN
   nuevo en el CASE (en vw_LimitesPorComponente Y vw_MuestrasEstado, idénticos).
   ---------------------------------------------------------------------------- */
SELECT DISTINCT Compartimiento, CompTipo
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE CompTipo = 'OTRO'
ORDER BY Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 3 — Qué hay realmente cargado en lc (lo que el área SÍ subió)
   Útil para detectar el typo '730E-' y modelos/componentes faltantes.
   ---------------------------------------------------------------------------- */
SELECT ProyKey, ModeloKey, CompTipo,
       Fe_LP, Fe_LC, Cu_LP, Cu_LC, PQ_LP, PQ_LC, Cr_LP, Cr_LC,
       Si_LP, Si_LC, Pb_LP, Sn_LP, TBN_LP
FROM [dbo].[vw_LimitesPorComponente] WITH (NOLOCK)
ORDER BY ProyKey, ModeloKey, CompTipo;
GO

-- (3b) Valores crudos de lc, por si hay que ver COMPONENTE/Proyecto/MODELO tal cual:
SELECT DISTINCT [Proyecto], [MODELO], [COMPONENTE]
FROM [Eqpcare].[lc] WITH (NOLOCK)
ORDER BY [Proyecto], [MODELO], [COMPONENTE];
GO


/* ----------------------------------------------------------------------------
   BLOQUE 4 — BARRIDO PASO 1 (RESUMEN) — idéntico al que genera KomfIA
   ---------------------------------------------------------------------------- */
SELECT * FROM [dbo].[vw_ObservadosResumen] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY NumCrit DESC, NumPrec DESC;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 5 — BARRIDO PASO 2 (DETALLE consolidado) — idéntico al de KomfIA
   Revisa la columna Detalle: 'Cu=24.2(LC4.0):C · Ca=...:C inf'
   ---------------------------------------------------------------------------- */
SELECT * FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY NumCrit DESC, Equipo, Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 6 — DETALLE DE UN EQUIPO (fuente de la matriz por-equipo)
   ---------------------------------------------------------------------------- */
SELECT * FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Equipo = 'CA3177'
ORDER BY NumCrit DESC, Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 7 — Conteo de flota (paso previo típico)
   ---------------------------------------------------------------------------- */
SELECT COUNT(ME.[Id]) AS Total, MP.[Name] AS Proyecto, EF.[Model] AS Modelo
FROM [Mine].[MiningEquipment] ME WITH (NOLOCK)
JOIN [Mine].[EquipmentFleet] EF ON EF.[Id] = ME.[EquipmentFleetId]
JOIN [Mine].[MiningProject]  MP ON MP.[Id] = ME.[MiningProjectId]
WHERE MP.[Name] LIKE '%Antapaccay%'
GROUP BY MP.[Name], EF.[Model];
GO


/* ----------------------------------------------------------------------------
   BLOQUE 8 — DETERMINISMO (desempate por LaboratoryDataId en fechas empatadas)
   rn_recencia=1 debe ser estable entre corridas.
   ---------------------------------------------------------------------------- */
SELECT FechaMuestreo, LaboratoryDataId, Fe_ppm, Indice_PQ, rn_recencia
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE Equipo = 'CA3177' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY rn_recencia;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 9 — LATENCIA del PASO 2 (mira "elapsed time" en la pestaña Messages)
   Si se acerca a decenas de segundos en un proyecto, conviene acotar a modelo.
   ---------------------------------------------------------------------------- */
SET STATISTICS TIME ON;
SELECT * FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY NumCrit DESC, Equipo, Compartimiento;
SET STATISTICS TIME OFF;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 10 — ESCALABILIDAD: probar OTRO proyecto/modelo
   0 filas puede significar (a) ninguno observado, o (b) sin límites en lc.
   Para distinguir, cruza SIEMPRE con el BLOQUE 1.
   Cambia el filtro a tu gusto:
   ---------------------------------------------------------------------------- */
SELECT * FROM [dbo].[vw_ObservadosResumen] WITH (NOLOCK)
WHERE Proyecto LIKE '%Cerro Verde%'
ORDER BY NumCrit DESC, NumPrec DESC;
GO

-- (10b) Toda la flota observada por proyecto (panorama global, 1 fila por proyecto):
SELECT Proyecto, COUNT(*) AS EquiposObservados,
       SUM(NumCrit) AS TotalCriticos, SUM(NumPrec) AS TotalPrecauciones
FROM [dbo].[vw_ObservadosResumen] WITH (NOLOCK)
GROUP BY Proyecto
ORDER BY EquiposObservados DESC;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 11 — Hor. Comp. (HsCc): ver si el componente trae horas reales o NULL
   NULL en HorasComponente => ese tipo de componente no está mapeado en el CASE
   de HsCc (no rompe; usa Hor. Aceite como respaldo).
   ---------------------------------------------------------------------------- */
SELECT Equipo, Compartimiento, HorasComponente, HorasDeAceite, Estado_General
FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%'
ORDER BY CASE WHEN HorasComponente IS NULL THEN 0 ELSE 1 END, Equipo;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 12 — VERIFICACIÓN DEL GUARD 'OTRO'  (tras re-correr DDL_vistas.sql)
   El guard hace que un componente NO reconocido (CompTipo='OTRO') no reciba
   límites → nunca dispara observado.
   ---------------------------------------------------------------------------- */

-- (12a) PRUEBA PRINCIPAL: por CompTipo, cuántas muestras hay, cuántas SIN límites
--       y cuántas observadas. Para 'OTRO' => sin_limites = muestras  Y  observados = 0.
SELECT
    CompTipo,
    COUNT(*) AS muestras,
    SUM(CASE WHEN Fe_LP IS NULL AND Cu_LP IS NULL AND PQ_LP IS NULL THEN 1 ELSE 0 END) AS sin_limites,
    SUM(CASE WHEN Estado_General <> 'OK' THEN 1 ELSE 0 END) AS observados
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE EsDDI = 0 AND rn_recencia = 1
GROUP BY CompTipo
ORDER BY CompTipo;
GO

-- (12b) PRUEBA NEGATIVA: ningún componente 'OTRO' debe tener límite asignado ni
--       estar observado. DEBE devolver 0 FILAS si el guard funciona.
SELECT TOP 50 Equipo, Proyecto, Modelo, Compartimiento, CompTipo,
       Fe_LP, Cu_LP, PQ_LP, Estado_General
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE CompTipo = 'OTRO' AND EsDDI = 0 AND rn_recencia = 1
  AND (Fe_LP IS NOT NULL OR Cu_LP IS NOT NULL OR PQ_LP IS NOT NULL
       OR Estado_General <> 'OK');
GO

-- (12c) Los componentes raros (Damper, Diferencial, Caja Giro, PTO…) NO deben
--       aparecer en el barrido. DEBE devolver 0 FILAS.
SELECT DISTINCT Compartimiento
FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Compartimiento NOT LIKE '%TRACCION%'
  AND Compartimiento NOT LIKE '%HIDRAUL%'
  AND Compartimiento NOT LIKE '%RUEDA%'
  AND Compartimiento NOT LIKE '%MANDO%'
  AND Compartimiento NOT LIKE '%TRANSMISION%'
  AND Compartimiento NOT LIKE '%MOTOR%';
GO


/* ----------------------------------------------------------------------------
   BLOQUE 13 — DIAGNÓSTICO POR EQUIPO (nueva vista vw_UltimoAnalisisFlota)
   Todos los componentes de UN equipo, su última muestra (no-DDI), con Hor. Comp.
   real. Es la fuente de la tabla ancha del diagnóstico.
   ---------------------------------------------------------------------------- */

-- (13a) Fuente del diagnóstico (lo que consumirá KomfIA para la tabla ancha).
--       Debe traer las ~6 filas de componentes del equipo, con HorasComponente.
SELECT Equipo, Proyecto, Modelo, Compartimiento, FechaMuestreo,
       Horometro, HorasDeAceite, HorasComponente, CM, Estado_General,
       Fe_ppm, Fe_LP, Fe_LC, Indice_PQ, PQ_LP, PQ_LC, Cr_ppm, Cr_LP, Cr_LC,
       Ni_ppm, Ni_LP, Ni_LC, Cu_ppm, Cu_LP, Cu_LC, Pb_ppm, Pb_LP, Sn_ppm, Sn_LP,
       Al_ppm, Al_LP, Al_LC, Si_ppm, Si_LP, Si_LC, Ca_ppm, Ca_LP, Ca_LC,
       Zn_ppm, Zn_LP, Zn_LC, K_ppm, K_LP, K_LC, B_ppm, P_ppm, Mg_ppm, Mg_LP, Mg_LC,
       V100, TBN, TBN_LP
FROM [dbo].[vw_UltimoAnalisisFlota] WITH (NOLOCK)
WHERE Equipo = 'CA3171'
ORDER BY Compartimiento;
GO

-- (13b) Comprobación de NO-regresión: el diagnóstico (todos los componentes) debe
--       tener >= filas que el barrido del mismo equipo (solo observados).
SELECT 'diagnostico_todos' AS fuente, COUNT(*) AS filas
FROM [dbo].[vw_UltimoAnalisisFlota] WITH (NOLOCK) WHERE Equipo = 'CA3177'
UNION ALL
SELECT 'barrido_observados', COUNT(*)
FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK) WHERE Equipo = 'CA3177';
GO

-- (13c) Hor. Comp. por componente del equipo (NULL = ese componente no mapeó en HsCc;
--       el formato usará Hor. Ace. como respaldo y lo encabezará como tal).
SELECT Compartimiento, FechaMuestreo, HorasComponente, HorasDeAceite, Cond_Area, Estado_General
FROM [dbo].[vw_UltimoAnalisisFlota] WITH (NOLOCK)
WHERE Equipo = 'CA3171'
ORDER BY Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 14 — TENDENCIA POR ELEMENTO (nueva vista vw_TendenciaElemento)
   1 fila por parámetro, con d1..d6 (6 valores cronológicos + chip embebido) y
   f1..f6 (fechas). PASO 2 de tendencia: el central solo PINTA d1..d6.
   ---------------------------------------------------------------------------- */

-- (14a) PASO 2 por defecto: SOLO parámetros relevantes (~4-8 filas chiquititas).
SELECT Parametro, Grupo, LP, LC, d1,d2,d3,d4,d5,d6,
       f1,f2,f3,f4,f5,f6, Prom, Sigma, Tendencia, NVecesObs, Inf
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%' AND Compartimiento LIKE '%RH'
  AND EsRelevante = 1
ORDER BY Orden;
GO

-- (14b) Matriz COMPLETA (los 17 parámetros): la MISMA query SIN "AND EsRelevante = 1".
SELECT Parametro, Grupo, LP, LC, d1, d6, Prom, Sigma, NVecesObs, EsRelevante, Tendencia
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%RH'
ORDER BY Orden;
GO

-- (14c) Sanidad: d1=más antigua, d6=la última; f1..f6 en orden cronológico ascendente.
SELECT Parametro, f1, f6, d1, d6, Tendencia
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%RH' AND Parametro IN ('Fe','PQ')
ORDER BY Orden;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 15 — HISTORIAL muestra por muestra (nueva vista vw_HistorialMuestra)
   1 fila por muestra (INCLUYE DDI), últimos 2 meses (horneados en la vista), params pre-formateados con
   chip. El central pinta la tabla con FechaMuestreo DESC (cantidad de datos, sin
   estadística). LIGERA: ventana 2 meses + columnas chip (no LP/LC).
   ---------------------------------------------------------------------------- */

-- (15a) Historial de un componente (lo que consumirá KomfIA, descendente).
--       La VISTA ya hornea la ventana de 2 meses → SELECT * sin filtro de fecha = liviano.
SELECT * FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY FechaMuestreo DESC;
GO

-- (15b) Cuántas muestras devuelve por componente (debe ser acotado, ~2 meses):
SELECT Compartimiento, COUNT(*) AS muestras_2m,
       SUM(CASE WHEN EsDDI=1 THEN 1 ELSE 0 END) AS ddi,
       MIN(FechaMuestreo) AS desde, MAX(FechaMuestreo) AS hasta
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3198'
GROUP BY Compartimiento
ORDER BY Compartimiento;
GO

-- (15c) Latencia (mira elapsed time): debe ser baja por la ventana de 2 meses.
SET STATISTICS TIME ON;
SELECT * FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY FechaMuestreo DESC;
SET STATISTICS TIME OFF;
GO

/* ----------------------------------------------------------------------------
   BLOQUE 16 — MARCADORES DE CHIP (:C / :P) en vistas pre-formateadas
   Tras re-correr DDL_vistas.sql: historial y tendencia ya NO usan emoji, usan
   marcador texto ':C' (>LC) / ':P' (>LP) — robusto a encoding. El central mapea
   :C->rojo, :P->amarillo, sufijo ' inf'=informativo. DEBEN verse ':C'/':P', NUNCA '🟥'/'🟨'.
   ---------------------------------------------------------------------------- */
-- (16a) Historial: las columnas de metales fuera de umbral deben traer ':C'/':P' (no emoji)
SELECT TOP 20 Fec=FechaMuestreo, CM, Fe, PQ, Cr, Cu, Si, Zn
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3160' AND Compartimiento LIKE '%HIDRAUL%'
ORDER BY FechaMuestreo DESC;
GO

-- (16b) Tendencia: d1..d6 deben traer ':C'/':P' pegados al valor (ej '244.7:C')
SELECT Parametro, d1, d2, d3, d4, d5, d6
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%RH' AND EsRelevante=1
ORDER BY Orden;
GO

/* ----------------------------------------------------------------------------
   BLOQUE 17 — DIAGNÓSTICO POR EQUIPO (nueva vista vw_DiagnosticoEquipo)
   Pre-formateada: 1 fila/componente con cada param ya chip-marcado (:C/:P).
   El central pivota componente x param y solo pinta -> no se corta.
   ---------------------------------------------------------------------------- */
SELECT Compartimiento, FechaMuestreo, HorasComponente, CM, Estado_General,
       Fe, PQ, Cr, Cu, Si, Ca, Zn, Na, V100, TBN
FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK)
WHERE Equipo='CA3177' ORDER BY Compartimiento;
GO
-- (17b) Debe traer las ~6 filas de componentes; los críticos con ':C', informativos con ':C inf'.


/* ----------------------------------------------------------------------------
   BLOQUE 18 — Hor. Comp. en tendencia/historial + TENDENCIA DE UN ELEMENTO
   ---------------------------------------------------------------------------- */

-- (18a) HorasComponente ahora presente en tendencia (rankeadas) e historial:
SELECT Equipo, Compartimiento, FechaMuestreo, Horometro, HorasDeAceite, HorasComponente
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE Equipo='CA3198' AND Compartimiento LIKE '%TRACCION%LH' AND rn_recencia<=8
ORDER BY FechaMuestreo DESC;
GO

-- (18b) TENDENCIA DE UN ELEMENTO (ej. Sodio) en TODOS los componentes de un equipo
--       1 fila por componente, d1..d6 = 6 valores cronológicos (chip), f1..f6 = fechas.
SELECT Compartimiento, Parametro, LP, LC, d1,d2,d3,d4,d5,d6, f1,f6, Tendencia, Inf
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3174' AND Parametro='Na'
ORDER BY Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 19 — HISTORIAL: 5 variantes (todas sobre vw_HistorialMuestra + Mets_Obs)
   Cronologico (FechaMuestreo DESC), ventana 2 meses horneada en la vista.
   ---------------------------------------------------------------------------- */

-- (19.1) GENERAL del equipo: todas las muestras del equipo (cualquier comp.), Met.Obs + Comp.
SELECT Compartimiento, FechaMuestreo, Horometro, HorasDeAceite, CM, Estado_General, Mets_Obs
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3171'
ORDER BY FechaMuestreo DESC, Compartimiento;
GO

-- (19.2) UN METAL en el equipo: el valor del metal por muestra (todos los comp.)
SELECT Compartimiento, FechaMuestreo, Horometro, HorasDeAceite, CM, Estado_General, Fe
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3171'
ORDER BY FechaMuestreo DESC, Compartimiento;
GO

-- (19.3) UN METAL en UN COMPONENTE: valor del metal + Hor. Comp. por muestra
SELECT FechaMuestreo, Horometro, HorasDeAceite, HorasComponente, CM, Estado_General, Fe
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY FechaMuestreo DESC;
GO

-- (19.4) UN COMPONENTE: Met.Obs + Hor. Comp. por muestra de ese componente
SELECT FechaMuestreo, Horometro, HorasDeAceite, HorasComponente, CM, Estado_General, Mets_Obs
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY FechaMuestreo DESC;
GO

-- (19.5) OBSERVADOS EN FLOTA: muestras observadas del proyecto/modelo (el central agrupa por fecha)
SELECT FechaMuestreo, Equipo, Compartimiento, CM, Mets_Obs
FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%' AND Mets_Obs IS NOT NULL
ORDER BY FechaMuestreo DESC, Equipo, Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 20 — HISTORIAL OBSERVADOS DE FLOTA (vista vw_HistorialFlotaObs, agregado)
   1 fila por fecha (30 días), liviano y rápido (sin subconsulta de Hor.Comp).
   Mira "elapsed time": debe ser MUCHO menor que el vw_HistorialMuestra fleet-wide.
   ---------------------------------------------------------------------------- */
SET STATISTICS TIME ON;
SELECT * FROM [dbo].[vw_HistorialFlotaObs] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY FechaMuestreo DESC;
SET STATISTICS TIME OFF;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 21 — HorasComponente en vw_UltimoAnalisisAceite y vw_EstadoActualMT
   Fix BadGateway "Invalid column name HorasComponente": ambas se rebasaron sobre
   vw_MuestrasRankeadas (que la calcula). Estas dos consultas deben ejecutar SIN error
   y traer la columna HorasComponente con valor (o NULL si HsCc no cubre el componente).
   ---------------------------------------------------------------------------- */
SELECT Equipo, Compartimiento, FechaMuestreo, HorasDeAceite, HorasComponente, CM, Estado_General
FROM [dbo].[vw_UltimoAnalisisAceite] WITH (NOLOCK)
WHERE Equipo = 'CA3171' AND Compartimiento LIKE '%TRACCION%LH';
GO

SELECT TOP 10 Equipo, Compartimiento, FechaMuestreo, HorasDeAceite, HorasComponente, Fe_ppm, Estado_General
FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY Fe_ppm DESC;
GO


/* ============================================================================
   BLOQUE 22 — VALIDAR LA FUNDACIÓN tras los cambios de perf (re-correr DDL primero)
   1) ventana 12 meses en vw_MuestrasEstado  2) HorasComponente vía JOIN pre-rankeado.
   Corre las 4; cada una 2 veces (usa la 2ª, warm).
   ============================================================================ */

-- 22.1  COBERTURA: ¿la ventana de 12m dejó fuera algún equipo que SÍ debería verse?
--       Lista equipos cuya ÚLTIMA muestra es > 12 meses (ya NO aparecen en estado actual).
--       Si solo salen equipos viejos / dados de baja → la ventana es segura. Si sale uno
--       que esperabas activo → avísame y subimos la ventana.
SELECT ME.[Code] AS Equipo, MP.[Name] AS Proyecto, MAX(LD.[FechaMuestreo]) AS UltimaMuestra
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
JOIN [Mine].[MiningProject]  MP ON MP.[Id] = ME.[MiningProjectId]
GROUP BY ME.[Code], MP.[Name]
HAVING MAX(LD.[FechaMuestreo]) < DATEADD(MONTH, -12, GETDATE())
ORDER BY UltimaMuestra DESC;
GO

-- 22.2  PISO Y TAMAÑO: la más antigua debe ser ~hoy-12m y las filas MUCHO menos que 104165.
SELECT COUNT(*) AS Filas, MIN(FechaMuestreo) AS MasAntigua, MAX(FechaMuestreo) AS MasReciente,
       COUNT(DISTINCT MiningEquipmentId) AS Equipos
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK);
GO

-- 22.3  HorasComponente (JOIN) sale con valor y SIN error en estado actual MT.
SELECT TOP 10 Equipo, Compartimiento, FechaMuestreo, HorasDeAceite, HorasComponente, Fe_ppm, Estado_General
FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY Fe_ppm DESC;
GO

-- 22.4  LATENCIA post-cambio (warm). Compara «elapsed time» con DIAGNOSTICO_LATENCIA:
--       L2.2 último de 1 equipo (antes ~5s) y L5 rn=1 fleet-wide (antes 6.4s, HsCc 2112 escaneos).
SET STATISTICS TIME ON;
SELECT * FROM [dbo].[vw_UltimoAnalisisAceite] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH';
SELECT Equipo, Compartimiento, HorasComponente
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK) WHERE rn_recencia = 1;
SET STATISTICS TIME OFF;
GO



/* ============================================================================
   BLOQUE 23 — DEDUP POR FECHA en rn_recencia (re-correr DDL primero)
   Antes: muestras del mismo día consumían ranking -> tendencia mostraba "3 de 6".
   Ahora rn_recencia cuenta FECHAS distintas (keeper = mayor LaboratoryDataId/día).
   ============================================================================ */
-- 23.1 rn=1 sigue dando 1 fila por equipo+compartimiento (la última fecha). NO debe duplicar.
SELECT Equipo, Compartimiento, COUNT(*) AS filas_rn1
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE rn_recencia = 1
GROUP BY Equipo, Compartimiento
HAVING COUNT(*) > 1;   -- debe devolver 0 filas
GO
-- 23.2 Tendencia: las 6 deben ser FECHAS DISTINTAS (sin 19-Jun repetido).
SELECT rn_recencia, FechaMuestreo, Horometro, CM
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH' AND rn_recencia <= 6
ORDER BY rn_recencia;   -- 6 filas, 6 fechas distintas, sin huecos
GO
-- 23.3 Historial SIGUE viendo TODAS las muestras (incluye mismo día) — no se perdió nada.
SELECT FechaMuestreo, CM, Fe FROM [dbo].[vw_HistorialMuestra] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH'
ORDER BY FechaMuestreo DESC;   -- puede haber 2+ del mismo día (correcto)
GO


/* ============================================================================
   BLOQUE 24 — CA3174 SIN LÍMITES (LP/LC) NI Hor.Comp. (marcha 2026-06-27)
   Síntoma: "tendencia del Fe del CA3174 MT RH" devolvió valores pero LP/LC y
   HorasComponente en blanco. LP/LC viene de [lc]; Hor.Comp. de [HsCc]. Que AMBOS
   fallen juntos apunta a una peculiaridad de CA3174 (Modelo/Proyecto/Compartimiento
   que no cruza). Correr de 24.1 a 24.5 para aislar la causa.
   ---------------------------------------------------------------------------- */
GO
-- 24.1 ¿Cómo se ve CA3174 en la FUNDACIÓN? (Proyecto/Modelo/Compartimiento/CompTipo reales)
--      Esperado: Proyecto='Antapaccay', Modelo='980E', CompTipo='TRACCION'.
SELECT DISTINCT Equipo, Proyecto, Modelo, Compartimiento, CompTipo
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE Equipo='CA3174' AND Compartimiento LIKE '%TRACCION%'
ORDER BY Compartimiento;
GO
-- 24.2 ¿Existe la fila de límites para ese Proyecto×Modelo×CompTipo?
--      Si Fe_LP sale NULL/!=200 o no hay fila → la combinación de CA3174 NO está en lc.
SELECT ProyKey, ModeloKey, CompTipo, Fe_LP, Fe_LC
FROM [dbo].[vw_LimitesPorComponente] WITH (NOLOCK)
WHERE ProyKey LIKE '%ANTAPACCAY%' AND CompTipo='TRACCION';
GO
-- 24.3 ¿Resuelve LP/LC en el ESTADO ACTUAL (triage) de CA3174? (ahí antes sí salía)
SELECT Equipo, Compartimiento, FechaMuestreo, Fe_ppm, Fe_LP, Fe_LC, Estado_General, HorasComponente
FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK)
WHERE Equipo='CA3174';
GO
-- 24.4 La query EXACTA que falló: tendencia Fe del CA3174 MT RH.
--      Mira si LP/LC/HorasComponente vienen poblados o NULL.
SELECT Equipo, Compartimiento, Parametro, LP, LC, HorasComponente, CM, d1,d2,d3,d4,d5,d6
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3174' AND Compartimiento LIKE '%TRACCION%' AND Compartimiento LIKE '%RH' AND Parametro='Fe';
GO
-- 24.5 ¿HsCc tiene a CA3174 (o 'T3174') con el SISTEMA mapeado? (origen de Hor.Comp.)
--      Si no aparece WHEEL MOTOR RH → HorasComponente NULL es esperado (gap HsCc).
SELECT [EQUIPO], [SISTEMA], [SMR ULTIMO SERVICIO], [HORAS DE TRABAJO ACUMULADO ], [FECHA]
FROM [Eqpcare].[HsCc] WITH (NOLOCK)
WHERE ([EQUIPO]='CA3174' OR [EQUIPO]='T3174')
ORDER BY [SISTEMA], [FECHA] DESC;
GO
