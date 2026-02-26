# KIC Spheroid Calcium Pipeline (Script 02b/03)

This repository contains an R script for merging **batch-level `merged.csv` datasets** generated in **Script 02a** of the KIC Spheroid Calcium pipeline.

This script represents the second step (**02b/03**) of a modular **KIC Spheroid Calcium analysis pipeline**.

The pipeline consolidates multiple single-batch datasets into a unified **multi-batch dataset**, harmonizes metadata across experiments, and exports a standardized file ready for statistical analysis and visualization.

---

## What the pipeline does

Starting from the **batch-level `merged.csv` files** generated in Script 02a, the script:

- Recursively scans an input folder for `merged.csv` files  
- Reads and merges all batch-level datasets into a unified multi-batch dataset  
- Harmonizes columns across batches (automatic NA fill for missing columns)  
- Preserves all logical flags generated in Script 02a:
  - `keep_1hz`  
  - `valid_well`  
- Retains assigned experimental metadata:
  - `Group`  
  - Optional `RowGroup`  
  - `Batch`  
- Performs integrity checks:
  - Reports missing metadata columns  
  - Detects potential duplicate well identifiers across batches  
- Generates a per-batch merge report (rows read, rows retained)  
- Exports a standardized `merged_multibatch.csv` file  

All file paths are selected interactively via GUI dialogs (`tcltk`).

---

## Required inputs

### Step 02a output

- One or multiple `merged.csv` files  
- Each file must originate from **Script 02a**  
- Nested folder structures are supported (recursive search enabled)

Required columns (generated in Script 02a):

- `Well`  
- `Batch`  
- `Group`  
- `Num.Peaks`  

Optional but recommended:

- `RowGroup`  
- `keep_1hz`  
- `valid_well`  

---

## Cleaned merged output

The script generates:

- `merged_multibatch.csv`  
- `file_merge_report.csv`  

### `merged_multibatch.csv` contains:

- All standardized MEANS summary statistics  
- Preserved filtering flags  
- Assigned `Group`  
- Optional `RowGroup`  
- `Batch` identifiers  
- Source tracking metadata  

The dataset is fully standardized and ready for:

- Statistical modeling  
- Cross-group comparisons  
- Timepoint aggregation  
- Multi-batch integration analysis  
- Downstream visualization (**Script 03**)  

---

## Typical use cases

- Integration of multiple independent calcium imaging experiments  
- Cross-batch reproducibility assessment  
- Multi-experiment dataset consolidation  
- Preparation for statistical comparison across biological replicates  
- Standardized preprocessing before visualization and modeling  

---

## Position in the KIC Pipeline

This script is **Script 02b** of a structured workflow:

- Script 01 – Raw CyteSeer CSV processing and MEANS summary generation  
- Script 02a – Single-batch MEANS merging and filtering  
- **Script 02b (this repository)** – Cross-batch merging  
- Script 03 – Statistical analysis and visualization  

---

## Methods Description

Batch-level MEANS datasets generated from CyteSeer calcium transient measurements were merged using a custom R-based GUI pipeline. Metadata harmonization was performed to ensure structural consistency across experiments, and filtering flags generated in single-batch preprocessing were preserved. The resulting multi-batch standardized dataset was exported for downstream statistical analysis and visualization.

---

## Authorship

This script was developed by **Michele Buono, Talitha Spanjersberg, Nikki Scheen, Nina van der Wilt** and can be used freely for research purposes, provided appropriate citation of the authors.

The overall workflow, structure, and clarity of the pipeline were iteratively refined with assistance from **OpenAI – ChatGPT 5.2**, which was used as a tool to improve code organization, documentation, and usability.
