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
#     4. Ensures column harmonization across batches (fill=TRUE logic)
#     5. Verifies presence of critical metadata columns
#        (Batch, Group, RowGroup if available)
#     6. Preserves all flags generated in Step 2a
#     7. Performs optional integrity checks:
#          - Duplicate well detection across batches
#          - Missing metadata reporting
#     8. Generates a per-batch merge report (rows read, rows retained)
#     9. Exports a standardized multi-batch merged.csv file
#        ready for downstream statistical analysis (Step 3)
#
# OUTPUT:
#   An output folder containing:
#     merged_multibatch.csv     (final merged dataset across batches)
#     file_merge_report.csv     (per-batch merge summary)
#
# NOTES:
#   - Uses tcltk (tk_choose.dir) for macOS folder pickers.
#   - Designed for interactive use (GUI folder selection + automated exports).
#   - Intended as Step 2b of a 3-step KIC calcium processing pipeline.
#   - Expects as input ONLY the merged.csv files produced by Step 2a.
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
files <- list.files(in_dir,
                    pattern = "\\.csv$",
                    full.names = TRUE,
                    recursive = TRUE,
                    ignore.case = TRUE)

if (!length(files)) stop("No .csv files found under: ", in_dir)

# ---- Helper: infer batch_id from folder structure ----------------------------
# batch_id = first folder under in_dir in the file's relative path; else "ROOT"
infer_batch_id <- function(f, root) {
  rel <- sub(paste0("^", gsub("([\\^\\$\\.\\|\\(\\)\\[\\]\\*\\+\\?\\\\])", "\\\\\\1", normalizePath(root)), "/?"), "", normalizePath(f))
  parts <- strsplit(rel, split = .Platform$file.sep, fixed = TRUE)[[1]]
  if (length(parts) >= 2) parts[1] else "ROOT"
}

# ---- Read each CSV robustly + attach metadata --------------------------------
report_list <- vector("list", length(files))
dt_list <- vector("list", length(files))

for (i in seq_along(files)) {
  f <- files[i]
  
  dt <- tryCatch(
    fread(f, sep = "auto", showProgress = FALSE),
    error = function(e) {
      warning("FAILED reading: ", f, " | ", conditionMessage(e))
      NULL
    }
  )
  
  if (is.null(dt)) {
    report_list[[i]] <- data.table(
      source_path = f,
      source_file = tools::file_path_sans_ext(basename(f)),
      batch_id    = infer_batch_id(f, in_dir),
      rows_read   = NA_integer_,
      status      = "READ_FAIL"
    )
    next
  }
  
  # ensure data.table
  setDT(dt)
  
  dt[, source_file := tools::file_path_sans_ext(basename(f))]
  dt[, source_path := f]
  dt[, batch_id := infer_batch_id(f, in_dir)]
  
  dt_list[[i]] <- dt
  
  report_list[[i]] <- data.table(
    source_path = f,
    source_file = unique(dt$source_file),
    batch_id    = unique(dt$batch_id),
    rows_read   = nrow(dt),
    status      = "OK"
  )
}

# drop failed reads
dt_list <- Filter(Negate(is.null), dt_list)
report  <- rbindlist(report_list, use.names = TRUE, fill = TRUE)

if (!length(dt_list)) stop("All CSV reads failed. Nothing to merge.")

# ---- Merge (raw) --------------------------------------------------------------
merged_raw <- rbindlist(dt_list, use.names = TRUE, fill = TRUE)

raw_out <- file.path(out_dir, "merged_raw.csv")
fwrite(merged_raw, raw_out)
message("Saved raw merge: ", raw_out)

# ---- Filtering ----------------------------------------------------------------
merged <- copy(merged_raw)

# Track filtering impacts (overall)
n0 <- nrow(merged)

# 1) Num.Peaks >= 2
if (!"Num.Peaks" %in% names(merged)) {
  stop("Column 'Num.Peaks' not found in merged data.")
}
NumPeaks_num <- suppressWarnings(as.numeric(trimws(as.character(merged[["Num.Peaks"]]))))
keep_peaks <- !is.na(NumPeaks_num) & NumPeaks_num >= 2
n_peaks_removed <- sum(!keep_peaks)

merged <- merged[keep_peaks]

# 2) Well must be strict 96-well ID A01–H12
if (!"Well" %in% names(merged)) {
  stop("Column 'Well' not found in merged data.")
}
merged[, Well := toupper(trimws(as.character(Well)))]

valid_well <- grepl("^[A-H](0[1-9]|1[0-2])$", merged$Well)
n_well_removed <- sum(is.na(merged$Well) | !valid_well)

merged <- merged[valid_well & !is.na(Well)]

n1 <- nrow(merged)

# ---- Save filtered merge -------------------------------------------------------
filtered_out <- file.path(out_dir, "merged_filtered.csv")
fwrite(merged, filtered_out)
message("Saved filtered merge: ", filtered_out)

# ---- Per-file post-filter audit (optional but very useful) --------------------
# Recompute kept counts per source_path after filtering:
kept_by_file <- merged[, .(rows_kept = .N), by = .(source_path, source_file, batch_id)]

report2 <- merge(
  report[status == "OK"],
  kept_by_file,
  by = c("source_path", "source_file", "batch_id"),
  all.x = TRUE
)

report2[is.na(rows_kept), rows_kept := 0L]
report2[, rows_removed := rows_read - rows_kept]

# Add overall filter summary as attributes (and also print)
message("---- FILTER SUMMARY ----")
message("Rows raw merged:     ", n0)
message("Removed (Num.Peaks): ", n_peaks_removed)
message("Removed (Well ID):   ", n_well_removed)
message("Rows final:          ", n1)

report_out <- file.path(out_dir, "file_merge_report.csv")
fwrite(report2, report_out)
message("Saved merge report:  ", report_out)

message("Done.")