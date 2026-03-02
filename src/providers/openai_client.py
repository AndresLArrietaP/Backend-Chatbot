# src/providers/openai_client.py
# -*- coding: utf-8 -*-
"""
Módulo: providers.openai_client
-------------------------------
Cliente del proveedor OpenAI para:
- NL → SQL (devuelve JSON con {"sql_query", "original_query"}).
- Construcción de respuesta en lenguaje natural (build_answer/construir_respuesta).

Cambios:
- Nombres y docstrings en español.
- Se mantienen alias de compatibilidad en inglés para no romper integraciones previas.
- Se preserva exactamente el comportamiento original.
"""

from typing import Any, List, Dict, Optional
from decouple import config as env
import json
import re
from openai import OpenAI


class OpenAIProvider:
    """
    Proveedor OpenAI usando la API Chat Completions.
    Lee modelo/clave desde variables de entorno OPENAI_API_KEY / OPENAI_MODEL.
    """

    def __init__(self) -> None:
        api_key = env("OPENAI_API_KEY", default=None)
        if not api_key:
            raise RuntimeError("Falta OPENAI_API_KEY en .env")
        self.cliente = OpenAI(api_key=api_key)

    # ---------------- Resolución de modelo ----------------

    def _resolver_modelo(self, nombre: Optional[str]) -> str:
        """Devuelve el nombre de modelo a usar (override o por defecto desde .env)."""
        return (nombre or env("OPENAI_MODEL", default="gpt-4o")).strip()

    # ---------------- Utilidades ----------------

    def _asegurar_sql_json(self, contenido: str) -> str:
        """
        Intenta extraer y validar un JSON con "sql_query" y "original_query".
        - Acepta JSON limpio o embebido dentro de texto.
        - Retorna el JSON minimizado (ensure_ascii=False).
        - Lanza RuntimeError si no es posible validar.
        """
        def _probar(s: str) -> Optional[str]:
            try:
                obj = json.loads(s)
                if isinstance(obj, dict) and "sql_query" in obj:
                    obj.setdefault("original_query", "")
                    return json.dumps(obj, ensure_ascii=False)
            except Exception:
                return None
            return None

        contenido = (contenido or "").strip()
        ok = _probar(contenido)
        if ok:
            return ok

        m = re.search(r"\{.*\}", contenido, re.DOTALL)
        if m:
            ok = _probar(m.group(0))
            if ok:
                return ok

        raise RuntimeError(f"OpenAI devolvió formato inválido: {contenido[:300]}")

    # ---------------- NL → SQL ----------------

    async def consulta_humana_a_sql(
        self,
        consulta: str,
        esquema_json: Dict[str, Any],
        dialecto: str = "postgresql",
        limite_por_defecto: int = 100,
        modelo: Optional[str] = None
    ) -> str:
        """
        Convierte una consulta en lenguaje natural a SQL (solo lectura) y devuelve JSON:
            {"sql_query": "...", "original_query": "..."}
        """
        esquema_compacto = [
            {
                "schema": t["schema"],
                "table": t["table"],
                "fq_name": t["fq_name"],
                "columns": [
                    {"name": c["name"], "type": c.get("type", "")}
                    for c in t["columns"]
                ]
            }
            for t in esquema_json.get("tables", [])
        ]

        system_prompt = f"""
You are a senior data analyst and SQL generator for {dialecto.upper()}.

RULES:
- ONLY SELECT or WITH + SELECT
- NEVER use INSERT, UPDATE, DELETE, DROP, ALTER, CREATE
- Use ONLY tables and columns from <schema_json>
- If the question implies totals, sums, rankings:
  → YOU MUST use GROUP BY
- Correctly detect dimensions vs metrics
- Always alias aggregated columns
- Always ORDER BY aggregated values
- Add LIMIT {limite_por_defecto} if missing

RETURN ONLY VALID JSON:
{{
  "sql_query": "...",
  "original_query": "{consulta}"
}}

<schema_json>
{json.dumps(esquema_compacto, ensure_ascii=False)}
</schema_json>
""".strip()

        mdl = self._resolver_modelo(modelo)

        resp = self.cliente.chat.completions.create(
            model=mdl,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": consulta},
            ],
            temperature=0.0,
            max_tokens=900,
        )

        contenido = resp.choices[0].message.content
        return self._asegurar_sql_json(contenido)

    # ---------------- Respuesta (build_answer) ----------------

    async def construir_respuesta(
        self,
        filas: List[Dict[str, Any]],
        consulta_humana: str,
        modelo: Optional[str] = None
    ) -> str:
        """
        Construye un breve resumen en español basado en las filas resultantes.
        - 2–3 frases, sin inventar datos.
        - Menciona totales/rankings si se observan en el resultado.
        """
        prompt = f"""
Eres un analista de datos senior.
Resume el resultado en español claro.

Reglas:
- No inventes datos
- 2–3 frases
- Menciona totales o rankings si existen

Pregunta:
{consulta_humana}

Resultado:
{json.dumps(filas, ensure_ascii=False)[:12000]}
""".strip()

        mdl = self._resolver_modelo(modelo)

        resp = self.cliente.chat.completions.create(
            model=mdl,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.2,
            max_tokens=500,
        )

        return (resp.choices[0].message.content or "").strip()

    # ---------------- Ping / Modelos ----------------

    async def ping(self, modelo: Optional[str] = None) -> str:
        """Ping simple para verificar disponibilidad del modelo."""
        mdl = self._resolver_modelo(modelo)
        resp = self.cliente.chat.completions.create(
            model=mdl,
            messages=[{"role": "user", "content": "ping"}],
            max_tokens=5,
            temperature=0.0,
        )
        return resp.choices[0].message.content

    def listar_modelos(self) -> Dict[str, Any]:
        """Lista de modelos visibles para la clave/proyecto actual."""
        items = []
        for m in self.cliente.models.list():
            items.append({"name": getattr(m, "id", None)})
        return {"status": "ok", "models": items}