# from typing import Any, List, Dict, Optional, Set
# from decouple import config as env
# import json
# import re
# import time
# import asyncio
# from decimal import Decimal
# from datetime import date, datetime
# from google import genai
# from google.genai import errors as genai_errors
# from logging import getLogger

# log = getLogger(__name__)

# # ---------------- JSON-safe helpers ----------------
# def _to_json_safe(v: Any) -> Any:
#     if isinstance(v, Decimal):
#         return float(v)
#     if isinstance(v, (datetime, date)):
#         return v.isoformat()
#     if isinstance(v, list):
#         return [_to_json_safe(x) for x in v]
#     if isinstance(v, tuple):
#         return tuple(_to_json_safe(x) for x in v)
#     if isinstance(v, dict):
#         return {k: _to_json_safe(val) for k, val in v.items()}
#     return v

# def _compact_rows_for_summary(rows: List[Dict[str, Any]], max_chars: int = 8000) -> str:
#     if not rows:
#         return "[]"

#     def _normalize_row(r: Dict[str, Any]) -> Dict[str, Any]:
#         nr: Dict[str, Any] = {}
#         for k, v in (r or {}).items():
#             v2 = _to_json_safe(v)
#             if isinstance(v2, str) and len(v2) > 200:
#                 nr[k] = v2[:200] + "…"
#             else:
#                 nr[k] = v2
#         return nr

#     normalized = [_normalize_row(r) for r in rows]
#     s = json.dumps(normalized, ensure_ascii=False)
#     if len(s) <= max_chars:
#         return s

#     lo, hi = 0, len(normalized)
#     best = "[]"
#     while lo < hi:
#         mid = (lo + hi) // 2
#         s2 = json.dumps(normalized[:max(1, mid)], ensure_ascii=False)
#         if len(s2) <= max_chars:
#             best = s2
#             lo = mid + 1
#         else:
#             hi = mid
#     return best

# # ---------------- Provider ----------------
# class GeminiProvider:
#     def __init__(self) -> None:
#         api_key = (env("GOOGLE_API_KEY", default="") or "").strip()
#         if not api_key:
#             raise RuntimeError("Falta GOOGLE_API_KEY en .env")
#         self.client = genai.Client(api_key=api_key)

#         # Cache de modelos disponibles y con capacidad de generateContent
#         self._available_all: List[str] = []
#         self._available_generate: List[str] = []
#         self._models_with_generate: Set[str] = set()

#         try:
#             for m in self.client.models.list():
#                 name = getattr(m, "name", "") or ""
#                 methods = getattr(m, "supported_generation_methods", None) or getattr(m, "generation_methods", None) or []
#                 methods_low = {str(x).lower() for x in (methods or [])}
#                 self._available_all.append(name)
#                 if any(k in methods_low for k in ("generatecontent", "generate_content", "generate")):
#                     self._models_with_generate.add(name)
#                     self._available_generate.append(name)
#             log.info("[gemini] modelos disponibles (generateContent): %s", self._available_generate)
#         except Exception as e:
#             log.warning("No se pudo listar modelos de Gemini: %s", e)

#     # ---------------- helpers de modelos ----------------
#     def _resolve_model(self, name: Optional[str]) -> str:
#         nm = (name or env("GEMINI_MODEL", default="gemini-1.5-flash")).strip()
#         return nm if nm.startswith("models/") else f"models/{nm}"

#     def _resolve_answer_model(self, name: Optional[str]) -> str:
#         nm = (name or env("GEMINI_MODEL_ANSWER", default=env("GEMINI_MODEL", default="gemini-1.5-flash"))).strip()
#         return nm if nm.startswith("models/") else f"models/{nm}"

#     def _supports_generate_content(self, model_name: str) -> bool:
#         if not model_name:
#             return False
#         if model_name in self._models_with_generate:
#             return True
#         try:
#             m = self.client.models.get(name=model_name)
#             methods = getattr(m, "supported_generation_methods", None) or getattr(m, "generation_methods", None) or []
#             methods_low = {str(x).lower() for x in (methods or [])}
#             ok = any(k in methods_low for k in ("generatecontent", "generate_content", "generate"))
#             if ok:
#                 self._models_with_generate.add(model_name)
#             return ok
#         except Exception as e:
#             log.info("Modelo no soporta generateContent o no existe: %s (%s)", model_name, e)
#             return False

#     def _candidate_models_env(self, env_key: str, primary: Optional[str]) -> List[str]:
#         raw = env(env_key, default="")
#         env_list = [s.strip() for s in raw.split(",") if s.strip()]
#         base: List[str] = []
#         if primary:
#             base.append(primary if primary.startswith("models/") else f"models/{primary}")
#         for m in env_list:
#             mm = m if m.startswith("models/") else f"models/{m}"
#             if mm not in base:
#                 base.append(mm)
#         for m in ["models/gemini-flash-latest", "models/gemini-1.5-flash"]:
#             if m not in base:
#                 base.append(m)
#         return base

#     def _best_match(self, desired: str) -> Optional[str]:
#         avail = self._available_generate or []
#         if not avail:
#             return None
#         d = desired if desired.startswith("models/") else f"models/{desired}"
#         if d in avail:
#             return d
#         if d.endswith("-latest"):
#             base = d[:-len("-latest")]
#             candidates = [m for m in avail if m.startswith(base)]
#             if candidates:
#                 candidates.sort(reverse=True)
#                 return candidates[0]
#         candidates = [m for m in avail if m.startswith(d)]
#         if candidates:
#             candidates.sort(reverse=True)
#             return candidates[0]
#         key = "flash" if "flash" in d else ("pro" if "pro" in d else "")
#         if key:
#             candidates = [m for m in avail if key in m]
#             if candidates:
#                 def _score(name: str) -> tuple:
#                     return (
#                         2 if "2.0" in name else (1 if "1.5" in name else 0),
#                         1 if "latest" in name else (1 if re.search(r"-00\d", name) else 0),
#                         name
#                     )
#                 candidates.sort(key=_score, reverse=True)
#                 return candidates[0]
#         return avail[0]

#     def _resolve_candidate_list(self, raw_list: List[str]) -> List[str]:
#         out: List[str] = []
#         seen = set()
#         for cand in raw_list:
#             m = self._best_match(cand)
#             if not m:
#                 log.info("[gemini] Sin match para %s", cand)
#                 continue
#             if m not in seen:
#                 out.append(m)
#                 seen.add(m)
#                 log.info("[gemini] alias %s -> %s", cand, m)
#         return out

#     # ---------------- timeouts / hedging ----------------
#     def _timeouts(self) -> Dict[str, float]:
#         return {
#             "per_model_timeout": env("LLM_PER_MODEL_TIMEOUT", default=14.0, cast=float),
#             "total_timeout": env("LLM_TOTAL_TIMEOUT", default=18.0, cast=float),
#             "hedge_stagger": env("LLM_HEDGE_STAGGER", default=0.6, cast=float),
#             "hedge_parallel": env("LLM_HEDGE_PARALLEL", default=2, cast=int),
#         }

#     async def _call_generate(self, model: str, contents: Any, config: Dict[str, Any], per_model_timeout: float):
#         try:
#             resp = await asyncio.wait_for(
#                 asyncio.to_thread(self.client.models.generate_content, model=model, contents=contents, config=config),
#                 timeout=per_model_timeout
#             )
#             return resp
#         except Exception as e:
#             return e

#     def _is_retryable(self, e: Exception) -> bool:
#         msg = (getattr(e, "message", "") or str(e)).lower()
#         status = (getattr(e, "status", "") or "").upper()
#         code = getattr(e, "code", None)
#         if "unavailable" in msg or status == "UNAVAILABLE" or code == 503:
#             return True
#         if "rate" in msg or "quota" in msg or code == 429:
#             return True
#         return False

#     # ---------------- util: asegurar JSON con { "sql_query", "original_query" } -------------
#     def _ensure_sql_json(self, text_payload: str) -> str:
#         def _try(s: str) -> Optional[str]:
#             try:
#                 obj = json.loads(s)
#                 if isinstance(obj, dict) and "sql_query" in obj:
#                     if "original_query" not in obj:
#                         obj["original_query"] = ""
#                     return json.dumps(obj, ensure_ascii=False)
#             except Exception:
#                 return None
#             return None

#         payload = (text_payload or "").strip()
#         ok = _try(payload)
#         if ok:
#             return ok
#         m = re.search(r"\{.*\}", payload, re.DOTALL)
#         if m:
#             ok = _try(m.group(0))
#             if ok:
#                 return ok
#         raise RuntimeError(f"Gemini devolvió un formato inesperado: {payload[:300]}")
#     ensure_sql_json = _ensure_sql_json

#     # ---------------- LLM: NL -> SQL ----------------
#     async def human_query_to_sql(
#         self,
#         human_query: str,
#         schema_json: Dict[str, Any],
#         dialect: str = "postgresql",
#         default_limit: int = 100,
#         model: Optional[str] = None
#     ) -> str:
#         schema_compact = [
#             {
#                 "schema": t["schema"],
#                 "table": t["table"],
#                 "columns": [{"name": c["name"], "type": c.get("type", "")} for c in t["columns"]],
#                 "fq_name": t.get("fq_name"),
#             }
#             for t in schema_json.get("tables", [])
#         ]
#         fq_names = [t.get("fq_name") for t in schema_json.get("tables", []) if t.get("fq_name")]

#         system_prompt = fr"""
# You are a careful SQL generator for {dialect.upper()}.

# Rules:
# - Generate only READ-ONLY statements:
#   * Allowed: SELECT queries (including WITH/CTE), window functions, aggregates (SUM/COUNT/AVG...), scalar functions, and optionally EXPLAIN (without ANALYZE).
#   * Avoid any data-modifying or destructive statements: INSERT, UPDATE, DELETE, DROP, ALTER, TRUNCATE, CREATE, MERGE, VACUUM, COPY, GRANT, REVOKE, CALL.
# - Use ONLY tables/columns from the provided schema JSON (do not hallucinate).
# - {self._dialect_quote(dialect)}
# - If identifiers contain spaces or accents, quote them accordingly (e.g., "Fecha de Pedido").
# - Prefer fully-qualified names exactly as listed in <allowed_fqn> when referencing tables (e.g., public."Table").

# - Numeric cleaning MACRO (use EXACTLY this token; the server will expand it):
#   NUMERIC_CLEAN("Col")

# - Date parsing MACRO (use EXACTLY this token; the server will expand it):
#   DATE_PARSE("Col")  --> returns a DATE

# - EXCLUDE footer/total rows and null/blank keys when grouping by textual keys:
#   * WHERE COALESCE(TRIM("Key"), '') <> ''
#     AND "Key" !~* '^\s*total'
#     AND "Key" !~* '^\s*gran\s*total'
#     AND "Key" !~* '^\s*totales'

# - Include a meaningful ORDER BY when helpful.
# - Add LIMIT {default_limit} if the user didn't specify it.

# - Return a strict JSON object with keys: "sql_query" and "original_query". No extra keys.

# ### EXAMPLES

# User: "Dame el total despachado por cada cliente"
# SQL:
# {{
#   "sql_query": "SELECT COALESCE(TRIM(\"Cliente Nombre\"), '(Sin cliente)') AS \"Cliente\", SUM(NUMERIC_CLEAN(\"Despachado\")) AS \"Total Despachado\" FROM public.\"ConsumoMARC\" WHERE COALESCE(TRIM(\"Cliente Nombre\"), '') <> '' GROUP BY 1 ORDER BY 2 DESC LIMIT {default_limit}",
#   "original_query": "Dame el total despachado por cada cliente"
# }}

# User: "Top 10 materiales por total despachado"
# SQL:
# {{
#   "sql_query": "SELECT COALESCE(TRIM(\"Descripción Material\"), '(Sin material)') AS \"Material\", SUM(NUMERIC_CLEAN(\"Despachado\")) AS \"Total Despachado\" FROM public.\"ConsumoMARC\" WHERE COALESCE(TRIM(\"Descripción Material\"), '') <> '' GROUP BY 1 ORDER BY 2 DESC LIMIT 10",
#   "original_query": "Top 10 materiales por total despachado"
# }}

# User: "Total despachado por mes (parsing de fechas mixtas)"
# SQL:
# {{
#   "sql_query": "WITH b AS (SELECT DATE_PARSE(\"Fecha de Pedido\") AS fecha, NUMERIC_CLEAN(\"Despachado\") AS desp FROM public.\"ConsumoMARC\") SELECT to_char(date_trunc('month', fecha), 'YYYY-MM') AS \"Mes\", SUM(desp) AS \"Total Despachado\" FROM b WHERE fecha IS NOT NULL GROUP BY 1 ORDER BY 1 ASC LIMIT 120",
#   "original_query": "Total despachado por mes (parsing de fechas mixtas)"
# }}

# <schema_json>
# {json.dumps(schema_compact, ensure_ascii=False)}
# </schema_json>

# <allowed_fqn>
# {json.dumps(fq_names, ensure_ascii=False)}
# </allowed_fqn>
# """.strip()

#         mdl_primary = self._resolve_model(model)
#         raw_candidates = self._candidate_models_env("GEMINI_MODEL_CANDIDATES", mdl_primary)
#         mdl_candidates = self._resolve_candidate_list(raw_candidates)
#         if not mdl_candidates:
#             mdl_candidates = self._available_generate or ["models/gemini-flash-latest"]

#         tcfg = self._timeouts()
#         per_model_timeout = tcfg["per_model_timeout"]
#         total_timeout = tcfg["total_timeout"]
#         hedge_stagger = tcfg["hedge_stagger"]
#         hedge_parallel = max(1, tcfg["hedge_parallel"])

#         contents = [
#             {"role": "system", "parts": [{"text": system_prompt}]},
#             {"role": "user",   "parts": [{"text": human_query}]}
#         ]
#         config = {"response_mime_type": "application/json", "temperature": 0.1, "max_output_tokens": 900}

#         start = time.time()
#         tasks: List[asyncio.Task] = []
#         launched = 0
#         errors_log: List[str] = []

#         async def _launch(m: str):
#             res = await self._call_generate(m, contents, config, per_model_timeout)
#             return m, res

#         for i in range(min(hedge_parallel, len(mdl_candidates))):
#             tasks.append(asyncio.create_task(_launch(mdl_candidates[i])))
#             launched += 1

#         winner_text: Optional[str] = None

#         while (time.time() - start) < total_timeout and tasks:
#             remaining = max(0.1, total_timeout - (time.time() - start))
#             done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED, timeout=remaining)
#             if not done:
#                 if launched < len(mdl_candidates):
#                     await asyncio.sleep(hedge_stagger)
#                     tasks.append(asyncio.create_task(_launch(mdl_candidates[launched])))
#                     launched += 1
#                 else:
#                     break
#                 continue

#             for d in done:
#                 model_used, res = await d
#                 if isinstance(res, Exception):
#                     msg = f"{getattr(res, 'status', '')}/{getattr(res, 'code', '')} {getattr(res, 'message', '') or str(res)}"
#                     errors_log.append(f"{model_used}: {msg}")
#                     if self._is_retryable(res) and launched < len(mdl_candidates):
#                         await asyncio.sleep(hedge_stagger)
#                         tasks.append(asyncio.create_task(_launch(mdl_candidates[launched])))
#                         launched += 1
#                     continue

#                 for p in pending:
#                     p.cancel()
#                 text = (res.text or "").strip()
#                 if text:
#                     log.info("[gemini.human_query_to_sql] winner=%s (lat=%.2fs)", model_used, time.time()-start)
#                     winner_text = text
#                     tasks.clear()
#                     break
#                 else:
#                     errors_log.append(f"{model_used}: respuesta vacía")

#             tasks = [t for t in tasks if not t.done()]
#             if winner_text:
#                 break

#             if launched < len(mdl_candidates) and len(tasks) < hedge_parallel:
#                 await asyncio.sleep(hedge_stagger)
#                 tasks.append(asyncio.create_task(_launch(mdl_candidates[launched])))
#                 launched += 1

#         if not winner_text:
#             for m in mdl_candidates:
#                 try:
#                     res = await asyncio.wait_for(
#                         asyncio.to_thread(self.client.models.generate_content, model=m, contents=contents, config=config),
#                         timeout=per_model_timeout * 1.5
#                     )
#                     txt = (res.text or "").strip()
#                     if txt:
#                         log.info("[gemini.human_query_to_sql] winner(sequential)=%s", m)
#                         winner_text = txt
#                         break
#                     errors_log.append(f"{m}: respuesta vacía (secuencial)")
#                 except Exception as e:
#                     msg = f"{getattr(e,'status','')}/{getattr(e,'code','')} {getattr(e,'message','') or str(e)}"
#                     errors_log.append(f"{m}: {msg}")

#         if winner_text:
#             return self._ensure_sql_json(winner_text)

#         detail = "; ".join(errors_log) if errors_log else "sin errores reportados"
#         raise RuntimeError(f"Fallo human_query_to_sql: {detail}")

#     # ---------------- LLM: resumen (JSON -> texto limpio) ----------------
#     async def build_answer(
#         self,
#         rows: List[Dict[str, Any]],
#         human_query: str,
#         model: Optional[str] = None
#     ) -> str:
#         """
#         Pide al modelo un JSON estricto:
#           {
#             "summary": "2-3 frases en español",
#             "bullets": ["texto con cifra", "...", "..."]
#           }
#         y aquí lo rendereamos a un texto limpio (sin * ni Markdown).
#         """
#         rows_json = _compact_rows_for_summary(rows[:120], max_chars=2000)

#         schema = {
#             "type": "object",
#             "properties": {
#                 "summary": {"type": "string"},
#                 "bullets": {
#                     "type": "array",
#                     "items": {"type": "string"},
#                     "minItems": 0,
#                     "maxItems": 6
#                 }
#             },
#             "required": ["summary"],
#             "additionalProperties": False
#         }

#         prompt = (
#             "Eres un analista de datos. Con la pregunta y las filas (JSON) genera un RESUMEN CLARO.\n"
#             "Devuelve **EXCLUSIVAMENTE** un JSON válido con esta forma:\n"
#             '{ "summary": "máx 3 frases, español, sin Markdown", "bullets": ["cifra 1", "cifra 2", ...] }\n'
#             "Reglas:\n"
#             "- NO uses viñetas Markdown (*, -, •). Sólo texto plano en cada bullet.\n"
#             "- 2–4 cifras clave en 'bullets' si es pertinente; omite bullets si no hay datos.\n"
#             "- No inventes valores.\n\n"
#             f"Pregunta del usuario:\n{human_query}\n\n"
#             f"Filas (JSON, truncado):\n{rows_json}\n\n"
#             "Valida y ajusta para que el JSON cumpla el esquema dado."
#         ).strip()

#         primary = self._resolve_answer_model(model)
#         raw_candidates = self._candidate_models_env("GEMINI_MODEL_ANSWER_CANDIDATES", primary)
#         mdl_candidates = self._resolve_candidate_list(raw_candidates)
#         if not mdl_candidates:
#             mdl_candidates = self._available_generate or ["models/gemini-flash-latest"]

#         per_model_timeout = float(env("ANSWER_PER_MODEL_TIMEOUT", default=8.0))
#         total_timeout = float(env("ANSWER_TOTAL_TIMEOUT", default=10.0))
#         hedge_stagger = float(env("ANSWER_HEDGE_STAGGER", default=0.4))
#         hedge_parallel = int(env("ANSWER_HEDGE_PARALLEL", default=2))

#         start = time.time()
#         tasks: List[asyncio.Task] = []
#         launched = 0
#         errors_log: List[str] = []
#         json_text: Optional[str] = None

#         contents = [
#             {"role": "system", "parts": [{"text": json.dumps(schema, ensure_ascii=False)}]},
#             {"role": "user", "parts": [{"text": prompt}]}
#         ]
#         config = {"response_mime_type": "application/json", "temperature": 0.15, "max_output_tokens": 500}

#         async def _launch(m: str):
#             try:
#                 resp = await asyncio.wait_for(
#                     asyncio.to_thread(self.client.models.generate_content, model=m, contents=contents, config=config),
#                     timeout=per_model_timeout
#                 )
#                 return m, resp
#             except Exception as e:
#                 return m, e

#         for i in range(min(hedge_parallel, len(mdl_candidates))):
#             tasks.append(asyncio.create_task(_launch(mdl_candidates[i])))
#             launched += 1

#         while tasks and (time.time() - start) < total_timeout:
#             remaining = max(0.1, total_timeout - (time.time() - start))
#             done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED, timeout=remaining)
#             if not done:
#                 if launched < len(mdl_candidates):
#                     await asyncio.sleep(hedge_stagger)
#                     tasks.append(asyncio.create_task(_launch(mdl_candidates[launched])))
#                     launched += 1
#                 else:
#                     break
#                 continue

#             for d in done:
#                 model_used, res = await d
#                 if isinstance(res, Exception):
#                     msg = f"{getattr(res,'status','')}/{getattr(res,'code','')} {getattr(res,'message','') or str(res)}"
#                     errors_log.append(f"{model_used}: {msg}")
#                     continue
#                 for p in pending:
#                     p.cancel()
#                 txt = (res.text or "").strip()
#                 if txt:
#                     json_text = txt
#                     log.info("[gemini.build_answer] winner=%s (lat=%.2fs)", model_used, time.time()-start)
#                     break
#                 errors_log.append(f"{model_used}: respuesta vacía")

#             tasks = [t for t in tasks if not t.done()]
#             if json_text:
#                 break

#             if launched < len(mdl_candidates) and len(tasks) < hedge_parallel:
#                 await asyncio.sleep(hedge_stagger)
#                 tasks.append(asyncio.create_task(_launch(mdl_candidates[launched])))
#                 launched += 1

#         if not json_text:
#             # Intento secuencial final
#             for m in mdl_candidates:
#                 try:
#                     res = await asyncio.wait_for(
#                         asyncio.to_thread(self.client.models.generate_content, model=m, contents=contents, config=config),
#                         timeout=per_model_timeout * 1.5
#                     )
#                     txt = (res.text or "").strip()
#                     if txt:
#                         json_text = txt
#                         log.info("[gemini.build_answer] winner(sequential)=%s", m)
#                         break
#                     errors_log.append(f"{m}: respuesta vacía (secuencial)")
#                 except Exception as e:
#                     msg = f"{getattr(e,'status','')}/{getattr(e,'code','')} {getattr(e,'message','') or str(e)}"
#                     errors_log.append(f"{m}: {msg}")

#         if not json_text:
#             log.warning("[gemini.build_answer] sin texto tras hedging/fallbacks: %s",
#                         "; ".join(errors_log) if errors_log else "sin errores reportados")
#             return ""  # main.py mostrará warning

#         # ---- Parsear y renderizar limpio ----
#         def _safe_parse(s: str) -> Dict[str, Any]:
#             try:
#                 obj = json.loads(s)
#                 if not isinstance(obj, dict):
#                     return {}
#                 return obj
#             except Exception:
#                 # intenta extraer primer {...}
#                 m = re.search(r"\{.*\}", s, re.DOTALL)
#                 try:
#                     return json.loads(m.group(0)) if m else {}
#                 except Exception:
#                     return {}

#         obj = _safe_parse(json_text) or {}
#         summary = (obj.get("summary") or "").strip()
#         bullets = obj.get("bullets") or []

#         # Sanitizar
#         summary = re.sub(r"\s+", " ", summary)
#         clean_bullets: List[str] = []
#         for b in bullets:
#             if not isinstance(b, str):
#                 continue
#             t = b.strip()
#             # fuera símbolos/balas Markdown al inicio
#             t = re.sub(r"^(\*|-|•|\u2022)\s*", "", t)
#             t = re.sub(r"\s+", " ", t)
#             if t:
#                 clean_bullets.append(t)

#         # Render a texto final
#         parts: List[str] = []
#         if summary:
#             parts.append(summary if summary.endswith((".", "!", "?")) else summary + ".")
#         for t in clean_bullets[:4]:
#             parts.append(f"- {t}")
#         return "\n".join(parts)

#     # ---------------- ping ----------------
#     async def ping(self, model: Optional[str] = None) -> str:
#         mdl_primary = self._resolve_model(model)
#         raw_candidates = self._candidate_models_env("GEMINI_MODEL_CANDIDATES", mdl_primary)
#         mdl_candidates = self._resolve_candidate_list(raw_candidates) or ["models/gemini-flash-latest"]

#         last_txt = ""
#         for mdl in mdl_candidates:
#             try:
#                 resp = await asyncio.to_thread(
#                     self.client.models.generate_content,
#                     model=mdl,
#                     contents=[{"role": "user", "parts": [{"text": "ping"}]}],
#                 )
#                 txt = (resp.text or "").strip()
#                 if txt:
#                     return txt
#                 last_txt = txt
#             except Exception as e:
#                 log.warning("[gemini] ping falló con %s: %s", mdl, e)
#                 continue
#         return last_txt

#     # ---------------- aux ----------------
#     def _dialect_quote(self, dialect: str) -> str:
#         d = (dialect or "postgresql").lower()
#         if d in ("postgresql", "sqlite"):
#             return 'Use double quotes for identifiers.'
#         if d == "mysql":
#             return 'Use backticks for identifiers.'
#         if d in ("mssql", "sqlserver"):
#             return 'Use square brackets for identifiers.'
#         return 'Use double quotes by default.'

#     def list_models(self) -> Dict[str, Any]:
#         items = []
#         for m in self.client.models.list():
#             methods = getattr(m, "supported_generation_methods", None) or getattr(m, "generation_methods", None)
#             items.append({"name": m.name, "methods": methods})
#         return {"status": "ok", "models": items}

# src/providers/gemini_client.py
from typing import Any, List, Dict, Optional
from decouple import config as env
import json
import re
import time
import asyncio
from decimal import Decimal
from datetime import date, datetime
from google import genai
from logging import getLogger

log = getLogger(__name__)

# ---------------- JSON-safe helpers ----------------
def _to_json_safe(v: Any) -> Any:
    if isinstance(v, Decimal):
        return float(v)
    if isinstance(v, (datetime, date)):
        return v.isoformat()
    if isinstance(v, list):
        return [_to_json_safe(x) for x in v]
    if isinstance(v, tuple):
        return tuple(_to_json_safe(x) for x in v)
    if isinstance(v, dict):
        return {k: _to_json_safe(val) for k, val in v.items()}
    return v

def _compact_rows_for_summary(rows: List[Dict[str, Any]], max_rows: int, max_chars: int) -> str:
    """
    Recorta filas y longitud total (en caracteres) para limitar tokens y latencia.
    """
    if not rows:
        return "[]"

    def _norm_row(r: Dict[str, Any]) -> Dict[str, Any]:
        out: Dict[str, Any] = {}
        for k, v in (r or {}).items():
            v2 = _to_json_safe(v)
            if isinstance(v2, str) and len(v2) > 200:
                out[k] = v2[:200] + "…"
            else:
                out[k] = v2
        return out

    data = [_norm_row(r) for r in rows[:max_rows]]
    s = json.dumps(data, ensure_ascii=False)
    if len(s) <= max_chars:
        return s

    # recorta por binaria hasta encajar en max_chars
    lo, hi = 1, len(data)
    best = "[]"
    while lo <= hi:
        mid = (lo + hi) // 2
        s2 = json.dumps(data[:mid], ensure_ascii=False)
        if len(s2) <= max_chars:
            best = s2
            lo = mid + 1
        else:
            hi = mid - 1
    return best

# ---------------- Provider ----------------
class GeminiProvider:
    def __init__(self) -> None:
        api_key = (env("GOOGLE_API_KEY", default="") or "").strip()
        if not api_key:
            raise RuntimeError("Falta GOOGLE_API_KEY en .env")
        self.client = genai.Client(api_key=api_key)

        # Cache simple de modelos con generate_content
        self._available_generate: List[str] = []
        try:
            for m in self.client.models.list():
                methods = getattr(m, "supported_generation_methods", None) or getattr(m, "generation_methods", None) or []
                ml = {str(x).lower() for x in (methods or [])}
                if any(k in ml for k in ("generatecontent", "generate_content", "generate")):
                    self._available_generate.append(m.name)
            log.info("[gemini] modelos generateContent: %s", self._available_generate)
        except Exception as e:
            log.warning("No se pudo listar modelos de Gemini: %s", e)

    # --------- helpers de modelos ----------
    def _resolve_model(self, name: Optional[str]) -> str:
        nm = (name or env("GEMINI_MODEL", default="gemini-1.5-flash")).strip()
        return nm if nm.startswith("models/") else f"models/{nm}"

    def _resolve_answer_model(self, name: Optional[str]) -> str:
        nm = (name or env("GEMINI_MODEL_ANSWER", default=env("GEMINI_MODEL", default="gemini-1.5-flash"))).strip()
        return nm if nm.startswith("models/") else f"models/{nm}"

    def _candidate_models_env(self, key: str, primary: Optional[str]) -> List[str]:
        raw = env(key, default="")
        env_list = [s.strip() for s in raw.split(",") if s.strip()]
        base: List[str] = []
        if primary:
            base.append(primary if primary.startswith("models/") else f"models/{primary}")
        for m in env_list:
            mm = m if m.startswith("models/") else f"models/{m}"
            if mm not in base:
                base.append(mm)
        # fallbacks razonables
        for m in ["models/gemini-2.0-flash", "models/gemini-flash-latest", "models/gemini-1.5-pro", "models/gemini-1.5-flash"]:
            if m not in base:
                base.append(m)
        return base

    def _best_match(self, desired: str) -> Optional[str]:
        avail = self._available_generate or []
        if not avail:
            return None
        d = desired if desired.startswith("models/") else f"models/{desired}"
        if d in avail:
            return d
        # prefijo
        cands = [m for m in avail if m.startswith(d)]
        if cands:
            cands.sort(reverse=True)
            return cands[0]
        # por palabra clave
        key = "flash" if "flash" in d else ("pro" if "pro" in d else "")
        if key:
            cands = [m for m in avail if key in m]
            if cands:
                cands.sort(reverse=True)
                return cands[0]
        return avail[0]

    def _resolve_candidate_list(self, raw_list: List[str]) -> List[str]:
        out, seen = [], set()
        for c in raw_list:
            m = self._best_match(c)
            if m and m not in seen:
                out.append(m); seen.add(m)
        return out

    def _timeouts(self) -> Dict[str, float]:
        return {
            "per_model_timeout": env("LLM_PER_MODEL_TIMEOUT", default=14.0, cast=float),
            "total_timeout": env("LLM_TOTAL_TIMEOUT", default=18.0, cast=float),
            "hedge_stagger": env("LLM_HEDGE_STAGGER", default=0.6, cast=float),
            "hedge_parallel": env("LLM_HEDGE_PARALLEL", default=2, cast=int),
        }

    async def _call_generate(self, model: str, contents: Any, config: Dict[str, Any], per_model_timeout: float):
        try:
            resp = await asyncio.wait_for(
                asyncio.to_thread(self.client.models.generate_content, model=model, contents=contents, config=config),
                timeout=per_model_timeout
            )
            return resp
        except Exception as e:
            return e

    # ---------- Ensure JSON {"sql_query","original_query"} ----------
    def _ensure_sql_json(self, payload: str) -> str:
        def _try(s: str) -> Optional[str]:
            try:
                obj = json.loads(s)
                if isinstance(obj, dict) and "sql_query" in obj:
                    obj.setdefault("original_query", "")
                    return json.dumps(obj, ensure_ascii=False)
            except Exception:
                return None
        t = (payload or "").strip()
        ok = _try(t)
        if ok: return ok
        m = re.search(r"\{.*\}", t, re.DOTALL)
        if m:
            ok = _try(m.group(0))
            if ok: return ok
        raise RuntimeError(f"Gemini devolvió un formato inesperado: {t[:300]}")

    # ---------------- NL -> SQL ----------------
    async def human_query_to_sql(
        self,
        human_query: str,
        schema_json: Dict[str, Any],
        dialect: str = "postgresql",
        default_limit: int = 100,
        model: Optional[str] = None
    ) -> str:

        # Compact schema para bajar tokens
        schema_compact = [
            {
                "schema": t["schema"],
                "table": t["table"],
                "columns": [{"name": c["name"], "type": c.get("type", "")} for c in t["columns"]],
                "fq_name": t.get("fq_name"),
            }
            for t in schema_json.get("tables", [])
        ]
        fq_names = [t.get("fq_name") for t in schema_json.get("tables", []) if t.get("fq_name")]

        system_prompt = fr"""
You are a careful SQL generator for {dialect.upper()}.

Rules:
- Only READ-ONLY statements (SELECT/CTE/EXPLAIN without ANALYZE). No INSERT/UPDATE/DELETE/DDL/CALL.
- Use only tables/columns from the provided schema. Do not hallucinate.
- {self._dialect_quote(dialect)}
- Quote identifiers with spaces/accents (e.g., "Fecha de Pedido").
- Prefer fully-qualified names as in <allowed_fqn>.
- Use macros (server expands): NUMERIC_CLEAN("Col"), DATE_PARSE("Col").
- Exclude totals/footer rows and blank keys when grouping:
  WHERE COALESCE(TRIM("Key"), '') <> ''
    AND "Key" !~* '^\s*total'
    AND "Key" !~* '^\s*gran\s*total'
    AND "Key" !~* '^\s*totales'
- Add LIMIT {default_limit} if missing.

Return ONLY:
{{
  "sql_query": "...",
  "original_query": "{human_query}"
}}

<schema_json>
{json.dumps(schema_compact, ensure_ascii=False)}
</schema_json>
<allowed_fqn>
{json.dumps(fq_names, ensure_ascii=False)}
</allowed_fqn>
""".strip()

        mdl_primary = self._resolve_model(model)
        raw_candidates = self._candidate_models_env("GEMINI_MODEL_CANDIDATES", mdl_primary)
        models = self._resolve_candidate_list(raw_candidates) or ["models/gemini-flash-latest"]

        tcfg = self._timeouts()
        per_model_timeout = tcfg["per_model_timeout"]
        total_timeout = tcfg["total_timeout"]
        hedge_stagger = tcfg["hedge_stagger"]
        hedge_parallel = max(1, tcfg["hedge_parallel"])

        contents = [
            {"role": "system", "parts": [{"text": system_prompt}]},
            {"role": "user",   "parts": [{"text": human_query}]}
        ]
        config = {"response_mime_type": "application/json", "temperature": 0.1, "max_output_tokens": 900}

        start = time.time()
        tasks: List[asyncio.Task] = []
        launched = 0
        errors: List[str] = []
        winner: Optional[str] = None

        async def _launch(m: str):
            res = await self._call_generate(m, contents, config, per_model_timeout)
            return m, res

        # lanzar N en paralelo controlado
        for i in range(min(hedge_parallel, len(models))):
            tasks.append(asyncio.create_task(_launch(models[i])))
            launched += 1

        while (time.time() - start) < total_timeout and tasks:
            remaining = max(0.1, total_timeout - (time.time() - start))
            done, pending = await asyncio.wait(tasks, return_when=asyncio.FIRST_COMPLETED, timeout=remaining)
            if not done:
                if launched < len(models):
                    await asyncio.sleep(hedge_stagger)
                    tasks.append(asyncio.create_task(_launch(models[launched])))
                    launched += 1
                else:
                    break
                continue

            for d in done:
                mdl, res = await d
                if isinstance(res, Exception):
                    errors.append(f"{mdl}: {getattr(res,'message','') or str(res)}")
                    continue
                for p in pending:
                    p.cancel()
                txt = (res.text or "").strip()
                if txt:
                    log.info("[gemini.human_query_to_sql] winner=%s (lat=%.2fs)", mdl, time.time()-start)
                    winner = txt; tasks.clear(); break
                errors.append(f"{mdl}: respuesta vacía")
            tasks = [t for t in tasks if not t.done()]
            if winner: break
            if launched < len(models) and len(tasks) < hedge_parallel:
                await asyncio.sleep(hedge_stagger)
                tasks.append(asyncio.create_task(_launch(models[launched])))
                launched += 1

        if not winner:
            # secuencial extendido
            for mdl in models:
                try:
                    res = await asyncio.wait_for(
                        asyncio.to_thread(self.client.models.generate_content, model=mdl, contents=contents, config=config),
                        timeout=per_model_timeout * 1.5
                    )
                    txt = (res.text or "").strip()
                    if txt:
                        log.info("[gemini.human_query_to_sql] winner(sequential)=%s", mdl)
                        winner = txt; break
                except Exception as e:
                    errors.append(f"{mdl}: {str(e)}")

        if winner:
            return self._ensure_sql_json(winner)

        raise RuntimeError("Fallo human_query_to_sql: " + "; ".join(errors[-6:]))

    # ---------------- Resumen (modo calidad con JSON estricto + auto-fix) ----------------
    async def build_answer(
        self,
        rows: List[Dict[str, Any]],
        human_query: str,
        model: Optional[str] = None
    ) -> str:
        """
        Pide JSON estricto:
          { "summary": "2-3 frases", "bullets": ["...", "..."] }
        con mayor tiempo por modelo (calidad) y auto-reparación si es inválido.
        Devuelve texto limpio (sin Markdown); si falla, retorna "" (main.py hará fallback).
        """
        max_rows  = int(env("ANSWER_MAX_ROWS",  default=140))
        max_chars = int(env("ANSWER_MAX_CHARS", default=2600))
        rows_json = _compact_rows_for_summary(rows, max_rows=max_rows, max_chars=max_chars)

        schema = {
            "type": "object",
            "properties": {
                "summary": {"type": "string"},
                "bullets": {"type": "array", "items": {"type": "string"}, "minItems": 0, "maxItems": 6}
            },
            "required": ["summary"],
            "additionalProperties": False
        }

        prompt = (
            "Eres un analista senior de datos. Devuelve un resumen claro en español.\n"
            "Responde EXCLUSIVAMENTE un JSON válido:\n"
            '{ "summary": "hasta 3 frases, sin Markdown", "bullets": ["cifra 1", "cifra 2", ...] }\n'
            "Reglas:\n"
            "- Usa solo lo que está en las filas; no inventes.\n"
            "- En 'bullets' usa texto plano (sin *, -, •).\n"
            "- Si hay muy pocos datos, indícalo.\n\n"
            f"Pregunta:\n{human_query}\n\n"
            f"Filas (JSON truncado):\n{rows_json}\n"
        ).strip()

        primary = self._resolve_answer_model(model)
        raw_cands = self._candidate_models_env("GEMINI_MODEL_ANSWER_CANDIDATES", primary)
        models = self._resolve_candidate_list(raw_cands) or ["models/gemini-flash-latest"]

        # Modo calidad: más tiempo, secuencial
        per_model_timeout = float(env("ANSWER_PER_MODEL_TIMEOUT", default=16.0))
        total_timeout     = float(env("ANSWER_TOTAL_TIMEOUT", default=28.0))
        hedge_parallel    = int(env("ANSWER_HEDGE_PARALLEL", default=1))
        hedge_stagger     = float(env("ANSWER_HEDGE_STAGGER", default=0.5))

        start = time.time()
        got_json: Optional[str] = None
        errors: List[str] = []

        def _first_json(s: str) -> Optional[str]:
            s = (s or "").strip()
            try:
                obj = json.loads(s)
                if isinstance(obj, dict):
                    return json.dumps(obj, ensure_ascii=False)
            except Exception:
                pass
            m = re.search(r"\{.*\}", s, re.DOTALL)
            if not m: return None
            try:
                obj = json.loads(m.group(0))
                if isinstance(obj, dict):
                    return json.dumps(obj, ensure_ascii=False)
            except Exception:
                return None
            return None

        def _render(obj: Dict[str, Any]) -> str:
            summary = re.sub(r"\s+", " ", (obj.get("summary") or "").strip())
            bullets = obj.get("bullets") or []
            parts = []
            if summary:
                parts.append(summary if summary.endswith(('.', '!', '?')) else summary + ".")
            clean = []
            for b in bullets[:4]:
                if isinstance(b, str):
                    t = re.sub(r"^(\*|-|•|\u2022)\s*", "", b.strip())
                    t = re.sub(r"\s+", " ", t)
                    if t: clean.append(t)
            for t in clean:
                parts.append(f"- {t}")
            return "\n".join(parts)

        async def _invoke(mdl: str, contents, config, timeout_s: float):
            try:
                resp = await asyncio.wait_for(
                    asyncio.to_thread(self.client.models.generate_content, model=mdl, contents=contents, config=config),
                    timeout=timeout_s
                )
                return resp.text or ""
            except Exception as e:
                return e

        base_contents = [
            {"role": "system", "parts": [{"text": json.dumps(schema, ensure_ascii=False)}]},
            {"role": "user", "parts": [{"text": prompt}]}
        ]
        base_config = {"response_mime_type": "application/json", "temperature": 0.12, "max_output_tokens": 700}

        idx = 0
        while (time.time() - start) < total_timeout and idx < len(models):
            mdl = models[idx]; idx += 1
            for attempt in range(2):
                rem = total_timeout - (time.time() - start)
                if rem <= 0.2: break
                timeout_this = min(per_model_timeout * (1.0 + 0.25 * attempt), rem)

                txt = await _invoke(mdl, base_contents, base_config, timeout_this)
                if isinstance(txt, Exception):
                    errors.append(f"{mdl}: {str(txt)}"); await asyncio.sleep(0.25*(attempt+1)); continue

                js = _first_json(txt)
                if js:
                    got_json = js
                    log.info("[gemini.build_answer] winner=%s attempt=%d lat=%.2fs", mdl, attempt+1, time.time()-start)
                    break

                # auto-fix
                fix_prompt = ("Corrige el siguiente contenido a un JSON VÁLIDO con 'summary' y 'bullets' únicamente:\n"
                              f"{(txt or '')[:4000]}")
                fix_contents = [
                    {"role": "system", "parts": [{"text": json.dumps(schema, ensure_ascii=False)}]},
                    {"role": "user", "parts": [{"text": fix_prompt}]}
                ]
                fix_txt = await _invoke(mdl, fix_contents, base_config, min(6.0, rem))
                if not isinstance(fix_txt, Exception):
                    js2 = _first_json(fix_txt)
                    if js2:
                        got_json = js2
                        log.info("[gemini.build_answer] winner(fix)=%s lat=%.2fs", mdl, time.time()-start)
                        break

                errors.append(f"{mdl}: sin JSON válido (attempt {attempt+1})")
                await asyncio.sleep(hedge_stagger)

            if got_json: break

        if not got_json:
            log.warning("[gemini.build_answer] sin JSON: %s", "; ".join(errors[-6:]))
            return ""  # main.py hará fallback

        try:
            obj = json.loads(got_json)
            if not isinstance(obj, dict):
                raise ValueError("non-dict")
            return _render(obj)[:1200]
        except Exception:
            log.warning("[gemini.build_answer] parse final falló; entrego texto plano")
            return (got_json or "")[:1200]

    # ---------------- ping ----------------
    async def ping(self, model: Optional[str] = None) -> str:
        mdl_primary = self._resolve_model(model)
        models = self._resolve_candidate_list(self._candidate_models_env("GEMINI_MODEL_CANDIDATES", mdl_primary)) or ["models/gemini-flash-latest"]
        last = ""
        for m in models:
            try:
                resp = await asyncio.to_thread(self.client.models.generate_content, model=m, contents=[{"role":"user","parts":[{"text":"ping"}]}])
                t = (resp.text or "").strip()
                if t: return t
                last = t
            except Exception as e:
                log.warning("[gemini] ping falló con %s: %s", m, e)
                continue
        return last

    # ---------------- aux ----------------
    def _dialect_quote(self, dialect: str) -> str:
        d = (dialect or "postgresql").lower()
        if d in ("postgresql", "sqlite"): return 'Use double quotes for identifiers.'
        if d == "mysql": return 'Use backticks for identifiers.'
        if d in ("mssql", "sqlserver"): return 'Use square brackets for identifiers.'
        return 'Use double quotes by default.'

    def list_models(self) -> Dict[str, Any]:
        items = []
        for m in self.client.models.list():
            methods = getattr(m, "supported_generation_methods", None) or getattr(m, "generation_methods", None)
            items.append({"name": m.name, "methods": methods})
        return {"status": "ok", "models": items}