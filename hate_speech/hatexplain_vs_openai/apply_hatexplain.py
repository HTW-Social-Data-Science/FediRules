import argparse
import sys
from os.path import join
from pathlib import Path

import pandas as pd

sys.path.append(str(Path(__file__).resolve().parent.parent))

from config import BASE_DIR
from hate_speech.hs_helpers import MODEL_CONFIG, classify_texts, standardize_bert_model_results

MODEL_NAME = "Hate-speech-CNERG/bert-base-uncased-hatexplain"
MODEL_NAME_SHORT = MODEL_CONFIG[MODEL_NAME]["model_name_short"]
LABELS_MAP = MODEL_CONFIG[MODEL_NAME]["labels_map"]


def parse_arguments():
    parser = argparse.ArgumentParser(description="Classify texts using HateXplain model.")
    parser.add_argument("--source", "-s", type=str, help="Path to file with texts to be classified.")
    parser.add_argument("--col", "-c", type=str, default="content", help="Name of the text column.")
    parser.add_argument("--skip", type=int, default=0, help="Starting index for processing.")
    return parser.parse_args()


chunk_size = 1000

if __name__ == '__main__':
    args = parse_arguments()
    texts_file = args.source

    skip = range(1, args.skip + 1)
    chunk_offset = args.skip // chunk_size

    for local_i, chunk in enumerate(pd.read_csv(join(BASE_DIR, args.source), chunksize=chunk_size, skiprows=skip)):
        global_i = chunk_offset + local_i
        print(f"Processing chunk {global_i}, shape = {chunk.shape}")

        chunk.dropna(subset=[args.col], inplace=True)
        print(f"  - after dropping NAs: shape = {chunk.shape}")

        hate_xplain = classify_texts(chunk[args.col].tolist(), model_name=MODEL_NAME)
        hate_xplain = standardize_bert_model_results(hate_xplain, MODEL_NAME)
        results_chunk = pd.concat([chunk.reset_index(drop=True),
                                   hate_xplain.reset_index(drop=True)], axis=1)

        results_chunk.to_parquet(join("hatexplain_output", f"hatexplain_chunk_{global_i}.parquet"))
