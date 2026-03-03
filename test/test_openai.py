# tests/test_openai.py
import os
from openai import OpenAI

key = os.environ.get("OPENAI_API_KEY")
print("OPENAI_API_KEY starts with:", (key[:6] + '...') if key else "(empty)")

client = OpenAI(api_key=key)

resp = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "ping"}],
    max_tokens=5
)

print("Respuesta:", resp.choices[0].message.content)