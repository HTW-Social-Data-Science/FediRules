import sys
from pathlib import Path

from openai import OpenAI

sys.path.append(str(Path(__file__).resolve().parent.parent))
from config import OPENAI_API_KEYS

if __name__ == '__main__':
    for key in OPENAI_API_KEYS:
        print(key)
        client = OpenAI(api_key=key)
        for b in client.batches.list(limit=100):
            desc = (b.metadata or {}).get("description")
            if desc == 'toots moderation job':
                print("here")
                print(b.id, b.status, b.metadata, b.input_file_id, client.files.retrieve(b.input_file_id).filename)
                print("errors:", b.errors)

        print("......")