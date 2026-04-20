# src/contexto_chat.py
# -*- coding: utf-8 -*-
"""
Módulo: contexto_chat
---------------------
Memoria conversacional por sesión con TTL, límite de turnos y persistencia
opcional a disco (archivo JSON).

Características:
  - Gestiona múltiples sesiones simultáneas en memoria (dict en RAM).
  - TTL configurable: las conversaciones expiradas se eliminan al siguiente acceso.
  - Máximo de turnos por sesión (ventana deslizante FIFO — los más recientes ganan).
  - Persistencia opcional a .cache/contexto_chat.json para sobrevivir
    recargas de uvicorn en desarrollo (activar con CONTEXTO_CHAT_PERSISTIR=true).
  - Expone el último resultado (filas + SQL + análisis) para que src/main.py
    pueda responder desde memoria sin re-ejecutar SQL.

Clases:
    TurnoConversacion          — Snapshot de un turno (pregunta + SQL + respuesta + filas).
    ConversacionActiva         — Lista de turnos de una sesión con timestamp.
    GestorContextoConversacional — Gestor principal; instanciado una vez en main.py.

Configuración (.env):
    CONTEXTO_CHAT_TTL_MINUTOS         (default: 45)
    CONTEXTO_CHAT_MAX_TURNOS          (default: 8)
    CONTEXTO_CHAT_MAX_CARACTERES      (default: 5000)
    CONTEXTO_CHAT_MAX_FILAS_RESULTADO (default: 200)
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from decimal import Decimal
from pathlib import Path
from threading import Lock
from typing import Dict, List, Any, Optional
import json


# ==============================================================================
#  Utilidades de serialización
# ==============================================================================

def _dt_a_texto(dt: datetime) -> str:
    """Convierte datetime a string ISO 8601 para persistencia en JSON."""
    return dt.isoformat()


def _texto_a_dt(valor: str) -> datetime:
    """Parsea string ISO 8601 a datetime. Devuelve utcnow() si falla."""
    try:
        return datetime.fromisoformat(valor)
    except Exception:
        return datetime.utcnow()


def _json_seguro(v: Any) -> Any:
    """Convierte recursivamente datetime/date a ISO para serialización JSON."""
    if isinstance(v, (datetime, date)):
        return v.isoformat()
    if isinstance(v, list):
        return [_json_seguro(x) for x in v]
    if isinstance(v, dict):
        return {k: _json_seguro(val) for k, val in v.items()}
    return v


def _hacer_jsonable(obj: Any) -> Any:
    """Convierte recursivamente tipos no-JSON (Decimal, datetime, tuple) a tipos nativos."""
    if isinstance(obj, datetime):
        return obj.isoformat()
    if isinstance(obj, date):
        return obj.isoformat()
    if isinstance(obj, Decimal):
        return float(obj)
    if isinstance(obj, dict):
        return {str(k): _hacer_jsonable(v) for k, v in obj.items()}
    if isinstance(obj, list):
        return [_hacer_jsonable(x) for x in obj]
    if isinstance(obj, tuple):
        return [_hacer_jsonable(x) for x in obj]
    return obj


# ==============================================================================
#  Modelos de datos
# ==============================================================================

@dataclass
class TurnoConversacion:
    """
    Snapshot de un turno de conversación.
    Almacena la pregunta del usuario, el SQL generado, la respuesta textual
    y las filas de resultado para responder desde memoria en turnos posteriores.
    """
    consulta_usuario: str
    sql_generado: str = ""
    respuesta_textual: str = ""
    row_count: int = 0
    filas_resultado: List[Dict[str, Any]] = field(default_factory=list)
    analisis_resultado: Dict[str, Any] = field(default_factory=dict)
    origen_respuesta: str = ""
    marca_tiempo: datetime = field(default_factory=datetime.utcnow)

    def a_dict(self) -> Dict[str, Any]:
        """Serializa el turno a dict JSON-seguro."""
        return {
            "consulta_usuario": self.consulta_usuario,
            "sql_generado": self.sql_generado,
            "respuesta_textual": self.respuesta_textual,
            "row_count": self.row_count,
            "filas_resultado": _json_seguro(self.filas_resultado),
            "analisis_resultado": _json_seguro(self.analisis_resultado),
            "origen_respuesta": self.origen_respuesta,
            "marca_tiempo": _dt_a_texto(self.marca_tiempo),
        }

    @classmethod
    def desde_dict(cls, data: Dict[str, Any]) -> "TurnoConversacion":
        """Deserializa un turno desde dict (cargado de JSON en disco)."""
        return cls(
            consulta_usuario=str(data.get("consulta_usuario") or "").strip(),
            sql_generado=str(data.get("sql_generado") or "").strip(),
            respuesta_textual=str(data.get("respuesta_textual") or "").strip(),
            row_count=max(0, int(data.get("row_count") or 0)),
            filas_resultado=list(data.get("filas_resultado") or []),
            analisis_resultado=dict(data.get("analisis_resultado") or {}),
            origen_respuesta=str(data.get("origen_respuesta") or "").strip(),
            marca_tiempo=_texto_a_dt(str(data.get("marca_tiempo") or "")),
        )


@dataclass
class ConversacionActiva:
    """
    Colección de turnos de una sesión activa.
    Incluye timestamp de última actualización para el cálculo de TTL.
    """
    session_id: str
    turnos: List[TurnoConversacion] = field(default_factory=list)
    actualizada_en: datetime = field(default_factory=datetime.utcnow)

    def a_dict(self) -> Dict[str, Any]:
        return {
            "session_id": self.session_id,
            "turnos": [t.a_dict() for t in self.turnos],
            "actualizada_en": _dt_a_texto(self.actualizada_en),
        }

    @classmethod
    def desde_dict(cls, data: Dict[str, Any]) -> "ConversacionActiva":
        return cls(
            session_id=str(data.get("session_id") or "").strip(),
            turnos=[TurnoConversacion.desde_dict(x) for x in (data.get("turnos") or [])],
            actualizada_en=_texto_a_dt(str(data.get("actualizada_en") or "")),
        )


# ==============================================================================
#  Gestor principal
# ==============================================================================

class GestorContextoConversacional:
    """
    Memoria conversacional multi-sesión con TTL y persistencia opcional a disco.

    Thread-safe: usa threading.Lock para acceso concurrente desde el event loop de uvicorn.
    Persistencia: escribe atómicamente (tmp → replace) para evitar corrupción del JSON.
    """

    def __init__(
        self,
        ttl_minutos: int = 45,
        max_turnos: int = 8,
        max_caracteres: int = 5000,
        max_filas_resultado: int = 200,
        persistir_archivo: bool = False,
        ruta_archivo: str = ".cache/contexto_chat.json",
    ) -> None:
        self.ttl = timedelta(minutes=max(1, ttl_minutos))
        self.max_turnos = max(1, max_turnos)
        self.max_caracteres = max(500, max_caracteres)
        self.max_filas_resultado = max(1, max_filas_resultado)
        self.persistir_archivo = bool(persistir_archivo)
        self.ruta_archivo = Path(ruta_archivo)
        self._lock = Lock()
        self._conversaciones: Dict[str, ConversacionActiva] = {}

        if self.persistir_archivo:
            self._cargar_desde_disco()

    # ------------------------------------------------------------------
    #  Persistencia a disco
    # ------------------------------------------------------------------

    def _cargar_desde_disco(self) -> None:
        """Carga conversaciones previas del archivo JSON si existe."""
        if not self.persistir_archivo or not self.ruta_archivo.exists():
            return
        try:
            contenido = json.loads(self.ruta_archivo.read_text(encoding="utf-8"))
            conversaciones = {}
            for sid, data in (contenido.get("conversaciones") or {}).items():
                conv = ConversacionActiva.desde_dict(data)
                if conv.session_id:
                    conversaciones[sid] = conv
            self._conversaciones = conversaciones
        except Exception:
            # Si el archivo está corrupto, se parte desde cero
            self._conversaciones = {}

    def _guardar_en_disco(self) -> None:
        """Persiste conversaciones en disco de forma atómica (tmp → replace)."""
        if not self.persistir_archivo:
            return
        self.ruta_archivo.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "conversaciones": {
                sid: conv.a_dict()
                for sid, conv in self._conversaciones.items()
            }
        }
        # Escritura atómica: evita archivo corrupto si el proceso muere durante el write
        tmp = self.ruta_archivo.with_suffix(".tmp")
        tmp.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2, default=str),
            encoding="utf-8",
        )
        tmp.replace(self.ruta_archivo)

    def _sincronizar_desde_disco(self) -> None:
        """Recarga desde disco si la persistencia está activada."""
        if self.persistir_archivo:
            self._cargar_desde_disco()

    # ------------------------------------------------------------------
    #  Gestión de sesiones
    # ------------------------------------------------------------------

    def limpiar_expiradas(self) -> None:
        """Elimina sesiones cuyo TTL ha vencido. Llamar antes de leer/escribir."""
        ahora = datetime.utcnow()
        with self._lock:
            self._sincronizar_desde_disco()
            expiradas = [
                sid
                for sid, conv in self._conversaciones.items()
                if (ahora - conv.actualizada_en) > self.ttl
            ]
            for sid in expiradas:
                self._conversaciones.pop(sid, None)
            if expiradas:
                self._guardar_en_disco()

    def registrar_turno(
        self,
        session_id: str,
        consulta_usuario: str,
        sql_generado: str = "",
        respuesta_textual: str = "",
        row_count: int = 0,
        filas_resultado: List[Dict[str, Any]] | None = None,
        analisis_resultado: Dict[str, Any] | None = None,
        origen_respuesta: str = "",
    ) -> None:
        """
        Añade un turno a la sesión. Si la sesión no existe, la crea.
        Aplica la ventana deslizante FIFO (max_turnos) al agregar.
        """
        if not session_id:
            return

        # Limitar filas almacenadas para no saturar RAM/disco
        filas_seguras = list(filas_resultado or [])[:self.max_filas_resultado]
        analisis_seguro = dict(analisis_resultado or {})

        turno = TurnoConversacion(
            consulta_usuario=(consulta_usuario or "").strip(),
            sql_generado=(sql_generado or "").strip(),
            respuesta_textual=(respuesta_textual or "").strip(),
            row_count=max(0, int(row_count or 0)),
            filas_resultado=filas_seguras,
            analisis_resultado=analisis_seguro,
            origen_respuesta=(origen_respuesta or "").strip(),
        )

        with self._lock:
            self._sincronizar_desde_disco()

            conv = self._conversaciones.get(session_id)
            if conv is None:
                conv = ConversacionActiva(session_id=session_id)
                self._conversaciones[session_id] = conv

            conv.turnos.append(turno)
            # Ventana deslizante: solo los últimos max_turnos
            conv.turnos = conv.turnos[-self.max_turnos:]
            conv.actualizada_en = datetime.utcnow()

            self._guardar_en_disco()

    def obtener_contexto(self, session_id: str) -> str:
        """
        Devuelve el historial de conversación de la sesión como texto plano
        para inyectarlo en el prompt del LLM.

        Si el texto supera max_caracteres, devuelve solo el final (más reciente).
        """
        if not session_id:
            return ""

        self.limpiar_expiradas()

        with self._lock:
            self._sincronizar_desde_disco()
            conv = self._conversaciones.get(session_id)
            if conv is None or not conv.turnos:
                return ""
            turnos = list(conv.turnos)

        lineas: List[str] = []
        for idx, turno in enumerate(turnos, start=1):
            lineas.append(f"Turno {idx} - usuario: {turno.consulta_usuario}")
            if turno.sql_generado:
                lineas.append(f"Turno {idx} - sql: {turno.sql_generado[:700]}")
            if turno.respuesta_textual:
                lineas.append(f"Turno {idx} - respuesta: {turno.respuesta_textual[:900]}")
            if turno.row_count:
                lineas.append(f"Turno {idx} - filas: {turno.row_count}")

        texto = "\n".join(lineas).strip()
        if len(texto) <= self.max_caracteres:
            return texto
        # Recortar desde el final para priorizar los turnos más recientes
        return texto[-self.max_caracteres:]

    def obtener_ultimo_resultado(self, session_id: str) -> Dict[str, Any]:
        """
        Devuelve el último turno de la sesión que tenga filas de resultado.
        Usado por main.py para responder desde memoria sin re-ejecutar SQL.

        Devuelve dict vacío si no hay sesión activa o ningún turno tiene filas.
        """
        if not session_id:
            return {}

        self.limpiar_expiradas()

        with self._lock:
            self._sincronizar_desde_disco()
            conv = self._conversaciones.get(session_id)
            if conv is None or not conv.turnos:
                return {}

            # Buscar el turno más reciente con filas (no necesariamente el último)
            ultimo = conv.turnos[-1]

        filas = list(ultimo.filas_resultado or [])
        return {
            "consulta_usuario": ultimo.consulta_usuario,
            "sql_generado": ultimo.sql_generado,
            "respuesta_textual": ultimo.respuesta_textual,
            "row_count": ultimo.row_count,
            "rows": filas,
            "rows_resultado": filas,
            "analisis": dict(ultimo.analisis_resultado or {}),
            "origen_respuesta": ultimo.origen_respuesta,
        }

    def obtener_estado(self, session_id: str) -> Dict[str, object]:
        """
        Devuelve metadata de la sesión: si está activa, cuántos turnos tiene
        y cuántos segundos le quedan antes de expirar.
        """
        if not session_id:
            return {
                "session_id": "",
                "activa": False,
                "turnos": 0,
                "ttl_minutos": int(self.ttl.total_seconds() // 60),
            }

        self.limpiar_expiradas()

        with self._lock:
            self._sincronizar_desde_disco()
            conv = self._conversaciones.get(session_id)
            if conv is None:
                return {
                    "session_id": session_id,
                    "activa": False,
                    "turnos": 0,
                    "ttl_minutos": int(self.ttl.total_seconds() // 60),
                }

            segundos_restantes = max(
                0,
                int((self.ttl - (datetime.utcnow() - conv.actualizada_en)).total_seconds()),
            )

            return {
                "session_id": session_id,
                "activa": True,
                "turnos": len(conv.turnos),
                "ttl_minutos": int(self.ttl.total_seconds() // 60),
                "segundos_restantes_aprox": segundos_restantes,
            }

    def olvidar(self, session_id: str) -> None:
        """Elimina una sesión de memoria y de disco (si persistencia activa)."""
        if not session_id:
            return
        with self._lock:
            self._sincronizar_desde_disco()
            self._conversaciones.pop(session_id, None)
            self._guardar_en_disco()
