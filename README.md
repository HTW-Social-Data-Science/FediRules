# Replication materials for FEDIRULES paper

This repository accompanies the paper
``FEDIRULES: Community Characteristics, Moderation Rules, and their Enforcement on the Fediverse''.
It contains code and selected intermediate outputs for all analyses described in the paper.

## Overview

The repository provides the code used for:

- Cleaning and preparation of input data, including server rules, blocking relationships, server metadata and a sample of server posts (toots)
- Large Language Model (LLM) prompting for hate speech and rule type classification
- Processing and aggregation of model outputs
- Statistical analysis and regression modeling

Due to privacy, licensing, and ethical constraints, no raw or processed data are included. As a result, the code cannot be executed end-to-end without access to 
the original datasets. However, all scripts and analysis notebooks include sufficient comments, documentation and intermediate outputs to allow reviewers to assess the methodological validity and analytical pipeline.

Results involving LLM APIs reflect the model versions available at the time of data collection.

## Repository Structure

```
.
├── logistic_regression/
│   │   Logistic regression analyses for results sections §R1, §R2, §D1
│   │   r1-characteristics_rule_adoption.R      – R1: instance characteristics predicting rule adoption
│   │   r1-characteristics_rule_adoption-subset.R – R1: instance characteristics predicting rule adoption for subset D_i
│   │   r2-rule_compliance.R                    – R2: rule compliance
│   │   r2-rule_compliance_hs.R                 – R2: compliance with hate speech rules
│   │   r2-rule_compliance_low_info.R           – R2: compliance with misinformation rules
│   │   d1-blocked_instances.R / d1-blocking_instances.R  – D1: blocking analyses
│   │   d1-blocked_instances-subset.R / d1-blocking_instances-subset.R – D1: blocking analyses on subset D_i
│   │
│   ├── results/
│   │   ├── r1/      – R1 results (DSL models, rule adoption)
│   │   ├── r2/      – R2 results (rule compliance)
│   │   ├── d1_blocked_instances/   – D1: blocked instances
│   │   └── d1_blocking_instances/  – D1: blocking instances
│   │
├── server_level_moderation/
│   │   Analysis of server-level moderation effectiveness and collateral damage (§P2)
│
├── community_modeling/
│   │   Topic modeling using BERTopic on instance toots
│
├── hate_speech/
│   │   Hate speech detection using OpenAI Moderation API and further experiments
│
├── preprocessing/
│   │   Scripts for preparing raw data
│   │   compute_political_leaning.py       – political leaning scores from news URLs
│   │   extract_metadata_from_toots.py     – extract toot metadata
│
├── rules/
│   │   Rule classification using GPT-5-mini (single-prompt and multi-prompt approaches)
│
└── translation/
    │   Translation of non-English server rules and toots
```

## Environment and Dependencies

Python dependencies are split into two files:

- `requirements.txt`: For CPU-based environments (e.g., macOS local machines)
- `requirements-gpu.txt`: For GPU-enabled environments (e.g., cloud VMs)

R scripts specify required packages at the top of each file.

Where applicable, random seeds are fixed in scripts; analyses involving external APIs are inherently non-deterministic.

## Data Documentation

The files described below are either included in this repository or were used as main data sources.
Files marked as **not included** were placed in the `data/` folder during analysis but are excluded
here due to privacy or ethical constraints.

#### `instance_level.parquet`

A dataset with information at the instance level. Each row corresponds to a single instance,
with metadata on users, software, moderation policies, content categories, and inter-instance relations.

---

### Community Modeling

#### `community_modeling/community_type_251219_reduced_merged.csv`

Reduced and merged community type labels derived from BERTopic clustering, used to assign
community discourse types to instances.

#### `toots_per_instance_sampled_75_percentile.csv` *(not included)*

Random toot sample per instance capped at the 75th percentile, used as documents for the BERTopic model.

---

### Rule Classification

#### `rules/final_rules_dataset_w_translations.parquet`

The joined rules for all servers including their translations.

#### `rules/rule_manual_annotation_cleaned.parquet`

Cleaned and simplified version of the manual annotations.

- Reduced to 24 categories used in the main analysis
- Rare or overlapping categories removed

#### `rules/annotated_rules/rule_manual_annotation_annotator_1.csv`

Sample of the joined rules of 500 servers for manual annotation.

#### `rules/annotated_rules/sample_annotated_rules_annotator_2.csv`

25% sample of the manually annotated rules, used for measuring inter-annotator agreement.

#### `rules/predictions_gpt/gpt_5_mini/predictions_for_linear_regression.parquet`

Final rule category predictions used in the logistic regression.

---

### Regression Data

The following files are the main input datasets for the logistic regression analyses.
They are not included in this repository due to privacy and ethical constraints.

#### `logistic_regression/regression_data.parquet` *(not included)*

Main instance-level dataset (D_oi in paper) used in §R1, §R2, and §D1 analyses.

#### `logistic_regression/regression_data_subset.parquet` *(not included)*

Subset of `regression_data.parquet` (D_i in paper) used in regression models.

---

### Blocking Relationships and Reasons

#### `server_level_moderation/blocking_relationships.parquet` *(not included)*

Instance-level moderation relationships (blocking pairs).

#### `server_level_moderation/annotated.csv` *(not included)*

Annotated blocking relationships used in the server-level moderation analysis.

#### `server_level_moderation/top_block_reason_manual_annotation.csv`

Manual annotations of the most frequent blocking reasons.

---

### Hate Speech Analysis

#### `hs_per_instance_all_toots.csv` *(not included)*

Predictions for hate speech prevalence generated by the OpenAI Moderation API, aggregated per instance.

---

### Misinformation Analysis

#### `13-toots_quality.parquet` *(not included)*

Average information quality from news links shared in toots.

---
