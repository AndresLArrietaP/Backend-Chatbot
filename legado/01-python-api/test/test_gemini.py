# test/test_gemini.py
# -*- coding: utf-8 -*-
"""
Script de diagnóstico: verifica que la clave de Gemini funciona y que al menos
un modelo de la cadena de candidatos responde.

Uso:
    python test/test_gemini.py

Variables de entorno requeridas (definidas en .env):
    GOOGLE_API_KEY
    GEMINI_MODEL_CANDIDATES  (opcional; default: gemini-2.5-flash)
"""

import os
import sys


def _leer_env(clave: str, default: str = "") -> str:
    val = os.environ.get(clave, "").strip()
    if val:
        return val
    try:
        from decouple import config
        return config(clave, default=default)
    except Exception:
        return default


def main() -> None:
    api_key = _leer_env("GOOGLE_API_KEY")
    if not api_key:
        print("[ERROR] GOOGLE_API_KEY no definida en .env")
        sys.exit(1)

    print(f"[INFO] GOOGLE_API_KEY starts with: {api_key[:6]}...")

    try:
        from google import genai
    except ImportError:
        print("[ERROR] google-genai no instalado. Ejecuta: pip install google-genai")
        sys.exit(1)

    # Usar genai.Client (API actual) — genai.configure está deprecado
    cliente = genai.Client(api_key=api_key)

    # Probar con la cadena de candidatos configurada en .env
    candidatos_raw = _leer_env("GEMINI_MODEL_CANDIDATES", default="gemini-2.5-flash")
    candidatos = [
        (m.strip() if m.strip().startswith("models/") else f"models/{m.strip()}")
        for m in candidatos_raw.split(",")
        if m.strip()
    ]

    for modelo in candidatos:
        print(f"[INFO] Probando modelo: {modelo}")
        try:
            resp = cliente.models.generate_content(
                model=modelo,
                contents=[{"role": "user", "parts": [{"text": "ping"}]}],
            )
            texto = (resp.text or "").strip()
            print(f"[OK] {modelo} respondió: {texto[:80]}")
            return
        except Exception as e:
            print(f"[WARN] {modelo} falló: {e}")

    print("[ERROR] Ningún modelo candidato respondió correctamente.")
    sys.exit(1)


if __name__ == "__main__":
    main()
