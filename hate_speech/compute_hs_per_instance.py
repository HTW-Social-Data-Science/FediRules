from __future__ import annotations

import argparse
import sys
from os.path import join, isfile
from pathlib import Path

import pandas as pd

sys.path.append(str(Path(__file__).resolve().parent.parent))

from config import OPENAI_API_KEYS
from hs_helpers import parse_moderation_batch_output, map_batch_input_to_output

DESCRIPTION_ALL = "all posts"
DESCRIPTION_SAMPLE = 'toots moderation job'


def load_moderation_output(output_file_path):
    """Load moderation output from a JSONL file into a DataFrame."""
    df = parse_moderation_batch_output(batch_output_file=output_file_path)
    df["instance_id"] = df["custom_id"].map(lambda x: x.rsplit("_", 1)[0])  # custom_id is like "{instance}_{postid}"
    return df[["instance_id", "categories.hate", "category_scores.hate"]]


def parse_arguments():
    parser = argparse.ArgumentParser(description="Compute hate speech percentages per instance.")
    parser.add_argument(
        "--sample_only", "-s", type=int, choices=[0, 1],
        help="1 if using only the random sample for hs estimation, 0 for all posts."
    )
    return parser.parse_args()


if __name__ == '__main__':

    args = parse_arguments()
    use_sample_only = args.sample_only == 1
    print(f"Using sample only: {use_sample_only}")
    # Map batch input files to output files
    if use_sample_only:
        done_by_filename = map_batch_input_to_output(api_keys=OPENAI_API_KEYS, description=DESCRIPTION_SAMPLE,
                                                     ignore=["100.jsonl"])
    else:
        done_by_filename_sample = map_batch_input_to_output(api_keys=OPENAI_API_KEYS, description=DESCRIPTION_SAMPLE,
                                                            ignore=["100.jsonl"])
        done_by_filename_rest = map_batch_input_to_output(api_keys=OPENAI_API_KEYS, description=DESCRIPTION_ALL)

        done_by_filename = {**done_by_filename_rest, **done_by_filename_sample}

    hs_per_instance = []
    rows = []
    counter = 0
    for input_filename, batch_id in done_by_filename.items():
        output_file_path = join("openai_output", f"{batch_id}.jsonl")
        # test whether file exists
        if not isfile(output_file_path):
            print(f"File {output_file_path} for {input_filename} does not exist")
        df = load_moderation_output(output_file_path=output_file_path)
        rows.append(df)
        counter += 1
        print(f"Processed {counter} files")

    all_df = pd.concat(rows, ignore_index=True)

    hs_per_instance_df = (
        all_df
        .groupby(["instance_id", "categories.hate"])
        .size()
        .unstack(fill_value=0)
    )
    hs_per_instance_df = hs_per_instance_df.reindex(columns=[False, True], fill_value=0)
    hs_per_instance_df = hs_per_instance_df.reset_index()
    hs_per_instance_df["n"] = hs_per_instance_df[False] + hs_per_instance_df[True]
    hs_per_instance_df["hs_percent"] = hs_per_instance_df[True] / hs_per_instance_df["n"]

    if use_sample_only:
        out = "hs_per_instance_sample_only.csv"
    else:
        out = "hs_per_instance_all_toots.csv"
    hs_per_instance_df.to_csv(out, index=False)
