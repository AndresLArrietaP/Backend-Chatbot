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

    # ---------------- Utils ----------------
    def _ensure_sql_json(self, content: str) -> str:
        def _try(s: str) -> Optional[str]:
            try:
                obj = json.loads(s)
                if isinstance(obj, dict) and "sql_query" in obj:
                    obj.setdefault("original_query", "")
                    return json.dumps(obj, ensure_ascii=False)
            except Exception:
                return None
            return None

        content = (content or "").strip()
        ok = _try(content)
        if ok:
            return ok

        m = re.search(r"\{.*\}", content, re.DOTALL)
        if m:
            ok = _try(m.group(0))
            if ok:
                return ok

        raise RuntimeError(f"OpenAI devolvió formato inválido: {content[:300]}")

    # ---------------- NL → SQL ----------------
    async def human_query_to_sql(
        self,
        human_query: str,
        schema_json: Dict[str, Any],
        dialect: str = "postgresql",
        default_limit: int = 100,
        model: Optional[str] = None
    ) -> str:

        schema_compact = [
            {
                "schema": t["schema"],
                "table": t["table"],
                "fq_name": t["fq_name"],
                "columns": [
                    {"name": c["name"], "type": c.get("type", "")}
                    for c in t["columns"]
                ]
            }
            for t in schema_json.get("tables", [])
        ]

        system_prompt = f"""
You are a senior data analyst and SQL generator for {dialect.upper()}.

RULES:
- ONLY SELECT or WITH + SELECT
- NEVER use INSERT, UPDATE, DELETE, DROP, ALTER, CREATE
- Use ONLY tables and columns from <schema_json>
- If the question implies totals, sums, rankings:
  → YOU MUST use GROUP BY
- Correctly detect dimensions vs metrics
- Always alias aggregated columns
- Always ORDER BY aggregated values
- Add LIMIT {default_limit} if missing

RETURN ONLY VALID JSON:
{{
  "sql_query": "...",
  "original_query": "{human_query}"
}}

<schema_json>
{json.dumps(schema_compact, ensure_ascii=False)}
</schema_json>
""".strip()

        mdl = self._resolve_model(model)

        resp = self.client.chat.completions.create(
            model=mdl,
            messages=[
                {"role": "system", "content": system_prompt},
                {"role": "user", "content": human_query},
            ],
            temperature=0.0,
            max_tokens=900,
        )

        content = resp.choices[0].message.content
        return self._ensure_sql_json(content)

    # ---------------- Answer ----------------
    async def build_answer(
        self,
        rows: List[Dict[str, Any]],
        human_query: str,
        model: Optional[str] = None
    ) -> str:

        prompt = f"""
Eres un analista de datos senior.
Resume el resultado en español claro.

Reglas:
- No inventes datos
- 2–3 frases
- Menciona totales o rankings si existen

Pregunta:
{human_query}

Resultado:
{json.dumps(rows, ensure_ascii=False)[:12000]}
""".strip()

        mdl = self._resolve_model(model)

        resp = self.client.chat.completions.create(
            model=mdl,
            messages=[{"role": "user", "content": prompt}],
            temperature=0.2,
            max_tokens=500,
        )

        return resp.choices[0].message.content.strip()

    async def ping(self, model: Optional[str] = None) -> str:
        mdl = self._resolve_model(model)
        resp = self.client.chat.completions.create(
            model=mdl,
            messages=[{"role": "user", "content": "ping"}],
            max_tokens=5,
            temperature=0.0,
        )
        return resp.choices[0].message.content

    def list_models(self) -> Dict[str, Any]:
        items = []
        for m in self.client.models.list():
            items.append({"name": getattr(m, "id", None)})
        return {"status": "ok", "models": items}