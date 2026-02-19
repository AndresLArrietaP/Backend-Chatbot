from typing import Any, List, Dict, Optional
from decouple import config as env
import json
import re
from google import genai

class GeminiProvider:
    def __init__(self) -> None:
        api_key = (env("GOOGLE_API_KEY", default="") or "").strip()
        if not api_key:
            raise RuntimeError("Falta GOOGLE_API_KEY en .env")
        self.client = genai.Client(api_key=api_key)

    def _resolve_model(self, name: Optional[str]) -> str:
        nm = (name or env("GEMINI_MODEL", default="gemini-1.5-flash")).strip()
        return nm if nm.startswith("models/") else f"models/{nm}"

    def _dialect_quote(self, dialect: str) -> str:
        d = (dialect or "postgresql").lower()
        if d in ("postgresql","sqlite"):
            return 'Use double quotes for identifiers.'
        if d == "mysql":
            return 'Use backticks for identifiers.'
        if d in ("mssql","sqlserver"):
            return 'Use square brackets for identifiers.'
        return 'Use double quotes by default.'

    def list_models(self) -> Dict[str, Any]:
        items = []
        for m in self.client.models.list():
            methods = getattr(m, "supported_generation_methods", None) or getattr(m, "generation_methods", None)
            items.append({"name": m.name, "methods": methods})
        return {"status": "ok", "models": items}

    def _ensure_sql_json(self, text_payload: str) -> str:
        """
        Asegura que el modelo devolvió un JSON con al menos "sql_query".
        Si vino mezclado con texto, intenta extraer el primer objeto JSON.
        """
        def _try(s: str) -> Optional[str]:
            try:
                obj = json.loads(s)
                if isinstance(obj, dict) and "sql_query" in obj:
                    return json.dumps(obj, ensure_ascii=False)
            except Exception:
                return None
            return None

        # 1) intento directo
        ok = _try(text_payload.strip())
        if ok:
            return ok

        # 2) buscar primer bloque { ... } plausible
        m = re.search(r"\{.*\}", text_payload, re.DOTALL)
        if m:
            ok = _try(m.group(0))
            if ok:
                return ok

        raise RuntimeError(f"Gemini devolvió un formato inesperado: {text_payload[:300]}")

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

        system_prompt = f"""
You are a careful SQL generator for {dialect.upper()}.

Rules:
- Use ONLY tables/columns from the schema.
- {self._dialect_quote(dialect)}
- Add LIMIT {default_limit} if missing.
- Return a JSON with: "sql_query" and "original_query".

<schema_json>
{json.dumps(schema_compact, ensure_ascii=False)}
</schema_json>
""".strip()

        mdl = self._resolve_model(model)
        resp = self.client.models.generate_content(
            model=mdl,
            contents=[
                {"role": "system", "parts": [{"text": system_prompt}]},
                {"role": "user",   "parts": [{"text": human_query}]}
            ],
            config={"response_mime_type": "application/json"}
        )
        # resp.text debería ser JSON; validamos robustamente
        return self._ensure_sql_json(resp.text or "")

    async def build_answer(
        self,
        rows: List[Dict[str,Any]],
        human_query: str,
        model: Optional[str]=None
    ) -> str:
        prompt = f"""
Eres un analista. Resume en español la respuesta a la pregunta:

{human_query}

Basado en estas filas:
{json.dumps(rows, ensure_ascii=False)[:15000]}
""".strip()

        mdl = self._resolve_model(model)
        resp = self.client.models.generate_content(model=mdl, contents=prompt)
        return resp.text or ""

    async def ping(self, model: Optional[str]=None) -> str:
        mdl = self._resolve_model(model)
        resp = self.client.models.generate_content(model=mdl, contents="ping")
        return resp.text or ""