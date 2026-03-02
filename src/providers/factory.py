# src/providers/factory.py

"""
Módulo: factory
---------------
Contiene la interfaz base para los proveedores LLM y la función
que selecciona automáticamente el proveedor configurado en el .env.
"""

from typing import Protocol, List, Dict, Any, Optional
from decouple import config as leer_env


class ProveedorLLM(Protocol):
    """
    Interfaz que deben implementar todos los proveedores LLM.
    """

    def listar_modelos(self) -> Dict[str, Any]:
        """Devuelve un diccionario con los modelos disponibles."""

    async def ping(self, modelo: Optional[str] = None) -> str:
        """Verifica la disponibilidad del proveedor."""

    async def consulta_humana_a_sql(
        self,
        consulta: str,
        esquema_json: Dict[str, Any],
        dialecto: str = "postgresql",
        limite_por_defecto: int = 100,
        modelo: Optional[str] = None
    ) -> str:
        """
        Convierte una consulta en lenguaje natural a una consulta SQL válida.
        """

    async def construir_respuesta(
        self,
        filas: List[Dict[str, Any]],
        consulta: str,
        modelo: Optional[str] = None
    ) -> str:
        """
        Construye una respuesta en lenguaje natural basada en las filas devueltas.
        """


def obtener_proveedor() -> ProveedorLLM:
    """
    Devuelve una instancia del proveedor LLM configurado en el .env.

    Returns:
        ProveedorLLM: instancia del proveedor activo (Gemini u OpenAI).
    """
    proveedor = leer_env("LLM_PROVIDER", default="gemini").lower()

    if proveedor == "openai":
        from .openai_client import OpenAIProvider
        return OpenAIProvider()

    # Por defecto se usa Gemini
    from .gemini_client import GeminiProvider
    return GeminiProvider()