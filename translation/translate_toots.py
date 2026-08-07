import logging
import os
import sys
from os.path import join

import pandas as pd
from tqdm import tqdm

from config import DATA_DIR

logging.basicConfig(
    filename='translate_all_toots_log.log',
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), '..')))
from helpers import translate, clean_df

PARQUET_PATH = join(DATA_DIR, "moderated_servers", "translated_toots_moderated_instances.parquet")
TARGET_DIR = join(DATA_DIR, "moderated_servers")
CSV_PATH = join(DATA_DIR, 'moderated_servers", "toots_moderated_instances.csv')
BATCH_SIZE = 60


def save_parquet_atomic(df, path):
    tmp = path + ".tmp"
    df.to_parquet(tmp, index=False)
    os.replace(tmp, path)


if __name__ == '__main__':
    if os.path.exists(PARQUET_PATH):
        print("Lade Parquet...")
        df = pd.read_parquet(PARQUET_PATH)
    else:
        print("Lade CSV...")
        df = pd.read_csv(CSV_PATH, low_memory=False)
        if "translated" not in df.columns:
            df["translated"] = 0
        before = len(df)
        df = clean_df(df, "content")
        after = len(df)
        logging.info(f"Cleaned dataframe: removed {before - after} rows with empty content.")
        df["content_translated_deepl"] = df["content"]

    mask = (df["language"] != "en") & (df["translated"] == 0)
    texts_to_translate = df.loc[mask, "content"]

    total = len(texts_to_translate)
    print(f"{pd.Timestamp.now()}: Translate {total} toots")
    logging.info(f"Translate {total} toots")

    results = []
    indices_list = []

    for idx, text in tqdm(zip(df.index[mask], texts_to_translate), total=total):
        try:
            translated = translate(text)
        except Exception as e:
            print(f"Error in line {idx}: {e}")
            logging.error(f"Error in line {idx}: {str(e)}")
            translated = text

        results.append(translated)
        indices_list.append(idx)

        if len(results) >= BATCH_SIZE:
            df.loc[indices_list, "content_translated_deepl"] = results
            df.loc[indices_list, "translated"] = 1

            save_parquet_atomic(df, PARQUET_PATH)

            results = []
            indices_list = []

    if results:
        df.loc[indices_list, "content_translated_deepl"] = results
        df.loc[indices_list, "translated"] = 1
        save_parquet_atomic(df, PARQUET_PATH)

    df.to_csv(os.path.join(TARGET_DIR, "translated_toots_moderated_instances.csv"), index=False)
    print(f"{pd.Timestamp.now()}: Finished.")
