# Dependencia externa — Módulo Acumulados / Ranking de Atención (motor diésel)

KomfIA **NO** define ni modifica estas vistas: viven en la MISMA base (`bd_kmmp_osconfiabilidad`), fueron
hechas para un **dashboard Power BI** (proyecto aparte, chat con MCP). KomfIA solo las **envuelve** en vistas
`vw_Acumulados*MD` (read-only). El .sql fuente completo lo tiene el usuario (`vw_Consolidado_RankingAtencion_3.sql`).

## Vistas base (externas)
| Vista | Grano | Uso |
|---|---|---|
| **vw_RankingAtencion** | 1 fila / equipo (foto actual) | ranking oficial ACTUAL — **base del wrapper de KomfIA** |
| vw_RankingHistorico | 1 fila / equipo·fecha | ranking corrido por fecha (foto a cualquier día) |
| vw_HistoricoAcumulados | 1 fila / equipo·fecha | suma corrida cruda (hoja «Histórico» del PBI) |
| vw_MuestrasElementos | 1 fila / muestra | normalización Na/K/Si por línea base del aceite |
| vw_ComparativoAceites | por Grado×Frecuencia | benchmark de ciclos de cambio de aceite |
| vw_AlertaTendencia | 1 fila / equipo | alerta de tendencia de Pb (último ciclo vs 2 previos) |

## ⚠ Alcance real (crítico)
- **Hardcodeadas a Antapaccay motor diésel**: `me.Code LIKE 'CA31%'` + listas por-equipo de `FechaBase` /
  `CambioMetal` / `Parciales` (RP) para CA3160–CA3198. **Hoy solo cubren Antapaccay motor diésel.**
- **Escalar a otra mina** (Antamina HT…, u otro componente) = cargar los datos de reset de esos equipos
  (fecha de arranque del motor, cambios de metal, RP). Es **dato aguas arriba**, no cambio de vista.
- Por eso `vw_AcumuladosFlotaMD` emite `Proyecto='Antapaccay'` fijo. Cuando el ranking base se generalice
  (traiga `Proyecto`/otras minas), se ajusta el wrapper para heredarlo.

## Columnas de vw_RankingAtencion que usa el wrapper
`[N° Int.]` (equipo), `[Serie]` (serie del motor), `[Horas Motor Actual]`, `[Horas Motor Metal]`,
`[Fe/Cr/Pb/Cu/Na/K/Si/Sn/Hollin Acum]`, `[Ranking]` (ponderado: Pb·0.68 + Cu·0.17 + Cr·0.07 + (Fe·Na·K·Si)·0.02),
`[Fe/Cr/Pb/Cu/Na/K ppm/h]`, `[NumMuestras]`, `[Intervenido]`.

## Wrappers KomfIA
- **vw_AcumuladosFlotaMD** (Tema flota/ranking) ✅ creada — tabla ordenada por `Ranking` desc, con `#`(Pos).
- **vw_AcumuladosEquipoMD** (Tema un equipo) — PENDIENTE (detalle de 1 equipo: metales acum + horas + serie + ppm/h).
- **Estado Motor (Alerta/Atención/Monitoreo)**: lo pinta el PBI (DAX), NO la vista base → falta la REGLA de umbral
  para reproducirlo en KomfIA (¿por score de Ranking? ¿por metales en alerta?). Pendiente confirmar.
