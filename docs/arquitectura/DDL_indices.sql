/* ============================================================================
   KomfIA — ÍNDICES  (archivo ÚNICO: desplegados + propuestos)
   Base: bd_kmmp_osconfiabilidad  (Azure SQL)
   Consolidado 2026-09-27: absorbe el antiguo INDICES_PROPUESTOS.sql (10/07/26).
   ----------------------------------------------------------------------------
   ⚠ La BD es SOLO-LECTURA para el proyecto: CREATE INDEX = ALTER en la tabla y
     requiere permiso del DBA. Los índices son ADITIVOS y REVERSIBLES (DROP al
     final); no cambian datos ni el esquema lógico.
   ⚠ NOTA Azure: WITH (ONLINE = ON, DATA_COMPRESSION = PAGE) requiere un tier que
     lo soporte (no Basic/S0-S2). Si da error, corre la sentencia SIN el WITH(...).
   ----------------------------------------------------------------------------
   POR QUÉ: el cuello de los módulos de flota está en la FUNDACIÓN
   vw_MuestrasEstado → escanea [Oil].[LaboratoryData] con ventana de 12 meses y
   window functions:
       ROW_NUMBER()/DENSE_RANK() OVER (PARTITION BY MiningEquipmentId,
            Compartimiento, EsDDI, CAST(FechaMuestreo AS date)
            ORDER BY LaboratoryDataId / FechaMuestreo DESC)
   El window fuerza un SORT masivo y bloquea el pushdown del filtro de equipo.
   Hay además un JOIN a [Eqpcare].[HsCc] con otro ROW_NUMBER (EQUIPO, SISTEMA,
   FECHA). Estos índices entregan el orden ya listo y aceleran el seek.
   ============================================================================ */


-- ============================================================================
-- § 1 · DESPLEGADOS EN PRODUCCIÓN  (creados por el DBA; verificar con § 4)
-- ============================================================================

/* 1.1 ÍNDICE PRINCIPAL — cubre el window function + el SELECT (el más importante).
   PARTITION BY (MiningEquipmentId, Compartimiento) + ORDER BY (FechaMuestreo DESC,
   LaboratoryDataId DESC) → SQL Server obtiene la última muestra sin sort.
   El INCLUDE evita key lookups al traer los metales/propiedades del SELECT.
   Estado: VIVO (confirmado 19/08/26, bloque L8.1 de DIAGNOSTICO_LATENCIA.sql). */
CREATE NONCLUSTERED INDEX IX_LabData_UltimaMuestra
ON [Oil].[LaboratoryData]
(
    [MiningEquipmentId],
    [Compartimiento],
    [FechaMuestreo]      DESC,
    [LaboratoryDataId]   DESC
)
INCLUDE
(
    [CM], [Grado], [Horometro], [HorasDeAceite], [HorasA], [HorasB],
    [Fe_ppm], [Cr_ppm], [Cu_ppm], [Ni_ppm], [Pb_ppm], [Sn_ppm], [Si_ppm], [Al_ppm],
    [Ca_ppm], [Zn_ppm], [K_ppm], [Mg_ppm], [B_ppm], [P_ppm], [Indice_PQ], [TBN], [V100]
)
WITH (ONLINE = ON, DATA_COMPRESSION = PAGE);
GO

/* 1.2 ÍNDICE DE APOYO — lookups por código de equipo (ej: ME.[Code] = 'CA3164') y
   para resolver los JOINs a proyecto/flota sin tocar la tabla base.
   Tabla pequeña (cientos de filas) → impacto menor, pero útil y barato. */
CREATE NONCLUSTERED INDEX IX_MiningEquipment_Code
ON [Mine].[MiningEquipment]
(
    [Code]
)
INCLUDE
(
    [Id], [MiningProjectId], [EquipmentFleetId]
)
WITH (ONLINE = ON);
GO


-- ============================================================================
-- § 2 · PROPUESTOS — NO desplegados. Gated DBA.
--       Origen: INDICES_PROPUESTOS.sql (10/07/26), ronda de velocidad del
--       barrido de Antamina (~60 equipos rondaba 2 min).
--       ⚠ Antes de pedirlos: las rondas del 19/08 y del 25/09 demostraron que
--       buena parte de esa latencia NO era de índices sino del patrón de la
--       vista (CTE referenciado 2× con JOIN entre sus ramas → nested loops).
--       Curar la vista primero; pedir índices solo si el plan real lo pide.
-- ============================================================================

-- 2.0 ⭐ URGENTE (30/09) — extender el INCLUDE del índice principal §1.1 con las 13 columnas que la
--     fundación lee desde el bloque D (28/09). Sin ellas el índice dejó de CUBRIR: cada vista por
--     equipo va a la tabla base o la recorre entera (/diagcompleto: 76 936 páginas para UN camión;
--     /condicionmt y /diagcompleto en FlowActionTimedOut). Misma clave: no cambia ningún plan de
--     orden, solo evita la tabla base. ONLINE = ON: no bloquea lecturas mientras se reconstruye.
--     Evidencia: VALIDACION_SSMS.sql BLOQUE 175.
-- CREATE NONCLUSTERED INDEX IX_LabData_UltimaMuestra
-- ON [Oil].[LaboratoryData] ([MiningEquipmentId], [Compartimiento], [FechaMuestreo] DESC, [LaboratoryDataId] DESC)
-- INCLUDE ([CM], [Grado], [Horometro], [HorasDeAceite], [HorasA], [HorasB],
--          [Fe_ppm], [Cr_ppm], [Cu_ppm], [Ni_ppm], [Pb_ppm], [Sn_ppm], [Si_ppm], [Al_ppm],
--          [Ca_ppm], [Zn_ppm], [K_ppm], [Mg_ppm], [B_ppm], [P_ppm], [Indice_PQ], [TBN], [V100],
--          [Viscosidad40], [TAN], [Oxidacion], [Sulfatacion], [Nitracion], [Mo_ppm],
--          [Agua], [Hollin], [Diesel], [Refrigerante], [Iso4406_4], [Iso4406_6], [Iso4406_14])
-- WITH (DROP_EXISTING = ON, ONLINE = ON, DATA_COMPRESSION = PAGE);

-- 2.1 LaboratoryData — variante angosta del principal (si 1.1 resultara muy pesado)
-- CREATE NONCLUSTERED INDEX IX_LaboratoryData_Equipo_Comp_Fecha
-- ON [Oil].[LaboratoryData] (MiningEquipmentId, Compartimiento, FechaMuestreo DESC)
-- INCLUDE (LaboratoryDataId, CM);
-- GO

-- 2.2 LaboratoryData — apoyo al FILTRO de 12 meses en escaneos de FLOTA (barrido,
--     que no filtra por equipo y poda solo por FechaMuestreo >= -12 meses)
-- CREATE NONCLUSTERED INDEX IX_LaboratoryData_Fecha
-- ON [Oil].[LaboratoryData] (FechaMuestreo DESC)
-- INCLUDE (MiningEquipmentId, Compartimiento, LaboratoryDataId, CM);
-- GO

-- 2.3 [Eqpcare].[HsCc] — el JOIN de «Hor. Comp.» (ROW_NUMBER por EQUIPO, SISTEMA, FECHA)
-- CREATE NONCLUSTERED INDEX IX_HsCc_Equipo_Sistema_Fecha
-- ON [Eqpcare].[HsCc] (EQUIPO, SISTEMA, FECHA DESC);
-- GO

-- 2.4 [Eqpcare].[lc] — join de límites por proyecto+componente. Tabla chica; un
--     scan suele ser barato. Crear SOLO si el plan muestra que pesa.
-- CREATE NONCLUSTERED INDEX IX_lc_Proyecto_Componente
-- ON [Eqpcare].[lc] (Proyecto, COMPONENTE, MODELO);
-- GO


-- ============================================================================
-- § 3 · CÓMO MEDIR (antes y después). Correr 2 veces; usar la 2ª (warm).
-- ============================================================================
-- SET STATISTICS IO ON; SET STATISTICS TIME ON;
-- GO
-- -- Barrido de flota (el caso lento):
-- SELECT MD FROM [dbo].[vw_ObservadosBarridoMD] WITH (NOLOCK)
-- WHERE Proyecto LIKE '%Antamina%' AND Modelo LIKE '%todos%';
-- GO
-- -- Triage MT de flota:
-- SELECT MD FROM [dbo].[vw_TriageMD] WITH (NOLOCK)
-- WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%todos%' AND CompTipo = 'TRACCION';
-- GO
-- SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
-- GO
-- ⚠ MEDIR CON EL OPERADOR DE PRODUCCIÓN (LIKE '%x%'), nunca con '='. La diferencia
--   medida fue de 5× y escondió una regresión hasta que estalló como FlowActionTimedOut.


-- ============================================================================
-- § 4 · VERIFICAR / REVERTIR
-- ============================================================================
-- ¿Siguen vivos los índices desplegados?
-- SELECT i.name AS Indice, i.type_desc, i.is_disabled
-- FROM sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id
-- WHERE t.name IN ('LaboratoryData','MiningEquipment','HsCc') AND i.name LIKE 'IX_%';
-- GO
-- ¿Se están usando?  (seeks/scans desde el último reinicio del servidor)
-- SELECT OBJECT_NAME(s.object_id) AS Tabla, i.name AS Indice,
--        s.user_seeks, s.user_scans, s.user_lookups, s.user_updates
-- FROM sys.dm_db_index_usage_stats s
--      JOIN sys.indexes i ON i.object_id = s.object_id AND i.index_id = s.index_id
-- WHERE OBJECT_NAME(s.object_id) IN ('LaboratoryData','HsCc','MiningEquipment')
-- ORDER BY Tabla, s.user_seeks DESC;
-- GO
--
-- DROP INDEX IX_LabData_UltimaMuestra            ON [Oil].[LaboratoryData];
-- DROP INDEX IX_MiningEquipment_Code             ON [Mine].[MiningEquipment];
-- DROP INDEX IX_LaboratoryData_Equipo_Comp_Fecha ON [Oil].[LaboratoryData];
-- DROP INDEX IX_LaboratoryData_Fecha             ON [Oil].[LaboratoryData];
-- DROP INDEX IX_HsCc_Equipo_Sistema_Fecha        ON [Eqpcare].[HsCc];
-- DROP INDEX IX_lc_Proyecto_Componente           ON [Eqpcare].[lc];


/* ============================================================================
   NOTAS
   - Costo: ocupan espacio y ralentizan un poco los INSERT del laboratorio. Para
     una BD analítica de lectura intensiva el trade-off es favorable.
   - Alternativa SIN permiso de DBA: materializar el barrido en una tabla/vista
     indexada refrescada por un job → cambio de arquitectura, se evalúa aparte.
   - Diagnóstico de latencia paso a paso: DIAGNOSTICO_LATENCIA.sql (bloques L0-L8).
   ============================================================================ */
