/* ============================================================================
   KomfIA — ÍNDICE DE VALIDACIÓN (bloques ordenados)
     BLOQUE 0   ¿Existen las 13 vistas? (deben aparecer las 13)
     BLOQUE 1   Componentes que el CASE NO reconoce (caen en 'OTRO')
     BLOQUE 22  VALIDAR LA FUNDACIÓN tras los cambios de perf (re-correr DDL primero)
     BLOQUE 23  DEDUP POR FECHA en rn_recencia (re-correr DDL primero)
     BLOQUE 24  CA3174 SIN LÍMITES (LP
     BLOQUE 25  SPARK (sparkline pre-computado en vw_TendenciaElemento) (2026-06-29)
     BLOQUE 26  SCOPE diagnóstico + filtro de proyecto del triage (marcha 2026-06-30)
     BLOQUE 32  vw_ObservadosBarridoMD (TIER 2 copia verbatim del "detalle de todos")
     BLOQUE 34  vw_ObservadosResumenMD (PASO 1 del barrido, columna MD)
     BLOQUE 35  barrido filtrado (MD_Criticos
     BLOQUE 36  vw_DiagnosticoMD (diagnóstico 1 equipo)
     BLOQUE 37  vw_Recomendaciones + bloque determinístico en DiagnosticoMD
     BLOQUE 38  vw_UltimoAnalisisMD (filtro por compAbbr, como el flujo)
     BLOQUE 39  vw_CondicionMT_MD (firma equipo, flujo MD_equipo)
     BLOQUE 40  vw_TendenciaP1MD (firma equipo+compAbbr, flujo MD_equipo_comp)
     BLOQUE 41  vw_TendenciaMD (detalle; firma equipo+compAbbr, flujo MD_equipo_comp)
     BLOQUE 42  vw_TendenciaGraficoMD (tabla del metal + gráfico ASCII combinados)
     BLOQUE 43  vw_TendenciaGraficoObsMD (default: gráficas de observados; firma equip
     BLOQUE 44  vw_TendenciaMetalMD (firma equipo+parametro, flujo MD_metal comp vacío
     BLOQUE 45  vw_HistorialMD (firma equipo+compAbbr, flujo MD_equipo_comp)
     BLOQUE 46  vw_HistorialMetalMD (firma equipo+compAbbr+parametro, flujo MD_metal)
     BLOQUE 47  vw_HistorialEquipoMD (equipo) + vw_HistorialFlotaMD (proyecto)
     BLOQUE 48  vw_HistorialMetalEquipoMD (firma equipo+parametro, flujo MD_metal comp
     BLOQUE 49  vw_TriageMD (firma proyecto, flujo MD_flota modelo
     BLOQUE 50  CORROBORAR límites gerencia (docs
     BLOQUE 51  VALIDAR fix Pb
     BLOQUE 52  VALIDAR Pb
     BLOQUE 53  VALIDAR salud (V100
     BLOQUE 54  #6b salud V100 (viscosidad) informativa en barrido detalle
     BLOQUE 55  #14 vw_TendenciaIncipienteMD (firma proyecto, flujo MD_flota modelo
     BLOQUE 56  Barrido: (todos) sin modelo Y por-modelo especifico (duplicacion)
     BLOQUE 57  Triage recos: solo metales de la tabla (sin Calcio
     BLOQUE 58  Historial INCLUYE DDI (unico topico con DDI; vw_MuestrasHistorial + rn
     BLOQUE 59  vw_ConteoFlotaMD (Conteo; flujo MD_flota; proyecto + modelo)
     BLOQUE 60  vw_RankingMD (formato largo; el flujo MD_ranking arma la tabla con pos
     BLOQUE 61  Tendencia con Grado (lubricante) + horas comp
     BLOQUE 62  vw_TendenciaMetalFlotaMD (Gap1; tendencia de un metal en la flota)
     BLOQUE 63  vw_CondicionCompMD (Gap2; condicion de un componente en la flota)
     BLOQUE 64  vw_UltimoMetalFlotaMD (Ultimo analisis en barrido por metal; 1..N metales)
   ============================================================================ */

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

/* ============================================================================
   BLOQUE 25 — SPARK (sparkline pre-computado en vw_TendenciaElemento) (2026-06-29)
   Solución al gráfico RE-PEDIDO que se regeneraba mal: la vista ahora trae una
   columna Spark (▁▂▃▄▅▆▇█, 1 char por muestra d1..d6 cronológica, normalizada al
   rango de la propia serie). El central solo la IMPRIME/COPIA (no regenera ASCII).
   Validar que: (a) el Motor del CA3165 Cu dibuja la subida 4.0->6.8 y la caída
   final; (b) las series planas salen '▄▄▄▄▄▄'; (c) <6 muestras → '·' en huecos.
   ---------------------------------------------------------------------------- */
GO
-- 25.1 Spark de Cu en CA3165 por componente (Motor debe verse ascendente con caída; planos = barras bajas/iguales)
SELECT Compartimiento, Parametro, d1, d2, d3, d4, d5, d6, Spark, Tendencia, EsRelevante
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3165' AND Parametro='Cu'
ORDER BY Compartimiento;
GO
-- 25.2 No rompe consumidores existentes: d1..d6 + LP/LC + Spark juntos (detalle por elemento de un equipo)
SELECT Parametro, LP, LC, d1, d2, d3, d4, d5, d6, Spark, Prom, Sigma
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH' AND EsRelevante=1
ORDER BY Orden;
GO
-- 25.3 Edge: equipo/parámetro con <6 muestras → Spark con '·' en los huecos (no debe dar error)
SELECT TOP 20 Equipo, Compartimiento, Parametro, d1, d2, d3, d4, d5, d6, Spark
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE d3 IS NULL OR d1 IS NULL
ORDER BY Equipo, Compartimiento, Orden;
GO
-- 25.4 Conteo de columnas / que la vista compila y Spark no es NULL cuando hay >=1 muestra
SELECT COUNT(*) AS Filas, SUM(CASE WHEN Spark IS NULL THEN 1 ELSE 0 END) AS SparkNulos
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK) WHERE Equipo='CA3165';
GO

-- 25.5 Grafico AISLADO en vw_TendenciaGrafico (1 componente): vertical, × a la altura, líneas LC/LP
SELECT Grafico
FROM [dbo].[vw_TendenciaGrafico] WITH (NOLOCK)
WHERE Equipo='CA3165' AND Parametro='Cu' AND Compartimiento='MOTOR';
GO
-- 25.6 Grafico Cr MT LH CA3171 (vw_TendenciaGrafico) + 25.7: vw_TendenciaElemento YA es ligera (SIN Grafico)
SELECT Grafico FROM [dbo].[vw_TendenciaGrafico] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH' AND Parametro='Cr';
GO
-- 25.7 Confirmar que vw_TendenciaElemento ya NO trae Grafico (columnas ligeras + Spark)
SELECT TOP 1 * FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK) WHERE Equipo='CA3165' AND Parametro='Cu';
GO

/* ============================================================================
   BLOQUE 26 — SCOPE diagnóstico + filtro de proyecto del triage (marcha 2026-06-30)
   Dos hallazgos de la marcha: (A) «Diagnóstico del CA3177» trajo los 6 componentes
   (SELECT * sin AND Estado_General<>'OK') → payload → SystemError. El DEFAULT debe ser
   SOLO observados. (C) «Triage MT de Antapaccay» filtró por Modelo '%980E%' (sin
   Proyecto) → coló HT321 de ANTAMINA (también 980E). Por proyecto = SIEMPRE Proyecto.
   Estos son fixes de INSTRUCCIÓN (las vistas están bien); abajo, queries de referencia.
   ---------------------------------------------------------------------------- */
GO
-- 26.1 Diagnóstico DEFAULT (solo observados) = filas ligeras; vs TODOS (6 comp) = pesado
SELECT 'observados' AS modo, COUNT(*) AS comps
FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK) WHERE Equipo='CA3177' AND Estado_General<>'OK'
UNION ALL
SELECT 'todos', COUNT(*) FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK) WHERE Equipo='CA3177';
GO
-- 26.2 Triage por MODELO (mal: cuela otros proyectos 980E) vs por PROYECTO (correcto)
SELECT DISTINCT Proyecto, COUNT(*) AS mt_obs
FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK)
WHERE Modelo LIKE '%980E%' AND Estado_General <> 'OK'
GROUP BY Proyecto;   -- ⚠ si aparece Antamina u otro, confirma la fuga de C
GO
SELECT COUNT(*) AS mt_obs_antapaccay
FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Estado_General <> 'OK';   -- el correcto
GO


/* ----------------------------------------------------------------------------
   BLOQUE 27 — DIAGNÓSTICO: NumCompObs/NumCompTotal YA son columnas de la vista
   (marcha 2026-07-08). Hallazgo: el agente generó un CTE con CROSS JOIN para
   "calcular" los conteos: SELECT d.*, c.NumCompTotal, c.NumCompObs FROM Diag d
   CROSS JOIN Counts c ... — pero Diag = SELECT * FROM vw_DiagnosticoEquipo, que
   YA expone NumCompTotal/NumCompObs (window PARTITION BY Equipo, pre-filtro).
   Resultado: NOMBRES DE COLUMNA DUPLICADOS en el result set → Power Automate no
   serializa el JSON → {"respuesta":""} vacío → el central dijo "todos OK" (falso).
   El reintento con la forma SIMPLE (abajo) funcionó. Fix de INSTRUCCIÓN
   (KomfIA_SQL P21): "NumCompObs/Total YA en la vista → NO recalcular vía CTE/JOIN".
   La vista NO cambia. Abajo: (27.1) confirma que las columnas ya vienen; (27.2)
   la query CORRECTA; (27.3) demuestra el duplicado que rompe el JSON.
   ---------------------------------------------------------------------------- */
GO
-- 27.1 Las columnas de conteo YA existen en la vista (1 fila/comp; conteo por equipo)
SELECT Compartimiento, Estado_General, NumCompObs, NumCompTotal
FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK) WHERE Equipo='CA3177' ORDER BY Compartimiento;
GO
-- 27.2 QUERY CORRECTA (simple): observados + conteos, SIN CTE. Debe traer NumComp* poblados.
SELECT * FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK)
WHERE Equipo='CA3177' AND Estado_General<>'OK' ORDER BY Compartimiento;
GO
-- 27.3 DEMOSTRACIÓN del bug: d.* ya trae NumCompTotal/NumCompObs; añadir c.NumComp* los
--      DUPLICA. En SSMS corre (columnas repetidas visibles); vía OData/JSON del flujo,
--      las claves duplicadas colapsan el objeto → respuesta vacía. NO usar esta forma.
WITH Diag AS (SELECT * FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK) WHERE Equipo='CA3177'),
     Counts AS (SELECT COUNT(*) AS NumCompTotal,
                       SUM(CASE WHEN Estado_General<>'OK' THEN 1 ELSE 0 END) AS NumCompObs FROM Diag)
SELECT d.*, c.NumCompTotal, c.NumCompObs      -- ⚠ NumCompTotal/NumCompObs DUPLICADAS (ya en d.*)
FROM Diag d CROSS JOIN Counts c
WHERE d.Estado_General<>'OK' ORDER BY d.Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 28 — ACUMULADO de vida por metal en vw_TendenciaElemento (pedido gerencia 2026-07-10)
   Nuevo: columnas Acumulado (Σ del ppm del metal en TODAS las muestras no-DDI del
   componente) y NmAcum (nº de muestras sumadas). vw_MuestrasRankeadas ya filtra
   EsDDI=0, así que el acumulado suma solo muestras de monitoreo (no las post-dializado).
   Es un PROXY de exposición/desgaste acumulado, NO masa real (ppm=concentración).
   ⚠ Solo tiene sentido para metales de desgaste; para V100/TBN la Σ no es interpretable.
   Re-correr DDL_vistas.sql (vw_TendenciaElemento) ANTES de este bloque.
   Validar: (28.1) Acumulado/NmAcum poblados y coherentes; (28.2) NmAcum >= 6 (hay más
   historia que las 6 mostradas); (28.3) el acumulado NO cambia d1..d6/Prom/Sigma (siguen
   sobre las 6 últimas); (28.4) que NmAcum = nº real de muestras no-DDI del componente.
   ---------------------------------------------------------------------------- */
GO
-- 28.1 Cr del MT LH del CA3171: tendencia (6) + acumulado de vida
SELECT Compartimiento, Parametro, d1,d2,d3,d4,d5,d6, Prom, Sigma, Acumulado, NmAcum
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%' AND Compartimiento LIKE '%LH' AND Parametro='Cr';
GO
-- 28.2 Cu de todos los componentes del CA3171: cada fila trae su Σ de vida del Cu
SELECT Compartimiento, Parametro, Prom, Sigma, NVecesObs, Acumulado, NmAcum
FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Parametro='Cu' ORDER BY Compartimiento;
GO
-- 28.4 Contraste: NmAcum debe igualar el nº de muestras no-DDI del componente en la base rankeada
SELECT COUNT(*) AS muestras_noDDI_reales
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%' AND Compartimiento LIKE '%LH';   -- comparar vs NmAcum de 28.1
GO


/* ----------------------------------------------------------------------------
   BLOQUE 29 — GRÁFICO de tendencia MÁS GRANDE + baseline visible (pedido gerencia 2026-07-10)
   vw_TendenciaGrafico regenerada: 12 niveles de alto (antes 7) y 9 de ancho por columna
   (antes 7). Las líneas LP (------) y LC (······) se dibujan a lo ancho completo y con más
   resolución vertical → la baseline horizontal se ve clara y grande. Misma consulta (1 comp).
   Re-correr DDL_vistas.sql (vw_TendenciaElemento primero — es su base — y vw_TendenciaGrafico).
   Validar en SSMS con resultado a TEXTO (Ctrl+T) para ver el multi-línea alineado.
   ---------------------------------------------------------------------------- */
GO
-- 29.1 Gráfico del Cr del MT LH del CA3171 (debe verse alto 12, ancho 9, con LC/LP a lo ancho)
SELECT Grafico FROM [dbo].[vw_TendenciaGrafico] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH%' AND Parametro='Cr';
GO
-- 29.2 Gráfico del Cu del Motor del CA3165 (otro componente/metal)
SELECT Grafico FROM [dbo].[vw_TendenciaGrafico] WITH (NOLOCK)
WHERE Equipo='CA3165' AND Compartimiento='MOTOR' AND Parametro='Cu';
GO


/* ----------------------------------------------------------------------------
   BLOQUE 30 — DETALLE del barrido con AMBOS límites (LP y LC) (pedido gerencia 2026-07-13)
   vw_ObservadosFlota.Detalle pasa de mostrar el límite CRUZADO ('Cu=7.7(LC4):C') a mostrar
   AMBOS ('Cu=7.7(LP3/LC4):C'), para precaución y crítico. Pb/Sn/TBN no tienen LC → solo LP.
   Robusto a NULL (ISNULL) → nunca desaparece la entrada del metal. Solo cambia el STRING
   Detalle; NumCrit/NumPrec/Mets_Obs/Infs_Obs y las demás vistas NO cambian.
   Re-correr DDL_vistas.sql (vw_ObservadosFlota → vw_ObservadosDetalle son la misma base).
   ---------------------------------------------------------------------------- */
GO
-- 30.1 Detalle de Antapaccay 980E: cada metal debe verse 'Metal=valor(LPx/LCy):sev'
SELECT Equipo, Compartimiento, NumCrit, NumPrec, Detalle
FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY NumCrit DESC, Equipo, Compartimiento;
GO
-- 30.2 Precauciones (NumCrit=0 AND NumPrec>0): confirmar que el límite (LP) sale en el Detalle
SELECT Equipo, Compartimiento, Detalle
FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%' AND NumCrit=0 AND NumPrec>0
ORDER BY Equipo, Compartimiento;
GO


/* ----------------------------------------------------------------------------
   BLOQUE 31 — CUADRO DE LÍMITES en el barrido desde PASO 1 (pedido 2026-07-15)
   Para que la matriz de límites (componente×metal, LP/LC) aparezca YA en la primera
   consulta de barrido (resumen), vw_ObservadosResumen ahora expone la columna Limites
   ("Comp: metal LP/LC" de los componentes observados del equipo). Se apoya en LimObs,
   nueva columna ligera de vw_ObservadosFlota (límites de los metales observados, sin
   valores ni chips). El central UNE por (comp, metal) para armar la matriz.
   Re-correr DDL_vistas.sql (vw_ObservadosFlota ANTES de vw_ObservadosResumen).
   ---------------------------------------------------------------------------- */
GO
-- 31.1 Resumen de Antapaccay: cada equipo trae Comp_Obs, Met_Obs y ahora Limites
SELECT Equipo, NumCrit, NumPrec, Comp_Obs, Met_Obs, Limites
FROM [dbo].[vw_ObservadosResumen] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY NumCrit DESC, NumPrec DESC;
GO
-- 31.2 LimObs por equipo+componente en la flota (límites de los metales observados)
SELECT Equipo, Compartimiento, Mets_Obs, LimObs
FROM [dbo].[vw_ObservadosFlota] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY Equipo, Compartimiento;
GO

/* ============================================================================
   BLOQUE 32 — vw_ObservadosBarridoMD (TIER 2 copia verbatim del "detalle de todos")
   Objetivo: confirmar que la vista entrega el bloque markdown YA armado y las cifras.
   ⚠ Ver el texto completo: Query > Query Options > Results > Grid/Text >
      "Maximum Characters Retrieved" súbelo (p.ej. 65535). Con Ctrl+T (modo texto)
      se lee mejor el markdown multilínea.
   ---------------------------------------------------------------------------- */
-- 32.1  Cifras + largo del bloque (1 fila por Proyecto+Modelo)
SELECT Proyecto, Modelo, NumEquipos, NumEquiposCriticos, NumEquiposSoloPrecau,
       LEN(DetalleTodosMD) AS LargoMD
FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';

-- 32.2  El bloque markdown pre-armado (esto es lo que el central imprimiría VERBATIM)
SELECT DetalleTodosMD
FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';
GO

/* ============================================================================
   BLOQUE 34 — vw_ObservadosResumenMD (PASO 1 del barrido, columna MD)
   ⚠ Sube "Maximum Characters Retrieved" para ver el bloque completo.
   ---------------------------------------------------------------------------- */
SELECT Proyecto, Modelo, NumEquipos, NumCriticos, NumSoloPrecau, LEN(MD) AS LargoMD
FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';

SELECT MD
FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';
GO

/* ============================================================================
   BLOQUE 35 — barrido filtrado (MD_Criticos / MD_Precaucion)
   ---------------------------------------------------------------------------- */
SELECT MD_Criticos   FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';
SELECT MD_Precaucion FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';
GO

/* ===== BLOQUE 36 — vw_DiagnosticoMD (diagnóstico 1 equipo) ===== */
SELECT Equipo, NumCompObs, NumCompTotal, LEN(MD) AS LargoMD, LEN(MD_Completo) AS LargoCompleto
FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo='CA3177';
SELECT MD          FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo='CA3177';
SELECT MD_Completo FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo='CA3177';
GO

-- ==== BLOQUE 37 — vw_Recomendaciones + bloque determinístico en DiagnosticoMD ====
SELECT * FROM [dbo].[vw_Recomendaciones];
SELECT Observados, Recomendaciones FROM [dbo].[vw_DiagnosticoMD] WITH (NOLOCK) WHERE Equipo='CA3177';
GO

-- ==== BLOQUE 38 — vw_UltimoAnalisisMD (filtro por compAbbr, como el flujo) ====
SELECT Observados, Recomendaciones, MD FROM [dbo].[vw_UltimoAnalisisMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%';
GO

-- ==== BLOQUE 39 — vw_CondicionMT_MD (firma equipo, flujo MD_equipo) ====
SELECT Observados, Recomendaciones, MD FROM [dbo].[vw_CondicionMT_MD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3177%';
GO

-- ==== BLOQUE 40 — vw_TendenciaP1MD (firma equipo+compAbbr, flujo MD_equipo_comp) ====
SELECT MD FROM [dbo].[vw_TendenciaP1MD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3177%' AND compAbbr LIKE '%MT LH%';
GO

-- ==== BLOQUE 41 — vw_TendenciaMD (detalle; firma equipo+compAbbr, flujo MD_equipo_comp) ====
SELECT Observados, Recomendaciones, MD FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%';   -- MD = matriz COMPLETA (default)
SELECT MD_Relevantes FROM [dbo].[vw_TendenciaMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%';   -- opt-in: solo fuera de umbral
GO

-- ==== BLOQUE 42 — vw_TendenciaGraficoMD (tabla del metal + gráfico ASCII combinados) ====
SELECT MD FROM [dbo].[vw_TendenciaGraficoMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%' AND Parametro='Cr';
GO

-- ==== BLOQUE 43 — vw_TendenciaGraficoObsMD (default: gráficas de observados; firma equipo+compAbbr) ====
SELECT MD FROM [dbo].[vw_TendenciaGraficoObsMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%';   -- debe traer Cr y Zn
SELECT MD FROM [dbo].[vw_TendenciaGraficoObsMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3177%' AND compAbbr LIKE '%MT LH%';   -- sin observados -> mensaje
GO

-- ==== BLOQUE 44 — vw_TendenciaMetalMD (firma equipo+parametro, flujo MD_metal comp vacío) ====
SELECT MD FROM [dbo].[vw_TendenciaMetalMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%%' AND Parametro='Cu';
GO

-- ==== BLOQUE 45 — vw_HistorialMD (firma equipo+compAbbr, flujo MD_equipo_comp) ====
SELECT MD FROM [dbo].[vw_HistorialMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%';
GO

-- ==== BLOQUE 46 — vw_HistorialMetalMD (firma equipo+compAbbr+parametro, flujo MD_metal) ====
SELECT MD FROM [dbo].[vw_HistorialMetalMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%MT LH%' AND Parametro='Cr';
GO

-- ==== BLOQUE 47 — vw_HistorialEquipoMD (equipo) + vw_HistorialFlotaMD (proyecto) ====
SELECT MD FROM [dbo].[vw_HistorialEquipoMD] WITH (NOLOCK) WHERE Equipo LIKE '%CA3171%';
SELECT MD FROM [dbo].[vw_HistorialFlotaMD]  WITH (NOLOCK) WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%';
GO

-- ==== BLOQUE 48 — vw_HistorialMetalEquipoMD (firma equipo+parametro, flujo MD_metal comp=todos) ====
SELECT MD FROM [dbo].[vw_HistorialMetalEquipoMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr LIKE '%todos%' AND Parametro='Cu';
GO

/* ==== BLOQUE 49 — vw_TriageMD EVOLUCIONADO (base ligera; flujo MD_triage: proyecto+modelo+compartimiento) ====
   Evolucion 2026-08-19: cualquier CompTipo, TODOS los equipos (obs o no), metales con valor entre parentesis,
   agrupado por modelo (en '(todos)' cada modelo lleva sub-titulo ### <modelo>). Recos solo TRACCION.
   Base: vw_MuestrasRankeadas rn=1 (1 pasada) — mas ligera que la version anterior (leia vw_DiagnosticoEquipo). */
-- (a) MT de toda la flota, sin modelo -> sale por modelo con sub-titulos:
SELECT Recomendaciones, MD FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antamina%' AND Modelo LIKE '%todos%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%traccion%';
GO
-- (b) Ruedas de un modelo especifico -> tabla unica de ese modelo (como '¿que ruedas estan observadas?'):
SELECT MD FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antamina%' AND Modelo LIKE '%980E%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%rueda%';
GO
-- Verifica: salen TODOS (🟩 OK incluidos), criticos/precaucion arriba, metales tipo 'Fe(199.0) · Cr(29.0)'.
-- PERF: comparar elapsed vs la version anterior (deberia bajar; base = rankeadas rn=1, 1 pasada).

-- ==== BLOQUE 50 — CORROBORAR límites gerencia (docs/gerencia/Limites.xlsx) vs [Eqpcare].[lc] ====
-- Origen gerencia = matriz Proyecto x Componente x Modelo, ~60 parámetros (Fe,Al,Cu,Pb,Sn,Cr,Ni,Si,
-- Na,K,Zn,P,B,Ca,Mg,PQ,TBN,Visc,ISO...). HALLAZGO: Pb/Sn SÍ tienen LC (Antapaccay MT: Pb LC=5, Sn LC=5).
-- Objetivo: (a) ver qué columnas/valores tiene realmente Eqpcare.lc; (b) detectar faltantes vs gerencia.
GO
-- 50.1 Columnas reales de [Eqpcare].[lc] (¿existen [PLOMO - LC], [ESTAÑO - LC], [TIPO], [MODELO]?)
SELECT ORDINAL_POSITION, COLUMN_NAME, DATA_TYPE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA='Eqpcare' AND TABLE_NAME='lc'
ORDER BY ORDINAL_POSITION;
GO
-- 50.2 Límites de Motor de Tracción por proyecto (contrastar 1:1 con Limites.xlsx filas MT)
--      Antapaccay MT: Fe 200/230, Pb 3/5, Sn 3/5, Cu 10/15, Cr 2/3, Ni 2/3, Si 75/80, PQ 130/150
SELECT [Proyecto], [COMPONENTE],
       [FIERRO - LP],[FIERRO - LC],[PLOMO - LP],[PLOMO - LC],[ESTAÑO - LP],[ESTAÑO - LC],
       [COBRE - LP],[COBRE - LC],[CROMO - LP],[CROMO - LC],[NIQUEL - LP],[NIQUEL - LC],
       [SILICIO - LP],[SILICIO - LC],[PQ - LP],[PQ - LC],[TBN - LP],[TBN - LC]
FROM [Eqpcare].[lc] WITH (NOLOCK)
WHERE [COMPONENTE] LIKE '%TRACCION%'
ORDER BY [Proyecto], [COMPONENTE];
GO
-- 50.3 ¿Eqpcare.lc trae [PLOMO - LC] / [ESTAÑO - LC] poblados? (si NULL/ausente → falta cargar del Excel)
--      Si estas columnas NO existen: la fundación vw_MuestrasEstado NO puede derivar Pb_LC/Sn_LC.
SELECT [Proyecto], [COMPONENTE], [PLOMO - LP], [PLOMO - LC], [ESTAÑO - LP], [ESTAÑO - LC]
FROM [Eqpcare].[lc] WITH (NOLOCK)
WHERE [COMPONENTE] LIKE '%TRACCION%' AND [Proyecto]='ANTAPACCAY';
GO
-- 50.4 Vista fundación: ¿expone Pb_LC / Sn_LC? (hoy NO — solo Pb_LP/Sn_LP). Confirmar el gap.
SELECT TOP 1 * FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE Compartimiento LIKE '%TRACCION%';   -- inspeccionar columnas Pb_/Sn_ en el grid
GO

-- ==== BLOQUE 51 — VALIDAR fix Pb/Sn LC (crítico) tras re-correr la cadena ====
-- ORDEN de re-corrida en SSMS (dependencias): 1) vw_LimitesPorComponente  2) vw_MuestrasEstado
-- 3) (vw_MuestrasRankeadas hereda por me.*)  4) vw_TendenciaElemento  5) las *MD (último, historial-metal).
GO
-- 51.1 La fundación ya expone Pb_LC / Sn_LC y marca crítico (Antapaccay MT: Pb LC=5, Sn LC=5)
SELECT TOP 20 Equipo, Compartimiento, Pb_ppm, Pb_LP, Pb_LC, Estado_Pb, Sn_ppm, Sn_LP, Sn_LC, Estado_Sn
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE Compartimiento LIKE '%TRACCION%' AND Proyecto='Antapaccay'
  AND (Pb_ppm > Pb_LP OR Sn_ppm > Sn_LP)
ORDER BY Pb_ppm DESC;
GO
-- 51.2 ¿Algún MT con Pb o Sn CRÍTICO (>LC) ahora? (antes: imposible, LC no existía)
SELECT Proyecto, Equipo, Compartimiento, Pb_ppm, Pb_LC, Estado_Pb, Sn_ppm, Sn_LC, Estado_Sn
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE Estado_Pb='CRITICO' OR Estado_Sn='CRITICO';
GO
-- 51.3 Último análisis de un MT: la tabla ya trae LC de Pb/Sn (no '—') y chip si supera
SELECT MD FROM [dbo].[vw_UltimoAnalisisMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3163%' AND compAbbr LIKE '%MT RH%';   -- CA3163 tenía Pb,Zn observados en triage
GO

-- ==== BLOQUE 52 — VALIDAR Pb/Sn LC en BARRIDO (vw_ObservadosFlota) ====
-- Re-correr en orden: vw_ObservadosFlota -> vw_ObservadosResumen -> vw_ObservadosResumenMD / vw_ObservadosBarridoMD.
GO
-- 52.1 ¿Mets_Obs ahora incluye Pb:C / Sn:C donde el ppm supera LC?
SELECT TOP 20 Equipo, Compartimiento, NumCrit, NumPrec, Mets_Obs
FROM [dbo].[vw_ObservadosFlota] WITH (NOLOCK)
WHERE Proyecto='Antapaccay' AND Compartimiento LIKE '%TRACCION%'
  AND (Mets_Obs LIKE '%Pb:C%' OR Mets_Obs LIKE '%Sn:C%')
ORDER BY NumCrit DESC;
GO
-- 52.2 Barrido resumen de Antapaccay 980E (los Pb/Sn crít deben contar en 🔴 Crít, no en 🟡 Prec)
SELECT MD FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';
GO

-- ==== BLOQUE 53 — VALIDAR salud (V100/viscosidad) en la fundación ====
-- Re-correr: vw_LimitesPorComponente -> vw_MuestrasEstado. V100 fuera de rango [LCI,LCS] = CRITICO.
GO
-- 53.1 ¿Estado_V100 marca crítico/precaución donde V100 sale del rango? (Antapaccay MT: LCI=70.1 LCS=85.7)
SELECT TOP 30 Proyecto, Equipo, Compartimiento, V100, V100_LCI, V100_LCS, Estado_V100, Estado_General
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE Estado_V100 IN ('CRITICO','PRECAUCION')
ORDER BY Estado_V100, Proyecto, Equipo;
GO
-- 53.2 IMPACTO: ¿cuántos componentes NUEVOS pasan a observado SOLO por V100?
--      (Estado_General<>OK pero ningún metal de desgaste fuera — el disparo es la viscosidad)
SELECT COUNT(*) AS SoloPorV100
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE rn_recencia=1 AND Estado_V100<>'OK'
  AND Fe_ppm<=ISNULL(Fe_LP,9999) AND Cr_ppm<=ISNULL(Cr_LP,9999) AND Cu_ppm<=ISNULL(Cu_LP,9999)
  AND Pb_ppm<=ISNULL(Pb_LP,9999) AND Sn_ppm<=ISNULL(Sn_LP,9999);
GO

-- ==== BLOQUE 54 — #6b salud V100 (viscosidad) informativa en barrido detalle ====
SELECT Modelo, MD FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%';   -- busca ' V100=' en el MD (chip salud en equipos ya observados)
GO
SELECT
  SUM(CASE WHEN Estado_General <> 'OK' THEN 1 ELSE 0 END) AS Observados_totales,
  SUM(CASE WHEN Estado_General <> 'OK' AND Estado_V100 IN ('CRITICO','PRECAUCION') THEN 1 ELSE 0 END) AS Con_V100_salud,
  SUM(CASE WHEN Estado_General =  'OK' AND Estado_V100 IN ('CRITICO','PRECAUCION') THEN 1 ELSE 0 END) AS Solo_V100_excluidos
FROM [dbo].[vw_ObservadosFlota] WITH (NOLOCK) WHERE Proyecto LIKE '%Antapaccay%';
GO

-- ==== BLOQUE 55 — #14 vw_TendenciaIncipienteMD (firma proyecto, flujo MD_flota modelo=todos) ====
-- FIX gerencia 2026-08-14: baseline = promedio de las 6 PREVIAS (rn 2..7), SIN el ultimo (rn 1); total 7 muestras.
-- + tabla 'Limites de referencia (ppm)' aparte (LP/LC de los metales incipientes), como en Tendencia.
SELECT Observados, Recomendaciones, MD FROM [dbo].[vw_TendenciaIncipienteMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%';
GO

-- ==== BLOQUE 56 — Barrido: (todos) sin modelo Y por-modelo especifico (duplicacion) ====
SELECT Modelo, MD FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%';
GO
SELECT Modelo, MD FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980%';
GO
SELECT DISTINCT Modelo FROM [dbo].[vw_ObservadosResumenMD] WITH (NOLOCK) WHERE Proyecto LIKE '%Antapaccay%';
GO

-- ==== BLOQUE 57 — Triage recos: solo metales de la tabla (sin Calcio/Zinc informativos) ====
SELECT MD, Recomendaciones FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%';
GO

-- ==== BLOQUE 58 — Historial INCLUYE DDI (unico topico con DDI; vw_MuestrasHistorial + rn_hist) ====
SELECT TOP 15 Equipo, Compartimiento, FechaMuestreo, CM, EsDDI, rn_hist
FROM [dbo].[vw_MuestrasHistorial] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND Compartimiento LIKE '%TRACCION%LH' ORDER BY rn_hist;
GO
SELECT MD FROM [dbo].[vw_HistorialMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3171%' AND compAbbr = 'MT LH';   -- las vistas MD filtran por compAbbr
GO

-- ==== BLOQUE 59 — vw_ConteoFlotaMD (Conteo; flujo MD_flota; proyecto + modelo) ====
SELECT Modelo, MD FROM [dbo].[vw_ConteoFlotaMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%';
GO
-- por-modelo: cambia '%todos%' por '%980%' (o el modelo real del proyecto)

-- ==== BLOQUE 60 — vw_RankingMD (formato largo; el flujo MD_ranking arma la tabla con pos<=top) ====
SELECT MAX(HeaderMD) + NCHAR(10) + STRING_AGG(Fila, NCHAR(10)) WITHIN GROUP (ORDER BY pos) AS MD
FROM [dbo].[vw_RankingMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%traccion%' AND Metal LIKE '%Fe%' AND pos <= 5;
GO
-- cambia 'pos <= 5' por 10 para top 10; cambia Metal/CompTipo para otros rankings

-- ==== BLOQUE 61 — Tendencia con Grado (lubricante) + horas comp ====
SELECT MD FROM [dbo].[vw_TendenciaMetalMD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3170%' AND Parametro='Fe';       -- tabla trae Grado + Hrs C. por componente
GO
SELECT MD FROM [dbo].[vw_TendenciaP1MD] WITH (NOLOCK)
WHERE Equipo LIKE '%CA3170%' AND compAbbr='MT LH';     -- info general incluye fila Grado
GO

-- ==== BLOQUE 62 — vw_TendenciaMetalFlotaMD (Gap1; flujo MD_metal_flota; proyecto+CompTipo+Metal) ====
SELECT MD FROM [dbo].[vw_TendenciaMetalFlotaMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%traccion%' AND Metal LIKE '%Fe%';
GO
-- '¿como evoluciono el Fe en los MT de la flota?' -> dirección por equipo. Cambia Metal/CompTipo.

-- ==== BLOQUE 63 — vw_CondicionCompMD (Gap2; flujo MD_metal_flota sin parametro; proyecto+CompTipo) ====
SELECT MD FROM [dbo].[vw_CondicionCompMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%hidraul%';
GO
-- '¿que sistemas hidraulicos necesitan atencion?' -> equipos con hidraulico observado. Cambia CompTipo.

-- ==== BLOQUE 64 — vw_UltimoMetalFlotaMD (Ultimo analisis en barrido por metal; 1..N metales) ====
-- 1 metal (como '¿ultimo analisis de hierro de todos los MT en Antamina?'):
SELECT MD FROM [dbo].[vw_UltimoMetalFlotaMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antamina%' AND Modelo LIKE '%todos%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%traccion%'
  AND CHARINDEX(',' + Metal + ',', ',' + 'Fe' + ',') > 0
ORDER BY MetalOrden;
GO
-- N metales (como 'hierro y cobre y cromo de los MT'): el flujo hace STRING_AGG -> 1 tabla por metal.
SELECT STRING_AGG(MD, NCHAR(10)+NCHAR(10)) WITHIN GROUP (ORDER BY MetalOrden) AS MD
FROM [dbo].[vw_UltimoMetalFlotaMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antamina%' AND Modelo LIKE '%todos%'
  AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%traccion%'
  AND CHARINDEX(',' + Metal + ',', ',' + 'Fe,Cu,Cr' + ',') > 0;
GO
-- Por modelo especifico (Modelo LIKE '%980E%' en vez de '%todos%'); ordena por valor desc dentro de cada metal.
-- Informativos (Ca/Zn/K/Na/Mg/B/P/V100) salen con 'inf' sin chip; TBN inverso (🟨 si < LP).
-- SIN columna "Estado" (el chip del valor ya lo indica; conteo observados/criticos en el encabezado).
-- El semaforo juzga contra el LP/LC de REFERENCIA del grupo cuando el limite propio de la fila es NULL
-- (evita falsos "OK" en valores altos de equipos sin limite cargado). CM se mantiene (aun sin data en Antamina).
-- ⚠️ junto al valor = metal en 0.0 (muestra no-DDI, posible falso positivo; el area lo revisa aparte).
-- Recomendaciones: el view la llena SOLO si CompTipo=TRACCION y el metal salio observado (verbatim vw_Recomendaciones);
-- el flujo agrega con cabecera MT (ver BLOQUE del flujo). Verificar que en no-MT / sin observados venga NULL:
SELECT Metal, CompTipo, Recomendaciones FROM [dbo].[vw_UltimoMetalFlotaMD] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antamina%' AND Modelo LIKE '%todos%' AND CompTipo COLLATE Latin1_General_CI_AI LIKE '%traccion%'
  AND CHARINDEX(',' + Metal + ',', ',' + 'Fe,Cu' + ',') > 0;
GO

-- ==== BLOQUE 65 — vw_AcumuladosFlotaMD (wrapper del Ranking de Atencion / acumulados motor diesel) ====
-- Requiere que vw_RankingAtencion exista en la BD (dashboard PBI). Alcance: Antapaccay motor diesel.
SELECT MD FROM [dbo].[vw_AcumuladosFlotaMD] WITH (NOLOCK) WHERE Proyecto LIKE '%Antapaccay%';
GO
-- Verifica: tabla ordenada por Ranking desc, # = posicion, metales Acum + H.Motor/H.Metal. SIN Estado (pendiente regla).
-- Sanity: comparar el orden/valores contra el dashboard (BLOQUE de vw_RankingAtencion en su propio .sql).
