import os
from dotenv import load_dotenv
import json
load_dotenv()

BASE_DIR = os.path.dirname(__file__)
DATA_DIR = os.path.join(BASE_DIR, "data")
DEEPL_API_KEY = os.getenv("DEEPL_API_KEY")
OPENAI_API_KEYS = [
    k.strip()
    for k in os.getenv("OPENAI_API_KEYS", "").split(",")
    if k.strip()
]

OPENAI_API_TARGET_KEY = os.getenv("OPENAI_API_TARGET_KEY")
