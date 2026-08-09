/* ============================================================================
   KomfIA — VISTAS (archivo único v5: cadena completa de 13 vistas; 23-jun-2026 (HorasComponente vía JOIN pre-rankeado; fundación con VENTANA 12 MESES))
   Base: bd_kmmp_osconfiabilidad (Azure SQL)

   QUÉ AGREGA (para la "matriz única" definida por el área):
   - Ca_ppm y Zn_ppm (grupo CONTAMINANTES junto a Si) con sus límites CALCIO/ZINC de [lc]
     y Estado_Ca / Estado_Zn informativos.
   - HorasA y HorasB (passthrough): candidatos a "Horas del componente" pedido por el área
     (verificar con la query al final cuál corresponde; mientras tanto no se muestran).
   IMPORTANTE: Estado_General NO cambia (Ca/Zn/B/P quedan informativos hasta que el área
   valide que deban disparar observados) → el triage actual NO se altera.

   POR QUÉ se re-crean TODAS las vistas de la cadena: las derivadas usan SELECT * y
   SQL Server CONGELA las columnas de una vista al crearla; al agregar columnas a la
   fundación hay que refrescar las derivadas (CREATE OR ALTER las re-captura).

   ORDEN DE DEPENDENCIAS (este archivo, de corrido con F5):
     1) vw_LimitesPorComponente  2) vw_MuestrasEstado  3) vw_MuestrasRankeadas
     4) vw_UltimoAnalisisAceite  5) vw_EstadoActualMT  6) vw_ObservadosFlota (barrido + HorasComponente)
     7) vw_ObservadosResumen (RESUMEN barrido, 1 fila/equipo)  8) vw_ObservadosDetalle (DETALLE barrido, ligero)
     9) vw_UltimoAnalisisFlota (DIAGNÓSTICO por equipo: vw_UltimoAnalisisAceite + Hor. Comp. de HsCc)
    10) vw_TendenciaElemento (TENDENCIA: detalle por elemento PASO 2, pre-formateado d1..d6 + chip)
    11) vw_HistorialMuestra (HISTORIAL muestra por muestra, 2 meses, pre-formateado por fila)
    12) vw_DiagnosticoEquipo (DIAGNÓSTICO por equipo, pre-formateado con chip :C/:P)
    13) vw_HistorialFlotaObs (HISTORIAL OBSERVADOS DE FLOTA, variante 5, agregado por fecha, 30 días).
   Todo CREATE OR ALTER (reversible). Junto con DDL_indices.sql cubren toda la capa de vistas.
   ============================================================================ */
GO


/* ----------------------------------------------------------------------------
   1) vw_LimitesPorComponente — + límites de CALCIO y ZINC
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_LimitesPorComponente] AS
SELECT
    UPPER(LTRIM(RTRIM([Proyecto]))) AS ProyKey,
    UPPER(LTRIM(RTRIM([MODELO])))   AS ModeloKey,
    CASE
        WHEN [COMPONENTE] LIKE '%TRACCION%'    THEN 'TRACCION'
        WHEN [COMPONENTE] LIKE '%HIDRAUL%'     THEN 'HIDRAULICO'
        WHEN [COMPONENTE] LIKE '%RUEDA%'       THEN 'RUEDA'
        WHEN [COMPONENTE] LIKE '%MANDO%'       THEN 'MANDO'
        WHEN [COMPONENTE] LIKE '%TRANSMISION%' THEN 'TRANSMISION'
        WHEN [COMPONENTE] LIKE '%MOTOR%'       THEN 'MOTOR'
        ELSE 'OTRO'
    END AS CompTipo,
    MIN([FIERRO - LP])  AS Fe_LP, MIN([FIERRO - LC])  AS Fe_LC,
    MIN([CROMO - LP])   AS Cr_LP, MIN([CROMO - LC])   AS Cr_LC,
    MIN([NIQUEL - LP])  AS Ni_LP, MIN([NIQUEL - LC])  AS Ni_LC,
    MIN([COBRE - LP])   AS Cu_LP, MIN([COBRE - LC])   AS Cu_LC,
    MIN([SILICIO - LP]) AS Si_LP, MIN([SILICIO - LC]) AS Si_LC,
    MIN([ALUMINIO - LP])AS Al_LP, MIN([ALUMINIO - LC])AS Al_LC,
    MIN([CALCIO - LP])  AS Ca_LP, MIN([CALCIO - LC])  AS Ca_LC,
    MIN([ZINC - LP])    AS Zn_LP, MIN([ZINC - LC])    AS Zn_LC,
    MIN([POTASIO - LP]) AS K_LP,  MIN([POTASIO - LC]) AS K_LC,
    MIN([SODIO - LP])   AS Na_LP, MIN([SODIO - LC])   AS Na_LC,
    MIN([MAGNESIO - LP])AS Mg_LP, MIN([MAGNESIO - LC])AS Mg_LC,
    MIN([PLOMO - LP])   AS Pb_LP, MIN([PLOMO - LC])   AS Pb_LC, MIN([ESTAÑO - LP])  AS Sn_LP, MIN([ESTAÑO - LC])  AS Sn_LC,
    MIN([PQ - LP])      AS PQ_LP, MIN([PQ - LC])      AS PQ_LC,
    MAX([TBN - LP])     AS TBN_LP,
    MIN([VISC - LCI])   AS V100_LCI, MIN([VISC - LCS])  AS V100_LCS,
    MIN([VISC - LPI])   AS V100_LPI, MIN([VISC - LPS])  AS V100_LPS
FROM [Eqpcare].[lc]
GROUP BY
    UPPER(LTRIM(RTRIM([Proyecto]))),
    UPPER(LTRIM(RTRIM([MODELO]))),
    CASE
        WHEN [COMPONENTE] LIKE '%TRACCION%'    THEN 'TRACCION'
        WHEN [COMPONENTE] LIKE '%HIDRAUL%'     THEN 'HIDRAULICO'
        WHEN [COMPONENTE] LIKE '%RUEDA%'       THEN 'RUEDA'
        WHEN [COMPONENTE] LIKE '%MANDO%'       THEN 'MANDO'
        WHEN [COMPONENTE] LIKE '%TRANSMISION%' THEN 'TRANSMISION'
        WHEN [COMPONENTE] LIKE '%MOTOR%'       THEN 'MOTOR'
        ELSE 'OTRO'
    END;
GO


/* ----------------------------------------------------------------------------
   2) vw_MuestrasEstado (FUNDACIÓN) — + Ca, Zn (con Estado informativo) + HorasA/HorasB
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_MuestrasEstado] AS
WITH muestras AS (
    SELECT
        ME.[Code]   AS Equipo,
        MP.[Name]   AS Proyecto,
        EF.[Model]  AS Modelo,
        UPPER(LTRIM(RTRIM(MP.[Name])))  AS ProyKey,
        UPPER(LTRIM(RTRIM(EF.[Model]))) AS ModeloKey,
        LD.[MiningEquipmentId],
        LD.[Compartimiento],
        CASE
            WHEN LD.[Compartimiento] LIKE '%TRACCION%'    THEN 'TRACCION'
            WHEN LD.[Compartimiento] LIKE '%HIDRAUL%'     THEN 'HIDRAULICO'
            WHEN LD.[Compartimiento] LIKE '%RUEDA%'       THEN 'RUEDA'
            WHEN LD.[Compartimiento] LIKE '%MANDO%'       THEN 'MANDO'
            WHEN LD.[Compartimiento] LIKE '%TRANSMISION%' THEN 'TRANSMISION'
            WHEN LD.[Compartimiento] LIKE '%MOTOR%'       THEN 'MOTOR'
            ELSE 'OTRO'
        END AS CompTipo,
        CASE WHEN LD.[CM] IN ('DDI','DIALIZADO','RELLENO+DIALIZADO') THEN 1 ELSE 0 END AS EsDDI,
        LD.[FechaMuestreo], LD.[Horometro], LD.[HorasDeAceite],
        LD.[HorasA], LD.[HorasB],            -- candidatos a "Horas del componente" (verificar)
        LD.[CM], LD.[Grado],
        LD.[Fe_ppm], LD.[Cr_ppm], LD.[Ni_ppm], LD.[Cu_ppm], LD.[Pb_ppm], LD.[Sn_ppm],
        LD.[Si_ppm], LD.[Al_ppm], LD.[Ca_ppm], LD.[Zn_ppm], LD.[Na_ppm], LD.[K_ppm], LD.[Mg_ppm], LD.[B_ppm], LD.[P_ppm],
        LD.[Indice_PQ], LD.[TBN], LD.[V100], LD.[LaboratoryDataId]
    FROM [Oil].[LaboratoryData] LD
    INNER JOIN [Mine].[MiningEquipment] ME ON ME.[Id] = LD.[MiningEquipmentId]
    INNER JOIN [Mine].[MiningProject]   MP ON MP.[Id] = ME.[MiningProjectId]
    INNER JOIN [Mine].[EquipmentFleet]  EF ON EF.[Id] = ME.[EquipmentFleetId]
    /* VENTANA 12 MESES (perf): la fundación rankea sobre 1 año en vez de 9 → corta el full-scan
       del histórico (último de 1 equipo leía la tabla entera, el window function bloquea el pushdown
       del filtro de equipo). Cubre estado actual/último/tendencia(6 muestras)/historial(2 meses).
       Tradeoff aceptado: equipos SIN muestra en 12 meses no aparecen en vistas de estado actual
       (la flota activa se muestrea ~mensual). Para volver al histórico completo: quitar este WHERE. */
    WHERE LD.[FechaMuestreo] >= DATEADD(MONTH, -12, GETDATE())
),
calc AS (
    /* dedup por FECHA: rn_dia=1 = muestra "keeper" del día (mayor LaboratoryDataId);
       date_rank numera FECHAS DISTINTAS (1=más reciente). Así rn_recencia cuenta DÍAS (no filas)
       y las muestras del mismo día (re-tests) no consumen ranking (la tendencia mostraba "3 de 6"). */
    SELECT *,
        ROW_NUMBER() OVER (PARTITION BY MiningEquipmentId, Compartimiento, EsDDI, CAST(FechaMuestreo AS date) ORDER BY LaboratoryDataId DESC) AS rn_dia,
        DENSE_RANK() OVER (PARTITION BY MiningEquipmentId, Compartimiento, EsDDI ORDER BY CAST(FechaMuestreo AS date) DESC) AS date_rank
    FROM muestras
)
SELECT
    m.Equipo, m.Proyecto, m.Modelo, m.MiningEquipmentId, m.Compartimiento, m.CompTipo, m.EsDDI,
    m.FechaMuestreo, m.Horometro, m.HorasDeAceite, m.HorasA, m.HorasB, m.CM, m.Grado,

    m.Fe_ppm,  lim.Fe_LP,  lim.Fe_LC,
    CASE WHEN m.Fe_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Fe_ppm > ISNULL(lim.Fe_LC,9999) THEN 'CRITICO'
         WHEN m.Fe_ppm > ISNULL(lim.Fe_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Fe,

    m.Cr_ppm,  lim.Cr_LP,  lim.Cr_LC,
    CASE WHEN m.Cr_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Cr_ppm > ISNULL(lim.Cr_LC,9999) THEN 'CRITICO'
         WHEN m.Cr_ppm > ISNULL(lim.Cr_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Cr,

    m.Ni_ppm,  lim.Ni_LP,  lim.Ni_LC,
    CASE WHEN m.Ni_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Ni_ppm > ISNULL(lim.Ni_LC,9999) THEN 'CRITICO'
         WHEN m.Ni_ppm > ISNULL(lim.Ni_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Ni,

    m.Cu_ppm,  lim.Cu_LP,  lim.Cu_LC,
    CASE WHEN m.Cu_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Cu_ppm > ISNULL(lim.Cu_LC,9999) THEN 'CRITICO'
         WHEN m.Cu_ppm > ISNULL(lim.Cu_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Cu,

    m.Si_ppm,  lim.Si_LP,  lim.Si_LC,
    CASE WHEN m.Si_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Si_ppm > ISNULL(lim.Si_LC,9999) THEN 'CRITICO'
         WHEN m.Si_ppm > ISNULL(lim.Si_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Si,

    m.Al_ppm,  lim.Al_LP,  lim.Al_LC,
    CASE WHEN m.Al_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Al_ppm > ISNULL(lim.Al_LC,9999) THEN 'CRITICO'
         WHEN m.Al_ppm > ISNULL(lim.Al_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Al,

    /* CONTAMINANTES nuevos (informativos: NO entran a Estado_General hasta validación del área) */
    m.Ca_ppm,  lim.Ca_LP,  lim.Ca_LC,
    CASE WHEN m.Ca_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Ca_ppm > ISNULL(lim.Ca_LC,9999) THEN 'CRITICO'
         WHEN m.Ca_ppm > ISNULL(lim.Ca_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Ca,

    m.Zn_ppm,  lim.Zn_LP,  lim.Zn_LC,
    CASE WHEN m.Zn_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Zn_ppm > ISNULL(lim.Zn_LC,9999) THEN 'CRITICO'
         WHEN m.Zn_ppm > ISNULL(lim.Zn_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Zn,
    m.K_ppm,   lim.K_LP,   lim.K_LC,
    CASE WHEN m.K_ppm IS NULL THEN 'SIN DATO'
         WHEN m.K_ppm > ISNULL(lim.K_LC,9999) THEN 'CRITICO'
         WHEN m.K_ppm > ISNULL(lim.K_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_K,

    m.Na_ppm,  lim.Na_LP,  lim.Na_LC,
    CASE WHEN m.Na_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Na_ppm > ISNULL(lim.Na_LC,9999) THEN 'CRITICO'
         WHEN m.Na_ppm > ISNULL(lim.Na_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Na,

    m.Mg_ppm,  lim.Mg_LP,  lim.Mg_LC,
    CASE WHEN m.Mg_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Mg_ppm > ISNULL(lim.Mg_LC,9999) THEN 'CRITICO'
         WHEN m.Mg_ppm > ISNULL(lim.Mg_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Mg,

    m.Pb_ppm,  lim.Pb_LP, lim.Pb_LC,
    CASE WHEN m.Pb_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Pb_ppm > ISNULL(lim.Pb_LC,9999) THEN 'CRITICO'
         WHEN m.Pb_ppm > ISNULL(lim.Pb_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Pb,

    m.Sn_ppm,  lim.Sn_LP, lim.Sn_LC,
    CASE WHEN m.Sn_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Sn_ppm > ISNULL(lim.Sn_LC,9999) THEN 'CRITICO'
         WHEN m.Sn_ppm > ISNULL(lim.Sn_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Sn,

    m.Indice_PQ, lim.PQ_LP, lim.PQ_LC,
    CASE WHEN m.Indice_PQ IS NULL THEN 'SIN DATO'
         WHEN m.Indice_PQ > ISNULL(lim.PQ_LC,9999) THEN 'CRITICO'
         WHEN m.Indice_PQ > ISNULL(lim.PQ_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_PQ,

    m.TBN, lim.TBN_LP,
    CASE WHEN m.TBN IS NULL THEN 'SIN DATO'
         WHEN m.TBN < ISNULL(lim.TBN_LP,0) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_TBN,

    m.B_ppm, m.P_ppm, m.V100, lim.V100_LCI, lim.V100_LCS,
    CASE WHEN m.V100 IS NULL OR m.V100 = 0 THEN 'SIN DATO'
         WHEN (lim.V100_LCI IS NOT NULL AND m.V100 < lim.V100_LCI) OR (lim.V100_LCS IS NOT NULL AND m.V100 > lim.V100_LCS) THEN 'CRITICO'
         WHEN (lim.V100_LPI IS NOT NULL AND m.V100 < lim.V100_LPI) OR (lim.V100_LPS IS NOT NULL AND m.V100 > lim.V100_LPS) THEN 'PRECAUCION'
         ELSE 'OK' END AS Estado_V100,

    /* Estado_General: SIN CAMBIOS respecto a v3 (Ca/Zn/B/P informativos; el triage no se altera) */
    CASE
        WHEN m.Fe_ppm    > ISNULL(lim.Fe_LC,9999)
          OR m.Cr_ppm    > ISNULL(lim.Cr_LC,9999)
          OR m.Ni_ppm    > ISNULL(lim.Ni_LC,9999)
          OR m.Cu_ppm    > ISNULL(lim.Cu_LC,9999)
          OR m.Si_ppm    > ISNULL(lim.Si_LC,9999)
          OR m.Al_ppm    > ISNULL(lim.Al_LC,9999)
          OR m.Pb_ppm    > ISNULL(lim.Pb_LC,9999)
          OR m.Sn_ppm    > ISNULL(lim.Sn_LC,9999)
          OR m.Indice_PQ > ISNULL(lim.PQ_LC,9999)
        THEN 'CRITICO'
        WHEN m.Fe_ppm    > ISNULL(lim.Fe_LP,9999)
          OR m.Cr_ppm    > ISNULL(lim.Cr_LP,9999)
          OR m.Ni_ppm    > ISNULL(lim.Ni_LP,9999)
          OR m.Cu_ppm    > ISNULL(lim.Cu_LP,9999)
          OR m.Si_ppm    > ISNULL(lim.Si_LP,9999)
          OR m.Al_ppm    > ISNULL(lim.Al_LP,9999)
          OR m.Pb_ppm    > ISNULL(lim.Pb_LP,9999)
          OR m.Sn_ppm    > ISNULL(lim.Sn_LP,9999)
          OR m.Indice_PQ > ISNULL(lim.PQ_LP,9999)
          OR (lim.TBN_LP IS NOT NULL AND m.TBN > 0 AND m.TBN < lim.TBN_LP)
        THEN 'PRECAUCION'
        ELSE 'OK'
    END AS Estado_General,

    /* rn_recencia = orden por FECHA distinta (1=más reciente), solo la keeper del día;
       mismo día/re-test -> NULL (no entra a rn=1 ni rn<=6). Historial (sin filtro rn) ve TODO. */
    CASE WHEN m.EsDDI = 0 AND m.rn_dia = 1 THEN m.date_rank END AS rn_recencia,

    m.LaboratoryDataId
FROM calc m
LEFT JOIN [dbo].[vw_LimitesPorComponente] lim
    ON lim.ProyKey   = m.ProyKey
   AND lim.ModeloKey = m.ModeloKey
   AND lim.CompTipo  = m.CompTipo
   /* GUARD anti-colisión: un componente NO reconocido por el CASE cae en 'OTRO'.
      Tanto las muestras como lc colapsan varios componentes distintos (CAJA GIRO,
      PTO, DAMPER, DIFERENCIAL…) en 'OTRO', y vw_LimitesPorComponente los mezcla con
      MIN() → límite ajeno/erróneo. Mientras el área no estandarice nombres y cargue
      límites por componente real, 'OTRO' NO matchea: sin límite (ISNULL→9999) = NUNCA
      dispara observado falso. NO afecta al 980E (sus 4 componentes sí mapean). */
   AND m.CompTipo  <> 'OTRO';
GO


/* ----------------------------------------------------------------------------
   3-5) Derivadas: misma definición que v3, re-creadas para RE-CAPTURAR las
   columnas nuevas (SELECT * congela columnas al crear la vista).
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_MuestrasRankeadas] AS
WITH hs AS (
    -- HsCc pre-rankeado: 1 fila (la más reciente) por EQUIPO+SISTEMA. Se escanea UNA vez
    -- (antes era subconsulta correlacionada por fila → HsCc escaneado 2112x). Alias Eq/Sis/Smr/Hta
    -- evitan ambiguedad con me.Equipo. Mapeo EQUIPO 'T####'->'CA####' y SISTEMA inglés<->compartimiento.
    SELECT [EQUIPO] AS Eq, [SISTEMA] AS Sis,
           TRY_CONVERT(decimal(12,2),[SMR ULTIMO SERVICIO])        AS Smr,
           TRY_CONVERT(decimal(12,2),[HORAS DE TRABAJO ACUMULADO ]) AS Hta,
           ROW_NUMBER() OVER (PARTITION BY [EQUIPO],[SISTEMA] ORDER BY [FECHA] DESC) AS rn
    FROM [Eqpcare].[HsCc]
)
SELECT me.*,
    CASE WHEN H.Smr IS NOT NULL AND me.Horometro >= H.Smr THEN me.Horometro - H.Smr ELSE H.Hta END AS HorasComponente
FROM [dbo].[vw_MuestrasEstado] me
LEFT JOIN hs H
  ON  H.rn = 1
  AND ( H.Eq = me.Equipo OR (H.Eq LIKE 'T[0-9]%' AND me.Equipo = 'CA'+SUBSTRING(H.Eq,2,10)) )
  AND H.Sis = CASE WHEN me.Compartimiento LIKE '%TRACCION%LH' THEN 'WHEEL MOTOR LH'
                   WHEN me.Compartimiento LIKE '%TRACCION%RH' THEN 'WHEEL MOTOR RH'
                   WHEN me.Compartimiento LIKE '%HIDRAULICO%' THEN 'HYDRAULIC'
                   WHEN me.Compartimiento LIKE '%RUEDA%LH'    THEN 'SPINDLE LH'
                   WHEN me.Compartimiento LIKE '%RUEDA%RH'    THEN 'SPINDLE RH'
                   WHEN me.Compartimiento LIKE 'MOTOR%'       THEN 'MOTOR DIESEL'
                   ELSE me.Compartimiento END
WHERE me.EsDDI = 0;
GO

CREATE OR ALTER VIEW [dbo].[vw_UltimoAnalisisAceite] AS
-- sobre vw_MuestrasRankeadas (no vw_MuestrasEstado) para exponer HorasComponente
-- (rankeadas ya filtra EsDDI=0). rn_recencia=1 = última muestra en uso por equipo+compartimiento.
SELECT * FROM [dbo].[vw_MuestrasRankeadas] WHERE rn_recencia = 1;
GO

CREATE OR ALTER VIEW [dbo].[vw_EstadoActualMT] AS
-- sobre vw_MuestrasRankeadas para exponer HorasComponente (rankeadas ya filtra EsDDI=0).
SELECT * FROM [dbo].[vw_MuestrasRankeadas] WHERE CompTipo = 'TRACCION' AND rn_recencia = 1;
GO


/* ============================================================================
   GRUPO C — BARRIDO/OBSERVADOS (v4.2): vw_ObservadosFlota sobre vw_MuestrasEstado
   ============================================================================ */
/* ============================================================================
   KomfIA — v4.2: vw_ObservadosFlota + "Hor. Comp." REAL desde [Eqpcare].[HsCc]
   Base: bd_kmmp_osconfiabilidad (Azure SQL)

   QUÉ AGREGA respecto a v4.1 (misma lógica Mets_Obs/Infs_Obs/NumCrit/NumPrec):
   - HorasComponente: horas reales del componente al momento de la muestra =
       Horometro de la muestra − [SMR ULTIMO SERVICIO] de HsCc (último cambio).
       Si no hay SMR o sale negativo, usa [HORAS DE TRABAJO ACUMULADO ] (snapshot HsCc).
   - Cond_Area: [ESTADO SOS] de HsCc (Normal/Observado/Precaucion/Critico) — la
       condición que el propio área mantiene, útil para contrastar (no se muestra
       por defecto en los formatos; queda disponible).

   MAPEOS (verificados contra la data real de HsCc):
   - Equipo: HsCc usa 'T3174' donde ME.Code es 'CA3174' (Antapaccay 980E) → el JOIN
     acepta igualdad directa O el patrón T#### → CA####.
   - Componente: HsCc.[SISTEMA] está en inglés para 980E → WHEEL MOTOR LH/RH ↔
     MOTOR DE TRACCION LH/RH, HYDRAULIC ↔ SISTEMA HIDRAULICO, SPINDLE ↔ RUEDA
     DELANTERA, MOTOR DIESEL ↔ MOTOR. Otros (D475A en español) → igualdad directa.
   - [HORAS DE TRABAJO ACUMULADO ] lleva ESPACIO FINAL en el nombre real (no es typo).
   LEFT JOIN: si HsCc no tiene el equipo/componente, HorasComponente sale NULL y
   el formato cae a Hor. Ace. (así lo dice Formatos de Respuesta). Nada se pierde.
   ============================================================================ */
GO

CREATE OR ALTER VIEW [dbo].[vw_ObservadosFlota] AS
WITH b AS (
    SELECT
        Equipo, Proyecto, Modelo, Compartimiento, CompTipo,
        FechaMuestreo, Horometro, HorasDeAceite, CM, Grado, Estado_General,
        /* DETERMINANTES fuera de limite: "Fe:C,Cr:P"  (C=>LC condenatorio | P=>LP) */
        STUFF(CONCAT(
            CASE WHEN Fe_ppm    > ISNULL(Fe_LC,9999) THEN ',Fe:C' WHEN Fe_ppm    > ISNULL(Fe_LP,9999) THEN ',Fe:P' ELSE '' END,
            CASE WHEN Indice_PQ > ISNULL(PQ_LC,9999) THEN ',PQ:C' WHEN Indice_PQ > ISNULL(PQ_LP,9999) THEN ',PQ:P' ELSE '' END,
            CASE WHEN Cr_ppm    > ISNULL(Cr_LC,9999) THEN ',Cr:C' WHEN Cr_ppm    > ISNULL(Cr_LP,9999) THEN ',Cr:P' ELSE '' END,
            CASE WHEN Ni_ppm    > ISNULL(Ni_LC,9999) THEN ',Ni:C' WHEN Ni_ppm    > ISNULL(Ni_LP,9999) THEN ',Ni:P' ELSE '' END,
            CASE WHEN Cu_ppm    > ISNULL(Cu_LC,9999) THEN ',Cu:C' WHEN Cu_ppm    > ISNULL(Cu_LP,9999) THEN ',Cu:P' ELSE '' END,
            CASE WHEN Pb_ppm    > ISNULL(Pb_LC,9999) THEN ',Pb:C' WHEN Pb_ppm    > ISNULL(Pb_LP,9999) THEN ',Pb:P' ELSE '' END,
            CASE WHEN Sn_ppm    > ISNULL(Sn_LC,9999) THEN ',Sn:C' WHEN Sn_ppm    > ISNULL(Sn_LP,9999) THEN ',Sn:P' ELSE '' END,
            CASE WHEN Al_ppm    > ISNULL(Al_LC,9999) THEN ',Al:C' WHEN Al_ppm    > ISNULL(Al_LP,9999) THEN ',Al:P' ELSE '' END,
            CASE WHEN Si_ppm    > ISNULL(Si_LC,9999) THEN ',Si:C' WHEN Si_ppm    > ISNULL(Si_LP,9999) THEN ',Si:P' ELSE '' END,
            CASE WHEN TBN_LP IS NOT NULL AND TBN > 0 AND TBN < TBN_LP THEN ',TBN:P' ELSE '' END
        ), 1, 1, '') AS Mets_Obs,
        /* INFORMATIVOS fuera de umbral (Ca/Zn/K/Mg): se muestran, NO disparan observado */
        STUFF(CONCAT(
            CASE WHEN Ca_ppm > ISNULL(Ca_LC,9999) THEN ',Ca:C' WHEN Ca_ppm > ISNULL(Ca_LP,9999) THEN ',Ca:P' ELSE '' END,
            CASE WHEN Zn_ppm > ISNULL(Zn_LC,9999) THEN ',Zn:C' WHEN Zn_ppm > ISNULL(Zn_LP,9999) THEN ',Zn:P' ELSE '' END,
            CASE WHEN K_ppm  > ISNULL(K_LC,9999)  THEN ',K:C'  WHEN K_ppm  > ISNULL(K_LP,9999)  THEN ',K:P'  ELSE '' END,
            CASE WHEN Na_ppm > ISNULL(Na_LC,9999) THEN ',Na:C' WHEN Na_ppm > ISNULL(Na_LP,9999) THEN ',Na:P' ELSE '' END,
            CASE WHEN Mg_ppm > ISNULL(Mg_LC,9999) THEN ',Mg:C' WHEN Mg_ppm > ISNULL(Mg_LP,9999) THEN ',Mg:P' ELSE '' END,
            /* SALUD del aceite: viscosidad. Solo dispara donde los limites VISC estan aterrizados (Antapaccay); V100=0/NULL -> SIN DATO (nada). Informativo: NO cuenta como metal observado */
            CASE WHEN Estado_V100 = 'CRITICO' THEN ',V100:C' WHEN Estado_V100 = 'PRECAUCION' THEN ',V100:P' ELSE '' END
        ), 1, 1, '') AS Infs_Obs,
        ( CASE WHEN Fe_ppm    > ISNULL(Fe_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Indice_PQ > ISNULL(PQ_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Cr_ppm    > ISNULL(Cr_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Ni_ppm    > ISNULL(Ni_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Cu_ppm    > ISNULL(Cu_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Al_ppm    > ISNULL(Al_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Si_ppm    > ISNULL(Si_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Pb_ppm    > ISNULL(Pb_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Sn_ppm    > ISNULL(Sn_LC,9999) THEN 1 ELSE 0 END) AS NumCrit,
        ( CASE WHEN Fe_ppm    > ISNULL(Fe_LP,9999) AND Fe_ppm    <= ISNULL(Fe_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Indice_PQ > ISNULL(PQ_LP,9999) AND Indice_PQ <= ISNULL(PQ_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Cr_ppm    > ISNULL(Cr_LP,9999) AND Cr_ppm    <= ISNULL(Cr_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Ni_ppm    > ISNULL(Ni_LP,9999) AND Ni_ppm    <= ISNULL(Ni_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Cu_ppm    > ISNULL(Cu_LP,9999) AND Cu_ppm    <= ISNULL(Cu_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Pb_ppm    > ISNULL(Pb_LP,9999) AND Pb_ppm    <= ISNULL(Pb_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Sn_ppm    > ISNULL(Sn_LP,9999) AND Sn_ppm    <= ISNULL(Sn_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Al_ppm    > ISNULL(Al_LP,9999) AND Al_ppm    <= ISNULL(Al_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Si_ppm    > ISNULL(Si_LP,9999) AND Si_ppm    <= ISNULL(Si_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN TBN_LP IS NOT NULL AND TBN > 0 AND TBN < TBN_LP THEN 1 ELSE 0 END) AS NumPrec,
        /* Detalle pre-formateado: parámetros fuera de límite con valor(LP/LC) y severidad (:C/:P) */
        STUFF(CONCAT(
            CASE WHEN Fe_ppm>ISNULL(Fe_LC,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Fe_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Fe_LC AS decimal(18,1))),'')+')'+':C' WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Fe_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Fe_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Indice_PQ>ISNULL(PQ_LC,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(PQ_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(PQ_LC AS decimal(18,1))),'')+')'+':C' WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(PQ_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(PQ_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Cr_ppm>ISNULL(Cr_LC,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Cr_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Cr_LC AS decimal(18,1))),'')+')'+':C' WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Cr_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Cr_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Ni_ppm>ISNULL(Ni_LC,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Ni_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Ni_LC AS decimal(18,1))),'')+')'+':C' WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Ni_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Ni_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Cu_ppm>ISNULL(Cu_LC,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Cu_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Cu_LC AS decimal(18,1))),'')+')'+':C' WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Cu_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Cu_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Al_ppm>ISNULL(Al_LC,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Al_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Al_LC AS decimal(18,1))),'')+')'+':C' WHEN Al_ppm>ISNULL(Al_LP,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Al_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Al_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Si_ppm>ISNULL(Si_LC,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Si_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Si_LC AS decimal(18,1))),'')+')'+':C' WHEN Si_ppm>ISNULL(Si_LP,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Si_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Si_LC AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN ' · Pb='+CONVERT(varchar(20),CAST(Pb_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Pb_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Pb_LC AS decimal(18,1))),'')+')'+CASE WHEN Pb_ppm>ISNULL(Pb_LC,9999) THEN ':C' ELSE ':P' END ELSE '' END,
            CASE WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN ' · Sn='+CONVERT(varchar(20),CAST(Sn_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Sn_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Sn_LC AS decimal(18,1))),'')+')'+CASE WHEN Sn_ppm>ISNULL(Sn_LC,9999) THEN ':C' ELSE ':P' END ELSE '' END,
            CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN ' · TBN='+CONVERT(varchar(20),CAST(TBN AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(TBN_LP AS decimal(18,1))),'')+')'+':P' ELSE '' END,
            CASE WHEN Ca_ppm>ISNULL(Ca_LC,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Ca_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Ca_LC AS decimal(18,1))),'')+')'+':C inf' WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Ca_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Ca_LC AS decimal(18,1))),'')+')'+':P inf' ELSE '' END,
            CASE WHEN Zn_ppm>ISNULL(Zn_LC,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Zn_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Zn_LC AS decimal(18,1))),'')+')'+':C inf' WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Zn_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Zn_LC AS decimal(18,1))),'')+')'+':P inf' ELSE '' END,
            CASE WHEN K_ppm>ISNULL(K_LC,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(K_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(K_LC AS decimal(18,1))),'')+')'+':C inf' WHEN K_ppm>ISNULL(K_LP,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(K_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(K_LC AS decimal(18,1))),'')+')'+':P inf' ELSE '' END,
            CASE WHEN Na_ppm>ISNULL(Na_LC,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Na_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Na_LC AS decimal(18,1))),'')+')'+':C inf' WHEN Na_ppm>ISNULL(Na_LP,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Na_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Na_LC AS decimal(18,1))),'')+')'+':P inf' ELSE '' END,
            CASE WHEN Mg_ppm>ISNULL(Mg_LC,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Mg_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Mg_LC AS decimal(18,1))),'')+')'+':C inf' WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+'('+ISNULL('LP'+CONVERT(varchar(20),CAST(Mg_LP AS decimal(18,1))),'')+ISNULL('/LC'+CONVERT(varchar(20),CAST(Mg_LC AS decimal(18,1))),'')+')'+':P inf' ELSE '' END
        ),1,3,'') AS Detalle,
        STUFF(CONCAT(
            CASE WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN ' · Fe '+CONVERT(varchar(20),CAST(Fe_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Fe_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN ' · PQ '+CONVERT(varchar(20),CAST(PQ_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(PQ_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN ' · Cr '+CONVERT(varchar(20),CAST(Cr_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Cr_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN ' · Ni '+CONVERT(varchar(20),CAST(Ni_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Ni_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN ' · Cu '+CONVERT(varchar(20),CAST(Cu_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Cu_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Al_ppm>ISNULL(Al_LP,9999) THEN ' · Al '+CONVERT(varchar(20),CAST(Al_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Al_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Si_ppm>ISNULL(Si_LP,9999) THEN ' · Si '+CONVERT(varchar(20),CAST(Si_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Si_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN ' · Pb '+CONVERT(varchar(20),CAST(Pb_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Pb_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN ' · Sn '+CONVERT(varchar(20),CAST(Sn_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Sn_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN ' · TBN '+CONVERT(varchar(20),CAST(TBN_LP AS decimal(18,1))) ELSE '' END,
            CASE WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN ' · Ca '+CONVERT(varchar(20),CAST(Ca_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Ca_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN ' · Zn '+CONVERT(varchar(20),CAST(Zn_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Zn_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN K_ppm>ISNULL(K_LP,9999) THEN ' · K '+CONVERT(varchar(20),CAST(K_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(K_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Na_ppm>ISNULL(Na_LP,9999) THEN ' · Na '+CONVERT(varchar(20),CAST(Na_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Na_LC AS decimal(18,1))),'') ELSE '' END,
            CASE WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN ' · Mg '+CONVERT(varchar(20),CAST(Mg_LP AS decimal(18,1)))+ISNULL('/'+CONVERT(varchar(20),CAST(Mg_LC AS decimal(18,1))),'') ELSE '' END
        ),1,3,'') AS LimObs,
        Fe_ppm, Fe_LP, Fe_LC, Indice_PQ, PQ_LP, PQ_LC, Cr_ppm, Cr_LP, Cr_LC, Ni_ppm, Ni_LP, Ni_LC,
        Cu_ppm, Cu_LP, Cu_LC, Pb_ppm, Pb_LP, Pb_LC, Sn_ppm, Sn_LP, Sn_LC, Al_ppm, Al_LP, Al_LC,
        Si_ppm, Si_LP, Si_LC, Ca_ppm, Ca_LP, Ca_LC, Zn_ppm, Zn_LP, Zn_LC,
        K_ppm, K_LP, K_LC, Na_ppm, Na_LP, Na_LC, Mg_ppm, Mg_LP, Mg_LC, B_ppm, P_ppm, V100, TBN, TBN_LP, Estado_V100
    FROM [dbo].[vw_MuestrasEstado]
    WHERE EsDDI = 0 AND rn_recencia = 1
),
obs AS (   /* SOLO filas con algo fuera de umbral -> el JOIN a HsCc cruza pocas filas (liviano) */
    SELECT * FROM b WHERE Mets_Obs IS NOT NULL OR Infs_Obs IS NOT NULL
),
hs AS (
    SELECT [EQUIPO], [SISTEMA], [SMR ULTIMO SERVICIO], [HORAS DE TRABAJO ACUMULADO ], [ESTADO SOS],
           ROW_NUMBER() OVER (PARTITION BY [EQUIPO], [SISTEMA] ORDER BY [FECHA] DESC) AS rn
    FROM [Eqpcare].[HsCc] WITH (NOLOCK)
)
SELECT
    obs.*,
    CASE WHEN TRY_CONVERT(decimal(12,2), H.[SMR ULTIMO SERVICIO]) IS NOT NULL
          AND obs.Horometro >= TRY_CONVERT(decimal(12,2), H.[SMR ULTIMO SERVICIO])
         THEN obs.Horometro - TRY_CONVERT(decimal(12,2), H.[SMR ULTIMO SERVICIO])
         ELSE TRY_CONVERT(decimal(12,2), H.[HORAS DE TRABAJO ACUMULADO ]) END AS HorasComponente,
    H.[ESTADO SOS] AS Cond_Area
FROM obs
LEFT JOIN hs H
  ON  H.rn = 1
  AND ( H.[EQUIPO] = obs.Equipo
        OR (H.[EQUIPO] LIKE 'T[0-9]%' AND obs.Equipo = 'CA' + SUBSTRING(H.[EQUIPO], 2, 10)) )
  AND H.[SISTEMA] = CASE
        WHEN obs.Compartimiento LIKE '%TRACCION%LH' THEN 'WHEEL MOTOR LH'
        WHEN obs.Compartimiento LIKE '%TRACCION%RH' THEN 'WHEEL MOTOR RH'
        WHEN obs.Compartimiento LIKE '%HIDRAULICO%' THEN 'HYDRAULIC'
        WHEN obs.Compartimiento LIKE '%RUEDA%LH'    THEN 'SPINDLE LH'
        WHEN obs.Compartimiento LIKE '%RUEDA%RH'    THEN 'SPINDLE RH'
        WHEN obs.Compartimiento LIKE 'MOTOR%'       THEN 'MOTOR DIESEL'
        ELSE obs.Compartimiento END;
GO


/* ----------------------------------------------------------------------------
   vw_ObservadosResumen — 1 FILA POR EQUIPO (resumen de barrido, liviano)
   Agrega los componentes observados de cada equipo (Comp_Obs) y sus metales
   (Met_Obs) → el orquestador recibe ~N filas pequeñas en vez de N×58 columnas,
   evitando que se sature o malinterprete. Para la Tabla 1 del barrido.
   El DETALLE de un equipo concreto se pide aparte a vw_ObservadosFlota WHERE Equipo=...
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_ObservadosResumen] AS
SELECT
    Equipo, Proyecto, Modelo,
    SUM(NumCrit)        AS NumCrit,
    SUM(NumPrec)        AS NumPrec,
    MAX(Horometro)      AS Horometro,
    MAX(HorasDeAceite)  AS HorasDeAceite,
    MAX(FechaMuestreo)  AS FechaUltima,
    MAX(CM)             AS CM,
    STRING_AGG(Compartimiento, ' · ') WITHIN GROUP (ORDER BY NumCrit DESC, Compartimiento) AS Comp_Obs,
    STRING_AGG(NULLIF(Mets_Obs,''), ' · ') WITHIN GROUP (ORDER BY NumCrit DESC) AS Met_Obs,
    -- Limites: "Comp: metal LP/LC" de los componentes observados del equipo (para el CUADRO DE LÍMITES
    -- del barrido, disponible YA en PASO 1). El central une por (comp,metal) para armar la matriz.
    STRING_AGG(NULLIF(Compartimiento + ': ' + LimObs, Compartimiento + ': '), '  |  ')
        WITHIN GROUP (ORDER BY NumCrit DESC, Compartimiento) AS Limites
FROM [dbo].[vw_ObservadosFlota]
WHERE Estado_General <> 'OK'
GROUP BY Equipo, Proyecto, Modelo;
GO


/* ----------------------------------------------------------------------------
   vw_ObservadosDetalle — DETALLE de barrido (PASO 2), LIGERO y PRE-FORMATEADO.
   1 fila por equipo+compartimiento observado. SOLO las columnas que el orquestador
   necesita para la MATRIZ compacta (formato Excel del área). NO trae metales sueltos
   (Fe_ppm, Fe_LP, Fe_LC…) a propósito: así el central NO puede armar el esqueleto de
   "último análisis" (4 grupos) — queda OBLIGADO a leer la columna Detalle y pivotar
   la matriz. Se consulta SIEMPRE con SELECT * (la vista ya recorta las columnas).
   Detalle formato (AMBOS límites): 'Cu=24.2(LP3/LC4):C · Sn=1.6(LP3):P'  — value(LP..[/LC..]):sev
   (:C=crítico >LC, :P=precaución >LP; Pb/Sn/TBN sin LC; sufijo ' inf'=informativo Ca/Zn/K/Na/Mg).
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_ObservadosDetalle] AS
SELECT
    Equipo, Proyecto, Modelo, Compartimiento,
    FechaMuestreo, HorasComponente, HorasDeAceite, CM,
    Estado_General, NumCrit, NumPrec, Detalle
FROM [dbo].[vw_ObservadosFlota]
WHERE Estado_General <> 'OK';
GO


/* ----------------------------------------------------------------------------
   vw_UltimoAnalisisFlota — DIAGNÓSTICO POR EQUIPO (todos los componentes).
   = vw_UltimoAnalisisAceite (última muestra no-DDI por componente, TODOS los
   params + LP/LC + Estado) + "Hor. Comp." real desde HsCc (mismo mapeo que el
   barrido). REUTILIZA vw_UltimoAnalisisAceite y NO toca vw_ObservadosFlota.
   Incluye componentes OK (a diferencia del barrido). Pensada para UN equipo
   (SELECT ... WHERE Equipo='CAxxxx') → el JOIN a HsCc cruza pocas filas.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_UltimoAnalisisFlota] AS
WITH hs AS (
    SELECT [EQUIPO], [SISTEMA], [SMR ULTIMO SERVICIO], [HORAS DE TRABAJO ACUMULADO ], [ESTADO SOS],
           ROW_NUMBER() OVER (PARTITION BY [EQUIPO], [SISTEMA] ORDER BY [FECHA] DESC) AS rn
    FROM [Eqpcare].[HsCc] WITH (NOLOCK)
)
SELECT
    u.*,                               -- u ya trae HorasComponente (vw_UltimoAnalisisAceite <- vw_MuestrasRankeadas)
    H.[ESTADO SOS] AS Cond_Area        -- el JOIN a HsCc queda SOLO para Cond_Area
FROM [dbo].[vw_UltimoAnalisisAceite] u
LEFT JOIN hs H
  ON  H.rn = 1
  AND ( H.[EQUIPO] = u.Equipo
        OR (H.[EQUIPO] LIKE 'T[0-9]%' AND u.Equipo = 'CA' + SUBSTRING(H.[EQUIPO], 2, 10)) )
  AND H.[SISTEMA] = CASE
        WHEN u.Compartimiento LIKE '%TRACCION%LH' THEN 'WHEEL MOTOR LH'
        WHEN u.Compartimiento LIKE '%TRACCION%RH' THEN 'WHEEL MOTOR RH'
        WHEN u.Compartimiento LIKE '%HIDRAULICO%' THEN 'HYDRAULIC'
        WHEN u.Compartimiento LIKE '%RUEDA%LH'    THEN 'SPINDLE LH'
        WHEN u.Compartimiento LIKE '%RUEDA%RH'    THEN 'SPINDLE RH'
        WHEN u.Compartimiento LIKE 'MOTOR%'       THEN 'MOTOR DIESEL'
        ELSE u.Compartimiento END
/* Excluye muestras sin componente (Compartimiento NULL/vacío): no son un
   compartimiento real y ensucian el diagnóstico (p.ej. registros CM='PM4'). */
WHERE u.Compartimiento IS NOT NULL AND LTRIM(RTRIM(u.Compartimiento)) <> '';
GO


/* ----------------------------------------------------------------------------
   10) vw_TendenciaElemento — DETALLE POR ELEMENTO de la tendencia (PASO 2),
   PRE-FORMATEADO y LIGERO (hermana de vw_ObservadosDetalle). 1 fila por
   (Equipo, Compartimiento, Parametro) sobre las 6 últimas no-DDI:
     - d1..d6 = 6 valores cronológicos (d1=+antigua, d6=última) con chip embebido.
     - f1..f6 = las 6 fechas (encabezado de la matriz).
     - LP, LC, Prom, Sigma, Tendencia, NVecesObs, Inf, Grupo, Orden.
     - EsRelevante=1 si superó su umbral en >=1 muestra (TBN/P INVERSOS: por debajo).
   PASO 2 por defecto: WHERE EsRelevante=1 (~4-8 filas). Matriz completa: sin ese filtro.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaElemento] AS
WITH s AS (
    SELECT Equipo, Compartimiento, FechaMuestreo, rn_recencia, HorasComponente, CM,
           Fe_ppm, Fe_LP, Fe_LC, Indice_PQ, PQ_LP, PQ_LC, Cr_ppm, Cr_LP, Cr_LC,
           Ni_ppm, Ni_LP, Ni_LC, Cu_ppm, Cu_LP, Cu_LC, Pb_ppm, Pb_LP, Pb_LC, Sn_ppm, Sn_LP, Sn_LC,
           Al_ppm, Al_LP, Al_LC, Si_ppm, Si_LP, Si_LC, Ca_ppm, Ca_LP, Ca_LC,
           Zn_ppm, Zn_LP, Zn_LC, K_ppm, K_LP, K_LC, Na_ppm, Na_LP, Na_LC, Mg_ppm, Mg_LP, Mg_LC,
           B_ppm, P_ppm, V100, TBN, TBN_LP
    FROM [dbo].[vw_MuestrasRankeadas]
    WHERE rn_recencia <= 6
),
u AS (
    SELECT s.Equipo, s.Compartimiento, s.FechaMuestreo, s.rn_recencia, s.HorasComponente, s.CM,
           p.Parametro, p.Grupo, p.Orden, p.Inf, p.Inv,
           CAST(p.Valor AS decimal(18,2)) AS Valor,
           CAST(p.LP AS decimal(18,2))    AS LP,
           CAST(p.LC AS decimal(18,2))    AS LC
    FROM s
    CROSS APPLY (VALUES
        ('Fe',  'Met. Desg.', 1,  0,0, s.Fe_ppm,    s.Fe_LP, s.Fe_LC),
        ('PQ',  'Met. Desg.', 2,  0,0, s.Indice_PQ, s.PQ_LP, s.PQ_LC),
        ('Cr',  'Met. Desg.', 3,  0,0, s.Cr_ppm,    s.Cr_LP, s.Cr_LC),
        ('Ni',  'Met. Desg.', 4,  0,0, s.Ni_ppm,    s.Ni_LP, s.Ni_LC),
        ('Cu',  'Met. Desg.', 5,  0,0, s.Cu_ppm,    s.Cu_LP, s.Cu_LC),
        ('Pb',  'Met. Desg.', 6,  0,0, s.Pb_ppm,    s.Pb_LP, s.Pb_LC),
        ('Sn',  'Met. Desg.', 7,  0,0, s.Sn_ppm,    s.Sn_LP, s.Sn_LC),
        ('Al',  'Met. Desg.', 8,  0,0, s.Al_ppm,    s.Al_LP, s.Al_LC),
        ('Si',  'Contam.',    9,  0,0, s.Si_ppm,    s.Si_LP, s.Si_LC),
        ('Ca',  'Contam.',    10, 1,0, s.Ca_ppm,    s.Ca_LP, s.Ca_LC),
        ('Zn',  'Contam.',    11, 1,0, s.Zn_ppm,    s.Zn_LP, s.Zn_LC),
        ('K',   'Contam.',    12, 1,0, s.K_ppm,     s.K_LP,  s.K_LC),
        ('Na',  'Contam.',    13, 1,0, s.Na_ppm,    s.Na_LP, s.Na_LC),
        ('B',   'Adit.',      14, 1,0, s.B_ppm,     NULL,    NULL),
        ('P',   'Adit.',      15, 0,1, s.P_ppm,     240,     NULL),
        ('Mg',  'Adit.',      16, 1,0, s.Mg_ppm,    s.Mg_LP, s.Mg_LC),
        ('V100','Salud',      17, 0,0, s.V100,      NULL,    NULL),
        ('TBN', 'Salud',      18, 0,1, s.TBN,       s.TBN_LP,NULL)
    ) AS p(Parametro, Grupo, Orden, Inf, Inv, Valor, LP, LC)
),
v AS (
    SELECT u.*,
        CONVERT(varchar(24), CAST(u.Valor AS decimal(18,1)))
        + CASE
            WHEN u.Valor IS NULL THEN ''
            WHEN u.Inv = 1 THEN CASE WHEN u.LP IS NOT NULL AND u.Valor > 0 AND u.Valor < u.LP THEN ':P' ELSE '' END
            ELSE CASE WHEN u.Valor > ISNULL(u.LC, 999999) THEN ':C'
                      WHEN u.Valor > ISNULL(u.LP, 999999) THEN ':P' ELSE '' END
          END AS Vstr,
        CASE
            WHEN u.Valor IS NULL THEN 0
            WHEN u.Inv = 1 THEN CASE WHEN u.LP IS NOT NULL AND u.Valor > 0 AND u.Valor < u.LP THEN 1 ELSE 0 END
            ELSE CASE WHEN u.Valor > ISNULL(u.LP, 999999) THEN 1 ELSE 0 END
          END AS FueraUmbral
    FROM u
)
, sa AS (   -- TODAS las muestras no-DDI (no solo 6) para el ACUMULADO de vida del componente
    SELECT Equipo, Compartimiento, Fe_ppm, Indice_PQ, Cr_ppm, Ni_ppm, Cu_ppm, Pb_ppm, Sn_ppm, Al_ppm,
           Si_ppm, Ca_ppm, Zn_ppm, K_ppm, Na_ppm, B_ppm, P_ppm, Mg_ppm, V100, TBN
    FROM [dbo].[vw_MuestrasRankeadas]   -- ya filtra EsDDI=0 → suma solo muestras de monitoreo
)
, acc AS (
    -- Σ acumulada del metal = suma de su ppm en TODAS las muestras registradas del componente
    -- (proxy de exposición/desgaste acumulado en la vida del componente) + nº de muestras.
    SELECT sa.Equipo, sa.Compartimiento, pa.Parametro,
           CAST(SUM(pa.Valor) AS decimal(18,1)) AS Acumulado,
           COUNT(pa.Valor) AS NmAcum
    FROM sa
    CROSS APPLY (VALUES
        ('Fe',sa.Fe_ppm),('PQ',sa.Indice_PQ),('Cr',sa.Cr_ppm),('Ni',sa.Ni_ppm),('Cu',sa.Cu_ppm),
        ('Pb',sa.Pb_ppm),('Sn',sa.Sn_ppm),('Al',sa.Al_ppm),('Si',sa.Si_ppm),('Ca',sa.Ca_ppm),
        ('Zn',sa.Zn_ppm),('K',sa.K_ppm),('Na',sa.Na_ppm),('B',sa.B_ppm),('P',sa.P_ppm),
        ('Mg',sa.Mg_ppm),('V100',sa.V100),('TBN',sa.TBN)
    ) AS pa(Parametro, Valor)
    GROUP BY sa.Equipo, sa.Compartimiento, pa.Parametro
)
, g AS (
SELECT
    Equipo, Compartimiento, Parametro, Grupo, Orden, Inf,
    MAX(LP) AS LP, MAX(LC) AS LC,
    MAX(CASE WHEN rn_recencia = 1 THEN HorasComponente END) AS HorasComponente,
    MAX(CASE WHEN rn_recencia = 1 THEN CM END) AS CM,
    MAX(CASE WHEN rn_recencia = 6 THEN Vstr END) AS d1,
    MAX(CASE WHEN rn_recencia = 5 THEN Vstr END) AS d2,
    MAX(CASE WHEN rn_recencia = 4 THEN Vstr END) AS d3,
    MAX(CASE WHEN rn_recencia = 3 THEN Vstr END) AS d4,
    MAX(CASE WHEN rn_recencia = 2 THEN Vstr END) AS d5,
    MAX(CASE WHEN rn_recencia = 1 THEN Vstr END) AS d6,
    MAX(CASE WHEN rn_recencia = 6 THEN FechaMuestreo END) AS f1,
    MAX(CASE WHEN rn_recencia = 5 THEN FechaMuestreo END) AS f2,
    MAX(CASE WHEN rn_recencia = 4 THEN FechaMuestreo END) AS f3,
    MAX(CASE WHEN rn_recencia = 3 THEN FechaMuestreo END) AS f4,
    MAX(CASE WHEN rn_recencia = 2 THEN FechaMuestreo END) AS f5,
    MAX(CASE WHEN rn_recencia = 1 THEN FechaMuestreo END) AS f6,
    CAST(AVG(Valor) AS decimal(18,1)) AS Prom,
    CAST(STDEV(Valor) AS decimal(18,1)) AS Sigma,
    SUM(FueraUmbral) AS NVecesObs,
    CASE WHEN SUM(FueraUmbral) > 0 THEN 1 ELSE 0 END AS EsRelevante,
    CASE
        WHEN MAX(CASE WHEN rn_recencia=1 THEN Valor END) > MAX(CASE WHEN rn_recencia=6 THEN Valor END) THEN N'↑'
        WHEN MAX(CASE WHEN rn_recencia=1 THEN Valor END) < MAX(CASE WHEN rn_recencia=6 THEN Valor END) THEN N'↓'
        ELSE N'→'
    END AS Tendencia,
    MAX(CASE WHEN rn_recencia = 6 THEN Valor END) AS n1,
    MAX(CASE WHEN rn_recencia = 5 THEN Valor END) AS n2,
    MAX(CASE WHEN rn_recencia = 4 THEN Valor END) AS n3,
    MAX(CASE WHEN rn_recencia = 3 THEN Valor END) AS n4,
    MAX(CASE WHEN rn_recencia = 2 THEN Valor END) AS n5,
    MAX(CASE WHEN rn_recencia = 1 THEN Valor END) AS n6
FROM v
GROUP BY Equipo, Compartimiento, Parametro, Grupo, Orden, Inf
)
SELECT
    g.Equipo, g.Compartimiento, g.Parametro, Grupo, Orden, Inf, LP, LC, HorasComponente, CM,
    d1, d2, d3, d4, d5, d6, f1, f2, f3, f4, f5, f6, Prom, Sigma, NVecesObs, EsRelevante, Tendencia,
    /* Spark: mini-tendencia visual (bloques ▁▂▃▄▅▆▇█) de n1..n6 cronológicos, normalizada al rango de la
       propia serie. PRE-COMPUTADA para que el central la IMPRIMA/COPIE tal cual (no regenere ASCII).
       NULL -> '·' (sin muestra esa fecha); serie plana (mx=mn) -> '▄'. */
    CONCAT(
        CASE WHEN n1 IS NULL THEN N'·' WHEN mm.mx = mm.mn THEN N'▄' ELSE SUBSTRING(N'▁▂▃▄▅▆▇█', 1 + CAST(ROUND((n1-mm.mn)/NULLIF(mm.mx-mm.mn,0)*7, 0) AS int), 1) END,
        CASE WHEN n2 IS NULL THEN N'·' WHEN mm.mx = mm.mn THEN N'▄' ELSE SUBSTRING(N'▁▂▃▄▅▆▇█', 1 + CAST(ROUND((n2-mm.mn)/NULLIF(mm.mx-mm.mn,0)*7, 0) AS int), 1) END,
        CASE WHEN n3 IS NULL THEN N'·' WHEN mm.mx = mm.mn THEN N'▄' ELSE SUBSTRING(N'▁▂▃▄▅▆▇█', 1 + CAST(ROUND((n3-mm.mn)/NULLIF(mm.mx-mm.mn,0)*7, 0) AS int), 1) END,
        CASE WHEN n4 IS NULL THEN N'·' WHEN mm.mx = mm.mn THEN N'▄' ELSE SUBSTRING(N'▁▂▃▄▅▆▇█', 1 + CAST(ROUND((n4-mm.mn)/NULLIF(mm.mx-mm.mn,0)*7, 0) AS int), 1) END,
        CASE WHEN n5 IS NULL THEN N'·' WHEN mm.mx = mm.mn THEN N'▄' ELSE SUBSTRING(N'▁▂▃▄▅▆▇█', 1 + CAST(ROUND((n5-mm.mn)/NULLIF(mm.mx-mm.mn,0)*7, 0) AS int), 1) END,
        CASE WHEN n6 IS NULL THEN N'·' WHEN mm.mx = mm.mn THEN N'▄' ELSE SUBSTRING(N'▁▂▃▄▅▆▇█', 1 + CAST(ROUND((n6-mm.mn)/NULLIF(mm.mx-mm.mn,0)*7, 0) AS int), 1) END
    ) AS Spark,
    acc.Acumulado, acc.NmAcum   -- Σ acumulada de vida (todas las muestras no-DDI) + nº de muestras sumadas
FROM g
LEFT JOIN acc ON acc.Equipo = g.Equipo AND acc.Compartimiento = g.Compartimiento AND acc.Parametro = g.Parametro
CROSS APPLY (SELECT MIN(x) AS mn, MAX(x) AS mx FROM (VALUES (n1),(n2),(n3),(n4),(n5),(n6)) t(x)) mm;
GO


/* ----------------------------------------------------------------------------
   14) vw_TendenciaGrafico — GRÁFICO de tendencia (VERTICAL, multi-línea) AISLADO.
   Hermana ligera-de-consumo de vw_TendenciaElemento: 1 fila por (Equipo,Compartimiento,
   Parametro) con SOLO la columna Grafico (pesada). Se separa para que la TABLA de
   tendencia (vw_TendenciaElemento) quede LIGERA: el Grafico (multi-línea) NO viaja
   en consultas multi-componente (evita payload/SystemError). Consultar SOLO de 1
   componente cuando se pide «el gráfico»:
     SELECT Grafico FROM vw_TendenciaGrafico WHERE Equipo='..' AND Parametro='..' AND Compartimiento LIKE '%..%'
   Lee d1..d6 de vw_TendenciaElemento (parsea el número antes del chip) → no duplica CTEs.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaGrafico] AS
SELECT te.Equipo, te.Compartimiento, te.Parametro,
    CONCAT(
        te.Parametro, N' — ', te.Compartimiento, N' (ppm)',
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=12 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 12=b1.rLC THEN N'·········' WHEN 12=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=12 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 12=b1.rLC THEN N'·········' WHEN 12=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=12 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 12=b1.rLC THEN N'·········' WHEN 12=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=12 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 12=b1.rLC THEN N'·········' WHEN 12=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=12 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 12=b1.rLC THEN N'·········' WHEN 12=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=12 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 12=b1.rLC THEN N'·········' WHEN 12=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 12=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 12=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=11 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 11=b1.rLC THEN N'·········' WHEN 11=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=11 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 11=b1.rLC THEN N'·········' WHEN 11=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=11 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 11=b1.rLC THEN N'·········' WHEN 11=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=11 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 11=b1.rLC THEN N'·········' WHEN 11=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=11 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 11=b1.rLC THEN N'·········' WHEN 11=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=11 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 11=b1.rLC THEN N'·········' WHEN 11=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 11=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 11=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=10 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 10=b1.rLC THEN N'·········' WHEN 10=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=10 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 10=b1.rLC THEN N'·········' WHEN 10=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=10 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 10=b1.rLC THEN N'·········' WHEN 10=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=10 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 10=b1.rLC THEN N'·········' WHEN 10=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=10 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 10=b1.rLC THEN N'·········' WHEN 10=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=10 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 10=b1.rLC THEN N'·········' WHEN 10=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 10=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 10=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=9 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 9=b1.rLC THEN N'·········' WHEN 9=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=9 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 9=b1.rLC THEN N'·········' WHEN 9=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=9 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 9=b1.rLC THEN N'·········' WHEN 9=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=9 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 9=b1.rLC THEN N'·········' WHEN 9=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=9 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 9=b1.rLC THEN N'·········' WHEN 9=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=9 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 9=b1.rLC THEN N'·········' WHEN 9=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 9=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 9=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=8 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 8=b1.rLC THEN N'·········' WHEN 8=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=8 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 8=b1.rLC THEN N'·········' WHEN 8=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=8 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 8=b1.rLC THEN N'·········' WHEN 8=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=8 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 8=b1.rLC THEN N'·········' WHEN 8=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=8 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 8=b1.rLC THEN N'·········' WHEN 8=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=8 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 8=b1.rLC THEN N'·········' WHEN 8=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 8=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 8=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=7 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 7=b1.rLC THEN N'·········' WHEN 7=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=7 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 7=b1.rLC THEN N'·········' WHEN 7=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=7 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 7=b1.rLC THEN N'·········' WHEN 7=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=7 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 7=b1.rLC THEN N'·········' WHEN 7=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=7 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 7=b1.rLC THEN N'·········' WHEN 7=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=7 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 7=b1.rLC THEN N'·········' WHEN 7=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 7=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 7=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=6 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 6=b1.rLC THEN N'·········' WHEN 6=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=6 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 6=b1.rLC THEN N'·········' WHEN 6=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=6 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 6=b1.rLC THEN N'·········' WHEN 6=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=6 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 6=b1.rLC THEN N'·········' WHEN 6=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=6 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 6=b1.rLC THEN N'·········' WHEN 6=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=6 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 6=b1.rLC THEN N'·········' WHEN 6=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 6=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 6=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=5 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 5=b1.rLC THEN N'·········' WHEN 5=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=5 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 5=b1.rLC THEN N'·········' WHEN 5=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=5 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 5=b1.rLC THEN N'·········' WHEN 5=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=5 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 5=b1.rLC THEN N'·········' WHEN 5=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=5 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 5=b1.rLC THEN N'·········' WHEN 5=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=5 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 5=b1.rLC THEN N'·········' WHEN 5=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 5=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 5=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=4 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 4=b1.rLC THEN N'·········' WHEN 4=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=4 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 4=b1.rLC THEN N'·········' WHEN 4=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=4 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 4=b1.rLC THEN N'·········' WHEN 4=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=4 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 4=b1.rLC THEN N'·········' WHEN 4=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=4 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 4=b1.rLC THEN N'·········' WHEN 4=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=4 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 4=b1.rLC THEN N'·········' WHEN 4=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 4=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 4=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=3 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 3=b1.rLC THEN N'·········' WHEN 3=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=3 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 3=b1.rLC THEN N'·········' WHEN 3=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=3 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 3=b1.rLC THEN N'·········' WHEN 3=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=3 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 3=b1.rLC THEN N'·········' WHEN 3=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=3 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 3=b1.rLC THEN N'·········' WHEN 3=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=3 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 3=b1.rLC THEN N'·········' WHEN 3=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 3=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 3=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=2 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 2=b1.rLC THEN N'·········' WHEN 2=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=2 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 2=b1.rLC THEN N'·········' WHEN 2=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=2 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 2=b1.rLC THEN N'·········' WHEN 2=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=2 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 2=b1.rLC THEN N'·········' WHEN 2=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=2 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 2=b1.rLC THEN N'·········' WHEN 2=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=2 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 2=b1.rLC THEN N'·········' WHEN 2=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 2=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 2=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'|', CASE WHEN p.n1 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n1/b0.vtop*12,0) AS int)=1 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n1 AS decimal(18,1))),9) WHEN 1=b1.rLC THEN N'·········' WHEN 1=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n2 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n2/b0.vtop*12,0) AS int)=1 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n2 AS decimal(18,1))),9) WHEN 1=b1.rLC THEN N'·········' WHEN 1=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n3 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n3/b0.vtop*12,0) AS int)=1 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n3 AS decimal(18,1))),9) WHEN 1=b1.rLC THEN N'·········' WHEN 1=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n4 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n4/b0.vtop*12,0) AS int)=1 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n4 AS decimal(18,1))),9) WHEN 1=b1.rLC THEN N'·········' WHEN 1=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n5 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n5/b0.vtop*12,0) AS int)=1 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n5 AS decimal(18,1))),9) WHEN 1=b1.rLC THEN N'·········' WHEN 1=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN p.n6 IS NOT NULL AND b0.vtop>0 AND CAST(ROUND(p.n6/b0.vtop*12,0) AS int)=1 THEN RIGHT(N'         '+N'×'+CONVERT(varchar(12),CAST(p.n6 AS decimal(18,1))),9) WHEN 1=b1.rLC THEN N'·········' WHEN 1=b1.rLP THEN N'---------' ELSE N'         ' END, CASE WHEN 1=b1.rLC THEN N' LC '+CONVERT(varchar(12),CAST(te.LC AS decimal(18,1))) WHEN 1=b1.rLP THEN N' LP '+CONVERT(varchar(12),CAST(te.LP AS decimal(18,1))) ELSE N'' END,
        CHAR(10), N'+', CASE WHEN te.f1 IS NULL THEN N'         ' ELSE RIGHT(N'         '+CONVERT(varchar(2),DAY(te.f1)),9) END, CASE WHEN te.f2 IS NULL THEN N'         ' ELSE RIGHT(N'         '+CONVERT(varchar(2),DAY(te.f2)),9) END, CASE WHEN te.f3 IS NULL THEN N'         ' ELSE RIGHT(N'         '+CONVERT(varchar(2),DAY(te.f3)),9) END, CASE WHEN te.f4 IS NULL THEN N'         ' ELSE RIGHT(N'         '+CONVERT(varchar(2),DAY(te.f4)),9) END, CASE WHEN te.f5 IS NULL THEN N'         ' ELSE RIGHT(N'         '+CONVERT(varchar(2),DAY(te.f5)),9) END, CASE WHEN te.f6 IS NULL THEN N'         ' ELSE RIGHT(N'         '+CONVERT(varchar(2),DAY(te.f6)),9) END, N' ', CHOOSE(MONTH(te.f6), N'Jan',N'Feb',N'Mar',N'Apr',N'May',N'Jun',N'Jul',N'Aug',N'Sep',N'Oct',N'Nov',N'Dec')
    ) AS Grafico
FROM [dbo].[vw_TendenciaElemento] te
CROSS APPLY (SELECT TRY_CONVERT(decimal(18,2), LEFT(te.d1, CHARINDEX(':', te.d1+':')-1)) AS n1,
        TRY_CONVERT(decimal(18,2), LEFT(te.d2, CHARINDEX(':', te.d2+':')-1)) AS n2,
        TRY_CONVERT(decimal(18,2), LEFT(te.d3, CHARINDEX(':', te.d3+':')-1)) AS n3,
        TRY_CONVERT(decimal(18,2), LEFT(te.d4, CHARINDEX(':', te.d4+':')-1)) AS n4,
        TRY_CONVERT(decimal(18,2), LEFT(te.d5, CHARINDEX(':', te.d5+':')-1)) AS n5,
        TRY_CONVERT(decimal(18,2), LEFT(te.d6, CHARINDEX(':', te.d6+':')-1)) AS n6) p
CROSS APPLY (SELECT MIN(x) AS mn, MAX(x) AS mx FROM (VALUES (p.n1),(p.n2),(p.n3),(p.n4),(p.n5),(p.n6)) t(x)) mm
CROSS APPLY (SELECT CASE WHEN ISNULL(te.LC,0) > ISNULL(mm.mx,0) THEN te.LC ELSE mm.mx END AS vtop) b0
CROSS APPLY (SELECT CASE WHEN b0.vtop>0 AND te.LC IS NOT NULL THEN CAST(ROUND(te.LC/b0.vtop*12,0) AS int) ELSE -1 END AS rLC,
                    CASE WHEN b0.vtop>0 AND te.LP IS NOT NULL THEN CAST(ROUND(te.LP/b0.vtop*12,0) AS int) ELSE -1 END AS rLP) b1;
GO


/* ----------------------------------------------------------------------------
   11) vw_HistorialMuestra — HISTORIAL muestra por muestra (últimos 2 meses, horneados).
   1 fila por MUESTRA (INCLUYE DDI, flag EsDDI), últimos 2 MESES (ventana horneada en la vista), PRE-FORMATEADA: cada parámetro
   ya trae su chip (marcador :C >LC, :P >LP; informativos Ca/Zn/K/Mg con ' inf'; TBN inverso).
   A diferencia de la tendencia (params en filas, 6 fechas), aquí las FECHAS van en
   FILAS (orden descendente al consultar) y los params en columnas -> tabla "cantidad
   de datos", sin estadistica. LIGERA: ventana 2 meses + columnas chip (no LP/LC).
   Reutiliza vw_MuestrasEstado (Estado_<metal> ya calculado). Se consulta por
   Equipo + Compartimiento: SELECT * FROM vw_HistorialMuestra WHERE Equipo='..'
   AND Compartimiento LIKE '%..%' ORDER BY FechaMuestreo DESC. (la vista ya acota 2 meses)
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_HistorialMuestra] AS
WITH hs AS (
    -- HsCc pre-rankeado: 1 fila (la más reciente) por EQUIPO+SISTEMA. Se escanea UNA vez
    -- (antes era subconsulta correlacionada por fila → HsCc escaneado 2112x). Alias Eq/Sis/Smr/Hta
    -- evitan ambiguedad con me.Equipo. Mapeo EQUIPO 'T####'->'CA####' y SISTEMA inglés<->compartimiento.
    SELECT [EQUIPO] AS Eq, [SISTEMA] AS Sis,
           TRY_CONVERT(decimal(12,2),[SMR ULTIMO SERVICIO])        AS Smr,
           TRY_CONVERT(decimal(12,2),[HORAS DE TRABAJO ACUMULADO ]) AS Hta,
           ROW_NUMBER() OVER (PARTITION BY [EQUIPO],[SISTEMA] ORDER BY [FECHA] DESC) AS rn
    FROM [Eqpcare].[HsCc]
)
SELECT
    Equipo, Proyecto, Modelo, Compartimiento, FechaMuestreo,
    Horometro, HorasDeAceite, CM, EsDDI, Estado_General,
    /* Met. Obs. = metales fuera de umbral de ESA muestra (determinantes + informativos con ' inf'),
       reusa Estado_<metal> ya calculados. Para variantes 1/4/5 del historial. */
    STUFF(CONCAT(
        CASE Estado_Fe  WHEN 'CRITICO' THEN ',Fe:C'  WHEN 'PRECAUCION' THEN ',Fe:P'  ELSE '' END,
        CASE Estado_PQ  WHEN 'CRITICO' THEN ',PQ:C'  WHEN 'PRECAUCION' THEN ',PQ:P'  ELSE '' END,
        CASE Estado_Cr  WHEN 'CRITICO' THEN ',Cr:C'  WHEN 'PRECAUCION' THEN ',Cr:P'  ELSE '' END,
        CASE Estado_Ni  WHEN 'CRITICO' THEN ',Ni:C'  WHEN 'PRECAUCION' THEN ',Ni:P'  ELSE '' END,
        CASE Estado_Cu  WHEN 'CRITICO' THEN ',Cu:C'  WHEN 'PRECAUCION' THEN ',Cu:P'  ELSE '' END,
        CASE Estado_Pb  WHEN 'PRECAUCION' THEN ',Pb:P' ELSE '' END,
        CASE Estado_Sn  WHEN 'PRECAUCION' THEN ',Sn:P' ELSE '' END,
        CASE Estado_Al  WHEN 'CRITICO' THEN ',Al:C'  WHEN 'PRECAUCION' THEN ',Al:P'  ELSE '' END,
        CASE Estado_Si  WHEN 'CRITICO' THEN ',Si:C'  WHEN 'PRECAUCION' THEN ',Si:P'  ELSE '' END,
        CASE Estado_TBN WHEN 'PRECAUCION' THEN ',TBN:P' ELSE '' END,
        CASE Estado_Ca  WHEN 'CRITICO' THEN ',Ca:C inf' WHEN 'PRECAUCION' THEN ',Ca:P inf' ELSE '' END,
        CASE Estado_Zn  WHEN 'CRITICO' THEN ',Zn:C inf' WHEN 'PRECAUCION' THEN ',Zn:P inf' ELSE '' END,
        CASE Estado_K   WHEN 'CRITICO' THEN ',K:C inf'  WHEN 'PRECAUCION' THEN ',K:P inf'  ELSE '' END,
        CASE Estado_Na  WHEN 'CRITICO' THEN ',Na:C inf' WHEN 'PRECAUCION' THEN ',Na:P inf' ELSE '' END,
        CASE Estado_Mg  WHEN 'CRITICO' THEN ',Mg:C inf' WHEN 'PRECAUCION' THEN ',Mg:P inf' ELSE '' END
    ), 1, 1, '') AS Mets_Obs,
    CONVERT(varchar(20),CAST(Fe_ppm    AS decimal(18,1))) + CASE Estado_Fe  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Fe,
    CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1))) + CASE Estado_PQ  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS PQ,
    CONVERT(varchar(20),CAST(Cr_ppm    AS decimal(18,1))) + CASE Estado_Cr  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Cr,
    CONVERT(varchar(20),CAST(Ni_ppm    AS decimal(18,1))) + CASE Estado_Ni  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Ni,
    CONVERT(varchar(20),CAST(Cu_ppm    AS decimal(18,1))) + CASE Estado_Cu  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Cu,
    CONVERT(varchar(20),CAST(Pb_ppm    AS decimal(18,1))) + CASE Estado_Pb  WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Pb,
    CONVERT(varchar(20),CAST(Sn_ppm    AS decimal(18,1))) + CASE Estado_Sn  WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Sn,
    CONVERT(varchar(20),CAST(Al_ppm    AS decimal(18,1))) + CASE Estado_Al  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Al,
    CONVERT(varchar(20),CAST(Si_ppm    AS decimal(18,1))) + CASE Estado_Si  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Si,
    CONVERT(varchar(20),CAST(Ca_ppm    AS decimal(18,1))) + CASE Estado_Ca  WHEN 'CRITICO' THEN ':C inf' WHEN 'PRECAUCION' THEN ':P inf' ELSE '' END AS Ca,
    CONVERT(varchar(20),CAST(Zn_ppm    AS decimal(18,1))) + CASE Estado_Zn  WHEN 'CRITICO' THEN ':C inf' WHEN 'PRECAUCION' THEN ':P inf' ELSE '' END AS Zn,
    CONVERT(varchar(20),CAST(K_ppm     AS decimal(18,1))) + CASE Estado_K   WHEN 'CRITICO' THEN ':C inf' WHEN 'PRECAUCION' THEN ':P inf' ELSE '' END AS K,
    CONVERT(varchar(20),CAST(Na_ppm    AS decimal(18,1))) + CASE Estado_Na  WHEN 'CRITICO' THEN ':C inf' WHEN 'PRECAUCION' THEN ':P inf' ELSE '' END AS Na,
    CONVERT(varchar(20),CAST(Mg_ppm    AS decimal(18,1))) + CASE Estado_Mg  WHEN 'CRITICO' THEN ':C inf' WHEN 'PRECAUCION' THEN ':P inf' ELSE '' END AS Mg,
    CONVERT(varchar(20),CAST(B_ppm     AS decimal(18,1))) AS B,
    CONVERT(varchar(20),CAST(P_ppm     AS decimal(18,1))) AS P,
    CONVERT(varchar(20),CAST(V100      AS decimal(18,1))) AS V100,
    CONVERT(varchar(20),CAST(TBN       AS decimal(18,1))) + CASE Estado_TBN WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS TBN,
    CASE WHEN H.Smr IS NOT NULL AND me.Horometro >= H.Smr THEN me.Horometro - H.Smr ELSE H.Hta END AS HorasComponente
FROM [dbo].[vw_MuestrasEstado] me
LEFT JOIN hs H
  ON  H.rn = 1
  AND ( H.Eq = me.Equipo OR (H.Eq LIKE 'T[0-9]%' AND me.Equipo = 'CA'+SUBSTRING(H.Eq,2,10)) )
  AND H.Sis = CASE WHEN me.Compartimiento LIKE '%TRACCION%LH' THEN 'WHEEL MOTOR LH'
                   WHEN me.Compartimiento LIKE '%TRACCION%RH' THEN 'WHEEL MOTOR RH'
                   WHEN me.Compartimiento LIKE '%HIDRAULICO%' THEN 'HYDRAULIC'
                   WHEN me.Compartimiento LIKE '%RUEDA%LH'    THEN 'SPINDLE LH'
                   WHEN me.Compartimiento LIKE '%RUEDA%RH'    THEN 'SPINDLE RH'
                   WHEN me.Compartimiento LIKE 'MOTOR%'       THEN 'MOTOR DIESEL'
                   ELSE me.Compartimiento END
WHERE me.Compartimiento IS NOT NULL
  AND me.FechaMuestreo >= DATEADD(MONTH, -2, GETDATE());   -- ventana 2 meses HORNEADA (a prueba de error del agente)
GO



/* ----------------------------------------------------------------------------
   12) vw_DiagnosticoEquipo — DIAGNÓSTICO por equipo, PRE-FORMATEADO (anti-corte).
   1 fila por COMPONENTE (último análisis no-DDI, TODOS los componentes incl. OK),
   con cada parámetro YA chip-marcado (:C >LC, :P >LP; informativos con ' inf';
   TBN inverso). + HorasComponente (HsCc). El central solo PIVOTA componente x
   parametro y PINTA (no computa chips ni carga 58 columnas crudas) -> no se corta.
   Espejo de vw_HistorialMuestra pero sobre vw_UltimoAnalisisFlota. Consultar por
   Equipo: SELECT * FROM vw_DiagnosticoEquipo WHERE Equipo='CAxxxx' ORDER BY Compartimiento.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_DiagnosticoEquipo] AS
SELECT
    Equipo, Proyecto, Modelo, Compartimiento, CompTipo, FechaMuestreo,
    Horometro, HorasDeAceite, HorasComponente, CM, Grado, Estado_General, Cond_Area,
    -- conteos por equipo (sobre TODOS los componentes) para el encabezado «X de N observados»
    -- aunque el central filtre Estado_General<>'OK': los window se calculan antes del filtro.
    COUNT(*) OVER (PARTITION BY Equipo) AS NumCompTotal,
    SUM(CASE WHEN Estado_General <> 'OK' THEN 1 ELSE 0 END) OVER (PARTITION BY Equipo) AS NumCompObs,
    CONVERT(varchar(20),CAST(Fe_ppm    AS decimal(18,1))) + CASE Estado_Fe  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Fe,
    CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1))) + CASE Estado_PQ  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS PQ,
    CONVERT(varchar(20),CAST(Cr_ppm    AS decimal(18,1))) + CASE Estado_Cr  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Cr,
    CONVERT(varchar(20),CAST(Ni_ppm    AS decimal(18,1))) + CASE Estado_Ni  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Ni,
    CONVERT(varchar(20),CAST(Cu_ppm    AS decimal(18,1))) + CASE Estado_Cu  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Cu,
    CONVERT(varchar(20),CAST(Pb_ppm    AS decimal(18,1))) + CASE Estado_Pb  WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Pb,
    CONVERT(varchar(20),CAST(Sn_ppm    AS decimal(18,1))) + CASE Estado_Sn  WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Sn,
    CONVERT(varchar(20),CAST(Al_ppm    AS decimal(18,1))) + CASE Estado_Al  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Al,
    CONVERT(varchar(20),CAST(Si_ppm    AS decimal(18,1))) + CASE Estado_Si  WHEN 'CRITICO' THEN ':C' WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS Si,
    CONVERT(varchar(20),CAST(Ca_ppm    AS decimal(18,1))) + CASE Estado_Ca  WHEN 'CRITICO' THEN ':C inf' WHEN 'PRECAUCION' THEN ':P inf' ELSE '' END AS Ca,
    CONVERT(varchar(20),CAST(Zn_ppm    AS decimal(18,1))) + CASE Estado_Zn  WHEN 'CRITICO' THEN ':C inf' WHEN 'PRECAUCION' THEN ':P inf' ELSE '' END AS Zn,
    CONVERT(varchar(20),CAST(K_ppm     AS decimal(18,1))) + CASE Estado_K   WHEN 'CRITICO' THEN ':C inf' WHEN 'PRECAUCION' THEN ':P inf' ELSE '' END AS K,
    CONVERT(varchar(20),CAST(Na_ppm    AS decimal(18,1))) + CASE Estado_Na  WHEN 'CRITICO' THEN ':C inf' WHEN 'PRECAUCION' THEN ':P inf' ELSE '' END AS Na,
    CONVERT(varchar(20),CAST(Mg_ppm    AS decimal(18,1))) + CASE Estado_Mg  WHEN 'CRITICO' THEN ':C inf' WHEN 'PRECAUCION' THEN ':P inf' ELSE '' END AS Mg,
    CONVERT(varchar(20),CAST(B_ppm     AS decimal(18,1))) AS B,
    CONVERT(varchar(20),CAST(P_ppm     AS decimal(18,1))) AS P,
    CONVERT(varchar(20),CAST(V100      AS decimal(18,1))) AS V100,
    CONVERT(varchar(20),CAST(TBN       AS decimal(18,1))) + CASE Estado_TBN WHEN 'PRECAUCION' THEN ':P' ELSE '' END AS TBN
FROM [dbo].[vw_UltimoAnalisisFlota];
GO


/* ----------------------------------------------------------------------------
   13) vw_HistorialFlotaObs — HISTORIAL DE OBSERVADOS EN FLOTA (variante 5), AGREGADO
   POR FECHA y LIGERO (solución directa, anti-timeout). 1 fila por (Proyecto,Modelo,
   Fecha): equipos/componentes/metales observados ese día (distintos). Ventana 30 días
   (más corta que el historial por-equipo: la flota completa por 2 meses se colgaba).
   NO trae los 17 params ni Hor. Comp. → no dispara la subconsulta lenta. El central
   PINTA directo (Fec | NumEquipos | Equip.Obs | Comp.Obs | Met.Obs), NO agrega él.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_HistorialFlotaObs] AS
WITH obs AS (
    SELECT Proyecto, Modelo, FechaMuestreo, Equipo, Compartimiento, Mets_Obs
    FROM [dbo].[vw_HistorialMuestra]
    WHERE Mets_Obs IS NOT NULL
      AND FechaMuestreo >= DATEADD(DAY, -30, GETDATE())
),
eq AS (
    SELECT Proyecto, Modelo, FechaMuestreo, COUNT(*) AS NumEquipos,
           STRING_AGG(Equipo, ', ') WITHIN GROUP (ORDER BY Equipo) AS Equip_Obs
    FROM (SELECT DISTINCT Proyecto, Modelo, FechaMuestreo, Equipo FROM obs) d
    GROUP BY Proyecto, Modelo, FechaMuestreo
),
cp AS (
    SELECT Proyecto, Modelo, FechaMuestreo,
           STRING_AGG(Compartimiento, ' · ') WITHIN GROUP (ORDER BY Compartimiento) AS Comp_Obs
    FROM (SELECT DISTINCT Proyecto, Modelo, FechaMuestreo, Compartimiento FROM obs) d
    GROUP BY Proyecto, Modelo, FechaMuestreo
),
mt AS (
    SELECT Proyecto, Modelo, FechaMuestreo,
           STRING_AGG(Metal, ', ') WITHIN GROUP (ORDER BY Metal) AS Met_Obs
    FROM (SELECT DISTINCT o.Proyecto, o.Modelo, o.FechaMuestreo,
                 LTRIM(LEFT(s.value, CHARINDEX(':', s.value + ':') - 1)) AS Metal
          FROM obs o CROSS APPLY STRING_SPLIT(o.Mets_Obs, ',') s) d
    GROUP BY Proyecto, Modelo, FechaMuestreo
)
SELECT eq.Proyecto, eq.Modelo, eq.FechaMuestreo, eq.NumEquipos,
       eq.Equip_Obs, cp.Comp_Obs, mt.Met_Obs
FROM eq
JOIN cp ON cp.Proyecto=eq.Proyecto AND cp.Modelo=eq.Modelo AND cp.FechaMuestreo=eq.FechaMuestreo
JOIN mt ON mt.Proyecto=eq.Proyecto AND mt.Modelo=eq.Modelo AND mt.FechaMuestreo=eq.FechaMuestreo;
GO


/* ============================================================================
   VALIDACIÓN  (queries de ejemplo; cópialas fuera de este comentario para correrlas)
   ----------------------------------------------------------------------------
   -- (A) Cadena base — Ca/Zn con límites y estado; y que el triage MT no cambió:
   SELECT Equipo, Compartimiento, Si_ppm, Ca_ppm, Ca_LP, Zn_ppm, Zn_LP, B_ppm, P_ppm, V100
   FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK) WHERE Equipo='CA3171';
   SELECT COUNT(*) FROM [dbo].[vw_EstadoActualMT] WITH (NOLOCK)
     WHERE Proyecto LIKE '%Antapaccay%' AND Estado_General <> 'OK';

   -- (B) Determinismo (desempate por LaboratoryDataId en fechas empatadas):
   SELECT FechaMuestreo, LaboratoryDataId, Fe_ppm, rn_recencia
   FROM [dbo].[vw_MuestrasRankeadas] WITH (NOLOCK)
   WHERE Equipo='CA3171' AND Compartimiento LIKE '%TRACCION%LH' ORDER BY rn_recencia;

   -- (C) Límites por MODELO (deben variar en HIDRAULICO; TRACCION por proyecto):
   SELECT ProyKey, ModeloKey, CompTipo, Fe_LP, Fe_LC, Cu_LP, Cu_LC
   FROM [dbo].[vw_LimitesPorComponente] WITH (NOLOCK)
   WHERE CompTipo IN ('TRACCION','HIDRAULICO') ORDER BY CompTipo, ProyKey, ModeloKey;

   -- (D) BARRIDO — observados de flota con horas de componente reales (HsCc):
   SELECT Equipo, Compartimiento, FechaMuestreo, Horometro, HorasDeAceite,
          HorasComponente, Cond_Area, Estado_General, Mets_Obs, Infs_Obs, NumCrit, NumPrec
   FROM [dbo].[vw_ObservadosFlota] WITH (NOLOCK)
   WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%' AND Mets_Obs IS NOT NULL
   ORDER BY NumCrit DESC, NumPrec DESC, Equipo;

   -- (E) BARRIDO PASO 2 — detalle ligero pre-formateado (lo que consume el central):
   SELECT * FROM [dbo].[vw_ObservadosDetalle] WITH (NOLOCK)
   WHERE Proyecto LIKE '%Antapaccay%' AND Modelo LIKE '%980E%'
   ORDER BY NumCrit DESC, Equipo, Compartimiento;

   REVERTIR todo:  DROP VIEW en orden inverso (vw_HistorialFlotaObs → vw_HistorialMuestra → vw_TendenciaElemento →
   vw_UltimoAnalisisFlota → vw_ObservadosDetalle → vw_ObservadosResumen → vw_ObservadosFlota →
   vw_EstadoActualMT → vw_UltimoAnalisisAceite → vw_MuestrasRankeadas → vw_MuestrasEstado →
   vw_LimitesPorComponente).
   ============================================================================ */


/* ============================================================================
   vw_ObservadosBarridoMD — TIER 2 (render determinístico / copia verbatim).
   Pre-arma EL BLOQUE MARKDOWN del DETALLE de barrido ("detalle de todos"), el
   caso lento (~2 min de render del central con flotas grandes). En vez de que el
   LLM pivotee/escriba la tabla token por token, la VISTA la entrega YA armada y
   el central la imprime VERBATIM. 1 fila por Proyecto+Modelo.
     - DetalleTodosMD: bloque markdown completo, agrupado por componente (críticos
       primero), cada sección con su mini-tabla | Equipo | Fec. | Hor.Comp. | CM |
       Est. | Observado |. Observado = columna Detalle con :C/:P → 🟥/🟨.
     - NumEquipos / NumEquiposCriticos / NumEquiposSoloPrecau: cifras para que el
       central redacte un RESUMEN corto y gerencial (pocos tokens = rápido).
   ⚠ Contiene emojis (🟥🟨): al crear la vista, ABRIR/EJECUTAR este .sql en SSMS
   desde el archivo (UTF-8), NO re-tipear ni pegar por un canal que los pierda.
   Depende de vw_ObservadosDetalle (bloque) y vw_ObservadosResumen (cifras).
   Validación: VALIDACION_SSMS.sql BLOQUE 32.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_ObservadosBarridoMD] AS
WITH f AS (
    SELECT
        Proyecto, Modelo, Compartimiento, Equipo, Estado_General, Grado, FechaMuestreo, HorasComponente, CM,
        CASE WHEN Estado_General = 'CRITICO' THEN 1 ELSE 2 END AS sev,
        STUFF(CONCAT(
            CASE WHEN Fe_ppm>ISNULL(Fe_LC,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+':C' WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Indice_PQ>ISNULL(PQ_LC,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+':C' WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Cr_ppm>ISNULL(Cr_LC,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+':C' WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Ni_ppm>ISNULL(Ni_LC,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+':C' WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Cu_ppm>ISNULL(Cu_LC,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+':C' WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Al_ppm>ISNULL(Al_LC,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+':C' WHEN Al_ppm>ISNULL(Al_LP,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Si_ppm>ISNULL(Si_LC,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+':C' WHEN Si_ppm>ISNULL(Si_LP,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN ' · Pb='+CONVERT(varchar(20),CAST(Pb_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN ' · Sn='+CONVERT(varchar(20),CAST(Sn_ppm AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN ' · TBN='+CONVERT(varchar(20),CAST(TBN AS decimal(18,1)))+':P' ELSE '' END,
            CASE WHEN Ca_ppm>ISNULL(Ca_LC,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+':C inf' WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+':P inf' ELSE '' END,
            CASE WHEN Zn_ppm>ISNULL(Zn_LC,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+':C inf' WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+':P inf' ELSE '' END,
            CASE WHEN K_ppm>ISNULL(K_LC,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+':C inf' WHEN K_ppm>ISNULL(K_LP,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+':P inf' ELSE '' END,
            CASE WHEN Na_ppm>ISNULL(Na_LC,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+':C inf' WHEN Na_ppm>ISNULL(Na_LP,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+':P inf' ELSE '' END,
            CASE WHEN Mg_ppm>ISNULL(Mg_LC,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+':C inf' WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+':P inf' ELSE '' END,
            /* SALUD del aceite: viscosidad V100 (informativo, no dispara Estado_General; solo aparece en equipos ya observados) */
            CASE WHEN Estado_V100='CRITICO' THEN ' · V100='+CONVERT(varchar(20),CAST(V100 AS decimal(18,1)))+':C salud' WHEN Estado_V100='PRECAUCION' THEN ' · V100='+CONVERT(varchar(20),CAST(V100 AS decimal(18,1)))+':P salud' ELSE '' END
        ),1,3,'') AS chipsCell
    FROM [dbo].[vw_ObservadosFlota]
    WHERE Estado_General <> 'OK'
),
fila AS (
    SELECT Proyecto, Modelo, Compartimiento, sev, Equipo, Estado_General,
        CAST(
            N'| ' + Equipo
          + N' | ' + ISNULL(Grado, N'—')
          + N' | ' + ISNULL(FORMAT(FechaMuestreo, 'dd-MMM'), N'—')
          + N' | ' + ISNULL(CONVERT(nvarchar(12), HorasComponente), N'—')
          + N' | ' + ISNULL(CM, N'—')
          + N' | ' + CASE Estado_General WHEN 'CRITICO' THEN N'🟥' WHEN 'PRECAUCION' THEN N'🟨' ELSE N'' END
          + N' | ' + ISNULL(REPLACE(REPLACE(chipsCell, ':C', N' 🟥'), ':P', N' 🟨'), N'—')
          + N' |'
        AS nvarchar(max)) AS filaMD
    FROM f
),
t_sec AS (
    SELECT Proyecto, Modelo, Compartimiento, MIN(sev) AS sev,
        CAST(
            N'**' + Compartimiento + N'** (' + CAST(COUNT(*) AS nvarchar(10)) + N' equipos)' + NCHAR(10)
          + N'| Equipo | Grado | Fec. | Hor.Comp. | CM | Est. | Observado |' + NCHAR(10)
          + N'|---|---|---|---|---|---|---|' + NCHAR(10)
          + STRING_AGG(filaMD, NCHAR(10)) WITHIN GROUP (ORDER BY sev, Equipo)
        AS nvarchar(max)) AS seccionMD
    FROM fila
    GROUP BY Proyecto, Modelo, Compartimiento
),
t_agg AS (
    SELECT Proyecto, Modelo,
        STRING_AGG(seccionMD, NCHAR(10)+NCHAR(10)) WITHIN GROUP (ORDER BY sev, Compartimiento) AS Secciones
    FROM t_sec GROUP BY Proyecto, Modelo
),
c_sec AS (
    SELECT Proyecto, Modelo, Compartimiento, MIN(sev) AS sev,
        CAST(
            N'**' + Compartimiento + N'** (' + CAST(COUNT(*) AS nvarchar(10)) + N' equipos)' + NCHAR(10)
          + N'| Equipo | Grado | Fec. | Hor.Comp. | CM | Est. | Observado |' + NCHAR(10)
          + N'|---|---|---|---|---|---|---|' + NCHAR(10)
          + STRING_AGG(filaMD, NCHAR(10)) WITHIN GROUP (ORDER BY sev, Equipo)
        AS nvarchar(max)) AS seccionMD
    FROM fila WHERE Estado_General='CRITICO'
    GROUP BY Proyecto, Modelo, Compartimiento
),
c_agg AS (
    SELECT Proyecto, Modelo,
        STRING_AGG(seccionMD, NCHAR(10)+NCHAR(10)) WITHIN GROUP (ORDER BY sev, Compartimiento) AS Secciones
    FROM c_sec GROUP BY Proyecto, Modelo
),
p_sec AS (
    SELECT Proyecto, Modelo, Compartimiento, MIN(sev) AS sev,
        CAST(
            N'**' + Compartimiento + N'** (' + CAST(COUNT(*) AS nvarchar(10)) + N' equipos)' + NCHAR(10)
          + N'| Equipo | Grado | Fec. | Hor.Comp. | CM | Est. | Observado |' + NCHAR(10)
          + N'|---|---|---|---|---|---|---|' + NCHAR(10)
          + STRING_AGG(filaMD, NCHAR(10)) WITHIN GROUP (ORDER BY sev, Equipo)
        AS nvarchar(max)) AS seccionMD
    FROM fila WHERE Estado_General='PRECAUCION'
    GROUP BY Proyecto, Modelo, Compartimiento
),
p_agg AS (
    SELECT Proyecto, Modelo,
        STRING_AGG(seccionMD, NCHAR(10)+NCHAR(10)) WITHIN GROUP (ORDER BY sev, Compartimiento) AS Secciones
    FROM p_sec GROUP BY Proyecto, Modelo
),
compsev AS (
    SELECT Proyecto, Modelo, Compartimiento,
        MIN(CASE WHEN Estado_General='CRITICO' THEN 1 ELSE 2 END) AS sev
    FROM [dbo].[vw_ObservadosFlota] WHERE Estado_General <> 'OK'
    GROUP BY Proyecto, Modelo, Compartimiento
),
metrows AS (
    SELECT DISTINCT o.Proyecto, o.Modelo, o.Compartimiento, m.ord, m.metal, m.lp, m.lc
    FROM [dbo].[vw_ObservadosFlota] o
    CROSS APPLY (VALUES
        (1, 'Fe', CASE WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN CAST(Fe_LP AS decimal(18,1)) END, CASE WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN CAST(Fe_LC AS decimal(18,1)) END),
        (2, 'PQ', CASE WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN CAST(PQ_LP AS decimal(18,1)) END, CASE WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN CAST(PQ_LC AS decimal(18,1)) END),
        (3, 'Cr', CASE WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN CAST(Cr_LP AS decimal(18,1)) END, CASE WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN CAST(Cr_LC AS decimal(18,1)) END),
        (4, 'Ni', CASE WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN CAST(Ni_LP AS decimal(18,1)) END, CASE WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN CAST(Ni_LC AS decimal(18,1)) END),
        (5, 'Cu', CASE WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN CAST(Cu_LP AS decimal(18,1)) END, CASE WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN CAST(Cu_LC AS decimal(18,1)) END),
        (6, 'Al', CASE WHEN Al_ppm>ISNULL(Al_LP,9999) THEN CAST(Al_LP AS decimal(18,1)) END, CASE WHEN Al_ppm>ISNULL(Al_LP,9999) THEN CAST(Al_LC AS decimal(18,1)) END),
        (7, 'Si', CASE WHEN Si_ppm>ISNULL(Si_LP,9999) THEN CAST(Si_LP AS decimal(18,1)) END, CASE WHEN Si_ppm>ISNULL(Si_LP,9999) THEN CAST(Si_LC AS decimal(18,1)) END),
        (8, 'Pb', CASE WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN CAST(Pb_LP AS decimal(18,1)) END, CAST(NULL AS decimal(18,1))),
        (9, 'Sn', CASE WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN CAST(Sn_LP AS decimal(18,1)) END, CAST(NULL AS decimal(18,1))),
        (10, 'TBN', CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN CAST(TBN_LP AS decimal(18,1)) END, CAST(NULL AS decimal(18,1))),
        (11, 'Ca', CASE WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN CAST(Ca_LP AS decimal(18,1)) END, CASE WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN CAST(Ca_LC AS decimal(18,1)) END),
        (12, 'Zn', CASE WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN CAST(Zn_LP AS decimal(18,1)) END, CASE WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN CAST(Zn_LC AS decimal(18,1)) END),
        (13, 'K', CASE WHEN K_ppm>ISNULL(K_LP,9999) THEN CAST(K_LP AS decimal(18,1)) END, CASE WHEN K_ppm>ISNULL(K_LP,9999) THEN CAST(K_LC AS decimal(18,1)) END),
        (14, 'Na', CASE WHEN Na_ppm>ISNULL(Na_LP,9999) THEN CAST(Na_LP AS decimal(18,1)) END, CASE WHEN Na_ppm>ISNULL(Na_LP,9999) THEN CAST(Na_LC AS decimal(18,1)) END),
        (15, 'Mg', CASE WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN CAST(Mg_LP AS decimal(18,1)) END, CASE WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN CAST(Mg_LC AS decimal(18,1)) END)
    ) m(ord, metal, lp, lc)
    WHERE o.Estado_General <> 'OK' AND m.lp IS NOT NULL
),
limtbl AS (
    SELECT r.Proyecto, r.Modelo,
        CAST(
            N'**Límites de referencia (ppm)**' + NCHAR(10)
          + N'| Componente | Metal | LP | LC |' + NCHAR(10)
          + N'|---|---|---|---|' + NCHAR(10)
          + STRING_AGG(CONVERT(nvarchar(max),
                N'| ' + r.Compartimiento + N' | ' + r.metal + N' | '
              + CONVERT(varchar(20), r.lp) + N' | ' + ISNULL(CONVERT(varchar(20), r.lc), N'—') + N' |'
            ), NCHAR(10)) WITHIN GROUP (ORDER BY s.sev, r.Compartimiento, r.ord)
        AS nvarchar(max)) AS LimitesMD
    FROM metrows r
    JOIN compsev s ON s.Proyecto=r.Proyecto AND ISNULL(s.Modelo,N'')=ISNULL(r.Modelo,N'') AND s.Compartimiento=r.Compartimiento
    GROUP BY r.Proyecto, r.Modelo
),
cnt AS (
    SELECT Proyecto, Modelo,
        COUNT(*) AS NumEquipos,
        SUM(CASE WHEN NumCrit > 0 THEN 1 ELSE 0 END) AS NumEquiposCriticos,
        SUM(CASE WHEN NumCrit = 0 AND NumPrec > 0 THEN 1 ELSE 0 END) AS NumEquiposSoloPrecau
    FROM [dbo].[vw_ObservadosResumen] GROUP BY Proyecto, Modelo
)
SELECT
    ta.Proyecto, ta.Modelo,
    c.NumEquipos, c.NumEquiposCriticos, c.NumEquiposSoloPrecau,
    CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Detalle de todos — flota observada, agrupado por componente**' + NCHAR(10) + NCHAR(10)
      + ta.Secciones + NCHAR(10) + NCHAR(10) + l.LimitesMD
    AS nvarchar(max)) AS MD,
    CAST(
        N'**Detalle de todos — flota observada, agrupado por componente**' + NCHAR(10) + NCHAR(10)
      + ta.Secciones + NCHAR(10) + NCHAR(10) + l.LimitesMD
    AS nvarchar(max)) AS DetalleTodosMD,
    CAST(
        N'**Detalle — SOLO CRÍTICOS — flota observada, agrupado por componente**' + NCHAR(10) + NCHAR(10)
      + ca.Secciones + NCHAR(10) + NCHAR(10) + l.LimitesMD
    AS nvarchar(max))  AS MD_Criticos,
    CAST(
        N'**Detalle — SOLO PRECAUCIÓN — flota observada, agrupado por componente**' + NCHAR(10) + NCHAR(10)
      + pa.Secciones + NCHAR(10) + NCHAR(10) + l.LimitesMD
    AS nvarchar(max))  AS MD_Precaucion
FROM t_agg ta
JOIN cnt    c ON c.Proyecto=ta.Proyecto AND ISNULL(c.Modelo,N'')=ISNULL(ta.Modelo,N'')
JOIN limtbl l ON l.Proyecto=ta.Proyecto AND ISNULL(l.Modelo,N'')=ISNULL(ta.Modelo,N'')
LEFT JOIN c_agg ca ON ca.Proyecto=ta.Proyecto AND ISNULL(ca.Modelo,N'')=ISNULL(ta.Modelo,N'')
LEFT JOIN p_agg pa ON pa.Proyecto=ta.Proyecto AND ISNULL(pa.Modelo,N'')=ISNULL(ta.Modelo,N'');
GO


/* ============================================================================
   vw_ObservadosResumenMD — TIER 2, PASO 1 del barrido (columna MD estándar).
   Pre-arma el bloque markdown del RESUMEN de barrido (1 fila/equipo: Crít/Prec,
   horómetros, Comp. Observados abreviados, Met. Obs. con chips) + el cuadro de
   límites. El tópico lo imprime verbatim. Calcada de vw_ObservadosResumen +
   formato. ⚠ Emojis: abrir/ejecutar el .sql desde archivo (UTF-8).
   Validación: VALIDACION_SSMS.sql BLOQUE 34.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_ObservadosResumenMD] AS
WITH r AS (
    SELECT Proyecto, Modelo, Equipo, NumCrit, NumPrec, Horometro, HorasDeAceite, FechaUltima, CM, Comp_Obs, Met_Obs,
        CAST(
            N'| ' + Equipo
          + N' | ' + CAST(NumCrit AS nvarchar(10))
          + N' | ' + CAST(NumPrec AS nvarchar(10))
          + N' | ' + ISNULL(CONVERT(nvarchar(20), CAST(Horometro AS decimal(18,0))), N'—')
          + N' | ' + ISNULL(CONVERT(nvarchar(20), CAST(HorasDeAceite AS decimal(18,0))), N'—')
          + N' | ' + ISNULL(FORMAT(FechaUltima, 'dd-MMM'), N'—')
          + N' | ' + ISNULL(CM, N'—')
          + N' | ' + ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(Comp_Obs,'MOTOR DE TRACCION LH','MT LH'),'MOTOR DE TRACCION RH','MT RH'),'RUEDA DELANTERA LH','RD LH'),'RUEDA DELANTERA RH','RD RH'),'SISTEMA HIDRAULICO','Hidr'),'MOTOR','Motor'), N'—')
          + N' | ' + REPLACE(REPLACE(REPLACE(ISNULL(Met_Obs,N'—'),':C',N' 🟥'),':P',N' 🟨'),',',N' · ')
          + N' |'
        AS nvarchar(max)) AS filaMD
    FROM [dbo].[vw_ObservadosResumen]
),
tabla AS (
    SELECT Proyecto, Modelo,
        STRING_AGG(filaMD, NCHAR(10)) WITHIN GROUP (ORDER BY NumCrit DESC, NumPrec DESC, Equipo) AS FilasMD
    FROM r GROUP BY Proyecto, Modelo
),
cnt AS (
    SELECT Proyecto, Modelo,
        COUNT(*) AS NumEquipos,
        SUM(CASE WHEN NumCrit > 0 THEN 1 ELSE 0 END) AS NumCriticos,
        SUM(CASE WHEN NumCrit = 0 AND NumPrec > 0 THEN 1 ELSE 0 END) AS NumSoloPrecau
    FROM [dbo].[vw_ObservadosResumen] GROUP BY Proyecto, Modelo
),
compsev AS (
    SELECT Proyecto, Modelo, Compartimiento,
        MIN(CASE WHEN Estado_General='CRITICO' THEN 1 ELSE 2 END) AS sev
    FROM [dbo].[vw_ObservadosFlota] WHERE Estado_General <> 'OK'
    GROUP BY Proyecto, Modelo, Compartimiento
),
metrows AS (
    SELECT DISTINCT o.Proyecto, o.Modelo, o.Compartimiento, m.ord, m.metal, m.lp, m.lc
    FROM [dbo].[vw_ObservadosFlota] o
    CROSS APPLY (VALUES
        (1, 'Fe', CASE WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN CAST(Fe_LP AS decimal(18,1)) END, CASE WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN CAST(Fe_LC AS decimal(18,1)) END),
        (2, 'PQ', CASE WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN CAST(PQ_LP AS decimal(18,1)) END, CASE WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN CAST(PQ_LC AS decimal(18,1)) END),
        (3, 'Cr', CASE WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN CAST(Cr_LP AS decimal(18,1)) END, CASE WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN CAST(Cr_LC AS decimal(18,1)) END),
        (4, 'Ni', CASE WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN CAST(Ni_LP AS decimal(18,1)) END, CASE WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN CAST(Ni_LC AS decimal(18,1)) END),
        (5, 'Cu', CASE WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN CAST(Cu_LP AS decimal(18,1)) END, CASE WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN CAST(Cu_LC AS decimal(18,1)) END),
        (6, 'Al', CASE WHEN Al_ppm>ISNULL(Al_LP,9999) THEN CAST(Al_LP AS decimal(18,1)) END, CASE WHEN Al_ppm>ISNULL(Al_LP,9999) THEN CAST(Al_LC AS decimal(18,1)) END),
        (7, 'Si', CASE WHEN Si_ppm>ISNULL(Si_LP,9999) THEN CAST(Si_LP AS decimal(18,1)) END, CASE WHEN Si_ppm>ISNULL(Si_LP,9999) THEN CAST(Si_LC AS decimal(18,1)) END),
        (8, 'Pb', CASE WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN CAST(Pb_LP AS decimal(18,1)) END, CAST(NULL AS decimal(18,1))),
        (9, 'Sn', CASE WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN CAST(Sn_LP AS decimal(18,1)) END, CAST(NULL AS decimal(18,1))),
        (10, 'TBN', CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN CAST(TBN_LP AS decimal(18,1)) END, CAST(NULL AS decimal(18,1))),
        (11, 'Ca', CASE WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN CAST(Ca_LP AS decimal(18,1)) END, CASE WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN CAST(Ca_LC AS decimal(18,1)) END),
        (12, 'Zn', CASE WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN CAST(Zn_LP AS decimal(18,1)) END, CASE WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN CAST(Zn_LC AS decimal(18,1)) END),
        (13, 'K', CASE WHEN K_ppm>ISNULL(K_LP,9999) THEN CAST(K_LP AS decimal(18,1)) END, CASE WHEN K_ppm>ISNULL(K_LP,9999) THEN CAST(K_LC AS decimal(18,1)) END),
        (14, 'Na', CASE WHEN Na_ppm>ISNULL(Na_LP,9999) THEN CAST(Na_LP AS decimal(18,1)) END, CASE WHEN Na_ppm>ISNULL(Na_LP,9999) THEN CAST(Na_LC AS decimal(18,1)) END),
        (15, 'Mg', CASE WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN CAST(Mg_LP AS decimal(18,1)) END, CASE WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN CAST(Mg_LC AS decimal(18,1)) END)
    ) m(ord, metal, lp, lc)
    WHERE o.Estado_General <> 'OK' AND m.lp IS NOT NULL
),
limtbl AS (
    SELECT r2.Proyecto, r2.Modelo,
        CAST(
            N'**Límites de referencia (ppm)**' + NCHAR(10)
          + N'| Componente | Metal | LP | LC |' + NCHAR(10)
          + N'|---|---|---|---|' + NCHAR(10)
          + STRING_AGG(CONVERT(nvarchar(max),
                N'| ' + r2.Compartimiento + N' | ' + r2.metal + N' | '
              + CONVERT(varchar(20), r2.lp) + N' | ' + ISNULL(CONVERT(varchar(20), r2.lc), N'—') + N' |'
            ), NCHAR(10)) WITHIN GROUP (ORDER BY s.sev, r2.Compartimiento, r2.ord)
        AS nvarchar(max)) AS LimitesMD
    FROM metrows r2
    JOIN compsev s ON s.Proyecto=r2.Proyecto AND ISNULL(s.Modelo,N'')=ISNULL(r2.Modelo,N'') AND s.Compartimiento=r2.Compartimiento
    GROUP BY r2.Proyecto, r2.Modelo
)
SELECT
    t.Proyecto, t.Modelo,
    c.NumEquipos, c.NumCriticos, c.NumSoloPrecau,
    CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Barrido Flota ' + ISNULL(t.Modelo,N'') + N' — ' + t.Proyecto + N' | Estado Actual (No-OK)**' + NCHAR(10)
      + N'**' + CAST(c.NumEquipos AS nvarchar(10)) + N' equipos con ≥1 componente observado — '
        + CAST(c.NumCriticos AS nvarchar(10)) + N' con CRÍTICO · '
        + CAST(c.NumSoloPrecau AS nvarchar(10)) + N' solo PRECAUCIÓN**' + NCHAR(10) + NCHAR(10)
      + N'| Equipo | 🔴 Crít | 🟡 Prec | Horóm. | Hrs Ace. | Últ. | CM | Comp. Observados | Met. Obs. |' + NCHAR(10)
      + N'|---|---|---|---|---|---|---|---|---|' + NCHAR(10)
      + t.FilasMD
      + NCHAR(10) + NCHAR(10) + l.LimitesMD
    AS nvarchar(max)) AS MD
FROM tabla t
JOIN cnt    c ON c.Proyecto=t.Proyecto AND ISNULL(c.Modelo,N'')=ISNULL(t.Modelo,N'')
JOIN limtbl l ON l.Proyecto=t.Proyecto AND ISNULL(l.Modelo,N'')=ISNULL(t.Modelo,N'');
GO


/* ============================================================================
   vw_DiagnosticoMD — TIER 2, diagnóstico de 1 equipo (columnas MD / MD_Completo).
   1 fila por componente, columna «Parámetros» uniforme (valor+chip, inf), variantes:
   MD = solo observados («X de N»); MD_Completo = todos (OK marcados «— (OK)»). + límites.
   Calcada de vw_DiagnosticoEquipo + formato. Filtro del flujo: Equipo. ⚠ emojis: abrir .sql desde archivo.
   Validación: VALIDACION_SSMS.sql BLOQUE 36.
   ---------------------------------------------------------------------------- */
CREATE OR ALTER VIEW [dbo].[vw_DiagnosticoMD] AS
WITH base AS (
    SELECT Equipo, Proyecto, Modelo, Compartimiento, Estado_General, NumCompObs, NumCompTotal,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE Compartimiento END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo]
),
unpv AS (
    SELECT b.Equipo, b.Compartimiento, b.compOrd, b.compAbbr, b.Estado_General, v.ord, v.grp, v.nombre, v.cell
    FROM [dbo].[vw_DiagnosticoEquipo] d
    JOIN base b ON b.Equipo=d.Equipo AND b.Compartimiento=d.Compartimiento
    CROSS APPLY (VALUES
            (1, N'Met. Desg.', N'Fe', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Fe AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (2, N'Met. Desg.', N'PQ', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(PQ AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (3, N'Met. Desg.', N'Cr', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cr AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (4, N'Met. Desg.', N'Ni', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ni AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (5, N'Met. Desg.', N'Cu', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cu AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (6, N'Met. Desg.', N'Pb', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Pb AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (7, N'Met. Desg.', N'Sn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Sn AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (8, N'Met. Desg.', N'Al', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Al AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (9, N'Contam.', N'Si', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Si AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (10, N'Contam.', N'Ca', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ca AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (11, N'Contam.', N'Zn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Zn AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (12, N'Contam.', N'K', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(K AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (13, N'Contam.', N'Na', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Na AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (14, N'Adit.', N'B', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(B AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (15, N'Adit.', N'P', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(P AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (16, N'Adit.', N'Mg', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Mg AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (17, N'Salud', N'V100', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(V100 AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (18, N'Salud', N'TBN', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(TBN AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—'))
    ) v(ord, grp, nombre, cell)
),
/* CABECERAS de columnas (dinámicas) por variante */
hdr_all AS (
    SELECT Equipo, COUNT(DISTINCT Compartimiento) AS N,
        STRING_AGG(compAbbr, N' | ') WITHIN GROUP (ORDER BY compOrd) AS cols
    FROM (SELECT DISTINCT Equipo, Compartimiento, compOrd, compAbbr FROM base) z GROUP BY Equipo
),
hdr_obs AS (
    SELECT Equipo, COUNT(DISTINCT Compartimiento) AS N,
        STRING_AGG(compAbbr, N' | ') WITHIN GROUP (ORDER BY compOrd) AS cols
    FROM (SELECT DISTINCT Equipo, Compartimiento, compOrd, compAbbr FROM base WHERE Estado_General<>'OK') z GROUP BY Equipo
),
/* FILAS de parámetros (celdas en orden de componente) por variante */
row_all AS (
    SELECT Equipo, grp, ord, nombre,
        CAST(N'| ' + nombre + N' | ' + STRING_AGG(cell, N' | ') WITHIN GROUP (ORDER BY compOrd) + N' |' AS nvarchar(max)) AS rowMD
    FROM unpv GROUP BY Equipo, grp, ord, nombre
),
row_obs AS (
    SELECT Equipo, grp, ord, nombre,
        CAST(N'| ' + nombre + N' | ' + STRING_AGG(cell, N' | ') WITHIN GROUP (ORDER BY compOrd) + N' |' AS nvarchar(max)) AS rowMD
    FROM unpv WHERE Estado_General<>'OK' GROUP BY Equipo, grp, ord, nombre
),
body_all AS (
    SELECT r.Equipo,
        STRING_AGG(CAST(CASE WHEN r.ord IN (1,9,14,17) THEN N'| **' + r.grp + N'** |' + REPLICATE(N' |', h.N) + NCHAR(10) ELSE N'' END + r.rowMD AS nvarchar(max)), NCHAR(10))
            WITHIN GROUP (ORDER BY r.ord) AS bodyMD
    FROM row_all r JOIN hdr_all h ON h.Equipo=r.Equipo GROUP BY r.Equipo
),
body_obs AS (
    SELECT r.Equipo,
        STRING_AGG(CAST(CASE WHEN r.ord IN (1,9,14,17) THEN N'| **' + r.grp + N'** |' + REPLICATE(N' |', h.N) + NCHAR(10) ELSE N'' END + r.rowMD AS nvarchar(max)), NCHAR(10))
            WITHIN GROUP (ORDER BY r.ord) AS bodyMD
    FROM row_obs r JOIN hdr_obs h ON h.Equipo=r.Equipo GROUP BY r.Equipo
),
g AS (
    SELECT Equipo, MAX(Proyecto) AS Proyecto, MAX(Modelo) AS Modelo, MAX(NumCompObs) AS NumCompObs, MAX(NumCompTotal) AS NumCompTotal
    FROM base GROUP BY Equipo
),
obsmetals AS (
    SELECT Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 WHEN Compartimiento='MOTOR' THEN 5 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE Compartimiento END AS compAbbr,
        STUFF(CONCAT(
            CASE WHEN Fe LIKE '%:C%' OR Fe LIKE '%:P%' THEN N', Fe' ELSE N'' END,
            CASE WHEN PQ LIKE '%:C%' OR PQ LIKE '%:P%' THEN N', PQ' ELSE N'' END,
            CASE WHEN Cr LIKE '%:C%' OR Cr LIKE '%:P%' THEN N', Cr' ELSE N'' END,
            CASE WHEN Ni LIKE '%:C%' OR Ni LIKE '%:P%' THEN N', Ni' ELSE N'' END,
            CASE WHEN Cu LIKE '%:C%' OR Cu LIKE '%:P%' THEN N', Cu' ELSE N'' END,
            CASE WHEN Pb LIKE '%:C%' OR Pb LIKE '%:P%' THEN N', Pb' ELSE N'' END,
            CASE WHEN Sn LIKE '%:C%' OR Sn LIKE '%:P%' THEN N', Sn' ELSE N'' END,
            CASE WHEN Al LIKE '%:C%' OR Al LIKE '%:P%' THEN N', Al' ELSE N'' END,
            CASE WHEN Si LIKE '%:C%' OR Si LIKE '%:P%' THEN N', Si' ELSE N'' END,
            CASE WHEN Ca LIKE '%:C%' OR Ca LIKE '%:P%' THEN N', Ca' ELSE N'' END,
            CASE WHEN Zn LIKE '%:C%' OR Zn LIKE '%:P%' THEN N', Zn' ELSE N'' END,
            CASE WHEN K LIKE '%:C%' OR K LIKE '%:P%' THEN N', K' ELSE N'' END,
            CASE WHEN Na LIKE '%:C%' OR Na LIKE '%:P%' THEN N', Na' ELSE N'' END,
            CASE WHEN Mg LIKE '%:C%' OR Mg LIKE '%:P%' THEN N', Mg' ELSE N'' END,
            CASE WHEN B LIKE '%:C%' OR B LIKE '%:P%' THEN N', B' ELSE N'' END,
            CASE WHEN P LIKE '%:C%' OR P LIKE '%:P%' THEN N', P' ELSE N'' END,
            CASE WHEN V100 LIKE '%:C%' OR V100 LIKE '%:P%' THEN N', V100' ELSE N'' END,
            CASE WHEN TBN LIKE '%:C%' OR TBN LIKE '%:P%' THEN N', TBN' ELSE N'' END
        ), 1, 2, N'') AS metals
    FROM [dbo].[vw_DiagnosticoEquipo]
    WHERE Estado_General <> 'OK'
),
obsagg AS (
    SELECT Equipo, STRING_AGG(compAbbr + N': ' + metals, N' · ') WITHIN GROUP (ORDER BY compOrd) AS Observados
    FROM obsmetals WHERE NULLIF(metals, N'') IS NOT NULL
    GROUP BY Equipo
),
obsmet AS (
    SELECT DISTINCT Equipo, mm.metal
    FROM [dbo].[vw_DiagnosticoEquipo]
    CROSS APPLY (VALUES
            (N'Fe', Fe),
            (N'PQ', PQ),
            (N'Cr', Cr),
            (N'Ni', Ni),
            (N'Cu', Cu),
            (N'Pb', Pb),
            (N'Sn', Sn),
            (N'Al', Al),
            (N'Si', Si),
            (N'Ca', Ca),
            (N'Zn', Zn),
            (N'P', P),
            (N'V100', V100)
    ) mm(metal, val)
    WHERE (mm.val LIKE '%:C%' OR mm.val LIKE '%:P%') AND Compartimiento LIKE '%TRACCION%'
),
recos AS (
    SELECT DISTINCT om.Equipo, r.ord, r.label, r.indicio
    FROM obsmet om JOIN [dbo].[vw_Recomendaciones] r ON r.metal = om.metal
),
recoblock AS (
    SELECT Equipo,
        CAST(N'**🔧 Recomendaciones Técnicas**' + NCHAR(10)
           + STRING_AGG(CONVERT(nvarchar(max), N'- **' + label + N':** ' + indicio), NCHAR(10)) WITHIN GROUP (ORDER BY ord)
           + NCHAR(10) + NCHAR(10) + N'Acortar la frecuencia de monitoreo y programar dializado/cambio de aceite en el próximo PM. Retirar los 8 tapones magnéticos para inspección y limpieza en busca de particulado anormal. Para mayor información y detalle, contactar a confiabilidad.operaciones@kmmp.com.pe' AS nvarchar(max)) AS Recomendaciones
    FROM recos GROUP BY Equipo
)
SELECT
    g.Equipo, g.Proyecto, g.Modelo, g.NumCompObs, g.NumCompTotal, oa.Observados, ISNULL(rb.Recomendaciones, N'**🔧 Recomendaciones Técnicas**' + NCHAR(10) + N'Sin parámetros de Motor de Tracción fuera de límite — sin recomendaciones aplicables por ahora.') AS Recomendaciones,
    CAST(
        N'**Diagnóstico ' + g.Equipo + N' — ' + CAST(g.NumCompObs AS nvarchar(10)) + N' de ' + CAST(g.NumCompTotal AS nvarchar(10)) + N' componentes observados**' + NCHAR(10) + NCHAR(10)
      + N'| Par. | ' + ho.cols + N' |' + NCHAR(10)
      + N'|---|' + REPLICATE(N'---|', ho.N) + NCHAR(10)
      + bo.bodyMD
    AS nvarchar(max)) AS MD,
    CAST(
        N'**Diagnóstico ' + g.Equipo + N' (completo) — ' + CAST(g.NumCompTotal AS nvarchar(10)) + N' componentes**' + NCHAR(10) + NCHAR(10)
      + N'| Par. | ' + ha.cols + N' |' + NCHAR(10)
      + N'|---|' + REPLICATE(N'---|', ha.N) + NCHAR(10)
      + ba.bodyMD
    AS nvarchar(max)) AS MD_Completo
FROM g
JOIN hdr_all ha ON ha.Equipo=g.Equipo
JOIN body_all ba ON ba.Equipo=g.Equipo
LEFT JOIN hdr_obs ho ON ho.Equipo=g.Equipo
LEFT JOIN body_obs bo ON bo.Equipo=g.Equipo
LEFT JOIN obsagg oa ON oa.Equipo=g.Equipo
LEFT JOIN recoblock rb ON rb.Equipo=g.Equipo;
GO


/* ==== vw_Recomendaciones (diccionario de indicios, para el bloque determinístico) ==== */
CREATE OR ALTER VIEW [dbo].[vw_Recomendaciones] AS
/* Diccionario de indicios (verbatim de Recomendaciones_MT.docx). metal -> unidad+indicio.
   Fe/PQ comparten unidad; Pb/Sn comparten. Extensible: agregar filas por (CompTipo,)metal. */
SELECT metal, ord, label, indicio
FROM (VALUES
    (N'Fe', 1, N'Hierro (Fe) y PQ', N'Alto Hierro y/o PQ entre muestras de aceite puede indicar un problema en los engranajes o cojinetes. De continuar elevada la tendencia, solicitar inspección del piñón solar.'),
    (N'PQ', 1, N'Hierro (Fe) y PQ', N'Alto Hierro y/o PQ entre muestras de aceite puede indicar un problema en los engranajes o cojinetes. De continuar elevada la tendencia, solicitar inspección del piñón solar.'),
    (N'Cr', 2, N'Cromo (Cr)', N'Alto Cromo entre muestras de aceite puede indicar un problema en los rodillos y pistas de rodamientos.'),
    (N'Ni', 3, N'Níquel (Ni)', N'Alto Níquel entre muestras de aceite puede indicar un problema en los engranajes. De continuar elevada la tendencia, solicitar inspección del piñón solar.'),
    (N'Cu', 4, N'Cobre (Cu)', N'Alto Cobre entre muestras de aceite puede indicar un desgaste en las arandelas de empuje (interna y/o externa) o en el cojinete. Revise la arandela de empuje si encuentra valores altos de Cu/Pb/Sn en conjunto; si encuentra daños o desgaste excesivo, reemplácela de ser necesario.'),
    (N'Pb', 5, N'Plomo (Pb) y Estaño (Sn)', N'Alto Plomo acompañado de alto Cu y Sn puede indicar un desgaste en las arandelas de empuje (interna y/o externa). Revise la arandela de empuje; si encuentra daños o desgaste excesivo, reemplácela de ser necesario.'),
    (N'Sn', 5, N'Plomo (Pb) y Estaño (Sn)', N'Alto Plomo acompañado de alto Cu y Sn puede indicar un desgaste en las arandelas de empuje (interna y/o externa). Revise la arandela de empuje; si encuentra daños o desgaste excesivo, reemplácela de ser necesario.'),
    (N'Si', 6, N'Silicio (Si)', N'Alto Silicio entre muestras de aceite probablemente esté asociado a ingreso de contaminación a la caja de engranajes. Revise la tendencia de Al: si ambas suben en paralelo indicaría presencia de tierra/polvo abrasivo, con correlación en el incremento de Fe/PQ.'),
    (N'Ca', 7, N'Calcio (Ca)', N'El calcio no es un elemento común en los componentes de la caja de engranajes ni en el aceite. Si el calcio aumenta rápidamente, se ha producido contaminación, generalmente por otro aceite o grasa. En ese caso, detenga el equipo y solicite el cambio de aceite; filtrar el aceite no ayudará a mejorar la condición.'),
    (N'Zn', 8, N'Zinc (Zn)', N'Alto Zinc puede indicar una de dos situaciones: contaminación del aceite de la caja de engranajes por una sustancia extraña, o un desgaste excesivo de los componentes mecánicos. Si otros elementos como el Fósforo o el Calcio crecen junto con el Zinc, se ha producido contaminación por grasa u otro aceite: detenga el equipo y cambie el aceite de la caja de engranajes; filtrar el aceite no ayudará a mejorar la condición. Si solo el Zn está elevado, puede indicar desgaste excesivo de componentes mecánicos: revise la tendencia de Fe/PQ/Cr y, de ser necesario, programe la inspección del piñón solar.'),
    (N'P', 9, N'Fósforo (P)', N'El fósforo no es un elemento común en los componentes de la caja de engranajes; está asociado al aditivo EP usado en los aceites ISO 680. Si la concentración de fósforo decae por debajo de 240 ppm, se debe realizar el cambio de aceite; filtrar el aceite no ayudará a mejorar la condición.'),
    (N'V100', 10, N'Viscosidad V100', N'Baja viscosidad con tendencia decreciente, acompañada de un sobrenivel de aceite, indicaría un posible pase interno de aceite hidráulico a la caja de engranajes: detenga el equipo y solicite el cambio de aceite. Baja viscosidad constante entre muestras indicaría una posible carga con aceite incorrecto: detenga el equipo y solicite el cambio de aceite. En ambos casos, filtrar el aceite no ayudará a mejorar la condición.')
) v(metal, ord, label, indicio);
GO


/* ==== vw_UltimoAnalisisMD (último análisis de 1 componente) ==== */
CREATE OR ALTER VIEW [dbo].[vw_UltimoAnalisisMD] AS
WITH u AS (
    SELECT *,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH'
             WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH'
             WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE Compartimiento END AS compAbbr
    FROM [dbo].[vw_UltimoAnalisisAceite]
),
om AS (
    SELECT Equipo, Compartimiento, mm.metal
    FROM [dbo].[vw_UltimoAnalisisAceite]
    CROSS APPLY (VALUES (N'Fe',Fe_ppm,Fe_LP,Fe_LC),(N'PQ',Indice_PQ,PQ_LP,PQ_LC),(N'Cr',Cr_ppm,Cr_LP,Cr_LC),(N'Ni',Ni_ppm,Ni_LP,Ni_LC),(N'Cu',Cu_ppm,Cu_LP,Cu_LC),(N'Pb',Pb_ppm,Pb_LP,Pb_LC),(N'Sn',Sn_ppm,Sn_LP,Sn_LC),(N'Al',Al_ppm,Al_LP,Al_LC),(N'Si',Si_ppm,Si_LP,Si_LC),(N'Ca',Ca_ppm,Ca_LP,Ca_LC),(N'Zn',Zn_ppm,Zn_LP,Zn_LC),(N'K',K_ppm,K_LP,K_LC),(N'Na',Na_ppm,Na_LP,Na_LC),(N'Mg',Mg_ppm,Mg_LP,Mg_LC)) mm(metal, ppm, lp, lc)
    WHERE (ppm > ISNULL(lc,9999) OR ppm > ISNULL(lp,9999)) AND Compartimiento LIKE '%TRACCION%'
),
reco AS (
    SELECT o.Equipo, o.Compartimiento,
        CAST(N'**🔧 Recomendaciones Técnicas**' + NCHAR(10)
           + STRING_AGG(CONVERT(nvarchar(max), N'- **' + r.label + N':** ' + r.indicio), NCHAR(10)) WITHIN GROUP (ORDER BY r.ord)
        AS nvarchar(max)) AS Recomendaciones
    FROM (SELECT DISTINCT Equipo, Compartimiento, metal FROM om) o
    JOIN [dbo].[vw_Recomendaciones] r ON r.metal = o.metal
    GROUP BY o.Equipo, o.Compartimiento
),
omall AS (
    SELECT Equipo, Compartimiento, STRING_AGG(metal, N', ') AS metals
    FROM (SELECT Equipo, Compartimiento, mm.metal
          FROM [dbo].[vw_UltimoAnalisisAceite]
          CROSS APPLY (VALUES (N'Fe',Fe_ppm,Fe_LP,Fe_LC),(N'PQ',Indice_PQ,PQ_LP,PQ_LC),(N'Cr',Cr_ppm,Cr_LP,Cr_LC),(N'Ni',Ni_ppm,Ni_LP,Ni_LC),(N'Cu',Cu_ppm,Cu_LP,Cu_LC),(N'Pb',Pb_ppm,Pb_LP,Pb_LC),(N'Sn',Sn_ppm,Sn_LP,Sn_LC),(N'Al',Al_ppm,Al_LP,Al_LC),(N'Si',Si_ppm,Si_LP,Si_LC),(N'Ca',Ca_ppm,Ca_LP,Ca_LC),(N'Zn',Zn_ppm,Zn_LP,Zn_LC),(N'K',K_ppm,K_LP,K_LC),(N'Na',Na_ppm,Na_LP,Na_LC),(N'Mg',Mg_ppm,Mg_LP,Mg_LC)) mm(metal, ppm, lp, lc)
          WHERE ppm > ISNULL(lc,9999) OR ppm > ISNULL(lp,9999)) z
    GROUP BY Equipo, Compartimiento
)
SELECT u.Equipo, u.Proyecto, u.Modelo, u.Compartimiento, u.compAbbr,
    ISNULL(u.compAbbr + N': ' + oaz.metals, u.compAbbr + N': (sin observados)') AS Observados,
    ISNULL(rc.Recomendaciones, N'**🔧 Recomendaciones Técnicas**' + NCHAR(10) + N'Sin parámetros de Motor de Tracción fuera de límite — sin recomendaciones aplicables por ahora.') AS Recomendaciones,
    CAST(
        N'**Último análisis — ' + u.Equipo + N' · ' + u.compAbbr + N'**' + NCHAR(10)
      + N'*Mod. ' + ISNULL(u.Modelo,N'—') + N' · Lubric. ' + ISNULL(u.Grado,N'—') + N' · Hor. ' + ISNULL(CONVERT(varchar(20),CAST(u.Horometro AS decimal(18,0))),N'—')
      + N' · Hor.Comp. ' + ISNULL(CONVERT(varchar(20),CAST(u.HorasComponente AS decimal(18,0))),N'—')
      + N' · CM ' + ISNULL(u.CM,N'—') + N' · ' + ISNULL(FORMAT(u.FechaMuestreo,'dd-MMM-yy'),N'—') + N'*' + NCHAR(10) + NCHAR(10)
      + N'| Par. | LP | LC | Valor |' + NCHAR(10) + N'|---|---|---|---|' + NCHAR(10)
      + N'| **Met. Desg.** | | | |' + NCHAR(10) +
            N'| Fe | ' + ISNULL(CONVERT(varchar(20),CAST(Fe_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(Fe_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN Fe_ppm>ISNULL(Fe_LC,9999) THEN CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+N' 🟥' WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+N' 🟨' ELSE CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+N'' END, N'—') + N' |' + NCHAR(10) +
            N'| PQ | ' + ISNULL(CONVERT(varchar(20),CAST(PQ_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(PQ_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN Indice_PQ>ISNULL(PQ_LC,9999) THEN CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+N' 🟥' WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+N' 🟨' ELSE CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+N'' END, N'—') + N' |' + NCHAR(10) +
            N'| Cr | ' + ISNULL(CONVERT(varchar(20),CAST(Cr_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(Cr_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN Cr_ppm>ISNULL(Cr_LC,9999) THEN CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+N' 🟥' WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+N' 🟨' ELSE CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+N'' END, N'—') + N' |' + NCHAR(10) +
            N'| Ni | ' + ISNULL(CONVERT(varchar(20),CAST(Ni_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(Ni_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN Ni_ppm>ISNULL(Ni_LC,9999) THEN CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+N' 🟥' WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+N' 🟨' ELSE CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+N'' END, N'—') + N' |' + NCHAR(10) +
            N'| Cu | ' + ISNULL(CONVERT(varchar(20),CAST(Cu_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(Cu_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN Cu_ppm>ISNULL(Cu_LC,9999) THEN CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+N' 🟥' WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+N' 🟨' ELSE CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+N'' END, N'—') + N' |' + NCHAR(10) +
            N'| Pb | ' + ISNULL(CONVERT(varchar(20),CAST(Pb_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(Pb_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN Pb_ppm>ISNULL(Pb_LC,9999) THEN CONVERT(varchar(20),CAST(Pb_ppm AS decimal(18,1)))+N' 🟥' WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN CONVERT(varchar(20),CAST(Pb_ppm AS decimal(18,1)))+N' 🟨' ELSE CONVERT(varchar(20),CAST(Pb_ppm AS decimal(18,1)))+N'' END, N'—') + N' |' + NCHAR(10) +
            N'| Sn | ' + ISNULL(CONVERT(varchar(20),CAST(Sn_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(Sn_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN Sn_ppm>ISNULL(Sn_LC,9999) THEN CONVERT(varchar(20),CAST(Sn_ppm AS decimal(18,1)))+N' 🟥' WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN CONVERT(varchar(20),CAST(Sn_ppm AS decimal(18,1)))+N' 🟨' ELSE CONVERT(varchar(20),CAST(Sn_ppm AS decimal(18,1)))+N'' END, N'—') + N' |' + NCHAR(10) +
            N'| Al | ' + ISNULL(CONVERT(varchar(20),CAST(Al_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(Al_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN Al_ppm>ISNULL(Al_LC,9999) THEN CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+N' 🟥' WHEN Al_ppm>ISNULL(Al_LP,9999) THEN CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+N' 🟨' ELSE CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+N'' END, N'—') + N' |' + NCHAR(10) +
            N'| Si | ' + ISNULL(CONVERT(varchar(20),CAST(Si_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(Si_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN Si_ppm>ISNULL(Si_LC,9999) THEN CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+N' 🟥' WHEN Si_ppm>ISNULL(Si_LP,9999) THEN CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+N' 🟨' ELSE CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+N'' END, N'—') + N' |' + NCHAR(10) +
            N'| **Contam.** | | | |' + NCHAR(10) +
            N'| Ca | ' + ISNULL(CONVERT(varchar(20),CAST(Ca_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(Ca_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN Ca_ppm>ISNULL(Ca_LC,9999) THEN CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+N' 🟥 inf' WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+N' 🟨 inf' ELSE CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+N' inf' END, N'—') + N' |' + NCHAR(10) +
            N'| Zn | ' + ISNULL(CONVERT(varchar(20),CAST(Zn_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(Zn_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN Zn_ppm>ISNULL(Zn_LC,9999) THEN CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+N' 🟥 inf' WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+N' 🟨 inf' ELSE CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+N' inf' END, N'—') + N' |' + NCHAR(10) +
            N'| K | ' + ISNULL(CONVERT(varchar(20),CAST(K_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(K_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN K_ppm>ISNULL(K_LC,9999) THEN CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+N' 🟥 inf' WHEN K_ppm>ISNULL(K_LP,9999) THEN CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+N' 🟨 inf' ELSE CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+N' inf' END, N'—') + N' |' + NCHAR(10) +
            N'| Na | ' + ISNULL(CONVERT(varchar(20),CAST(Na_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(Na_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN Na_ppm>ISNULL(Na_LC,9999) THEN CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+N' 🟥 inf' WHEN Na_ppm>ISNULL(Na_LP,9999) THEN CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+N' 🟨 inf' ELSE CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+N' inf' END, N'—') + N' |' + NCHAR(10) +
            N'| **Adit.** | | | |' + NCHAR(10) +
            N'| B | ' + N'—' + N' | ' + N'—' + N' | ' + ISNULL(CONVERT(varchar(20),CAST(B_ppm AS decimal(18,1))), N'—') + N' |' + NCHAR(10) +
            N'| P | ' + N'—' + N' | ' + N'—' + N' | ' + ISNULL(CONVERT(varchar(20),CAST(P_ppm AS decimal(18,1))), N'—') + N' |' + NCHAR(10) +
            N'| Mg | ' + ISNULL(CONVERT(varchar(20),CAST(Mg_LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(varchar(20),CAST(Mg_LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(CASE WHEN Mg_ppm>ISNULL(Mg_LC,9999) THEN CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+N' 🟥 inf' WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+N' 🟨 inf' ELSE CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+N' inf' END, N'—') + N' |' + NCHAR(10) +
            N'| **Salud** | | | |' + NCHAR(10) +
            N'| V100 | ' + N'—' + N' | ' + N'—' + N' | ' + ISNULL(CONVERT(varchar(20),CAST(V100 AS decimal(18,1))), N'—') + N' |' + NCHAR(10) +
            N'| TBN | ' + ISNULL(CONVERT(varchar(20),CAST(TBN_LP AS decimal(18,1))), N'—') + N' | ' + N'—' + N' | ' + ISNULL(CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN CONVERT(varchar(20),CAST(TBN AS decimal(18,1)))+N' 🟨' ELSE CONVERT(varchar(20),CAST(TBN AS decimal(18,1))) END, N'—') + N' |' + NCHAR(10)
    AS nvarchar(max)) AS MD
FROM u
LEFT JOIN reco  rc  ON rc.Equipo=u.Equipo AND rc.Compartimiento=u.Compartimiento
LEFT JOIN omall oaz ON oaz.Equipo=u.Equipo AND oaz.Compartimiento=u.Compartimiento;
GO


/* ==== vw_CondicionMT_MD (condición de Motores de Tracción de 1 equipo) ==== */
CREATE OR ALTER VIEW [dbo].[vw_CondicionMT_MD] AS
WITH base AS (
    SELECT Equipo, Proyecto, Modelo, Compartimiento, Estado_General,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 ELSE 2 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' ELSE N'MT RH' END AS compAbbr
    FROM [dbo].[vw_DiagnosticoEquipo]
    WHERE Compartimiento LIKE '%TRACCION%'
),
unpv AS (
    SELECT b.Equipo, b.compOrd, v.ord, v.grp, v.nombre, v.cell
    FROM [dbo].[vw_DiagnosticoEquipo] d
    JOIN base b ON b.Equipo=d.Equipo AND b.Compartimiento=d.Compartimiento
    CROSS APPLY (VALUES
            (1, N'Met. Desg.', N'Fe', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Fe AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (2, N'Met. Desg.', N'PQ', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(PQ AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (3, N'Met. Desg.', N'Cr', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cr AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (4, N'Met. Desg.', N'Ni', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ni AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (5, N'Met. Desg.', N'Cu', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Cu AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (6, N'Met. Desg.', N'Pb', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Pb AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (7, N'Met. Desg.', N'Sn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Sn AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (8, N'Met. Desg.', N'Al', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Al AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (9, N'Contam.', N'Si', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Si AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (10, N'Contam.', N'Ca', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Ca AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (11, N'Contam.', N'Zn', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Zn AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (12, N'Contam.', N'K', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(K AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (13, N'Contam.', N'Na', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Na AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (14, N'Adit.', N'B', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(B AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (15, N'Adit.', N'P', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(P AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (16, N'Adit.', N'Mg', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(Mg AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (17, N'Salud', N'V100', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(V100 AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—')),
            (18, N'Salud', N'TBN', ISNULL(REPLACE(REPLACE(REPLACE(REPLACE(CAST(TBN AS nvarchar(40)),':C inf',N' 🟥 inf'),':P inf',N' 🟨 inf'),':C',N' 🟥'),':P',N' 🟨'), N'—'))
    ) v(ord, grp, nombre, cell)
),
hdr AS (
    SELECT Equipo, COUNT(DISTINCT compAbbr) AS N,
        STRING_AGG(compAbbr, N' | ') WITHIN GROUP (ORDER BY compOrd) AS cols
    FROM (SELECT DISTINCT Equipo, compOrd, compAbbr FROM base) z GROUP BY Equipo
),
rows_ AS (
    SELECT Equipo, grp, ord, nombre,
        CAST(N'| ' + nombre + N' | ' + STRING_AGG(cell, N' | ') WITHIN GROUP (ORDER BY compOrd) + N' |' AS nvarchar(max)) AS rowMD
    FROM unpv GROUP BY Equipo, grp, ord, nombre
),
body AS (
    SELECT r.Equipo,
        STRING_AGG(CAST(CASE WHEN r.ord IN (1,9,14,17) THEN N'| **' + r.grp + N'** |' + REPLICATE(N' |', h.N) + NCHAR(10) ELSE N'' END + r.rowMD AS nvarchar(max)), NCHAR(10))
            WITHIN GROUP (ORDER BY r.ord) AS bodyMD
    FROM rows_ r JOIN hdr h ON h.Equipo=r.Equipo GROUP BY r.Equipo
),
/* Observados y Recomendaciones (MT) */
obsdet AS (
    SELECT b.Equipo, b.compOrd, b.compAbbr, mm.metal
    FROM base b
    JOIN [dbo].[vw_DiagnosticoEquipo] d ON d.Equipo=b.Equipo AND d.Compartimiento=b.Compartimiento
    CROSS APPLY (VALUES
            (N'Fe', Fe),
            (N'PQ', PQ),
            (N'Cr', Cr),
            (N'Ni', Ni),
            (N'Cu', Cu),
            (N'Pb', Pb),
            (N'Sn', Sn),
            (N'Al', Al),
            (N'Si', Si),
            (N'Ca', Ca),
            (N'Zn', Zn),
            (N'P', P),
            (N'V100', V100)
    ) mm(metal, val)
    WHERE mm.val LIKE '%:C%' OR mm.val LIKE '%:P%'
),
obscomp AS (
    SELECT Equipo, compOrd, compAbbr, STRING_AGG(metal, N', ') AS metals
    FROM obsdet GROUP BY Equipo, compOrd, compAbbr
),
obsall AS (
    SELECT Equipo, STRING_AGG(compAbbr + N': ' + metals, N' · ') WITHIN GROUP (ORDER BY compOrd) AS Observados
    FROM obscomp GROUP BY Equipo
),
recos AS (
    SELECT DISTINCT od.Equipo, r.ord, r.label, r.indicio
    FROM obsdet od JOIN [dbo].[vw_Recomendaciones] r ON r.metal = od.metal
),
recoblock AS (
    SELECT Equipo,
        CAST(N'**🔧 Recomendaciones Técnicas**' + NCHAR(10)
           + STRING_AGG(CONVERT(nvarchar(max), N'- **' + label + N':** ' + indicio), NCHAR(10)) WITHIN GROUP (ORDER BY ord)
           + NCHAR(10) + NCHAR(10) + N'Acortar la frecuencia de monitoreo y programar dializado/cambio de aceite en el próximo PM. Retirar los 8 tapones magnéticos para inspección y limpieza en busca de particulado anormal. Para mayor información y detalle, contactar a confiabilidad.operaciones@kmmp.com.pe' AS nvarchar(max)) AS Recomendaciones
    FROM recos GROUP BY Equipo
),
g AS (
    SELECT Equipo, MAX(Proyecto) AS Proyecto, MAX(Modelo) AS Modelo,
        COUNT(DISTINCT CASE WHEN Estado_General<>'OK' THEN Compartimiento END) AS NumObs,
        COUNT(DISTINCT Compartimiento) AS NumMT
    FROM base GROUP BY Equipo
)
SELECT
    g.Equipo, g.Proyecto, g.Modelo,
    ISNULL(oa.Observados, N'(ninguno fuera de límite)') AS Observados,
    ISNULL(rb.Recomendaciones, N'**🔧 Recomendaciones Técnicas**' + NCHAR(10) + N'Sin parámetros de Motor de Tracción fuera de límite — sin recomendaciones aplicables por ahora.') AS Recomendaciones,
    CAST(
        N'**Condición Motores de Tracción — ' + g.Equipo + N'** · ' + CAST(g.NumObs AS nvarchar(10)) + N' de ' + CAST(g.NumMT AS nvarchar(10)) + N' observados' + NCHAR(10) + NCHAR(10)
      + N'| Par. | ' + h.cols + N' |' + NCHAR(10)
      + N'|---|' + REPLICATE(N'---|', h.N) + NCHAR(10)
      + bd.bodyMD
    AS nvarchar(max)) AS MD
FROM g
JOIN hdr h ON h.Equipo=g.Equipo
JOIN body bd ON bd.Equipo=g.Equipo
LEFT JOIN obsall oa ON oa.Equipo=g.Equipo
LEFT JOIN recoblock rb ON rb.Equipo=g.Equipo;
GO


/* ==== vw_TendenciaP1MD (PASO 1 de tendencia: general x fechas) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaP1MD] AS
WITH base AS (
    SELECT Equipo, Proyecto, Modelo, Compartimiento, rn_recencia,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE Compartimiento END AS compAbbr,
        ISNULL(FORMAT(FechaMuestreo,'dd-MMM'), N'—') AS colLabel
    FROM [dbo].[vw_MuestrasRankeadas]
    WHERE rn_recencia <= 6
),
unpv AS (
    SELECT b.Equipo, b.compAbbr, b.rn_recencia, v.ord, v.etq, v.val
    FROM [dbo].[vw_MuestrasRankeadas] d
    JOIN base b ON b.Equipo=d.Equipo AND b.Compartimiento=d.Compartimiento AND b.rn_recencia=d.rn_recencia
    CROSS APPLY (VALUES
            (1, N'Horómetro', ISNULL(CONVERT(nvarchar(20),CAST(Horometro AS decimal(18,0))), N'—')),
            (2, N'Hrs Aceite', ISNULL(CONVERT(nvarchar(20),CAST(HorasDeAceite AS decimal(18,0))), N'—')),
            (3, N'Hrs Comp', ISNULL(CONVERT(nvarchar(20),CAST(HorasComponente AS decimal(18,0))), N'—')),
            (4, N'CM', ISNULL(CM, N'—')),
            (5, N'Estado', CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END)
    ) v(ord, etq, val)
),
hdr AS (
    SELECT Equipo, compAbbr, COUNT(*) AS Ncols,
        STRING_AGG(colLabel, N' | ') WITHIN GROUP (ORDER BY rn_recencia DESC) AS cols
    FROM (SELECT DISTINCT Equipo, compAbbr, rn_recencia, colLabel FROM base) z
    GROUP BY Equipo, compAbbr
),
rows_ AS (
    SELECT Equipo, compAbbr, ord, etq,
        CAST(N'| ' + etq + N' | ' + STRING_AGG(val, N' | ') WITHIN GROUP (ORDER BY rn_recencia DESC) + N' |' AS nvarchar(max)) AS rowMD
    FROM unpv GROUP BY Equipo, compAbbr, ord, etq
),
body AS (
    SELECT Equipo, compAbbr,
        STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY ord) AS bodyMD
    FROM rows_ GROUP BY Equipo, compAbbr
),
meta AS (
    SELECT DISTINCT Equipo, compAbbr, MAX(Modelo) OVER (PARTITION BY Equipo) AS Modelo FROM base
)
SELECT
    h.Equipo, h.compAbbr,
    CAST(NULL AS nvarchar(max)) AS Observados,      -- contrato fijo (no aplica en PASO 1)
    CAST(NULL AS nvarchar(max)) AS Recomendaciones, -- contrato fijo (no aplica en PASO 1)
    CAST(
        N'**Tendencia — ' + h.Equipo + N' · ' + h.compAbbr + N'** · últimas ' + CAST(h.Ncols AS nvarchar(10)) + N' muestras' + NCHAR(10) + NCHAR(10)
      + N'| Campo | ' + h.cols + N' |' + NCHAR(10)
      + N'|---|' + REPLICATE(N'---|', h.Ncols) + NCHAR(10)
      + bd.bodyMD + NCHAR(10) + NCHAR(10)
      + N'_¿Deseas el **detalle por elemento** (metales × fechas) o la **gráfica** de un metal?_'
    AS nvarchar(max)) AS MD
FROM hdr h
JOIN body bd ON bd.Equipo=h.Equipo AND bd.compAbbr=h.compAbbr;
GO


/* ==== vw_TendenciaMD (tendencia DETALLE: params x fechas + Σvida + Spark) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaMD] AS
WITH te AS (
    SELECT *, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE Compartimiento END AS compAbbr FROM [dbo].[vw_TendenciaElemento]
),
rowcte AS (
    SELECT Equipo, Compartimiento, compAbbr, Grupo, Orden, EsRelevante,
        CAST(N'| ' + Parametro + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(LC AS decimal(18,1))), N'—') + N' | '
           + ISNULL(REPLACE(REPLACE(CAST(d1 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d2 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d3 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d5 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + CASE WHEN Orden IN (17,18) THEN N'—' ELSE ISNULL(CONVERT(nvarchar(20),CAST(Acumulado AS decimal(18,1))), N'—') END + N' | ' + ISNULL(Spark, N'—') + N' |' AS nvarchar(max)) AS rowMD
    FROM te
),
datehdr AS (
    SELECT Equipo, Compartimiento, MAX(compAbbr) AS compAbbr,
        ISNULL(FORMAT(MAX(f1),'dd-MMM'),N'—') AS h1, ISNULL(FORMAT(MAX(f2),'dd-MMM'),N'—') AS h2,
        ISNULL(FORMAT(MAX(f3),'dd-MMM'),N'—') AS h3, ISNULL(FORMAT(MAX(f4),'dd-MMM'),N'—') AS h4,
        ISNULL(FORMAT(MAX(f5),'dd-MMM'),N'—') AS h5, ISNULL(FORMAT(MAX(f6),'dd-MMM'),N'—') AS h6
    FROM te GROUP BY Equipo, Compartimiento
),
body_all AS (
    SELECT Equipo, Compartimiento,
        STRING_AGG(CAST(CASE WHEN Orden IN (1,9,14,17) THEN N'| **' + Grupo + N'** |' + REPLICATE(N' |', 10) + NCHAR(10) ELSE N'' END + rowMD AS nvarchar(max)), NCHAR(10))
            WITHIN GROUP (ORDER BY Orden) AS bodyMD
    FROM rowcte GROUP BY Equipo, Compartimiento
),
body_rel AS (   -- tabla SOLO de los parámetros relevantes (sin cabeceras de grupo, filas limpias)
    SELECT Equipo, Compartimiento,
        STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY Orden) AS bodyMD
    FROM rowcte WHERE EsRelevante=1 GROUP BY Equipo, Compartimiento
),
statbody AS (   -- Resumen estadístico por parámetro (Prom, σ, Σvida, Nº fuera)
    SELECT Equipo, Compartimiento,
        STRING_AGG(CAST(N'| ' + CONVERT(nvarchar(20),Parametro) + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Prom AS decimal(18,1))),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Sigma AS decimal(18,1))),N'—') + N' | ' + CASE WHEN Orden IN (17,18) THEN N'—' ELSE ISNULL(CONVERT(nvarchar(20),CAST(Acumulado AS decimal(18,1))), N'—') END + N' | ' + CONVERT(nvarchar(10), NVecesObs) + CASE WHEN NVecesObs>0 THEN N' 🟥' ELSE N'' END + N' |' AS nvarchar(max)), NCHAR(10)) WITHIN GROUP (ORDER BY Orden) AS bodyMD
    FROM te GROUP BY Equipo, Compartimiento
),
/* Observados y Recomendaciones sobre la ÚLTIMA muestra (d6), MT-scoped */
obslast AS (
    SELECT te.Equipo, te.Compartimiento, te.compAbbr, te.Parametro
    FROM te WHERE (te.d6 LIKE '%:C%' OR te.d6 LIKE '%:P%')
),
obsall AS (
    SELECT Equipo, Compartimiento, MAX(compAbbr) AS compAbbr, STRING_AGG(CONVERT(nvarchar(20), Parametro), N', ') AS metals
    FROM obslast GROUP BY Equipo, Compartimiento
),
recos AS (
    SELECT DISTINCT ol.Equipo, ol.Compartimiento, r.ord, r.label, r.indicio
    FROM obslast ol JOIN [dbo].[vw_Recomendaciones] r ON r.metal = ol.Parametro
    WHERE ol.Compartimiento LIKE '%TRACCION%'
),
recoblock AS (
    SELECT Equipo, Compartimiento,
        CAST(N'**🔧 Recomendaciones Técnicas**' + NCHAR(10)
           + STRING_AGG(CONVERT(nvarchar(max), N'- **' + label + N':** ' + indicio), NCHAR(10)) WITHIN GROUP (ORDER BY ord)
           + NCHAR(10) + NCHAR(10) + N'Acortar la frecuencia de monitoreo y programar dializado/cambio de aceite en el próximo PM. Retirar los 8 tapones magnéticos para inspección y limpieza en busca de particulado anormal. Para mayor información y detalle, contactar a confiabilidad.operaciones@kmmp.com.pe' AS nvarchar(max)) AS Recomendaciones
    FROM recos GROUP BY Equipo, Compartimiento
)
SELECT
    d.Equipo, d.compAbbr,
    ISNULL(oa.compAbbr + N': ' + oa.metals, d.compAbbr + N': (última muestra sin observados)') AS Observados,
    ISNULL(rb.Recomendaciones,
        CASE WHEN d.compAbbr LIKE 'MT %'
             THEN N'**🔧 Recomendaciones Técnicas**' + NCHAR(10) + N'Sin parámetros de Motor de Tracción fuera de límite en la última muestra — sin recomendaciones aplicables por ahora.'
             ELSE N'**🔧 Recomendaciones Técnicas**' + NCHAR(10) + N'Nada que comentar sobre el Motor de Tracción para este componente.' END) AS Recomendaciones,
    CAST(   -- DEFAULT (columna=MD): matriz COMPLETA, todos los parámetros
        N'**Tendencia detalle — ' + d.Equipo + N' · ' + d.compAbbr + N'** (todos los parámetros)' + NCHAR(10) + NCHAR(10)
      + N'| Par. | LP | LC | ' + d.h1+N' | '+d.h2+N' | '+d.h3+N' | '+d.h4+N' | '+d.h5+N' | '+d.h6 + N' | Σvida | Spark |' + NCHAR(10)
      + N'|---|' + REPLICATE(N'---|', 10) + NCHAR(10)
      + ba.bodyMD + NCHAR(10) + NCHAR(10)
      + N'**Resumen estadístico**' + NCHAR(10) + NCHAR(10)
      + N'| Par. | Prom. | σ | Σvida | Nº fuera |' + NCHAR(10)
      + N'|---|---|---|---|---|' + NCHAR(10) + st.bodyMD
    AS nvarchar(max)) AS MD,
    CAST(   -- opt-in (columna=MD_Relevantes): TABLA solo si hay relevantes; si no, solo el mensaje
        N'**Tendencia — parámetros relevantes · ' + d.Equipo + N' · ' + d.compAbbr + N'**' + NCHAR(10) + NCHAR(10)
      + CASE WHEN br.bodyMD IS NOT NULL THEN
            N'| Par. | LP | LC | ' + d.h1+N' | '+d.h2+N' | '+d.h3+N' | '+d.h4+N' | '+d.h5+N' | '+d.h6 + N' | Σvida | Spark |' + NCHAR(10)
          + N'|---|' + REPLICATE(N'---|', 10) + NCHAR(10) + br.bodyMD
        ELSE N'_Sin parámetros fuera de umbral — el componente opera en condición normal._' END
    AS nvarchar(max)) AS MD_Relevantes
FROM datehdr d
JOIN body_all ba ON ba.Equipo=d.Equipo AND ba.Compartimiento=d.Compartimiento
LEFT JOIN body_rel br ON br.Equipo=d.Equipo AND br.Compartimiento=d.Compartimiento
LEFT JOIN statbody st ON st.Equipo=d.Equipo AND st.Compartimiento=d.Compartimiento
LEFT JOIN obsall oa ON oa.Equipo=d.Equipo AND oa.Compartimiento=d.Compartimiento
LEFT JOIN recoblock rb ON rb.Equipo=d.Equipo AND rb.Compartimiento=d.Compartimiento;
GO


/* ==== vw_TendenciaGraficoMD (wrapper del gráfico ASCII en fence, contrato MD) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaGraficoMD] AS
SELECT
    g.Equipo, CASE WHEN g.Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN g.Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN g.Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN g.Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN g.Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN g.Compartimiento='MOTOR' THEN N'Motor' ELSE g.Compartimiento END AS compAbbr, g.Parametro,
    CAST(NULL AS nvarchar(max)) AS Observados,
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Tendencia de ' + CONVERT(nvarchar(20), g.Parametro) + N' — ' + g.Equipo + N' · ' + CASE WHEN g.Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN g.Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN g.Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN g.Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN g.Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN g.Compartimiento='MOTOR' THEN N'Motor' ELSE g.Compartimiento END + N'**' + NCHAR(10) + NCHAR(10)
      + N'| Par. | LP | LC | ' + ISNULL(FORMAT(te.f1,'dd-MMM'),N'—') + N' | ' + ISNULL(FORMAT(te.f2,'dd-MMM'),N'—') + N' | ' + ISNULL(FORMAT(te.f3,'dd-MMM'),N'—') + N' | ' + ISNULL(FORMAT(te.f4,'dd-MMM'),N'—') + N' | ' + ISNULL(FORMAT(te.f5,'dd-MMM'),N'—') + N' | ' + ISNULL(FORMAT(te.f6,'dd-MMM'),N'—') + N' | Σvida | Spark |' + NCHAR(10)
      + N'|---|---|---|---|---|---|---|---|---|---|' + NCHAR(10)
      + N'| ' + CONVERT(nvarchar(20),g.Parametro) + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(te.LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(te.LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(te.d1 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(te.d2 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(te.d3 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(te.d4 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(te.d5 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(te.d6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·')
        + N' | ' + CASE WHEN te.Orden IN (17,18) THEN N'—' ELSE ISNULL(CONVERT(nvarchar(20),CAST(te.Acumulado AS decimal(18,1))), N'—') END + N' | ' + ISNULL(te.Spark, N'·') + N' |' + NCHAR(10) + NCHAR(10)
      + N'```' + NCHAR(10) + g.Grafico + NCHAR(10) + N'```'
    AS nvarchar(max)) AS MD
FROM [dbo].[vw_TendenciaGrafico] g
JOIN [dbo].[vw_TendenciaElemento] te
  ON te.Equipo=g.Equipo AND te.Compartimiento=g.Compartimiento AND te.Parametro=g.Parametro;
GO


/* ==== vw_TendenciaGraficoObsMD (gráficas de los metales observados; default del gráfico) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaGraficoObsMD] AS
WITH base AS (
    SELECT DISTINCT Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE Compartimiento END AS compAbbr FROM [dbo].[vw_TendenciaElemento]
),
gobs AS (   -- concatena las gráficas de los parámetros relevantes (fuera de umbral), cada una en su ```
    SELECT te.Equipo, te.Compartimiento,
        STRING_AGG(CONVERT(nvarchar(max), N'```' + NCHAR(10) + gr.Grafico + NCHAR(10) + N'```'), NCHAR(10)+NCHAR(10))
            WITHIN GROUP (ORDER BY te.Orden) AS graphs
    FROM [dbo].[vw_TendenciaElemento] te
    JOIN [dbo].[vw_TendenciaGrafico] gr
      ON gr.Equipo=te.Equipo AND gr.Compartimiento=te.Compartimiento AND gr.Parametro=te.Parametro
    WHERE te.EsRelevante=1
    GROUP BY te.Equipo, te.Compartimiento
)
SELECT b.Equipo, b.compAbbr,
    CAST(NULL AS nvarchar(max)) AS Observados,       -- contrato fijo
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,  -- contrato fijo
    CAST(
        N'**Gráficas de metales observados — ' + b.Equipo + N' · ' + b.compAbbr + N'**' + NCHAR(10) + NCHAR(10)
      + ISNULL(go.graphs, N'_No hay metales fuera de límite en este componente. Dime qué metal quieres graficar (ej. Cr, Fe, Cu)._')
    AS nvarchar(max)) AS MD
FROM base b
LEFT JOIN gobs go ON go.Equipo=b.Equipo AND go.Compartimiento=b.Compartimiento;
GO


/* ==== vw_TendenciaMetalMD (tendencia de un metal en todos los componentes) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaMetalMD] AS
WITH te AS (
    SELECT Equipo, Parametro, LP, LC, d6, Tendencia, Acumulado, Spark, Orden, Prom, Sigma, NVecesObs,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN 1 WHEN Compartimiento LIKE '%TRACCION%RH' THEN 2 WHEN Compartimiento LIKE '%RUEDA%LH' THEN 3 WHEN Compartimiento LIKE '%RUEDA%RH' THEN 4 WHEN Compartimiento='MOTOR' THEN 5 WHEN Compartimiento LIKE '%HIDRAUL%' THEN 6 ELSE 9 END AS compOrd, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE Compartimiento END AS compAbbr
    FROM [dbo].[vw_TendenciaElemento]
),
qrows AS (
    SELECT Equipo, Parametro, compOrd,
        CAST(N'| ' + compAbbr + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(LP AS decimal(18,1))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(LC AS decimal(18,1))), N'—') + N' | ' + ISNULL(REPLACE(REPLACE(CAST(d6 AS nvarchar(40)),':C',N' 🟥'),':P',N' 🟨'), N'·')
           + N' | ' + ISNULL(Tendencia, N'—') + N' | ' + ISNULL(Spark, N'·') + N' |' AS nvarchar(max)) AS rowMD
    FROM te
),
srows AS (
    SELECT Equipo, Parametro, compOrd,
        CAST(N'| ' + compAbbr + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Prom AS decimal(18,1))),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Sigma AS decimal(18,1))),N'—')
           + N' | ' + CASE WHEN Orden IN (17,18) THEN N'—' ELSE ISNULL(CONVERT(nvarchar(20),CAST(Acumulado AS decimal(18,1))), N'—') END + N' | ' + CONVERT(nvarchar(10), NVecesObs) + CASE WHEN NVecesObs>0 THEN N' 🟥' ELSE N'' END + N' |' AS nvarchar(max)) AS rowMD
    FROM te
),
qbody AS (SELECT Equipo, Parametro, STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY compOrd) AS b FROM qrows GROUP BY Equipo, Parametro),
sbody AS (SELECT Equipo, Parametro, STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY compOrd) AS b FROM srows GROUP BY Equipo, Parametro)
SELECT
    q.Equipo, N'(todos)' AS compAbbr, q.Parametro,
    CAST(NULL AS nvarchar(max)) AS Observados,
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Tendencia de ' + CONVERT(nvarchar(20), q.Parametro) + N' — ' + q.Equipo + N' (todos los componentes)**' + NCHAR(10) + NCHAR(10)
      + N'| Componente | LP | LC | Última | Tend. | Spark |' + NCHAR(10)
      + N'|---|---|---|---|---|---|' + NCHAR(10) + q.b + NCHAR(10) + NCHAR(10)
      + N'**Resumen estadístico**' + NCHAR(10) + NCHAR(10)
      + N'| Componente | Prom. | σ | Σvida | Nº fuera |' + NCHAR(10)
      + N'|---|---|---|---|---|' + NCHAR(10) + s.b
    AS nvarchar(max)) AS MD
FROM qbody q JOIN sbody s ON s.Equipo=q.Equipo AND s.Parametro=q.Parametro;
GO


/* ==== vw_HistorialMD (log cronológico de un componente) ==== */
CREATE OR ALTER VIEW [dbo].[vw_HistorialMD] AS
WITH s AS (
    SELECT Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE Compartimiento END AS compAbbr, rn_recencia, FechaMuestreo, Horometro, HorasDeAceite, HorasComponente, CM,
        CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm, Fe_LP, Indice_PQ, PQ_LP, Cr_ppm, Cr_LP, Ni_ppm, Ni_LP, Cu_ppm, Cu_LP,
        Pb_ppm, Pb_LP, Sn_ppm, Sn_LP, Al_ppm, Al_LP, Si_ppm, Si_LP
    FROM [dbo].[vw_MuestrasRankeadas]
    WHERE rn_recencia <= 12
),
obs AS (
    SELECT s.Equipo, s.Compartimiento, s.rn_recencia,
        STRING_AGG(CASE WHEN mm.ppm > ISNULL(mm.lp, 9999) THEN CONVERT(nvarchar(20), mm.metal) END, N', ') AS obsList
    FROM s CROSS APPLY (VALUES
            (N'Fe',Fe_ppm,Fe_LP),
            (N'PQ',Indice_PQ,PQ_LP),
            (N'Cr',Cr_ppm,Cr_LP),
            (N'Ni',Ni_ppm,Ni_LP),
            (N'Cu',Cu_ppm,Cu_LP),
            (N'Pb',Pb_ppm,Pb_LP),
            (N'Sn',Sn_ppm,Sn_LP),
            (N'Al',Al_ppm,Al_LP),
            (N'Si',Si_ppm,Si_LP)
    ) mm(metal, ppm, lp)
    GROUP BY s.Equipo, s.Compartimiento, s.rn_recencia
),
rows_ AS (
    SELECT s.Equipo, s.Compartimiento, s.compAbbr, s.rn_recencia,
        CAST(N'| ' + ISNULL(FORMAT(s.FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(s.Horometro AS decimal(18,0))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(s.HorasDeAceite AS decimal(18,0))), N'—')
           + N' | ' + ISNULL(o.obsList, N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(s.HorasComponente AS decimal(18,0))), N'—') + N' | ' + ISNULL(s.CM,N'—') + N' | ' + s.estadoChip + N' |' AS nvarchar(max)) AS rowMD
    FROM s LEFT JOIN obs o ON o.Equipo=s.Equipo AND o.Compartimiento=s.Compartimiento AND o.rn_recencia=s.rn_recencia
),
body AS (
    SELECT Equipo, Compartimiento, MAX(compAbbr) AS compAbbr, COUNT(*) AS N,
        STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY rn_recencia) AS bodyMD
    FROM rows_ GROUP BY Equipo, Compartimiento
)
SELECT
    b.Equipo, b.compAbbr,
    CAST(NULL AS nvarchar(max)) AS Observados,
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Historial — ' + b.Equipo + N' · ' + b.compAbbr + N'** · ' + CAST(b.N AS nvarchar(10)) + N' muestras (recientes arriba)' + NCHAR(10) + NCHAR(10)
      + N'| Fecha | Horóm. | Hor. Aci. | Met. Obs. | Hrs Comp | CM | Estado |' + NCHAR(10)
      + N'|---|---|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
    AS nvarchar(max)) AS MD
FROM body b;
GO


/* ==== vw_HistorialMetalMD (historial de un metal en un componente) ==== */
CREATE OR ALTER VIEW [dbo].[vw_HistorialMetalMD] AS
WITH s AS (
    SELECT Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE Compartimiento END AS compAbbr, rn_recencia, FechaMuestreo, Horometro, HorasDeAceite, HorasComponente, CM, CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm, Fe_LP, Fe_LC, Indice_PQ, PQ_LP, PQ_LC, Cr_ppm, Cr_LP, Cr_LC, Ni_ppm, Ni_LP, Ni_LC,
        Cu_ppm, Cu_LP, Cu_LC, Pb_ppm, Pb_LP, Pb_LC, Sn_ppm, Sn_LP, Sn_LC, Al_ppm, Al_LP, Al_LC, Si_ppm, Si_LP, Si_LC,
        Ca_ppm, Ca_LP, Ca_LC, Zn_ppm, Zn_LP, Zn_LC, K_ppm, K_LP, K_LC, Na_ppm, Na_LP, Na_LC,
        Mg_ppm, Mg_LP, Mg_LC, B_ppm, P_ppm, V100, TBN, TBN_LP
    FROM [dbo].[vw_MuestrasRankeadas]
    WHERE rn_recencia <= 12
),
u AS (
    SELECT s.Equipo, s.Compartimiento, s.compAbbr, s.rn_recencia, s.FechaMuestreo, s.Horometro, s.HorasDeAceite, s.HorasComponente, s.CM, s.estadoChip,
        CONVERT(nvarchar(20), m.metal) AS Parametro, CAST(m.Valor AS decimal(18,2)) AS Valor,
        CAST(m.LP AS decimal(18,2)) AS LP, CAST(m.LC AS decimal(18,2)) AS LC
    FROM s CROSS APPLY (VALUES
            (N'Fe',Fe_ppm,Fe_LP,Fe_LC),
            (N'PQ',Indice_PQ,PQ_LP,PQ_LC),
            (N'Cr',Cr_ppm,Cr_LP,Cr_LC),
            (N'Ni',Ni_ppm,Ni_LP,Ni_LC),
            (N'Cu',Cu_ppm,Cu_LP,Cu_LC),
            (N'Pb',Pb_ppm,Pb_LP,Pb_LC),
            (N'Sn',Sn_ppm,Sn_LP,Sn_LC),
            (N'Al',Al_ppm,Al_LP,Al_LC),
            (N'Si',Si_ppm,Si_LP,Si_LC),
            (N'Ca',Ca_ppm,Ca_LP,Ca_LC),
            (N'Zn',Zn_ppm,Zn_LP,Zn_LC),
            (N'K',K_ppm,K_LP,K_LC),
            (N'Na',Na_ppm,Na_LP,Na_LC),
            (N'Mg',Mg_ppm,Mg_LP,Mg_LC),
            (N'B',B_ppm,NULL,NULL),
            (N'P',P_ppm,NULL,NULL),
            (N'V100',V100,NULL,NULL),
            (N'TBN',TBN,TBN_LP,NULL)
    ) m(metal, Valor, LP, LC)
),
rows_ AS (
    SELECT Equipo, Compartimiento, compAbbr, Parametro, rn_recencia, LP, LC,
        CAST(N'| ' + ISNULL(FORMAT(FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Horometro AS decimal(18,0))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasDeAceite AS decimal(18,0))), N'—') + N' | ' + ISNULL(CASE WHEN u.Valor > ISNULL(u.LC,999999) THEN CONVERT(nvarchar(20),CAST(u.Valor AS decimal(18,1)))+N' 🟥' WHEN u.Valor > ISNULL(u.LP,999999) THEN CONVERT(nvarchar(20),CAST(u.Valor AS decimal(18,1)))+N' 🟨' ELSE CONVERT(nvarchar(20),CAST(u.Valor AS decimal(18,1))) END, N'—')
           + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasComponente AS decimal(18,0))), N'—') + N' | ' + ISNULL(CM,N'—') + N' | ' + estadoChip + N' |' AS nvarchar(max)) AS rowMD
    FROM u
),
body AS (
    SELECT Equipo, Compartimiento, MAX(compAbbr) AS compAbbr, Parametro,
        MAX(LP) AS LP, MAX(LC) AS LC, COUNT(*) AS N,
        STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY rn_recencia) AS bodyMD
    FROM rows_
    GROUP BY Equipo, Compartimiento, Parametro
)
SELECT
    b.Equipo, b.compAbbr, b.Parametro,
    CAST(NULL AS nvarchar(max)) AS Observados,
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Historial de ' + b.Parametro + N' — ' + b.Equipo + N' · ' + b.compAbbr + N'**'
      + N' · LP ' + ISNULL(CONVERT(nvarchar(20),CAST(b.LP AS decimal(18,1))),N'—')
      + N' · LC ' + ISNULL(CONVERT(nvarchar(20),CAST(b.LC AS decimal(18,1))),N'—')
      + N' · ' + CAST(b.N AS nvarchar(10)) + N' muestras (recientes arriba)' + NCHAR(10) + NCHAR(10)
      + N'| Fecha | Horóm. | Hor. Aci. | ' + b.Parametro + N' | Hrs Comp | CM | Estado |' + NCHAR(10)
      + N'|---|---|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
    AS nvarchar(max)) AS MD
FROM body b;
GO


/* ==== vw_HistorialEquipoMD ==== */
CREATE OR ALTER VIEW [dbo].[vw_HistorialEquipoMD] AS
WITH s0 AS (
    SELECT Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE Compartimiento END AS compAbbr, rn_recencia, FechaMuestreo, Horometro, HorasDeAceite, CM, CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm,Fe_LP,Indice_PQ,PQ_LP,Cr_ppm,Cr_LP,Ni_ppm,Ni_LP,Cu_ppm,Cu_LP,Pb_ppm,Pb_LP,Sn_ppm,Sn_LP,Al_ppm,Al_LP,Si_ppm,Si_LP,
        ROW_NUMBER() OVER (PARTITION BY Equipo ORDER BY FechaMuestreo DESC) AS grn
    FROM [dbo].[vw_MuestrasRankeadas]
),
s AS (SELECT * FROM s0 WHERE grn <= 24),
obs AS (
    SELECT s.Equipo, s.Compartimiento, s.rn_recencia,
        STRING_AGG(CASE WHEN mm.ppm > ISNULL(mm.lp,9999) THEN CONVERT(nvarchar(20), mm.metal) END, N', ') AS obsList
    FROM s CROSS APPLY (VALUES
            (N'Fe',Fe_ppm,Fe_LP),
            (N'PQ',Indice_PQ,PQ_LP),
            (N'Cr',Cr_ppm,Cr_LP),
            (N'Ni',Ni_ppm,Ni_LP),
            (N'Cu',Cu_ppm,Cu_LP),
            (N'Pb',Pb_ppm,Pb_LP),
            (N'Sn',Sn_ppm,Sn_LP),
            (N'Al',Al_ppm,Al_LP),
            (N'Si',Si_ppm,Si_LP)
    ) mm(metal, ppm, lp)
    GROUP BY s.Equipo, s.Compartimiento, s.rn_recencia
),
rows_ AS (
    SELECT s.Equipo, s.grn,
        CAST(N'| ' + ISNULL(FORMAT(s.FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(s.Horometro AS decimal(18,0))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(s.HorasDeAceite AS decimal(18,0))), N'—')
           + N' | ' + ISNULL(o.obsList, N'—') + N' | ' + s.compAbbr + N' | ' + ISNULL(s.CM,N'—') + N' | ' + s.estadoChip + N' |' AS nvarchar(max)) AS rowMD
    FROM s LEFT JOIN obs o ON o.Equipo=s.Equipo AND o.Compartimiento=s.Compartimiento AND o.rn_recencia=s.rn_recencia
),
body AS (SELECT Equipo, COUNT(*) AS N, STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY grn) AS bodyMD FROM rows_ GROUP BY Equipo)
SELECT b.Equipo,
    CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(N'**Historial del equipo — ' + b.Equipo + N'** · ' + CAST(b.N AS nvarchar(10)) + N' muestras (todos los componentes, recientes arriba)' + NCHAR(10) + NCHAR(10)
       + N'| Fecha | Horóm. | Hor. Aci. | Met. Obs. | Componente | CM | Estado |' + NCHAR(10) + N'|---|---|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
    AS nvarchar(max)) AS MD
FROM body b;
GO


/* ==== vw_HistorialFlotaMD ==== */
CREATE OR ALTER VIEW [dbo].[vw_HistorialFlotaMD] AS
WITH s0 AS (
    SELECT Proyecto, Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE Compartimiento END AS compAbbr, rn_recencia, FechaMuestreo, Estado_General, CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm,Fe_LP,Indice_PQ,PQ_LP,Cr_ppm,Cr_LP,Ni_ppm,Ni_LP,Cu_ppm,Cu_LP,Pb_ppm,Pb_LP,Sn_ppm,Sn_LP,Al_ppm,Al_LP,Si_ppm,Si_LP,
        ROW_NUMBER() OVER (PARTITION BY Proyecto ORDER BY FechaMuestreo DESC) AS grn
    FROM [dbo].[vw_MuestrasRankeadas]
    WHERE Estado_General NOT LIKE '%OK%' AND Estado_General NOT LIKE '%NORMAL%'
),
s AS (SELECT * FROM s0 WHERE grn <= 24),
obs AS (
    SELECT s.Equipo, s.Compartimiento, s.rn_recencia,
        STRING_AGG(CASE WHEN mm.ppm > ISNULL(mm.lp,9999) THEN CONVERT(nvarchar(20), mm.metal) END, N', ') AS obsList
    FROM s CROSS APPLY (VALUES
            (N'Fe',Fe_ppm,Fe_LP),
            (N'PQ',Indice_PQ,PQ_LP),
            (N'Cr',Cr_ppm,Cr_LP),
            (N'Ni',Ni_ppm,Ni_LP),
            (N'Cu',Cu_ppm,Cu_LP),
            (N'Pb',Pb_ppm,Pb_LP),
            (N'Sn',Sn_ppm,Sn_LP),
            (N'Al',Al_ppm,Al_LP),
            (N'Si',Si_ppm,Si_LP)
    ) mm(metal, ppm, lp)
    GROUP BY s.Equipo, s.Compartimiento, s.rn_recencia
),
rows_ AS (
    SELECT s.Proyecto, s.grn,
        CAST(N'| ' + ISNULL(FORMAT(s.FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + s.Equipo + N' | ' + s.compAbbr
           + N' | ' + s.estadoChip + N' | ' + ISNULL(o.obsList, N'—') + N' |' AS nvarchar(max)) AS rowMD
    FROM s LEFT JOIN obs o ON o.Equipo=s.Equipo AND o.Compartimiento=s.Compartimiento AND o.rn_recencia=s.rn_recencia
),
body AS (SELECT Proyecto, COUNT(*) AS N, STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY grn) AS bodyMD FROM rows_ GROUP BY Proyecto)
SELECT b.Proyecto, N'(todos)' AS Modelo,
    CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(N'**Historial de observados — flota ' + b.Proyecto + N'** · últimos ' + CAST(b.N AS nvarchar(10)) + N' registros observados (recientes arriba)' + NCHAR(10) + NCHAR(10)
       + N'| Fecha | Equipo | Componente | Estado | Observados |' + NCHAR(10) + N'|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
    AS nvarchar(max)) AS MD
FROM body b;
GO


/* ==== vw_HistorialMetalEquipoMD (variante 2: metal en todos los componentes) ==== */
CREATE OR ALTER VIEW [dbo].[vw_HistorialMetalEquipoMD] AS
WITH s0 AS (
    SELECT Equipo, Compartimiento, CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' WHEN Compartimiento LIKE '%RUEDA%LH' THEN N'RD LH' WHEN Compartimiento LIKE '%RUEDA%RH' THEN N'RD RH' WHEN Compartimiento LIKE '%HIDRAUL%' THEN N'Sist. Hidr.' WHEN Compartimiento='MOTOR' THEN N'Motor' ELSE Compartimiento END AS compAbbr, FechaMuestreo, Horometro, HorasDeAceite, CM, CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' WHEN Estado_General LIKE '%OK%' OR Estado_General LIKE '%NORMAL%' THEN N'🟢' ELSE ISNULL(Estado_General,N'—') END AS estadoChip,
        Fe_ppm,Fe_LP,Fe_LC,Indice_PQ,PQ_LP,PQ_LC,Cr_ppm,Cr_LP,Cr_LC,Ni_ppm,Ni_LP,Ni_LC,Cu_ppm,Cu_LP,Cu_LC,
        Pb_ppm,Pb_LP,Pb_LC,Sn_ppm,Sn_LP,Sn_LC,Al_ppm,Al_LP,Al_LC,Si_ppm,Si_LP,Si_LC,Ca_ppm,Ca_LP,Ca_LC,Zn_ppm,Zn_LP,Zn_LC,
        K_ppm,K_LP,K_LC,Na_ppm,Na_LP,Na_LC,Mg_ppm,Mg_LP,Mg_LC,B_ppm,P_ppm,V100,TBN,TBN_LP,
        ROW_NUMBER() OVER (PARTITION BY Equipo ORDER BY FechaMuestreo DESC) AS grn
    FROM [dbo].[vw_MuestrasRankeadas]
),
s AS (SELECT * FROM s0 WHERE grn <= 24),
u AS (
    SELECT s.Equipo, s.compAbbr, s.grn, s.FechaMuestreo, s.Horometro, s.HorasDeAceite, s.CM, s.estadoChip,
        CONVERT(nvarchar(20), m.metal) AS Parametro, CAST(m.Valor AS decimal(18,2)) AS Valor,
        CAST(m.LP AS decimal(18,2)) AS LP, CAST(m.LC AS decimal(18,2)) AS LC
    FROM s CROSS APPLY (VALUES
            (N'Fe',Fe_ppm,Fe_LP,Fe_LC),
            (N'PQ',Indice_PQ,PQ_LP,PQ_LC),
            (N'Cr',Cr_ppm,Cr_LP,Cr_LC),
            (N'Ni',Ni_ppm,Ni_LP,Ni_LC),
            (N'Cu',Cu_ppm,Cu_LP,Cu_LC),
            (N'Pb',Pb_ppm,Pb_LP,Pb_LC),
            (N'Sn',Sn_ppm,Sn_LP,Sn_LC),
            (N'Al',Al_ppm,Al_LP,Al_LC),
            (N'Si',Si_ppm,Si_LP,Si_LC),
            (N'Ca',Ca_ppm,Ca_LP,Ca_LC),
            (N'Zn',Zn_ppm,Zn_LP,Zn_LC),
            (N'K',K_ppm,K_LP,K_LC),
            (N'Na',Na_ppm,Na_LP,Na_LC),
            (N'Mg',Mg_ppm,Mg_LP,Mg_LC),
            (N'B',B_ppm,NULL,NULL),
            (N'P',P_ppm,NULL,NULL),
            (N'V100',V100,NULL,NULL),
            (N'TBN',TBN,TBN_LP,NULL)
    ) m(metal, Valor, LP, LC)
),
rows_ AS (
    SELECT Equipo, Parametro, grn,
        CAST(N'| ' + ISNULL(FORMAT(FechaMuestreo,'dd-MMM-yy'),N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(Horometro AS decimal(18,0))), N'—') + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(HorasDeAceite AS decimal(18,0))), N'—') + N' | ' + ISNULL(CASE WHEN u.Valor > ISNULL(u.LC,999999) THEN CONVERT(nvarchar(20),CAST(u.Valor AS decimal(18,1)))+N' 🟥' WHEN u.Valor > ISNULL(u.LP,999999) THEN CONVERT(nvarchar(20),CAST(u.Valor AS decimal(18,1)))+N' 🟨' ELSE CONVERT(nvarchar(20),CAST(u.Valor AS decimal(18,1))) END, N'—')
           + N' | ' + compAbbr + N' | ' + ISNULL(CM,N'—') + N' | ' + estadoChip + N' |' AS nvarchar(max)) AS rowMD
    FROM u
),
body AS (
    SELECT Equipo, Parametro, COUNT(*) AS N,
        STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY grn) AS bodyMD
    FROM rows_ GROUP BY Equipo, Parametro
)
SELECT b.Equipo, N'(todos)' AS compAbbr, b.Parametro,
    CAST(NULL AS nvarchar(max)) AS Observados, CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(N'**Historial de ' + b.Parametro + N' — ' + b.Equipo + N' (todos los componentes)** · ' + CAST(b.N AS nvarchar(10)) + N' muestras (recientes arriba)' + NCHAR(10) + NCHAR(10)
       + N'| Fecha | Horóm. | Hor. Aci. | ' + b.Parametro + N' | Componente | CM | Estado |' + NCHAR(10)
       + N'|---|---|---|---|---|---|---|' + NCHAR(10) + b.bodyMD
    AS nvarchar(max)) AS MD
FROM body b;
GO


/* ==== vw_TriageMD (triage MT de flota — caso de uso principal) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TriageMD] AS
WITH base AS (
    SELECT Equipo, Proyecto, Compartimiento, Estado_General, HorasComponente, FechaMuestreo, Grado,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' ELSE N'MT' END AS compAbbr, CASE WHEN Estado_General LIKE '%CRITIC%' THEN N'🟥' WHEN Estado_General LIKE '%PRECAUC%' THEN N'🟨' ELSE N'—' END AS estadoChip, CASE WHEN Estado_General LIKE '%CRITIC%' THEN 1 WHEN Estado_General LIKE '%PRECAUC%' THEN 2 ELSE 3 END AS estadoOrd
    FROM [dbo].[vw_DiagnosticoEquipo]
    WHERE Compartimiento LIKE '%TRACCION%'
),
obsdet AS (   -- metales observados por MT (value:marker :C/:P)
    SELECT b.Equipo, b.Proyecto, b.Compartimiento, mm.metal
    FROM base b
    JOIN [dbo].[vw_DiagnosticoEquipo] d ON d.Equipo=b.Equipo AND d.Compartimiento=b.Compartimiento
    CROSS APPLY (VALUES
            (N'Fe', Fe),
            (N'PQ', PQ),
            (N'Cr', Cr),
            (N'Ni', Ni),
            (N'Cu', Cu),
            (N'Pb', Pb),
            (N'Sn', Sn),
            (N'Al', Al),
            (N'Si', Si),
            (N'Ca', Ca),
            (N'Zn', Zn),
            (N'P', P),
            (N'V100', V100)
    ) mm(metal, val)
    WHERE mm.val LIKE '%:C%' OR mm.val LIKE '%:P%'
),
metcell AS (   -- "Fe, Cu" por MT observado
    SELECT Equipo, Compartimiento, STRING_AGG(CONVERT(nvarchar(20),metal), N', ') AS metals
    FROM obsdet GROUP BY Equipo, Compartimiento
),
rows_ AS (
    SELECT b.Equipo, b.Proyecto, b.estadoOrd,
        CAST(N'| ' + b.Equipo + N' | ' + b.compAbbr + N' | ' + ISNULL(b.Grado,N'—') + N' | ' + b.estadoChip + N' | ' + ISNULL(mc.metals, N'—')
           + N' | ' + ISNULL(CONVERT(nvarchar(20),CAST(b.HorasComponente AS decimal(18,0))),N'—')
           + N' | ' + ISNULL(FORMAT(b.FechaMuestreo,'dd-MMM-yy'),N'—') + N' |' AS nvarchar(max)) AS rowMD
    FROM base b LEFT JOIN metcell mc ON mc.Equipo=b.Equipo AND mc.Compartimiento=b.Compartimiento
    WHERE b.Estado_General NOT LIKE '%OK%' AND b.Estado_General NOT LIKE '%NORMAL%'
),
body AS (
    SELECT Proyecto, STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY estadoOrd, Equipo) AS bodyMD
    FROM rows_ GROUP BY Proyecto
),
cnt AS (
    SELECT Proyecto, COUNT(*) AS Ntot,
        SUM(CASE WHEN Estado_General NOT LIKE '%OK%' AND Estado_General NOT LIKE '%NORMAL%' THEN 1 ELSE 0 END) AS Nobs
    FROM base GROUP BY Proyecto
),
recos AS (   -- por metal: indicio + equipos observados
    SELECT od.Proyecto, r.ord, r.label, r.indicio, STRING_AGG(CONVERT(nvarchar(20), od.Equipo), N', ') AS equipos
    FROM (SELECT DISTINCT Proyecto, Equipo, metal FROM obsdet) od
    JOIN [dbo].[vw_Recomendaciones] r ON r.metal = od.metal
    GROUP BY od.Proyecto, r.ord, r.label, r.indicio
),
recoblock AS (
    SELECT Proyecto,
        CAST(N'**🔧 Recomendaciones Técnicas**' + NCHAR(10)
           + STRING_AGG(CONVERT(nvarchar(max), N'- **' + label + N':** ' + indicio + N' _(equipos: ' + equipos + N')_'), NCHAR(10)) WITHIN GROUP (ORDER BY ord)
           + NCHAR(10) + NCHAR(10) + N'Acortar la frecuencia de monitoreo y programar dializado/cambio de aceite en el próximo PM. Retirar los 8 tapones magnéticos para inspección y limpieza en busca de particulado anormal. Para mayor información y detalle, contactar a confiabilidad.operaciones@kmmp.com.pe' AS nvarchar(max)) AS Recomendaciones
    FROM recos GROUP BY Proyecto
)
SELECT
    c.Proyecto, N'(todos)' AS Modelo,
    CAST(NULL AS nvarchar(max)) AS Observados,
    ISNULL(rb.Recomendaciones, N'**🔧 Recomendaciones Técnicas**' + NCHAR(10) + N'Ningún Motor de Tracción observado en la flota — sin recomendaciones aplicables.') AS Recomendaciones,
    CAST(
        N'**Triage Motores de Tracción — ' + c.Proyecto + N'** · ' + CAST(c.Nobs AS nvarchar(10)) + N' de ' + CAST(c.Ntot AS nvarchar(10)) + N' MT observados' + NCHAR(10) + NCHAR(10)
      + CASE WHEN bd.bodyMD IS NOT NULL THEN
            N'| Equipo | MT | Grado | Estado | Metales Obs. | Hrs Comp | Últ. |' + NCHAR(10)
          + N'|---|---|---|---|---|---|---|' + NCHAR(10) + bd.bodyMD
        ELSE N'_Ninguno observado — todos los Motores de Tracción del proyecto dentro de límite._' END
    AS nvarchar(max)) AS MD
FROM cnt c
LEFT JOIN body bd ON bd.Proyecto=c.Proyecto
LEFT JOIN recoblock rb ON rb.Proyecto=c.Proyecto;
GO

/* ==== vw_TendenciaIncipienteMD (#14: MT que varian de su promedio sin superar LP) ==== */
CREATE OR ALTER VIEW [dbo].[vw_TendenciaIncipienteMD] AS
WITH s AS (   -- ultimas 6 muestras MT por equipo+comp, normalizadas por metal de desgaste
    SELECT Proyecto, Equipo, Compartimiento, rn_recencia,
        CASE WHEN Compartimiento LIKE '%TRACCION%LH' THEN N'MT LH' WHEN Compartimiento LIKE '%TRACCION%RH' THEN N'MT RH' ELSE N'MT' END AS compAbbr,
        p.metal, p.Orden, CAST(p.Valor AS decimal(18,2)) AS Valor, CAST(p.LP AS decimal(18,2)) AS LP
    FROM [dbo].[vw_MuestrasRankeadas]
    CROSS APPLY (VALUES
        (N'Fe',1,Fe_ppm,Fe_LP),
        (N'PQ',2,Indice_PQ,PQ_LP),
        (N'Cr',3,Cr_ppm,Cr_LP),
        (N'Ni',4,Ni_ppm,Ni_LP),
        (N'Cu',5,Cu_ppm,Cu_LP),
        (N'Pb',6,Pb_ppm,Pb_LP),
        (N'Sn',7,Sn_ppm,Sn_LP),
        (N'Al',8,Al_ppm,Al_LP),
        (N'Si',9,Si_ppm,Si_LP)
    ) p(metal, Orden, Valor, LP)
    WHERE EsDDI = 0 AND rn_recencia <= 6 AND Compartimiento LIKE '%TRACCION%'
),
agg AS (   -- ultimo (rn=1) vs promedio de las previas (rn 2..6) por equipo+comp+metal
    SELECT Proyecto, Equipo, Compartimiento, compAbbr, metal, Orden,
        MAX(CASE WHEN rn_recencia = 1 THEN Valor END) AS ult,
        MAX(CASE WHEN rn_recencia = 1 THEN LP END)    AS LP,
        AVG(CASE WHEN rn_recencia BETWEEN 2 AND 6 THEN Valor END) AS prom_prev,
        SUM(CASE WHEN rn_recencia BETWEEN 2 AND 6 AND Valor IS NOT NULL THEN 1 ELSE 0 END) AS n_prev
    FROM s GROUP BY Proyecto, Equipo, Compartimiento, compAbbr, metal, Orden
),
inc AS (   -- incipientes: acercandose al LP (mitad superior) y subiendo >=40% sobre su media, SIN superarlo aun
    SELECT *, CONVERT(int, ROUND((ult - prom_prev) / NULLIF(prom_prev, 0) * 100, 0)) AS pct
    FROM agg
    WHERE n_prev >= 2 AND ult > 0 AND prom_prev > 0
      AND LP IS NOT NULL            -- solo metales con limite definido (aproximacion medible)
      AND ult <= LP                 -- aun NO observado
      AND ult >= 0.5 * LP           -- mitad superior: acercandose al limite (filtra ruido de traza)
      AND ult >= prom_prev * 1.4    -- acelerando respecto a su propia media
),
eq AS (   -- por equipo+comp MT: lista de metales incipientes + severidad
    SELECT Proyecto, Equipo, compAbbr,
        STRING_AGG(CONVERT(nvarchar(max),
            metal + N' ' + CONVERT(nvarchar(20), CAST(prom_prev AS decimal(18,1))) + N'→'
            + CONVERT(nvarchar(20), CAST(ult AS decimal(18,1)))
            + N' (+' + CASE WHEN pct > 500 THEN N'>500' ELSE CONVERT(nvarchar(12), pct) END + N'%)'), N', ') WITHIN GROUP (ORDER BY Orden) AS mets,
        MIN(CASE WHEN pct >= 80 THEN 1 ELSE 2 END) AS sev
    FROM inc GROUP BY Proyecto, Equipo, compAbbr
),
rows_ AS (
    SELECT Proyecto, sev, Equipo,
        CAST(N'| ' + Equipo + N' | ' + compAbbr + N' | '
           + CASE WHEN sev = 1 THEN N'🟧 acelerada' ELSE N'🔵 incipiente' END
           + N' | ' + mets + N' |' AS nvarchar(max)) AS rowMD
    FROM eq
),
body AS (
    SELECT Proyecto, STRING_AGG(rowMD, NCHAR(10)) WITHIN GROUP (ORDER BY sev, Equipo) AS bodyMD, COUNT(*) AS Ninc
    FROM rows_ GROUP BY Proyecto
),
tot AS (   -- MT evaluados por proyecto (para "X de N")
    SELECT Proyecto, COUNT(DISTINCT Equipo + N'|' + Compartimiento) AS Ntot
    FROM s WHERE rn_recencia = 1 GROUP BY Proyecto
)
SELECT
    t.Proyecto, N'(todos)' AS Modelo,
    CAST(NULL AS nvarchar(max)) AS Observados,
    CAST(NULL AS nvarchar(max)) AS Recomendaciones,
    CAST(
        N'**Tendencia incipiente 🔵 🟧 - Motores de Traccion - ' + t.Proyecto + N'** - '
      + CAST(ISNULL(b.Ninc, 0) AS nvarchar(10)) + N' de ' + CAST(t.Ntot AS nvarchar(10)) + N' MT' + NCHAR(10)
      + N'_MT acercandose al limite (>=50% del LP) y subiendo >=40% sobre su propia media, SIN superarlo aun._' + NCHAR(10) + NCHAR(10)
      + CASE WHEN b.bodyMD IS NOT NULL THEN
            N'| Equipo | MT | Tendencia | Parametros (prom' + N'→' + N'ult) |' + NCHAR(10)
          + N'|---|---|---|---|' + NCHAR(10) + b.bodyMD
        ELSE N'_Ninguno - ningun Motor de Traccion muestra desviacion incipiente sobre su comportamiento historico._' END
    AS nvarchar(max)) AS MD
FROM tot t
LEFT JOIN body b ON b.Proyecto = t.Proyecto;
GO
