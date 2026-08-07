import pandas as pd
import json
from os.path import join
from glob import glob
from config import DATA_DIR, BASE_DIR

if __name__ == '__main__':
    toots_dir = join(DATA_DIR, "toots")
    output_dir = join(BASE_DIR, "toots", "preprocessed")

    all_files = glob(join(toots_dir, "*.jsonl"))
    all_data = []
    for file in all_files:
        instance = file.split("/")[-1].split(".jsonl")[0]
        with open(file, "r", encoding="utf-8") as f:
            for line in f:
                obj = json.loads(line)
                # print(obj.keys())
                all_data.append({
                    "custom_id": f"{instance}_{obj.get('id', '')}",
                    "account": obj.get('account', '').get('acct', ''),
                })

    df = pd.DataFrame(all_data)
    df.to_parquet(join(output_dir, "toots_metadata.parquet"), index=False)
