/* ============================================================================
   INDICES PROPUESTOS — optimización de velocidad (barrido Antamina y módulos por-equipo)
   KMMP / bd_kmmp_osconfiabilidad
   ----------------------------------------------------------------------------
   ⚠ GATED: requiere permiso del DBA (CREATE INDEX = ALTER en las tablas Oil/Eqpcare).
   La BD venía como SOLO-LECTURA para el proyecto; NO ejecutar hasta confirmar permiso.
   Son ADITIVOS y REVERSIBLES (DROP al final). No cambian datos ni el esquema lógico.

   PORQUÉ: el cuello de la lentitud (Antamina ~60 equipos, rondaba 2 min) está en la
   FUNDACIÓN vw_MuestrasEstado → escanea [Oil].[LaboratoryData] filtrando por FechaMuestreo
   (12 meses) y aplica window functions:
       ROW_NUMBER()/DENSE_RANK() OVER (PARTITION BY MiningEquipmentId, Compartimiento, EsDDI,
                                       CAST(FechaMuestreo AS date) ORDER BY LaboratoryDataId/FechaMuestreo DESC)
   El window fuerza un SORT masivo y bloquea el pushdown del filtro de equipo. Además hay
   un JOIN a [Eqpcare].[HsCc] con otro ROW_NUMBER (PARTITION BY EQUIPO,SISTEMA ORDER BY FECHA).
   Estos índices dan a esos operadores el orden ya listo (menos sort) y aceleran el seek.

   CÓMO MEDIR (antes y después): correr una consulta representativa con métricas ON.
   ============================================================================ */

-- ============================================================================
-- 0) MEDICIÓN ANTES (correr ESTO primero, anotar tiempo/lecturas, LUEGO crear índices)
-- ============================================================================
SET STATISTICS IO ON; SET STATISTICS TIME ON;
GO
-- Barrido flota Antamina (el caso lento):
SELECT * FROM [dbo].[vw_ObservadosResumen] WITH (NOLOCK)
WHERE Proyecto LIKE '%Antamina%' AND Modelo LIKE '%980%' ORDER BY NumCrit DESC, NumPrec DESC;
GO
-- Diagnóstico de 1 equipo (módulo por-equipo):
SELECT * FROM [dbo].[vw_DiagnosticoEquipo] WITH (NOLOCK) WHERE Equipo='CA3171' AND Estado_General<>'OK';
GO
SET STATISTICS IO OFF; SET STATISTICS TIME OFF;
GO


-- ============================================================================
-- 1) [Oil].[LaboratoryData] — el índice PRINCIPAL (mayor impacto)
--    Soporta: JOIN por MiningEquipmentId + PARTITION/ORDER de los window + seek por equipo.
--    Beneficia TODOS los módulos por-equipo (último, tendencia, historial, diagnóstico) y
--    el barrido (escaneo de un índice angosto pre-ordenado en vez del clustered de 105 col).
-- ============================================================================
CREATE NONCLUSTERED INDEX IX_LaboratoryData_Equipo_Comp_Fecha
ON [Oil].[LaboratoryData] (MiningEquipmentId, Compartimiento, FechaMuestreo DESC)
INCLUDE (LaboratoryDataId, CM);   -- claves del window; INCLUDE ligero (no infla el índice)
GO

-- 2) [Oil].[LaboratoryData] — apoyo al FILTRO de 12 meses en escaneos de FLOTA (barrido)
--    Para el barrido (sin filtro de equipo) que poda por FechaMuestreo >= -12 meses.
CREATE NONCLUSTERED INDEX IX_LaboratoryData_Fecha
ON [Oil].[LaboratoryData] (FechaMuestreo DESC)
INCLUDE (MiningEquipmentId, Compartimiento, LaboratoryDataId, CM);
GO

-- 3) [Eqpcare].[HsCc] — el JOIN de "Hor. Comp." (ROW_NUMBER por EQUIPO,SISTEMA ORDER BY FECHA)
CREATE NONCLUSTERED INDEX IX_HsCc_Equipo_Sistema_Fecha
ON [Eqpcare].[HsCc] (EQUIPO, SISTEMA, FECHA DESC);
GO

-- 4) (OPCIONAL, baja prioridad) [Eqpcare].[lc] — join de límites por proyecto+componente.
--    Tabla chica (límites); un scan suele ser barato. Crear SOLO si el plan muestra que pesa.
-- CREATE NONCLUSTERED INDEX IX_lc_Proyecto_Componente ON [Eqpcare].[lc] (Proyecto, COMPONENTE, MODELO);
-- GO


-- ============================================================================
-- 5) MEDICIÓN DESPUÉS (re-correr el bloque 0 con las mismas 2 consultas y comparar
--    "elapsed time" y "logical reads"). Éxito = caída notable, sobre todo en el barrido.
-- ============================================================================


-- ============================================================================
-- REVERSIBILIDAD — si algo no conviene, DROP (no deja rastro; los índices no cambian datos)
-- ============================================================================
-- DROP INDEX IX_LaboratoryData_Equipo_Comp_Fecha ON [Oil].[LaboratoryData];
-- DROP INDEX IX_LaboratoryData_Fecha             ON [Oil].[LaboratoryData];
-- DROP INDEX IX_HsCc_Equipo_Sistema_Fecha        ON [Eqpcare].[HsCc];
-- DROP INDEX IX_lc_Proyecto_Componente           ON [Eqpcare].[lc];

/* NOTAS
   - Si tras (1)+(2)+(3) el barrido sigue lento, el siguiente paso es un índice CUBRIENTE
     (INCLUDE con los _ppm/CM/etc.) sobre LaboratoryData — más pesado pero elimina los key
     lookups. Se evalúa con el plan de ejecución real (Ctrl+M en SSMS) ANTES de agregarlo.
   - Costo: los índices ocupan espacio y ralentizan un poco los INSERT del laboratorio; para
     una BD analítica de lectura intensiva el trade-off es favorable.
   - Alternativa SIN permiso de DBA (si nunca se puede indexar): materializar el barrido en
     una tabla/vista indexada refrescada por un job — cambio de arquitectura, evaluar aparte.
   ============================================================================ */
