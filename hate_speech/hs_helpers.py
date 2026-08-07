import json
from os.path import join
from typing import List, Dict

import pandas as pd
from openai import OpenAI
from transformers import AutoTokenizer, AutoModelForSequenceClassification, pipeline


def prepare_batch_input(df: pd.DataFrame, batch_no, text_col, id_col, target_dir="openai_input", prefix=None):
    if prefix is not None:
        target_file_path = join(target_dir, f"{prefix}_{batch_no}.jsonl")
    else:
        target_file_path = join(target_dir, f"{batch_no}.jsonl")
    with open(target_file_path, "w") as f:  # "w" is important to overwrite existing files
        for _, row in df.iterrows():
            id, text = row[id_col], row[text_col]
            record = {
                "custom_id": f"{id}",
                "method": "POST",
                "url": "/v1/moderations",
                "body": {
                    "model": "omni-moderation-latest",
                    "input": text
                }
            }
            f.write(json.dumps(record) + "\n")


def parse_moderation_batch_output(batch_output_file: str) -> pd.DataFrame:
    """Parse the output JSONL file from an OpenAI moderation batch job into a DataFrame."""

    rows = []
    with open(batch_output_file, "r", encoding="utf-8") as f:
        for line in f:
            obj = json.loads(line)

            custom_id = obj.get("custom_id")
            resp = obj.get("response", {}) or {}
            body = resp.get("body", {}) or {}
            results = body.get("results") or []

            r0 = results[0] if results else {}  # moderation result is usually first element

            # Flatten r0 (flagged + nested dicts)
            flat_r0 = pd.json_normalize(r0, sep=".").to_dict(orient="records")[0] if r0 else {}

            # Also keep some metadata from the wrapper
            rows.append({
                "custom_id": custom_id,
                "status_code": resp.get("status_code"),
                "request_id": resp.get("request_id"),
                "model": body.get("model"),
                **flat_r0,
            })

    return pd.DataFrame(rows)


def map_batch_input_to_output(api_keys, description, ignore=None):
    done_by_filename = {}
    for api_key in api_keys:
        client = OpenAI(api_key=api_key)
        for b in client.batches.list(limit=100):
            desc = (b.metadata or {}).get("description")
            if b.status != "completed" or desc != description:
                # print("skipping batch:", end=" ")
                # print(b.id, b.status, b.metadata, b.input_file_id)
                continue
            print("found completed batch:", end=" ")
            # print(b.id, b.status, b.metadata, b.input_file_id)
            try:
                f = client.files.retrieve(b.input_file_id)
                print(f.filename)
            except Exception as e:
                print("  - could not retrieve input file info:", e)
                continue
            # f.filename is the name of the uploaded file (jsonl filename)
            done_by_filename[f.filename] = b.id
    if ignore is not None:
        for fn in ignore:
            if fn in done_by_filename:
                del done_by_filename[fn]
    return done_by_filename


def parse_moderation_batch_input(batch_output_file: str) -> pd.DataFrame:
    """Parse the input JSONL file for OpenAI moderation batch job into a DataFrame."""

    rows = []
    with open(batch_output_file, "r", encoding="utf-8") as f:
        for line in f:
            obj = json.loads(line)
            body = obj.get("body", {}) or {}

            flat_r0 = pd.json_normalize(body, sep=".").to_dict(orient="records")[0] if body else {}
            rows.append({
                "custom_id": obj.get("custom_id"),
                **flat_r0,
            })

    return pd.DataFrame(rows)


MODEL_CONFIG = {"irlab-udc/MetaHateBERT":
    {
        "model_name_short": "MetaHateBERT",
        "output_structure": "target_class",
        "labels_map": {"LABEL_0": 0, "LABEL_1": 2}
    },
    "Hate-speech-CNERG/dehatebert-mono-english":
        {
            "model_name_short": "DehateBERT",
            "output_structure": "target_class",
            "labels_map": {"NON_HATE": 0, "HATE": 2}
        },
    "Hate-speech-CNERG/bert-base-uncased-hatexplain":
        {
            "model_name_short": "HateXplain",
            "output_structure": "target_class",
            "labels_map": {"normal": 0, "offensive": 1, "hate speech": 2}
        }
}


def build_classifier(model_name):
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    model = AutoModelForSequenceClassification.from_pretrained(model_name)
    classifier = pipeline("text-classification", model=model, tokenizer=tokenizer)
    return classifier


def classify_texts(texts, model_name, batch_size=16):
    classifier = build_classifier(model_name)
    return classifier(texts, truncation=True, padding=True, batch_size=batch_size)


def top_label_per_entry(data: List[Dict[str, float]]) -> [Dict[str, float]]:
    """
    For a list of {'label': str, 'score': float} dicts, return the dict
    with the highest score. Returns None if empty.
    """
    if not data:
        return {"label": None, "score": None}
    return max(data, key=lambda d: d.get("score", float("-inf")))


def standardize_bert_model_results(results, model_name):
    model_name_short = MODEL_CONFIG[model_name]["model_name_short"]
    output_structure = MODEL_CONFIG[model_name]["output_structure"]
    if output_structure == "target_class":
        results = [[r["label"], r["score"]] for r in results]
    elif output_structure == "all_classes":
        results = [[top_label_per_entry(r)] for r in results]
    results = pd.DataFrame(results, columns=[f"{model_name_short}_label", f"{model_name_short}_score"])
    results[f"{model_name_short}_label"] = results[f"{model_name_short}_label"].map(
        MODEL_CONFIG[model_name]["labels_map"])
    return results


def moderate_text(text: str, client: OpenAI) -> dict:
    """
    Returns JSON like:
    {
      "flagged": bool,
      "categories": { "<policy>": bool, ... },
      "category_scores": { "<policy>": float, ... }
    }
    """
    resp = client.moderations.create(
        model="omni-moderation-latest",
        input=text
    )
    r = resp.results[0]
    return {
        "flagged": bool(r.flagged),
        "categories": dict(r.categories),
        "category_scores": dict(r.category_scores),
    }


def moderations_to_df(moderations, text_ids=None):
    """
    Convert a list of moderation result dicts into a flat pandas DataFrame.

    Each element of `moderations` should look like:
    {
        'flagged': bool,
        'categories': {...},
        'category_scores': {...}
    }
    """
    rows = []

    for i, m in enumerate(moderations):
        # Convert OpenAI objects to plain dicts if needed
        if hasattr(m, "to_dict"):
            m = m.to_dict()

        row = {
            "flagged": m.get("flagged", None),
        }

        # Boolean categories
        for cat, val in m.get("categories", {}).items():
            row[f"cat_{cat}"] = val

        # Score categories
        for cat, val in m.get("category_scores", {}).items():
            row[f"score_{cat}"] = val

        # Optional: attach your own ID for the corresponding text
        if text_ids is not None:
            row["text_id"] = text_ids[i]

        rows.append(row)

    return pd.DataFrame(rows)
