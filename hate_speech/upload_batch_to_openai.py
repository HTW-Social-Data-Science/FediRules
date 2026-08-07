import sys
from pathlib import Path

from openai import OpenAI

from hate_speech.hs_helpers import map_batch_input_to_output

sys.path.append(str(Path(__file__).resolve().parent.parent))
from config import OPENAI_API_KEYS
from glob import glob

BATCH_FILES = glob("openai_input/*.jsonl")
MAX_NO_BATCHES = 6  # number of batches to submit per client
DESCRIPTION = "all posts"

def prepare_batch(batch_file_path, client, description="toots moderation job"):
    print(f"Preparing batch for file: {batch_file_path}")
    batch_input_file = client.files.create(file=open(batch_file_path, "rb"), purpose="batch")
    batch_input_file_id = batch_input_file.id
    print(batch_input_file_id)  # batch_id 100 refers to random sample for annotation evaluation
    batch = client.batches.create(
        input_file_id=batch_input_file_id,
        endpoint="/v1/moderations",
        completion_window="24h",
        metadata={
            "description": description
        }
    )
    return batch


if __name__ == '__main__':
    # if file with completed batch_ids exists, skip those
    done_by_filename = map_batch_input_to_output(api_keys=OPENAI_API_KEYS, description=DESCRIPTION)

    print("completed batches by filename (sample):")
    for fn, bid in list(done_by_filename.items()):
        print(fn, "->", bid)

    batch_files_to_process = [bf for bf in BATCH_FILES if Path(bf).name not in done_by_filename and "all_posts_" in bf]
    print(sorted(batch_files_to_process))

    client_counter = 0
    for api_key in OPENAI_API_KEYS:
        print("Using API key:", api_key)
        client = OpenAI(api_key=api_key)
        print(sorted(batch_files_to_process)[client_counter:client_counter + MAX_NO_BATCHES])
        try:
            for batch_file_path in sorted(batch_files_to_process)[client_counter:client_counter + MAX_NO_BATCHES]:
                batch = prepare_batch(batch_file_path=batch_file_path, client=client, description=DESCRIPTION)
                print("Batch ID:", batch.id)
                print("Status:", batch.status)
            client_counter += MAX_NO_BATCHES
        except Exception as e:
            print(e)

