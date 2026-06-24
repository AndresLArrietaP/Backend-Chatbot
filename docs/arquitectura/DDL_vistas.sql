/* ============================================================================
   KomfIA — VISTAS (archivo único v5: cadena completa de 13 vistas; 23-jun-2026 (vw_UltimoAnalisisAceite/vw_EstadoActualMT ahora exponen HorasComponente))
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
    MIN([PLOMO - LP])   AS Pb_LP, MIN([ESTAÑO - LP])  AS Sn_LP,
    MIN([PQ - LP])      AS PQ_LP, MIN([PQ - LC])      AS PQ_LC,
    MAX([TBN - LP])     AS TBN_LP
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

    m.Pb_ppm,  lim.Pb_LP,
    CASE WHEN m.Pb_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Pb_ppm > ISNULL(lim.Pb_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Pb,

    m.Sn_ppm,  lim.Sn_LP,
    CASE WHEN m.Sn_ppm IS NULL THEN 'SIN DATO'
         WHEN m.Sn_ppm > ISNULL(lim.Sn_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_Sn,

    m.Indice_PQ, lim.PQ_LP, lim.PQ_LC,
    CASE WHEN m.Indice_PQ IS NULL THEN 'SIN DATO'
         WHEN m.Indice_PQ > ISNULL(lim.PQ_LC,9999) THEN 'CRITICO'
         WHEN m.Indice_PQ > ISNULL(lim.PQ_LP,9999) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_PQ,

    m.TBN, lim.TBN_LP,
    CASE WHEN m.TBN IS NULL THEN 'SIN DATO'
         WHEN m.TBN < ISNULL(lim.TBN_LP,0) THEN 'PRECAUCION' ELSE 'OK' END AS Estado_TBN,

    m.B_ppm, m.P_ppm, m.V100,

    /* Estado_General: SIN CAMBIOS respecto a v3 (Ca/Zn/B/P informativos; el triage no se altera) */
    CASE
        WHEN m.Fe_ppm    > ISNULL(lim.Fe_LC,9999)
          OR m.Cr_ppm    > ISNULL(lim.Cr_LC,9999)
          OR m.Ni_ppm    > ISNULL(lim.Ni_LC,9999)
          OR m.Cu_ppm    > ISNULL(lim.Cu_LC,9999)
          OR m.Si_ppm    > ISNULL(lim.Si_LC,9999)
          OR m.Al_ppm    > ISNULL(lim.Al_LC,9999)
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

    CASE WHEN m.EsDDI = 0 THEN
        ROW_NUMBER() OVER (
            PARTITION BY m.MiningEquipmentId, m.Compartimiento, m.EsDDI
            ORDER BY m.FechaMuestreo DESC, m.LaboratoryDataId DESC
        )
    END AS rn_recencia,

    m.LaboratoryDataId
FROM muestras m
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
            CASE WHEN Pb_ppm    > ISNULL(Pb_LP,9999) THEN ',Pb:P' ELSE '' END,
            CASE WHEN Sn_ppm    > ISNULL(Sn_LP,9999) THEN ',Sn:P' ELSE '' END,
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
            CASE WHEN Mg_ppm > ISNULL(Mg_LC,9999) THEN ',Mg:C' WHEN Mg_ppm > ISNULL(Mg_LP,9999) THEN ',Mg:P' ELSE '' END
        ), 1, 1, '') AS Infs_Obs,
        ( CASE WHEN Fe_ppm    > ISNULL(Fe_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Indice_PQ > ISNULL(PQ_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Cr_ppm    > ISNULL(Cr_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Ni_ppm    > ISNULL(Ni_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Cu_ppm    > ISNULL(Cu_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Al_ppm    > ISNULL(Al_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Si_ppm    > ISNULL(Si_LC,9999) THEN 1 ELSE 0 END) AS NumCrit,
        ( CASE WHEN Fe_ppm    > ISNULL(Fe_LP,9999) AND Fe_ppm    <= ISNULL(Fe_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Indice_PQ > ISNULL(PQ_LP,9999) AND Indice_PQ <= ISNULL(PQ_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Cr_ppm    > ISNULL(Cr_LP,9999) AND Cr_ppm    <= ISNULL(Cr_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Ni_ppm    > ISNULL(Ni_LP,9999) AND Ni_ppm    <= ISNULL(Ni_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Cu_ppm    > ISNULL(Cu_LP,9999) AND Cu_ppm    <= ISNULL(Cu_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Pb_ppm    > ISNULL(Pb_LP,9999) THEN 1 ELSE 0 END
        + CASE WHEN Sn_ppm    > ISNULL(Sn_LP,9999) THEN 1 ELSE 0 END
        + CASE WHEN Al_ppm    > ISNULL(Al_LP,9999) AND Al_ppm    <= ISNULL(Al_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN Si_ppm    > ISNULL(Si_LP,9999) AND Si_ppm    <= ISNULL(Si_LC,9999) THEN 1 ELSE 0 END
        + CASE WHEN TBN_LP IS NOT NULL AND TBN > 0 AND TBN < TBN_LP THEN 1 ELSE 0 END) AS NumPrec,
        /* Detalle pre-formateado: parámetros fuera de límite con valor(LP/LC) y severidad (:C/:P) */
        STUFF(CONCAT(
            CASE WHEN Fe_ppm>ISNULL(Fe_LC,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+'(LC'+CONVERT(varchar(20),CAST(Fe_LC AS decimal(18,1)))+'):C' WHEN Fe_ppm>ISNULL(Fe_LP,9999) THEN ' · Fe='+CONVERT(varchar(20),CAST(Fe_ppm AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(Fe_LP AS decimal(18,1)))+'):P' ELSE '' END,
            CASE WHEN Indice_PQ>ISNULL(PQ_LC,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+'(LC'+CONVERT(varchar(20),CAST(PQ_LC AS decimal(18,1)))+'):C' WHEN Indice_PQ>ISNULL(PQ_LP,9999) THEN ' · PQ='+CONVERT(varchar(20),CAST(Indice_PQ AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(PQ_LP AS decimal(18,1)))+'):P' ELSE '' END,
            CASE WHEN Cr_ppm>ISNULL(Cr_LC,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+'(LC'+CONVERT(varchar(20),CAST(Cr_LC AS decimal(18,1)))+'):C' WHEN Cr_ppm>ISNULL(Cr_LP,9999) THEN ' · Cr='+CONVERT(varchar(20),CAST(Cr_ppm AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(Cr_LP AS decimal(18,1)))+'):P' ELSE '' END,
            CASE WHEN Ni_ppm>ISNULL(Ni_LC,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+'(LC'+CONVERT(varchar(20),CAST(Ni_LC AS decimal(18,1)))+'):C' WHEN Ni_ppm>ISNULL(Ni_LP,9999) THEN ' · Ni='+CONVERT(varchar(20),CAST(Ni_ppm AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(Ni_LP AS decimal(18,1)))+'):P' ELSE '' END,
            CASE WHEN Cu_ppm>ISNULL(Cu_LC,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+'(LC'+CONVERT(varchar(20),CAST(Cu_LC AS decimal(18,1)))+'):C' WHEN Cu_ppm>ISNULL(Cu_LP,9999) THEN ' · Cu='+CONVERT(varchar(20),CAST(Cu_ppm AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(Cu_LP AS decimal(18,1)))+'):P' ELSE '' END,
            CASE WHEN Al_ppm>ISNULL(Al_LC,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+'(LC'+CONVERT(varchar(20),CAST(Al_LC AS decimal(18,1)))+'):C' WHEN Al_ppm>ISNULL(Al_LP,9999) THEN ' · Al='+CONVERT(varchar(20),CAST(Al_ppm AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(Al_LP AS decimal(18,1)))+'):P' ELSE '' END,
            CASE WHEN Si_ppm>ISNULL(Si_LC,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+'(LC'+CONVERT(varchar(20),CAST(Si_LC AS decimal(18,1)))+'):C' WHEN Si_ppm>ISNULL(Si_LP,9999) THEN ' · Si='+CONVERT(varchar(20),CAST(Si_ppm AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(Si_LP AS decimal(18,1)))+'):P' ELSE '' END,
            CASE WHEN Pb_ppm>ISNULL(Pb_LP,9999) THEN ' · Pb='+CONVERT(varchar(20),CAST(Pb_ppm AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(Pb_LP AS decimal(18,1)))+'):P' ELSE '' END,
            CASE WHEN Sn_ppm>ISNULL(Sn_LP,9999) THEN ' · Sn='+CONVERT(varchar(20),CAST(Sn_ppm AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(Sn_LP AS decimal(18,1)))+'):P' ELSE '' END,
            CASE WHEN TBN_LP IS NOT NULL AND TBN>0 AND TBN<TBN_LP THEN ' · TBN='+CONVERT(varchar(20),CAST(TBN AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(TBN_LP AS decimal(18,1)))+'):P' ELSE '' END,
            CASE WHEN Ca_ppm>ISNULL(Ca_LC,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+'(LC'+CONVERT(varchar(20),CAST(Ca_LC AS decimal(18,1)))+'):C inf' WHEN Ca_ppm>ISNULL(Ca_LP,9999) THEN ' · Ca='+CONVERT(varchar(20),CAST(Ca_ppm AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(Ca_LP AS decimal(18,1)))+'):P inf' ELSE '' END,
            CASE WHEN Zn_ppm>ISNULL(Zn_LC,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+'(LC'+CONVERT(varchar(20),CAST(Zn_LC AS decimal(18,1)))+'):C inf' WHEN Zn_ppm>ISNULL(Zn_LP,9999) THEN ' · Zn='+CONVERT(varchar(20),CAST(Zn_ppm AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(Zn_LP AS decimal(18,1)))+'):P inf' ELSE '' END,
            CASE WHEN K_ppm>ISNULL(K_LC,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+'(LC'+CONVERT(varchar(20),CAST(K_LC AS decimal(18,1)))+'):C inf' WHEN K_ppm>ISNULL(K_LP,9999) THEN ' · K='+CONVERT(varchar(20),CAST(K_ppm AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(K_LP AS decimal(18,1)))+'):P inf' ELSE '' END,
            CASE WHEN Na_ppm>ISNULL(Na_LC,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+'(LC'+CONVERT(varchar(20),CAST(Na_LC AS decimal(18,1)))+'):C inf' WHEN Na_ppm>ISNULL(Na_LP,9999) THEN ' · Na='+CONVERT(varchar(20),CAST(Na_ppm AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(Na_LP AS decimal(18,1)))+'):P inf' ELSE '' END,
            CASE WHEN Mg_ppm>ISNULL(Mg_LC,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+'(LC'+CONVERT(varchar(20),CAST(Mg_LC AS decimal(18,1)))+'):C inf' WHEN Mg_ppm>ISNULL(Mg_LP,9999) THEN ' · Mg='+CONVERT(varchar(20),CAST(Mg_ppm AS decimal(18,1)))+'(LP'+CONVERT(varchar(20),CAST(Mg_LP AS decimal(18,1)))+'):P inf' ELSE '' END
        ),1,3,'') AS Detalle,
        Fe_ppm, Fe_LP, Fe_LC, Indice_PQ, PQ_LP, PQ_LC, Cr_ppm, Cr_LP, Cr_LC, Ni_ppm, Ni_LP, Ni_LC,
        Cu_ppm, Cu_LP, Cu_LC, Pb_ppm, Pb_LP, Sn_ppm, Sn_LP, Al_ppm, Al_LP, Al_LC,
        Si_ppm, Si_LP, Si_LC, Ca_ppm, Ca_LP, Ca_LC, Zn_ppm, Zn_LP, Zn_LC,
        K_ppm, K_LP, K_LC, Na_ppm, Na_LP, Na_LC, Mg_ppm, Mg_LP, Mg_LC, B_ppm, P_ppm, V100, TBN, TBN_LP
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
    STRING_AGG(NULLIF(Mets_Obs,''), ' · ') WITHIN GROUP (ORDER BY NumCrit DESC) AS Met_Obs
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
   Detalle formato: 'Cu=24.2(LC4):C · Sn=1.6(LP3):P'  (:C=crítico:C, :P=precaución:P,
   sufijo ' inf'=informativo Ca/Zn/K/Mg).
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
           Ni_ppm, Ni_LP, Ni_LC, Cu_ppm, Cu_LP, Cu_LC, Pb_ppm, Pb_LP, Sn_ppm, Sn_LP,
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
        ('Pb',  'Met. Desg.', 6,  0,0, s.Pb_ppm,    s.Pb_LP, NULL),
        ('Sn',  'Met. Desg.', 7,  0,0, s.Sn_ppm,    s.Sn_LP, NULL),
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
        WHEN MAX(CASE WHEN rn_recencia=1 THEN Valor END) > MAX(CASE WHEN rn_recencia=6 THEN Valor END) THEN '↑'
        WHEN MAX(CASE WHEN rn_recencia=1 THEN Valor END) < MAX(CASE WHEN rn_recencia=6 THEN Valor END) THEN '↓'
        ELSE '→'
    END AS Tendencia
FROM v
GROUP BY Equipo, Compartimiento, Parametro, Grupo, Orden, Inf;
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
    Horometro, HorasDeAceite, HorasComponente, CM, Estado_General, Cond_Area,
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
