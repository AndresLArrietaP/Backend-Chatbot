# src/providers/openai_client.py
# -*- coding: utf-8 -*-
"""
Módulo: providers.openai_client
-------------------------------
Cliente del proveedor OpenAI para:
- NL → SQL
- Construcción de respuesta en lenguaje natural

Queda preparado como alternativa futura al flujo principal con Gemini.
"""

from __future__ import annotations

from typing import Any, List, Dict, Optional
import asyncio
import json
import re

from decouple import config as env
from openai import OpenAI

from ..analitica import generar_analisis_resultado, renderizar_resumen_analitico


class OpenAIProvider:
    """Proveedor OpenAI usando la API Chat Completions."""

    def __init__(self) -> None:
        api_key = (env("OPENAI_API_KEY", default=None) or "").strip()
        if not api_key:
            raise RuntimeError("Falta OPENAI_API_KEY en .env")
        self.cliente = OpenAI(api_key=api_key)

    def _resolver_modelo(self, nombre: Optional[str]) -> str:
        return (nombre or env("OPENAI_MODEL", default="gpt-4o")).strip()

    def _asegurar_sql_json(self, contenido: str) -> str:
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

        if re.match(r"^\s*(with|select)\b", contenido, flags=re.IGNORECASE):
            return json.dumps({"sql_query": contenido.strip(), "original_query": ""}, ensure_ascii=False)

        raise RuntimeError(f"OpenAI devolvió formato inválido: {contenido[:300]}")

    def _prompt_dialecto(self, dialecto: str, limite_por_defecto: int) -> str:
        d = (dialecto or "postgresql").lower().strip()
        if d in ("mssql", "sqlserver"):
            return (
                "DIALECTO: SQL Server / Azure SQL. "
                f"Usa TOP ({limite_por_defecto}) en vez de LIMIT. "
                "Usa corchetes para identificadores. "
                "No uses sintaxis exclusiva de Postgres ni macros como NUMERIC_CLEAN o DATE_PARSE."
            )
        return (
            "DIALECTO: PostgreSQL. "
            f"Usa LIMIT {limite_por_defecto} si la consulta no trae límite. "
            "Usa comillas dobles para identificadores con espacios."
        )

    async def consulta_humana_a_sql(
        self,
        consulta: str,
        esquema_json: Dict[str, Any],
        dialecto: str = "postgresql",
        limite_por_defecto: int = 100,
        modelo: Optional[str] = None,
        conversation_context: Optional[str] = None,
    ) -> str:
        esquema_compacto = [
            {
                "schema": t["schema"],
                "table": t["table"],
                "fq_name": t.get("fq_name"),
                "columns": [{"name": c["name"], "type": c.get("type", "")} for c in t.get("columns", [])],
            }
            for t in esquema_json.get("tables", [])
        ]

        bloque_contexto = ""
        if conversation_context:
            bloque_contexto = f"\n<contexto_conversacional>\n{conversation_context}\n</contexto_conversacional>\n"

        system_prompt = f"""
You are a senior data analyst and SQL generator for {dialecto.upper()}.

RULES:
- ONLY SELECT or WITH + SELECT
- NEVER use INSERT, UPDATE, DELETE, DROP, ALTER, CREATE, EXEC
- Use ONLY tables and columns from <schema_json>
- Prefer real business joins and avoid irrelevant joins.
- If the user asks totals, rankings or comparisons, include GROUP BY / ORDER BY as needed.
- Always return SQL COMPLETE and executable.
- Return ONLY valid JSON:
{{
  "sql_query": "...",
  "original_query": "{consulta}"
}}

{self._prompt_dialecto(dialecto, limite_por_defecto)}
{bloque_contexto}
<schema_json>
{json.dumps(esquema_compacto, ensure_ascii=False)}
</schema_json>
""".strip()

        mdl = self._resolver_modelo(modelo)

        def _llamar():
            return self.cliente.chat.completions.create(
                model=mdl,
                messages=[
                    {"role": "system", "content": system_prompt},
                    {"role": "user", "content": consulta},
                ],
                temperature=0.0,
                max_tokens=1400,
            )

        resp = await asyncio.to_thread(_llamar)
        contenido = resp.choices[0].message.content or ""
        return self._asegurar_sql_json(contenido)

    async def construir_respuesta(
        self,
        filas: List[Dict[str, Any]],
        consulta_humana: str,
        modelo: Optional[str] = None,
    ) -> str:
        analisis = generar_analisis_resultado(filas, consulta_humana=consulta_humana)
        respaldo = renderizar_resumen_analitico(analisis)

        mdl = self._resolver_modelo(modelo)
        prompt = f"""
Eres un analista senior de datos.
Resume el resultado en español claro y ejecutivo.

Reglas:
- No inventes datos.
- Basa la respuesta en `analisis` y en una muestra de `rows`.
- Menciona máximos, mínimos, mediana y tendencia cuando existan.
- Si no hay tendencia confiable, dilo explícitamente.
- Responde en 1 párrafo y luego hasta 4 viñetas.

Pregunta:
{consulta_humana}

Analisis determinístico:
{json.dumps(analisis, ensure_ascii=False)}

Rows (muestra):
{json.dumps(filas[:80], ensure_ascii=False)}
""".strip()

        def _llamar():
            return self.cliente.chat.completions.create(
                model=mdl,
                messages=[{"role": "user", "content": prompt}],
                temperature=0.15,
                max_tokens=700,
            )

        try:
            resp = await asyncio.to_thread(_llamar)
            return (resp.choices[0].message.content or "").strip() or respaldo
        except Exception:
            return respaldo

    async def ping(self, modelo: Optional[str] = None) -> str:
        mdl = self._resolver_modelo(modelo)

        def _llamar():
            return self.cliente.chat.completions.create(
                model=mdl,
                messages=[{"role": "user", "content": "ping"}],
                max_tokens=5,
                temperature=0.0,
            )

        resp = await asyncio.to_thread(_llamar)
        return (resp.choices[0].message.content or "").strip()

    def listar_modelos(self) -> Dict[str, Any]:
        items = []
        for modelo in self.cliente.models.list():
            items.append({"name": getattr(modelo, "id", None)})
        return {"status": "ok", "models": items}

    # Aliases legacy
    async def human_query_to_sql(
        self,
        human_query: str,
        schema_json: Dict[str, Any],
        dialect: str = "postgresql",
        default_limit: int = 100,
        model: Optional[str] = None,
        conversation_context: Optional[str] = None,
    ) -> str:
        return await self.consulta_humana_a_sql(
            consulta=human_query,
            esquema_json=schema_json,
            dialecto=dialect,
            limite_por_defecto=default_limit,
            modelo=model,
            conversation_context=conversation_context,
        )

    async def build_answer(
        self,
        rows: List[Dict[str, Any]],
        human_query: str,
        model: Optional[str] = None,
    ) -> str:
        return await self.construir_respuesta(
            filas=rows,
            consulta_humana=human_query,
            modelo=model,
        )

    def list_models(self) -> Dict[str, Any]:
        return self.listar_modelos()
