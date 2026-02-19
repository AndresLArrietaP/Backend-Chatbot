from typing import Any, List, Dict, Optional
from decouple import config as env
import json
import re
from openai import OpenAI

class OpenAIProvider:
    def __init__(self) -> None:
        api_key = env("OPENAI_API_KEY", default=None)
        if not api_key:
            raise RuntimeError("Falta OPENAI_API_KEY en .env")
        self.client = OpenAI(api_key=api_key)

    def _resolve_model(self, name: Optional[str]) -> str:
        return (name or env("OPENAI_MODEL", default="gpt-4o")).strip()

    def list_models(self) -> Dict[str, Any]:
        items = []
        for m in self.client.models.list():
            # En OpenAI Python 1.x, m.id es el nombre del modelo
            items.append({"name": getattr(m, "id", None)})
        return {"status": "ok", "models": items}

    def _ensure_sql_json(self, content: str) -> str:
        def _try(s: str) -> Optional[str]:
            try:
                obj = json.loads(s)
                if isinstance(obj, dict) and "sql_query" in obj:
                    return json.dumps(obj, ensure_ascii=False)
            except Exception:
                return None
            return None

        ok = _try(content.strip())
        if ok:
            return ok

        m = re.search(r"\{.*\}", content, re.DOTALL)
        if m:
            ok = _try(m.group(0))
            if ok:
                return ok

        raise RuntimeError(f"OpenAI devolvió un formato inesperado: {content[:300]}")

    async def human_query_to_sql(
        self,
        human_query: str,
        schema_json: Dict[str,Any],
        dialect: str="postgresql",
        default_limit: int=100,
        model: Optional[str]=None
    ) -> str:
        schema_compact = [
            {"schema": t["schema"], "table": t["table"],
             "columns": [c["name"] for c in t["columns"]]}
            for t in schema_json.get("tables", [])
        ]

        system_message = f"""
You are a careful SQL generator for the {dialect.upper()} dialect.
Rules:
- Base your query ONLY on the provided schema (JSON).
- Use ANSI quoting accordingly (double quotes for PostgreSQL/SQLite, backticks for MySQL, brackets for SQL Server).
- Add LIMIT {default_limit} if missing.
- Return a strict JSON object with keys: "sql_query" and "original_query".
- Do not hallucinate tables or columns.
<schema_json>
{json.dumps(schema_compact, ensure_ascii=False)}
</schema_json>
""".strip()

        mdl = self._resolve_model(model)
        resp = self.client.chat.completions.create(
            model=mdl,
            response_format={"type": "json_object"},
            messages=[
                {"role": "system", "content": system_message},
                {"role": "user", "content": human_query},
            ],
            max_tokens=800,
            temperature=0.1,
        )
        content = resp.choices[0].message.content
        return self._ensure_sql_json(content)

    async def build_answer(
        self,
        rows: List[Dict[str,Any]],
        human_query: str,
        model: Optional[str]=None
    ) -> str:
        prompt = f"""
Eres un analista. Con la pregunta del usuario y las filas de SQL, responde en español de forma concisa y útil.
Incluye cifras clave. Si no hay datos, dilo explícitamente.

<user_question>
{human_query}
</user_question>
<sql_rows>
{json.dumps(rows, ensure_ascii=False)[:15000]}
</sql_rows>
""".strip()

        mdl = self._resolve_model(model)
        resp = self.client.chat.completions.create(
            model=mdl,
            messages=[{"role": "system", "content": prompt}],
            max_tokens=600,
            temperature=0.2,
        )
        return resp.choices[0].message.content or ""

    async def ping(self, model: Optional[str]=None) -> str:
        mdl = self._resolve_model(model)
        resp = self.client.chat.completions.create(
            model=mdl,
            messages=[{"role": "user", "content": "ping"}],
            max_tokens=5,
            temperature=0.0,
        )
        return resp.choices[0].message.content or ""