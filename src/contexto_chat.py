# src/contexto_chat.py
# -*- coding: utf-8 -*-
"""
Memoria conversacional para desarrollo con:
- TTL
- límite de turnos
- persistencia opcional a archivo JSON
- recuperación entre recargas/reloads de uvicorn
- almacenamiento del último resultado para continuidad determinística
"""

from __future__ import annotations

from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from decimal import Decimal
from pathlib import Path
from threading import Lock
from typing import Dict, List, Any, Optional
import json


def _dt_a_texto(dt: datetime) -> str:
    return dt.isoformat()


def _texto_a_dt(valor: str) -> datetime:
    try:
        return datetime.fromisoformat(valor)
    except Exception:
        return datetime.utcnow()
    
def _json_seguro(v: Any) -> Any:
    if isinstance(v, (datetime, date)):
        return v.isoformat()
    if isinstance(v, list):
        return [_json_seguro(x) for x in v]
    if isinstance(v, dict):
        return {k: _json_seguro(val) for k, val in v.items()}
    return v


def _hacer_jsonable(obj: Any) -> Any:
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


@dataclass
class TurnoConversacion:
    consulta_usuario: str
    sql_generado: str = ""
    respuesta_textual: str = ""
    row_count: int = 0
    filas_resultado: List[Dict[str, Any]] = field(default_factory=list)
    analisis_resultado: Dict[str, Any] = field(default_factory=dict)
    origen_respuesta: str = ""
    marca_tiempo: datetime = field(default_factory=datetime.utcnow)

    def a_dict(self) -> Dict[str, Any]:
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


class GestorContextoConversacional:
    """Memoria conversacional con TTL y persistencia opcional."""

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

    def _cargar_desde_disco(self) -> None:
        if not self.persistir_archivo:
            return
        if not self.ruta_archivo.exists():
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
            self._conversaciones = {}

    def _guardar_en_disco(self) -> None:
        if not self.persistir_archivo:
            return

        self.ruta_archivo.parent.mkdir(parents=True, exist_ok=True)
        payload = {
            "conversaciones": {
                sid: conv.a_dict()
                for sid, conv in self._conversaciones.items()
            }
        }

        tmp = self.ruta_archivo.with_suffix(".tmp")
        tmp.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
        tmp.replace(self.ruta_archivo)

    def _sincronizar_desde_disco(self) -> None:
        if self.persistir_archivo:
            self._cargar_desde_disco()

    def limpiar_expiradas(self) -> None:
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
        if not session_id:
            return

        filas_seguras = list(filas_resultado or [])[:200]
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
            conv.turnos = conv.turnos[-self.max_turnos:]
            conv.actualizada_en = datetime.utcnow()

            self._guardar_en_disco()

    def obtener_contexto(self, session_id: str) -> str:
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
        return texto[-self.max_caracteres:]

    def obtener_ultimo_resultado(self, session_id: str) -> Dict[str, Any]:
        if not session_id:
            return {}

        self.limpiar_expiradas()

        with self._lock:
            self._sincronizar_desde_disco()
            conv = self._conversaciones.get(session_id)
            if conv is None or not conv.turnos:
                return {}

            for turno in reversed(conv.turnos):
                if turno.filas_resultado:
                    return {
                        "consulta_usuario": turno.consulta_usuario,
                        "sql_generado": turno.sql_generado,
                        "respuesta_textual": turno.respuesta_textual,
                        "row_count": turno.row_count,
                        "rows_resultado": list(turno.filas_resultado or []),
                        "columnas_resultado": list(turno.columnas_resultado or []),
                        "analisis_resultado": dict(turno.analisis_resultado or {}),
                        "marca_tiempo": _dt_a_texto(turno.marca_tiempo),
                    }

        return {}

    def obtener_estado(self, session_id: str) -> Dict[str, object]:
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

            restantes = max(
                0,
                int((self.ttl - (datetime.utcnow() - conv.actualizada_en)).total_seconds()),
            )

            return {
                "session_id": session_id,
                "activa": True,
                "turnos": len(conv.turnos),
                "ttl_minutos": int(self.ttl.total_seconds() // 60),
                "segundos_restantes_aprox": restantes,
            }
            
    def obtener_ultimo_resultado(self, session_id: str) -> Dict[str, Any]:
        if not session_id:
            return {}

        self.limpiar_expiradas()

        with self._lock:
            self._sincronizar_desde_disco()
            conv = self._conversaciones.get(session_id)
            if conv is None or not conv.turnos:
                return {}

            ultimo = conv.turnos[-1]

        return {
            "consulta_usuario": ultimo.consulta_usuario,
            "sql_generado": ultimo.sql_generado,
            "respuesta_textual": ultimo.respuesta_textual,
            "row_count": ultimo.row_count,
            "rows": list(ultimo.filas_resultado or []),
            "analisis": dict(ultimo.analisis_resultado or {}),
            "origen_respuesta": ultimo.origen_respuesta,
        }

    def olvidar(self, session_id: str) -> None:
        if not session_id:
            return

        with self._lock:
            self._sincronizar_desde_disco()
            self._conversaciones.pop(session_id, None)
            self._guardar_en_disco()