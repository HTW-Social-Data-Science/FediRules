import os
from os.path import join

from openai import OpenAI

from config import OPENAI_API_KEYS
DESCRIPTION = "all posts"


batch_ids_completed = []
for api_key in OPENAI_API_KEYS:
    client = OpenAI(api_key=api_key)
    for b in client.batches.list(limit=100).data:
        print(b.id, b.status, b.metadata)
        print("errors:", b.errors)
        if b.error_file_id:
            err_text = client.files.content(b.error_file_id).text
            print("\n--- error file (first ~50 lines) ---")
            for i, line in enumerate(err_text.splitlines()[:50], 1):
                print(f"{i:02d} {line}")
        desc = (b.metadata or {}).get("description")
        if b.status == "completed" and desc == DESCRIPTION: # there is no better way to distinguish batch jobs
            out_text = client.files.content(b.output_file_id).text
            out_path = join("openai_moderations_outputs_all", f"{b.id}.jsonl")
            # pass if out_path exists
            if os.path.exists(out_path):
                print(f"Output file already exists, skipping download: {out_path}")
                batch_ids_completed.append(b.id)
                continue
            with open(out_path, "w", encoding="utf-8") as f:
                f.write(out_text)
            print(f"Downloaded output to: {out_path}")
            batch_ids_completed.append(b.id)

