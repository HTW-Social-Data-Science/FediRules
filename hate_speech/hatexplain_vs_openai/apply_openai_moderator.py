import argparse
import sys
from os.path import join
from pathlib import Path

import pandas as pd
from openai import OpenAI

sys.path.append(str(Path(__file__).resolve().parent.parent))
from config import OPENAI_API_KEYS, BASE_DIR
from hate_speech.hs_helpers import moderate_text, moderations_to_df

chunk_size = 1000


def parse_arguments():
    parser = argparse.ArgumentParser(description="TODO")
    parser.add_argument("--source", "-s", type=str, help="Path to file with texts to be classified.")
    parser.add_argument("--col", "-c", type=str, default="content", help="Name of the text column.")
    parser.add_argument("--skip", type=int, default=0, help="Starting index for processing.")
    return parser.parse_args()


if __name__ == '__main__':
    args = parse_arguments()
    client = OpenAI(api_key=OPENAI_API_KEYS[0])

    texts_file = args.source

    skip = range(1, args.skip + 1)
    chunk_offset = args.skip // chunk_size

    for local_i, chunk in enumerate(pd.read_csv(join(BASE_DIR, args.source), chunksize=chunk_size, skiprows=skip)):
        global_i = chunk_offset + local_i
        print(f"Processing chunk {global_i}, shape = {chunk.shape}")

        chunk.dropna(subset=[args.col], inplace=True)
        print(f"  - after dropping NAs: shape = {chunk.shape}")
        openai_moderator = []
        for text in chunk[args.col].tolist():
            res = moderate_text(text, client)
            # print(res)
            openai_moderator.append(res)

        out = chunk[["id", args.col]]
        moderations = moderations_to_df(openai_moderator)
        out = pd.concat([out.reset_index(drop=True), moderations.reset_index(drop=True)], axis=1)
        out.to_parquet(join("openai_moderator_output", f"openai_moderator_chunk_{global_i}.parquet"))
