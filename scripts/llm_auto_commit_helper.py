import sys, requests, os

message = sys.argv[1]
api = os.environ[sys.argv[2]]

out = requests.post(
    "https://openrouter.ai/api/v1/chat/completions",
    headers={
        'Authorization': 'Bearer ' + api,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://yehogwon.github.io',
        'X-Title': 'https://yehogwon.github.io',
    },
    json={
        'model': 'google/gemini-2.5-pro-exp-03-25:free',
        'messages': [
            {
                'role': 'user',
                'content': message
            }
        ]
    },
)

print(out.json()['choices'][0]['message']['content'])
