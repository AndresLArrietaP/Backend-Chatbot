/* ============================================================================
   KomfIA — Índices para el patrón "último análisis por equipo + compartimiento"
   Base: bd_kmmp_osconfiabilidad  (Azure SQL)
   Objetivo: acelerar condición/triage/tendencia/ranking y soportar el desempate
             determinístico (FechaMuestreo DESC, LaboratoryDataId DESC).
   Riesgo: bajo. Reversible con DROP INDEX. Tabla de carga por lote (no OLTP).
   ----------------------------------------------------------------------------
   NOTA Azure: WITH (ONLINE = ON, DATA_COMPRESSION = PAGE) requiere un tier que lo
   soporte (no Basic/S0-S2). Si da error, ejecuta la misma sentencia SIN el WITH(...).
   ============================================================================ */

/* 1) ÍNDICE PRINCIPAL — cubre el window function + el SELECT (el más importante)
   PARTITION BY (MiningEquipmentId, Compartimiento) + ORDER BY (FechaMuestreo DESC,
   LaboratoryDataId DESC) → SQL Server obtiene la última muestra sin sort.
   El INCLUDE evita key lookups al traer los metales/propiedades del SELECT. */
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

/* 2) ÍNDICE DE APOYO (opcional) — lookups por código de equipo (ej: ME.[Code]='CA3164')
   y para resolver los JOINs a proyecto/flota sin tocar la tabla base.
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

/* ----------------------------------------------------------------------------
   Para revertir si fuera necesario:
   DROP INDEX IX_LabData_UltimaMuestra ON [Oil].[LaboratoryData];
   DROP INDEX IX_MiningEquipment_Code ON [Mine].[MiningEquipment];
   ----------------------------------------------------------------------------
   Verificación rápida tras crear (mira el plan: debe desaparecer el Sort y el
   Key Lookup en la consulta de "último análisis"):
       SET STATISTICS IO, TIME ON;
       -- corre aquí tu consulta de condición de un equipo
   ---------------------------------------------------------------------------- */
