from typing import Protocol, List, Dict, Any, Optional
from decouple import config as env

# Interfaz que los providers deben implementar
class LLMProvider(Protocol):
    def list_models(self) -> Dict[str, Any]: ...
    async def ping(self, model: Optional[str] = None) -> str: ...
    async def human_query_to_sql(
        self,
        human_query: str,
        schema_json: Dict[str, Any],
        dialect: str = "postgresql",
        default_limit: int = 100,
        model: Optional[str] = None
    ) -> str: ...
    async def build_answer(
        self,
        rows: List[Dict[str, Any]],
        human_query: str,
        model: Optional[str] = None
    ) -> str: ...

def get_provider() -> LLMProvider:
    provider = env("LLM_PROVIDER", default="gemini").lower()
    if provider == "openai":
        from .openai_client import OpenAIProvider
        return OpenAIProvider()
    # por defecto gemini
    from .gemini_client import GeminiProvider
    return GeminiProvider()