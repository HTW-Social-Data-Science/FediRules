import pandas as pd
import os
from os.path import join
import sys
import glob
import json
sys.path.append(os.path.dirname(os.path.abspath('.')))
from config import DATA_DIR


timestamps = []

for filepath in glob.glob(join(DATA_DIR, '05-timeline_raw', '*.jsonl'), recursive=True):
    with open(filepath, 'r') as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            toot = json.loads(line)
            if 'created_at' in toot:
                timestamps.append(toot['created_at'])

timestamps = pd.to_datetime(timestamps, format='mixed', errors='coerce')
print(f"Total toots: {len(timestamps)}")