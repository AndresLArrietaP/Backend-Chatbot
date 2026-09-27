# src/alertas.py
# -*- coding: utf-8 -*-
"""
Módulo: alertas
----------------
Detección de metales fuera de límite en [Oil].[LaboratoryData].

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  ESTADO: SCAFFOLDING — deshabilitado por defecto.
  Para activar: ALERTAS_ACEITE_HABILITADAS=true en .env
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

ARQUITECTURA COMPLETA (cuándo se active):
══════════════════════════════════════════

  [Power Automate — Flujo programado, ej. cada 4 horas]
      │
      ▼ Trigger: Recurrence (Schedule)
      │
      ▼ HTTP Action
          Method : GET
          URL    : {PUBLIC_BASE_URL}/alerts/oil?horas_atras=4
          Headers: Content-Type: application/json
          (si el endpoint tiene API key, agregar header aquí)
      │
      ▼ Condition: body('HTTP')['total'] is greater than 0
          │
          ├─ YES → [Office 365 Outlook — Send an email (V2)]
          │            To      : lista de destinatarios (variable o fijo)
          │            Subject : "[ALERTA ACEITE] @{body('HTTP')['total']} alertas — @{utcNow()}"
          │            Body    : HTML construido con Apply to each sobre body('HTTP')['alertas']
          │
          └─ NO  → (sin acción, flujo termina)

  [Este backend — endpoint GET /alerts/oil]
      │
      ▼ Consulta [Oil].[LaboratoryData] para el período solicitado
      ▼ Consulta límites LP/LC desde BD  ← TODO: confirmar tabla
      ▼ Compara metal a metal por muestra
      ▼ Devuelve JSON estructurado con lista de AlertaAceite

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
PASOS PARA ACTIVAR (checklist):
  1. Confirmar nombre exacto de tabla de límites en BD
     (buscar tabla con LP/LC por metal y compartimiento)
  2. Completar _obtener_limites_desde_bd() con la query real
  3. Ajustar METALES_A_VIGILAR si hay columnas con otro nombre en BD
  4. Setear ALERTAS_ACEITE_HABILITADAS=true en .env
  5. En Power Automate: crear flujo con el esquema descrito arriba
  6. En Power Automate: configurar el cuerpo del email con las variables
     de cada alerta (ver _formatear_cuerpo_email_html() abajo)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Tuple

from decouple import config as env

from . import database

log = logging.getLogger(__name__)


# ──────────────────────────────────────────────────────────────
#  FLAG DE ACTIVACIÓN
#  Mientras sea False este módulo no ejecuta nada real.
# ──────────────────────────────────────────────────────────────

ALERTAS_ACEITE_HABILITADAS: bool = env("ALERTAS_ACEITE_HABILITADAS", default=False, cast=bool)


# ──────────────────────────────────────────────────────────────
#  METALES A VIGILAR
#  Nombre de columna en [Oil].[LaboratoryData] → etiqueta legible
#  Ajustar si el nombre exacto de columna en BD difiere.
# ──────────────────────────────────────────────────────────────

METALES_A_VIGILAR: Dict[str, str] = {
    # columna_bd       : etiqueta_legible
    # --- Desgaste ---
    "Fe_ppm"   : "Hierro (Fe)",
    "Cu_ppm"   : "Cobre (Cu)",
    "Al_ppm"   : "Aluminio (Al)",
    "Cr_ppm"   : "Cromo (Cr)",
    "Pb_ppm"   : "Plomo (Pb)",
    "Sn_ppm"   : "Estaño (Sn)",
    "Ni_ppm"   : "Níquel (Ni)",
    "Ag_ppm"   : "Plata (Ag)",
    "Mn_ppm"   : "Manganeso (Mn)",
    # --- Contaminación ---
    "Si_ppm"   : "Silicio (Si)",
    "Na_ppm"   : "Sodio (Na)",
    "K_ppm"    : "Potasio (K)",
    "V_ppm"    : "Vanadio (V)",
    "Ti_ppm"   : "Titanio (Ti)",
    "Cd_ppm"   : "Cadmio (Cd)",
    # --- Aditivos ---
    "B_ppm"    : "Boro (B)",
    "Mg_ppm"   : "Magnesio (Mg)",
    "Ca_ppm"   : "Calcio (Ca)",
    "Zn_ppm"   : "Zinc (Zn)",
    "P_ppm"    : "Fósforo (P)",
    "Mo_ppm"   : "Molibdeno (Mo)",    # aditivo a niveles normales; vigila si sube (posible desgaste)
    "Ba_ppm"   : "Bario (Ba)",
}

CATEGORIA_METAL: Dict[str, str] = {
    # Desgaste
    "Fe_ppm": "desgaste",  "Cu_ppm": "desgaste",  "Al_ppm": "desgaste",
    "Cr_ppm": "desgaste",  "Pb_ppm": "desgaste",  "Sn_ppm": "desgaste",
    "Ni_ppm": "desgaste",  "Ag_ppm": "desgaste",  "Mn_ppm": "desgaste",
    # Contaminación
    "Si_ppm": "contaminacion",  "Na_ppm": "contaminacion",  "K_ppm": "contaminacion",
    "V_ppm" : "contaminacion",  "Ti_ppm": "contaminacion",  "Cd_ppm": "contaminacion",
    # Aditivos
    "B_ppm" : "aditivo",  "Mg_ppm": "aditivo",  "Ca_ppm": "aditivo",
    "Zn_ppm": "aditivo",  "P_ppm" : "aditivo",  "Mo_ppm": "aditivo",  "Ba_ppm": "aditivo",
}


# ──────────────────────────────────────────────────────────────
#  LÍMITES FALLBACK (hardcoded)
#
#  TODO: Reemplazar con consulta real a BD una vez confirmada la
#        tabla de límites (ver _obtener_limites_desde_bd abajo).
#
#  Estructura: { "columna_bd": { "COMPARTIMIENTO": (LP, LC) } }
#    LP = Límite de Precaución  (nivel 2 — atención)
#    LC = Límite Crítico        (nivel 3 — acción inmediata)
#
#  Los valores numéricos abajo son PLACEHOLDERS — verificar con
#  el equipo de KMMP los límites reales antes de activar.
# ──────────────────────────────────────────────────────────────

_LIMITES_FALLBACK: Dict[str, Dict[str, Tuple[float, float]]] = {
    # "columna": { "COMPARTIMIENTO": (LP, LC) }
    "Fe_ppm": {
        "MOTOR"                : (60.0, 100.0),   # TODO: confirmar
        "MOTOR DE TRACCION RH" : (40.0,  80.0),   # TODO: confirmar
        "MOTOR DE TRACCION LH" : (40.0,  80.0),   # TODO: confirmar
        "SISTEMA HIDRAULICO"   : (20.0,  40.0),   # TODO: confirmar
        "RUEDA DELANTERA RH"   : (50.0,  80.0),   # TODO: confirmar
        "RUEDA DELANTERA LH"   : (50.0,  80.0),   # TODO: confirmar
    },
    "Cu_ppm": {
        "MOTOR"                : (20.0,  40.0),   # TODO: confirmar
        "MOTOR DE TRACCION RH" : (15.0,  30.0),   # TODO: confirmar
        "MOTOR DE TRACCION LH" : (15.0,  30.0),   # TODO: confirmar
        "SISTEMA HIDRAULICO"   : (10.0,  20.0),   # TODO: confirmar
    },
    "Al_ppm": {
        "MOTOR"                : (10.0,  20.0),   # TODO: confirmar
        "SISTEMA HIDRAULICO"   : (10.0,  20.0),   # TODO: confirmar
    },
    "Si_ppm": {
        "MOTOR"                : (15.0,  25.0),   # TODO: confirmar
        "SISTEMA HIDRAULICO"   : (15.0,  25.0),   # TODO: confirmar
    },
    "Na_ppm": {
        "MOTOR"                : (20.0,  30.0),   # TODO: confirmar
    },
    # Agrega más metales y compartimientos según confirmes con KMMP
}


# ──────────────────────────────────────────────────────────────
#  ESTRUCTURA DE ALERTA
# ──────────────────────────────────────────────────────────────

@dataclass
class AlertaAceite:
    equipo_id       : str
    codigo_equipo   : str
    compartimiento  : str
    fecha_muestreo  : str           # ISO string
    codigo_muestra  : str
    metal_columna   : str           # nombre de columna BD
    metal_etiqueta  : str           # nombre legible
    categoria       : str           # desgaste / contaminacion / aditivo
    valor           : float
    limite_precaucion: Optional[float]
    limite_critico   : Optional[float]
    severidad       : str           # "precaucion" | "critico"

    def to_dict(self) -> Dict[str, Any]:
        return {
            "equipo_id"        : self.equipo_id,
            "codigo_equipo"    : self.codigo_equipo,
            "compartimiento"   : self.compartimiento,
            "fecha_muestreo"   : self.fecha_muestreo,
            "codigo_muestra"   : self.codigo_muestra,
            "metal"            : self.metal_etiqueta,
            "categoria"        : self.categoria,
            "valor_ppm"        : self.valor,
            "limite_precaucion": self.limite_precaucion,
            "limite_critico"   : self.limite_critico,
            "severidad"        : self.severidad,
        }


# ──────────────────────────────────────────────────────────────
#  OBTENCIÓN DE LÍMITES DESDE BD (a completar)
# ──────────────────────────────────────────────────────────────

def _obtener_limites_desde_bd() -> Optional[Dict[str, Dict[str, Tuple[float, float]]]]:
    """
    TODO: Implementar cuando se confirme la tabla de límites en BD.

    Buscar en el esquema una tabla del tipo:
      - [Oil].[MetalLimits]
      - [Oil].[OilLimits]
      - [dbo].[LimitesAceite]
      - [Eqpcare].[ComponentLimits]
      ... (preguntar al equipo KMMP o revisar schema con GET /schema)

    La query debería devolver algo como:
      SELECT Metal, Compartimiento, LP, LC
      FROM [Oil].[MetalLimits]   -- ← nombre a confirmar

    Y construir un dict con la misma forma que _LIMITES_FALLBACK.

    Mientras no esté implementado, retorna None y se usa el fallback.
    """
    # TODO: descomentar y adaptar cuando se confirme la tabla
    # try:
    #     sql = """
    #         SELECT [Metal], [Compartimiento], [LimitePrecaucion], [LimiteCritico]
    #         FROM [Oil].[MetalLimits]   -- REEMPLAZAR con nombre real
    #         WHERE [Activo] = 1
    #     """
    #     filas = database.consultar_raw(sql)  # ver nota abajo *
    #     limites: Dict[str, Dict[str, Tuple[float, float]]] = {}
    #     for f in filas:
    #         metal = f["Metal"]
    #         comp  = (f["Compartimiento"] or "").strip().upper()
    #         lp    = float(f["LimitePrecaucion"] or 0)
    #         lc    = float(f["LimiteCritico"] or 0)
    #         limites.setdefault(metal, {})[comp] = (lp, lc)
    #     return limites if limites else None
    # except Exception as e:
    #     log.warning("[alertas] No se pudieron cargar límites desde BD: %s", e)
    #     return None
    #
    # * database.consultar_raw() es un helper que ejecuta SQL sin validación
    #   de tablas permitidas (uso interno). Si no existe, usar database.consultar()
    #   con la FQN de la tabla en allowed_fqn.
    return None


# ──────────────────────────────────────────────────────────────
#  LÓGICA DE DETECCIÓN
# ──────────────────────────────────────────────────────────────

def _obtener_limites_activos() -> Dict[str, Dict[str, Tuple[float, float]]]:
    """Intenta BD primero, cae en fallback hardcoded si BD no responde."""
    from_bd = _obtener_limites_desde_bd()
    if from_bd:
        log.debug("[alertas] Límites cargados desde BD (%d metales)", len(from_bd))
        return from_bd
    log.debug("[alertas] Usando límites fallback hardcoded")
    return _LIMITES_FALLBACK


def _clasificar_severidad(valor: float, lp: Optional[float], lc: Optional[float]) -> Optional[str]:
    """
    Retorna 'critico' si valor >= LC,
            'precaucion' si valor >= LP,
            None si está dentro del límite.
    """
    if lc is not None and valor >= lc:
        return "critico"
    if lp is not None and valor >= lp:
        return "precaucion"
    return None


def verificar_alertas(horas_atras: int = 24) -> List[AlertaAceite]:
    """
    Consulta [Oil].[LaboratoryData] para las últimas `horas_atras` horas
    y devuelve las muestras donde algún metal supera LP o LC.

    Args:
        horas_atras: ventana de tiempo hacia atrás desde ahora.

    Returns:
        Lista de AlertaAceite ordenada por severidad desc (críticos primero).
    """
    if not ALERTAS_ACEITE_HABILITADAS:
        log.debug("[alertas] Módulo deshabilitado. Retorna vacío.")
        return []

    limites = _obtener_limites_activos()

    # Columnas a traer: las que están en METALES_A_VIGILAR + identificadores
    cols_metales = ", ".join(f"[{c}]" for c in METALES_A_VIGILAR)
    sql_alertas = f"""
        SELECT
            [MiningEquipmentId],
            [CodigoMuestreo],
            [Compartimiento],
            CONVERT(varchar(23), [FechaMuestreo], 126) AS [FechaMuestreo],
            {cols_metales}
        FROM [Oil].[LaboratoryData]
        WHERE [FechaMuestreo] >= DATEADD(HOUR, -{horas_atras}, GETDATE())
          AND [FechaMuestreo] IS NOT NULL
        ORDER BY [FechaMuestreo] DESC
    """

    try:
        filas = database.consultar_raw(sql_alertas)
    except AttributeError:
        # database.consultar_raw no existe aún — usar consultar con FQN
        # TODO: ajustar cuando se implemente consultar_raw o equivalente
        log.warning("[alertas] database.consultar_raw no disponible. Ver TODO en alertas.py.")
        return []
    except Exception as e:
        log.error("[alertas] Error consultando LaboratoryData: %s", e)
        return []

    alertas: List[AlertaAceite] = []

    for fila in filas:
        compartimiento = (fila.get("Compartimiento") or "").strip().upper()
        equipo_id      = str(fila.get("MiningEquipmentId") or "")
        codigo_muestra = str(fila.get("CodigoMuestreo") or "")
        fecha          = str(fila.get("FechaMuestreo") or "")

        for col, etiqueta in METALES_A_VIGILAR.items():
            raw = fila.get(col)
            if raw is None:
                continue
            try:
                valor = float(raw)
            except (TypeError, ValueError):
                continue

            limites_metal = limites.get(col, {})
            # Busca límite por compartimiento exacto, luego por defecto genérico ("*")
            lp_lc = limites_metal.get(compartimiento) or limites_metal.get("*")
            if lp_lc is None:
                continue  # no hay límite definido para este metal+compartimiento

            lp, lc = lp_lc
            severidad = _clasificar_severidad(valor, lp, lc)
            if severidad is None:
                continue  # dentro de límites, sin alerta

            alertas.append(AlertaAceite(
                equipo_id        = equipo_id,
                codigo_equipo    = equipo_id,   # TODO: si hay JOIN con equipo, reemplazar por código legible
                compartimiento   = compartimiento,
                fecha_muestreo   = fecha,
                codigo_muestra   = codigo_muestra,
                metal_columna    = col,
                metal_etiqueta   = etiqueta,
                categoria        = CATEGORIA_METAL.get(col, "desconocido"),
                valor            = valor,
                limite_precaucion= lp,
                limite_critico   = lc,
                severidad        = severidad,
            ))

    # Críticos primero
    alertas.sort(key=lambda a: (0 if a.severidad == "critico" else 1, -a.valor))
    return alertas


# ──────────────────────────────────────────────────────────────
#  HELPER: CUERPO DE EMAIL HTML
#
#  Usado opcionalmente si en el futuro el backend genera el email
#  directamente (via SMTP u otro). Si se usa Power Automate para
#  enviar el correo, este helper no es necesario — Power Automate
#  arma el HTML con sus propias variables de expresión.
#  Se deja como referencia del formato sugerido.
# ──────────────────────────────────────────────────────────────

def _formatear_cuerpo_email_html(alertas: List[AlertaAceite], periodo_horas: int) -> str:
    """
    Genera un cuerpo HTML para el email de alertas.
    Útil como referencia del diseño del correo, incluso si Power Automate
    arma su propio HTML.
    """
    if not alertas:
        return "<p>No se detectaron alertas en el período.</p>"

    criticos   = [a for a in alertas if a.severidad == "critico"]
    precaucion = [a for a in alertas if a.severidad == "precaucion"]

    def _fila_tabla(a: AlertaAceite) -> str:
        color = "#c0392b" if a.severidad == "critico" else "#e67e22"
        badge = "CRÍTICO" if a.severidad == "critico" else "PRECAUCIÓN"
        return (
            f"<tr>"
            f"<td>{a.codigo_equipo}</td>"
            f"<td>{a.compartimiento}</td>"
            f"<td>{a.metal_etiqueta}</td>"
            f"<td><b>{a.valor:.1f}</b></td>"
            f"<td>{a.limite_precaucion}</td>"
            f"<td>{a.limite_critico}</td>"
            f"<td style='color:{color};font-weight:bold'>{badge}</td>"
            f"<td>{a.fecha_muestreo[:10]}</td>"
            f"<td>{a.codigo_muestra}</td>"
            f"</tr>"
        )

    filas_html = "".join(_fila_tabla(a) for a in alertas)
    resumen = f"{len(criticos)} crítico(s), {len(precaucion)} precaución"

    return f"""
<html><body style="font-family:Arial,sans-serif;font-size:13px;">
<h2 style="color:#c0392b;">⚠ Alerta de Aceite — KMMP / Antapaccay</h2>
<p>Período analizado: últimas <b>{periodo_horas} horas</b><br>
   Total de alertas : <b>{len(alertas)}</b> ({resumen})</p>
<table border="1" cellpadding="5" cellspacing="0"
       style="border-collapse:collapse;width:100%;font-size:12px;">
  <thead style="background:#2c3e50;color:white;">
    <tr>
      <th>Equipo</th><th>Compartimiento</th><th>Metal</th>
      <th>Valor (ppm)</th><th>LP</th><th>LC</th>
      <th>Severidad</th><th>Fecha muestra</th><th>Código muestra</th>
    </tr>
  </thead>
  <tbody>{filas_html}</tbody>
</table>
<p style="color:#7f8c8d;font-size:11px;margin-top:20px;">
  Generado automáticamente por el sistema de monitoreo de aceites.<br>
  Ante dudas, consultar el historial completo en el chatbot.
</p>
</body></html>
"""
