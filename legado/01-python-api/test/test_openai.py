# test/test_openai.py
# -*- coding: utf-8 -*-
"""
Script de diagnóstico: verifica que la clave de OpenAI funciona y que el modelo
configurado responde.

Uso:
    python test/test_openai.py

Variables de entorno requeridas (definidas en .env):
    OPENAI_API_KEY
    OPENAI_MODEL  (opcional; default: gpt-4o)
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
    api_key = _leer_env("OPENAI_API_KEY")
    if not api_key:
        print("[ERROR] OPENAI_API_KEY no definida en .env")
        sys.exit(1)

    print(f"[INFO] OPENAI_API_KEY starts with: {api_key[:6]}...")

    try:
        from openai import OpenAI
    except ImportError:
        print("[ERROR] openai no instalado. Ejecuta: pip install openai")
        sys.exit(1)

    modelo = _leer_env("OPENAI_MODEL", default="gpt-4o")
    print(f"[INFO] Probando modelo: {modelo}")

    try:
        cliente = OpenAI(api_key=api_key)
        resp = cliente.chat.completions.create(
            model=modelo,
            messages=[{"role": "user", "content": "ping"}],
            max_tokens=5,
            temperature=0.0,
        )
        texto = (resp.choices[0].message.content or "").strip()
        print(f"[OK] {modelo} respondió: {texto}")
    except Exception as e:
        print(f"[ERROR] Falló la llamada a OpenAI: {e}")
        sys.exit(1)


if __name__ == "__main__":
    main()
