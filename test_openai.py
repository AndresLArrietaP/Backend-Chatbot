from openai import OpenAI


client = OpenAI(api_key="key")
resp = client.chat.completions.create(
    model="gpt-4o",
    messages=[{"role": "user", "content": "ping"}],
    max_tokens=5
)

print(resp.choices[0].message.content)