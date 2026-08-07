import json
import os
import re
import csv
from urllib.parse import urlparse
from multiprocessing import Pool, cpu_count
import pandas as pd
import sys

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
from config import DATA_DIR

GRINBERG_PATH = os.path.join(
    DATA_DIR,
    "LazerLab-twitter-fake-news-replication-2c941b8",
    "domains", "domain_coding", "data",
    "website_alignment_scores.xlsx"
)
TIMELINE_DIR = os.path.join(DATA_DIR, "05-timeline_raw")
OUTPUT_PATH = os.path.join(DATA_DIR, "server_political_leaning.csv")

href_re = re.compile(r'href=["\']([^"\']+)["\']')


def load_grinberg():
    df = pd.read_excel(GRINBERG_PATH)
    return dict(zip(df["website"], df["align"]))


def extract_domain(url):
    try:
        netloc = urlparse(url).netloc.lower().split(":")[0]
        if netloc.startswith("www."):
            netloc = netloc[4:]
        return netloc if netloc else None
    except Exception:
        return None


def process_file(args):
    fpath, grinberg = args
    server = os.path.basename(fpath)[:-6]  # strip .jsonl

    scores = []
    n_posts = 0

    with open(fpath, "r", encoding="utf-8") as fh:
        for line in fh:
            try:
                toot = json.loads(line)
            except Exception:
                continue

            post_scores = []

            content = toot.get("content") or ""
            for url in href_re.findall(content):
                domain = extract_domain(url)
                if domain and domain in grinberg:
                    post_scores.append(grinberg[domain])

            card = toot.get("card")
            if card and card.get("url"):
                domain = extract_domain(card["url"])
                if domain and domain in grinberg:
                    post_scores.append(grinberg[domain])

            if post_scores:
                n_posts += 1
                scores.extend(post_scores)

    if not scores:
        return None

    return {
        "server": server,
        "lean": sum(scores) / len(scores),
        "n_matched_urls": len(scores),
        "n_posts_with_urls": n_posts,
    }


def main():
    grinberg = load_grinberg()
    print(f"Loaded {len(grinberg)} Grinberg domain ratings.")

    files = [
        os.path.join(TIMELINE_DIR, f)
        for f in os.listdir(TIMELINE_DIR)
        if f.endswith(".jsonl")
    ]
    print(f"Processing {len(files)} server files with {cpu_count()} workers.")

    args = [(f, grinberg) for f in files]
    results = []
    with Pool(cpu_count()) as pool:
        for i, result in enumerate(pool.imap_unordered(process_file, args, chunksize=10)):
            if result:
                results.append(result)
            if (i + 1) % 1000 == 0:
                print(f"  {i+1}/{len(files)} files processed, {len(results)} servers matched so far")

    results.sort(key=lambda x: x["server"])

    with open(OUTPUT_PATH, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=["server", "lean", "n_matched_urls", "n_posts_with_urls"])
        writer.writeheader()
        writer.writerows(results)

    print(f"\nDone. {len(results)} servers with political leaning scores.")
    print(f"Output: {OUTPUT_PATH}")


if __name__ == "__main__":
    main()
