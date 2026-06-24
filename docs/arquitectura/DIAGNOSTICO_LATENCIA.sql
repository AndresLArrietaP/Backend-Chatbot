/* ============================================================================
   KomfIA — DIAGNÓSTICO DE LATENCIA  (bd_kmmp_osconfiabilidad, Azure SQL)
   Objetivo: averiguar DÓNDE se va el tiempo. Hay 3 tramos posibles:
     (1) BD        — lo que tarda SQL Server en calcular y devolver las filas.
     (2) LLM-gen   — lo que tarda «KomfIA SQL» (Sonnet) en ESCRIBIR el SELECT.
     (3) Render    — lo que tarda «KomfIA Central» en PINTAR la tabla en el chat.
   Este archivo mide (1). Para (2) y (3) ver el BLOQUE L0 (metodología).
   Hipótesis del usuario: la data se obtiene rápido; el cuello está en (3) render.
   Estos bloques sirven para CONFIRMARLO con números.

   CÓMO MEDIR BIEN (importante):
   - Antes de cada bloque, activa:  SET STATISTICS TIME ON;  SET STATISTICS IO ON;
     (ya van incluidos). Mira en la pestaña «Messages»: «elapsed time» = reloj de pared
     del servidor; «CPU time» = cómputo puro; «logical reads» = páginas leídas (esfuerzo).
   - CORRE CADA BLOQUE 2 VECES. La 1ª paga «cold cache» (Azure levanta páginas a memoria);
     usa la 2ª (warm) como número real. La 1ª corrida también incluye el cold-start de Azure.
   - Para separar «cómputo del servidor» de «transferencia de filas a SSMS», usa la
     variante con  SELECT ... INTO #t  (materializa en el server, sin pintar grid) que
     aparece comentada en los bloques pesados.
   - Activa el PLAN REAL (Ctrl+M, o «Include Actual Execution Plan») en L4/L5/L6 y mira
     qué operador se lleva el mayor % (Scan, el Sort del ROW_NUMBER, o el Nested Loops de
     la subconsulta de HorasComponente).
   Requisito: haber corrido la versión vigente de DDL_vistas.sql.
   ============================================================================ */


/* ----------------------------------------------------------------------------
   L0 — METODOLOGÍA de atribución (no se ejecuta; es para interpretar)
   Para cada consulta del chat tienes 3 relojes:
     A = «elapsed time» aquí en SSMS (warm)              → tramo (1) BD
     B = tiempo del nodo «KomfIA SQL / TEST-SQL-V2» en la traza de Copilot
     C = tiempo TOTAL hasta que aparece la respuesta pintada
   Entonces (aprox.):
     LLM-gen (2)  ≈  B − A − (overhead del conector, ~1-3s)
     Render  (3)  ≈  C − B
   Lectura rápida:
     - Si A es chico (p.ej. 2-5s) y B es grande (p.ej. 30s) → el cuello es (2) LLM-gen
       del SELECT (prompt largo / modelo lento), NO la BD.
     - Si C − B es grande (p.ej. +20s) y crece con el nº de filas/columnas → el cuello
       es (3) render del central (tabla muy grande). ← hipótesis del usuario.
     - Si A ya es grande → entonces sí, la BD; ataca con L4-L8.
   Apunta A, B, C de: conteo, último, diagnóstico, triage, barrido-detalle, tendencia,
   historial-flota. Con esa tabla decidimos dónde invertir (vista vs Formatos/render).
   ---------------------------------------------------------------------------- */


/* ----------------------------------------------------------------------------
   L1 — TAMAÑO Y FORMA DE LOS DATOS (cuánto se escanea de raíz)
   ---------------------------------------------------------------------------- */
SELECT COUNT(*) AS Filas_LaboratoryData FROM [Oil].[LaboratoryData] WITH (NOLOCK);
GO
SELECT
    MIN(FechaMuestreo) AS Desde, MAX(FechaMuestreo) AS Hasta,
    COUNT(*) AS Total,
    SUM(CASE WHEN FechaMuestreo >= DATEADD(DAY,-90,GETDATE()) THEN 1 ELSE 0 END) AS Ult_90d,
    COUNT(DISTINCT MiningEquipmentId) AS Equipos,
    COUNT(DISTINCT Compartimiento)    AS Compartimientos
FROM [Oil].[LaboratoryData] WITH (NOLOCK);
GO
SELECT COUNT(*) AS Filas_HsCc FROM [Eqpcare].[HsCc] WITH (NOLOCK);
SELECT COUNT(*) AS Filas_lc   FROM [Eqpcare].[lc]   WITH (NOLOCK);
GO


/* ----------------------------------------------------------------------------
   L2 — ⭐ CRONÓMETRO DE LAS CONSULTAS REALES (el "A" de cada tópico)
   Corre 2 veces; anota el «elapsed time» (warm) de cada una y compáralo con el
   tiempo del nodo flow en Copilot (B). Si A << B → el problema NO es la BD.
   ---------------------------------------------------------------------------- */
SET STATISTICS TIME ON; SET STATISTICS IO ON;

-- L2.1 Conteo de flota (en el chat tardó ~24s)
SELECT ME.[Code] AS Equipo, MP.[Name] AS Proyecto, EF.[Model] AS Modelo, COUNT(*) OVER() AS Total
FROM [Mine].[MiningEquipment] ME WITH (NOLOCK)
JOIN [Mine].[EquipmentFleet] EF ON EF.[Id]=ME.[EquipmentFleetId]
JOIN [Mine].[MiningProject]  MP ON MP.[Id]=ME.[MiningProjectId]
WHERE MP.[Name] LIKE '%Antapaccay%' AND EF.[Model] LIKE '%980E%' ORDER BY ME.[Code];
GO
-- L2.2 Último análisis 1 compartimiento (chat ~24-30s)
SELECT * FROM [dbo].[vw_UltimoAnalisisAceite] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH';
GO
-- L2.3 Diagnóstico 1 equipo (chat ~34s) — el que más se cortaba
SELECT * FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK) WHERE Equipo='CA3177' ORDER BY Compartimiento;
GO
-- L2.4 Triage MT proyecto (chat ~58s)
SELECT TOP 500 * FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%' AND Estado_General<>'OK'
ORDER BY CASE Estado_General WHEN 'CRITICO' THEN 1 ELSE 2 END, Fe_ppm DESC;
GO
-- L2.5 Barrido DETALLE "de todos" (chat ~70s) — el más pesado
SELECT * FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
ORDER BY NumCrit DESC, NumPrec DESC, Equipo, Compartimiento;
GO
-- L2.6 Tendencia PASO 2 (chat ~21-42s)
SELECT * FROM [dbo].[vw_TendenciaElemento] WITH (NOLOCK)
WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH' ORDER BY Orden;
GO
-- L2.7 Historial flota (ya medido ~4s; control)
SELECT * FROM [dbo].[vw_HistorialFlotaObs] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%' ORDER BY FechaMuestreo DESC;
GO

SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO


/* ----------------------------------------------------------------------------
   L3 — VARIANTE "solo cómputo de servidor" (sin transferir filas a SSMS)
   Si L2.5 fue lento, corre esto: SELECT ... INTO #t mide el cómputo puro del server.
   Si #t es MUCHO más rápido que L2.5 → buena parte era transferencia de filas
   (y entonces el conector de Copilot también la paga: conviene devolver MENOS filas).
   ---------------------------------------------------------------------------- */
SET STATISTICS TIME ON;
SELECT * INTO #t_detalle FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%';
SELECT COUNT(*) AS Filas_devueltas FROM #t_detalle;
DROP TABLE #t_detalle;
SET STATISTICS TIME OFF;
GO


/* ----------------------------------------------------------------------------
   L4 — AISLAR LA FUNDACIÓN, CAPA POR CAPA  (activa el PLAN REAL, Ctrl+M)
   Mide cada nivel para ver cuál dispara el tiempo.
   ---------------------------------------------------------------------------- */
SET STATISTICS TIME ON; SET STATISTICS IO ON;

-- L4.1 Scan crudo de la tabla base (piso de todo)
SELECT COUNT(*) FROM [Oil].[LaboratoryData] LD WITH (NOLOCK);
GO
-- L4.2 Join de 4 tablas (réplica del CTE 'muestras', sin Estado/lc/ROW_NUMBER)
SELECT COUNT(*)
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id]=LD.[MiningEquipmentId]
INNER JOIN [Mine].[MiningProject]   MP ON MP.[Id]=ME.[MiningProjectId]
INNER JOIN [Mine].[EquipmentFleet]  EF ON EF.[Id]=ME.[EquipmentFleetId];
GO
-- L4.3 vw_LimitesPorComponente sola (GROUP BY sobre lc) — debería ser barata
SELECT * FROM [dbo].[vw_LimitesPorComponente] WITH (NOLOCK);
GO
-- L4.4 vw_MuestrasEstado COMPLETA (lc join + 16 CASE Estado + ROW_NUMBER sobre TODO)
SELECT COUNT(*) FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK);
GO
-- L4.5 vw_MuestrasRankeadas (= MuestrasEstado sin DDI + subconsulta HorasComponente)
SELECT COUNT(*) FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK);
GO

SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO


/* ----------------------------------------------------------------------------
   L5 — AISLAR EL COSTO DE LA SUBCONSULTA HorasComponente (a [Eqpcare].[HsCc])
   Mismas filas (la última de cada equipo+comp), CON y SIN HorasComponente.
   El delta de «elapsed»/«logical reads» = costo de la subconsulta correlacionada.
   Si es grande, es candidato nº1 a optimizar (convertir a JOIN/APPLY agregado).
   ---------------------------------------------------------------------------- */
SET STATISTICS TIME ON; SET STATISTICS IO ON;
-- SIN HorasComponente (directo sobre la fundación)
SELECT Equipo, Compartimiento, FechaMuestreo, Estado_General
FROM [dbo].[vw_MuestrasEstado] WITH (NOLOCK)
WHERE EsDDI=0 AND rn_recencia=1;
GO
-- CON HorasComponente (vía rankeadas → corre la subconsulta)
SELECT Equipo, Compartimiento, FechaMuestreo, HorasComponente, Estado_General
FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
WHERE rn_recencia=1;
GO
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO


/* ----------------------------------------------------------------------------
   L6 — HIPÓTESIS DE OPTIMIZACIÓN: ¿una VENTANA DE FECHA acelera la fundación?
   La fundación hoy escanea TODO el histórico para el ROW_NUMBER. Si casi todo el
   uso real es "lo reciente", acotar a, p.ej., 120 días podría bajar mucho el costo.
   Esto NO cambia ninguna vista; solo MIDE el potencial (compara con L4.4).
   ---------------------------------------------------------------------------- */
SET STATISTICS TIME ON; SET STATISTICS IO ON;
SELECT COUNT(*)
FROM [Oil].[LaboratoryData] LD WITH (NOLOCK)
INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id]=LD.[MiningEquipmentId]
INNER JOIN [Mine].[MiningProject]   MP ON MP.[Id]=ME.[MiningProjectId]
INNER JOIN [Mine].[EquipmentFleet]  EF ON EF.[Id]=ME.[EquipmentFleetId]
WHERE LD.[FechaMuestreo] >= DATEADD(DAY,-120,GETDATE());   -- vs sin filtro (L4.2)
SET STATISTICS TIME OFF; SET STATISTICS IO OFF;
GO


/* ----------------------------------------------------------------------------
   L7 — ÍNDICES: qué hay y qué pide el optimizador
   (La BD es de solo lectura para nosotros: NO podemos crear índices, pero esto
    sirve para SUSTENTAR ante el DBA qué índice ayudaría, o para DDL_indices.sql.)
   Puede requerir permiso VIEW DATABASE STATE; si falla, omite L7.2/L7.3.
   ---------------------------------------------------------------------------- */
-- L7.1 Índices existentes en las tablas base
SELECT t.name AS Tabla, i.name AS Indice, i.type_desc,
       STUFF((SELECT ', '+c.name FROM sys.index_columns ic
              JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
              WHERE ic.object_id=i.object_id AND ic.index_id=i.index_id AND ic.is_included_column=0
              ORDER BY ic.key_ordinal FOR XML PATH('')),1,2,'') AS Columnas_clave
FROM sys.indexes i JOIN sys.tables t ON t.object_id=i.object_id
WHERE t.name IN ('LaboratoryData','MiningEquipment','MiningProject','EquipmentFleet','HsCc','lc')
ORDER BY t.name, i.index_id;
GO
-- L7.2 Índices que el optimizador "desearía" (lo más útil para la fundación)
SELECT TOP 20
       ROUND(s.avg_total_user_cost * s.avg_user_impact * (s.user_seeks+s.user_scans),0) AS Beneficio,
       d.statement AS Tabla, d.equality_columns, d.inequality_columns, d.included_columns,
       s.user_seeks, s.user_scans
FROM sys.dm_db_missing_index_group_stats s
JOIN sys.dm_db_missing_index_groups g ON s.group_handle=g.index_group_handle
JOIN sys.dm_db_missing_index_details d ON g.index_handle=d.index_handle
ORDER BY Beneficio DESC;
GO
-- L7.3 Estadísticas de uso de índices (¿se usan o solo pesan en escritura?)
SELECT OBJECT_NAME(s.object_id) AS Tabla, i.name AS Indice,
       s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
FROM sys.dm_db_index_usage_stats s JOIN sys.indexes i
     ON i.object_id=s.object_id AND i.index_id=s.index_id
WHERE OBJECT_NAME(s.object_id) IN ('LaboratoryData','HsCc')
ORDER BY Tabla, s.user_seeks DESC;
GO


/* ============================================================================
   CÓMO DECIDIR CON LOS RESULTADOS
   - L2 vs traza Copilot (L0): si los "A" (SSMS warm) son chicos y los "B/C" del chat
     son grandes → invertir en RENDER (Formatos más compactos / menos filas-columnas /
     conocimiento dedicado a pintar) y en acortar el prompt de KomfIA SQL (LLM-gen).
   - Si algún "A" es grande: mira L4 para ubicar la capa; L5 para HorasComponente;
     L6 para ver si una ventana de fecha en la fundación lo arregla; L7 para índices.
   - Reglas de pulgar de payload (afectan render y transferencia):
       barrido detalle "de todos" → ya pasa a SOLO críticos por defecto;
       diagnóstico → ya pasa a solo componentes observados;
       tendencia/historial → columnas mínimas.
   ============================================================================ */
