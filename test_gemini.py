import os
import google.generativeai as genai

key = (os.environ.get("GOOGLE_API_KEY") or "").strip()
print("GOOGLE_API_KEY starts with:", key[:6], "..." if key else "(empty)")

genai.configure(api_key=key)
m = genai.GenerativeModel("gemini-1.5-flash")
r = m.generate_content("ping")
print("OK:", (r.text or "")[:50])