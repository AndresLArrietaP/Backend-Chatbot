# src/providers/factory.py
# -*- coding: utf-8 -*-
"""
Módulo: providers.factory
--------------------------
Define la interfaz estructural (Protocol) que deben cumplir todos los
proveedores LLM, y expone la función de fábrica que instancia el proveedor
configurado en el entorno.

Proveedores disponibles:
  gemini   → GeminiProvider  (src/providers/gemini_client.py)  ← activo por defecto
  openai   → OpenAIProvider  (src/providers/openai_client.py)  ← alternativo

Selección:
  Configura LLM_PROVIDER=gemini o LLM_PROVIDER=openai en el .env.
  La función obtener_proveedor() devuelve la instancia correcta al importar el módulo.

Uso:
  from src.providers.factory import obtener_proveedor
  proveedor = obtener_proveedor()
  sql = await proveedor.consulta_humana_a_sql(...)
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
        modelo: Optional[str] = None,
        conversation_context: Optional[str] = None,
    ) -> str:
        """
        Convierte una consulta en lenguaje natural a una consulta SQL válida.
        """

    async def construir_respuesta(
        self,
        filas: List[Dict[str, Any]],
        consulta_humana: str,
        modelo: Optional[str] = None,
    ) -> str:
        """
        Construye una respuesta en lenguaje natural basada en las filas devueltas.
        """


def obtener_proveedor() -> ProveedorLLM:
    """
    Devuelve una instancia del proveedor LLM configurado en LLM_PROVIDER (.env).

    Proveedor activo:
      LLM_PROVIDER=gemini  → GeminiProvider  (default; requiere GOOGLE_API_KEY)
      LLM_PROVIDER=openai  → OpenAIProvider  (requiere OPENAI_API_KEY)

    Cualquier valor distinto de "openai" cae a Gemini.
    El fallback cross-provider (Gemini → OpenAI en caso de fallo total) se maneja
    en src/main.py._generar_sql(), no aquí.
    """
    proveedor = leer_env("LLM_PROVIDER", default="gemini").lower().strip()

    if proveedor == "openai":
        from .openai_client import OpenAIProvider
        return OpenAIProvider()

    # Gemini es el proveedor principal (default)
    from .gemini_client import GeminiProvider
    return GeminiProvider()