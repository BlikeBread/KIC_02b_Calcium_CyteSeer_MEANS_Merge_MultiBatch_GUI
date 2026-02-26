###############################################################################
# KIC CALCIUM ANALYSIS PIPELINE — STEP 2b
# -----------------------------------------------------------------------------
#
# PURPOSE:
#   Interactive GUI tool to merge multiple batch-level merged.csv files
#   generated in Step 2a into a unified multi-batch dataset.
#
#   The script:
#     1. Prompts the user to select input/output folders (tk_choose.dir)
#     2. Recursively scans the input directory for batch-level merged.csv files
#        generated in Step 2a
#     3. Reads and merges all batch-level datasets into a single
#        multi-batch dataset
#     4. Harmonizes columns across batches (rbindlist with fill=TRUE logic)
#     5. Appends provenance metadata for traceability
#        (batch_id, source_file, source_path)
#     6. Preserves all flags and metadata generated in Step 2a
#     7. Performs no additional filtering or modification of the data
#     8. Exports a standardized raw multi-batch dataset ready for downstream
#        statistical analysis (Step 3)
#
# OUTPUT:
#   An output folder containing:
#     merged_raw.csv    (final merged dataset across all batches; unfiltered)
#
# NOTES:
#   - Uses tcltk (tk_choose.dir) for macOS folder pickers.
#   - Designed for interactive use (GUI folder selection + automated exports).
#   - Intended as Step 2b of a 3-step KIC calcium processing pipeline.
#   - Expects as input ONLY the merged.csv files produced by Step 2a.
#   - This step performs merging only (no QC filtering).
#
# AUTHORS:
#   Michele Buono
#   Talitha Spanjersberg
#   Nikki Scheen
#   Nina van der Wilt
#   Regenerative Medicine Center Utrecht (2026)
###############################################################################

suppressPackageStartupMessages({
  library(data.table)  # fread, rbindlist, fwrite
})

# ---- GUI folder selection (tcltk) --------------------------------------------
if (!requireNamespace("tcltk", quietly = TRUE)) {
  stop("Package 'tcltk' not available. On macOS install XQuartz, then restart R.")
}

in_dir <- tcltk::tk_choose.dir(caption = "Select INPUT folder (contains CSVs or subfolders)")
if (is.na(in_dir) || !nzchar(in_dir)) stop("No input folder selected.")

out_dir <- tcltk::tk_choose.dir(caption = "Select OUTPUT folder (recommended: empty folder)")
if (is.na(out_dir) || !nzchar(out_dir)) stop("No output folder selected.")

# ---- Find CSV files (recursive) ----------------------------------------------
files <- list.files(
  in_dir,
  pattern = "\\.csv$",
  full.names = TRUE,
  recursive = TRUE,
  ignore.case = TRUE
)

if (!length(files)) stop("No .csv files found under: ", in_dir)

# ---- Helper: infer batch_id from folder structure ----------------------------
# batch_id = first folder under in_dir in the file's relative path; else "ROOT"
infer_batch_id <- function(f, root) {
  rel <- sub(
    paste0("^", gsub("([\\^\\$\\.\\|\\(\\)\\[\\]\\*\\+\\?\\\\])", "\\\\\\1", normalizePath(root)), "/?"),
    "",
    normalizePath(f)
  )
  parts <- strsplit(rel, split = .Platform$file.sep, fixed = TRUE)[[1]]
  if (length(parts) >= 2) parts[1] else "ROOT"
}

# ---- Read each CSV robustly + attach provenance ------------------------------
dt_list <- vector("list", length(files))
kept <- 0L
failed <- 0L

for (i in seq_along(files)) {
  f <- files[i]
  
  dt <- tryCatch(
    fread(f, sep = "auto", showProgress = FALSE),
    error = function(e) NULL
  )
  
  if (is.null(dt)) {
    warning("FAILED reading: ", f)
    failed <- failed + 1L
    next
  }
  
  setDT(dt)
  
  dt[, source_file := tools::file_path_sans_ext(basename(f))]
  dt[, source_path := f]
  dt[, batch_id := infer_batch_id(f, in_dir)]
  
  kept <- kept + 1L
  dt_list[[i]] <- dt
}

dt_list <- Filter(Negate(is.null), dt_list)
if (!length(dt_list)) stop("All CSV reads failed. Nothing to merge.")

# ---- Merge (RAW ONLY) ---------------------------------------------------------
merged_raw <- rbindlist(dt_list, use.names = TRUE, fill = TRUE)

raw_out <- file.path(out_dir, "merged_raw.csv")
fwrite(merged_raw, raw_out)

message("Merged files read OK: ", kept)
message("Files failed to read: ", failed)
message("Rows merged total:    ", nrow(merged_raw))
message("Saved: ", raw_out)
message("Done.")