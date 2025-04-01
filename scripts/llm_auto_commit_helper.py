import sys, requests, os

instruction = sys.argv[1]
summary = sys.argv[2]
api = os.environ[sys.argv[3]]

out = requests.post(
    "https://openrouter.ai/api/v1/chat/completions",
    headers={
        'Authorization': 'Bearer ' + api,
        'Content-Type': 'application/json',
        'HTTP-Referer': 'https://yehogwon.github.io',
        'X-Title': 'https://yehogwon.github.io',
    },
    json={
        # 'model': 'deepseek/deepseek-r1-distill-qwen-14b:free',
        # 'model': 'deepseek/deepseek-v3-base:free',
        'model': 'google/gemini-2.5-pro-exp-03-25:free',
        'messages': [
            {
                'role': 'user',
                'content': instruction
            },
            {
                'role': 'user',
                'content': f'Here is the information: {summary}'
            }
        ]
    },
)

print(out.json()['choices'][0]['message']['content'])
