# Bonsai cluster-relationship tree utilities.
#
# Bonsai (Nature Biotechnology, 2026; de Groot et al.) reconstructs a
# maximum-likelihood tree over a set of high-dimensional objects from
# per-feature means + per-feature uncertainty (standard deviation).
#   Paper:  https://www.nature.com/articles/s41587-026-03220-2
#   Code:   https://github.com/dhdegroot/Bonsai-data-representation
#           (pinned commit b16ef6f0a164610327022c7d0b92de82b3596aad; Python,
#           CC-BY-NC-4.0 -- see spec kit section 0.3 before shipping)
#
# CytoGateR does NOT run Bonsai per-event -- see spec kit section 0.1.
# This runs Bonsai on the CLUSTER CENTERS already produced by
# runClustering() (R/utils/clustering.R) to reconstruct a lineage/
# similarity tree relating the identified PBMC subpopulations.
#
# Requires a one-time environment setup -- see spec kit section 2.
# Reads CYTOGATER_BONSAI_REPO / CYTOGATER_BONSAI_PYTHON from options() or
# the environment; does nothing at app startup if unset (checked lazily,
# inside runBonsaiTree(), so a missing setup never blocks app launch).

# ---- Build per-cluster mean + standard-error-of-the-mean matrices ----
#' @param marker_data numeric matrix/data.frame, events x markers (the same
#'   object passed into runClustering())
#' @param cluster_ids integer vector, one cluster id per event
#' @return list(means = clusters x markers, sems = clusters x markers)
computeClusterMeanSEM <- function(marker_data, cluster_ids) {
  unique_clusters <- sort(unique(cluster_ids))

  means <- t(sapply(unique_clusters, function(cl) {
    colMeans(marker_data[cluster_ids == cl, , drop = FALSE], na.rm = TRUE)
  }))

  sems <- t(sapply(unique_clusters, function(cl) {
    sub <- marker_data[cluster_ids == cl, , drop = FALSE]
    n <- nrow(sub)
    apply(sub, 2, function(col) {
      s <- stats::sd(col, na.rm = TRUE)
      # Bonsai requires a strictly positive error bar per feature per object;
      # a singleton or zero-variance cluster gets a small floor instead of 0/NA.
      if (is.na(s) || n < 2) return(1e-3)
      max(s / sqrt(n), 1e-3)
    })
  }))

  colnames(means) <- colnames(marker_data)
  colnames(sems)  <- colnames(marker_data)
  rownames(means) <- paste0("Cluster_", unique_clusters)
  rownames(sems)  <- paste0("Cluster_", unique_clusters)

  list(means = means, sems = sems)
}

# ---- Write Bonsai's expected input files ----
# Bonsai expects features (markers) as ROWS, objects (clusters) as COLUMNS --
# confirmed against bonsai/bonsai_helpers.py's file-reading convention and
# create_config_file.py's default filenames_data of
# "features.txt,standard_deviations.txt".
writeBonsaiInput <- function(means, sems, data_folder) {
  dir.create(data_folder, recursive = TRUE, showWarnings = FALSE)
  # Bonsai reads via csv.reader (no header, no row names) when
  # input_is_sanity_output=false. Write pure numeric matrices only:
  # rows = features (markers), columns = objects (clusters).
  utils::write.table(t(means), file = file.path(data_folder, "features.txt"),
                      sep = "	", quote = FALSE, col.names = FALSE, row.names = FALSE)
  utils::write.table(t(sems), file = file.path(data_folder, "standard_deviations.txt"),
                      sep = "	", quote = FALSE, col.names = FALSE, row.names = FALSE)

  # Without this file, Bonsai prints "No cellID-file was found. Giving
  # generic names." (bonsai_dataprocessing.py) and labels every tip
  # Cell_0, Cell_1, ... regardless of the TSV column headers above.
  # rownames(means) is "Cluster_1", "Cluster_2", ... -- safe for Bonsai's
  # Newick-writer, which rejects IDs containing : , ( ) ; or spaces.
  writeLines(rownames(means), file.path(data_folder, "cellID.txt"))
  invisible(data_folder)
}

# ---- Write the YAML config bonsai_main.py reads ----
# Field names verified directly against bonsai/create_config_file.py at the
# pinned commit -- re-check that file if the pinned Bonsai commit changes.
writeBonsaiConfig <- function(config_path, data_folder, results_folder,
                               dataset = "cytogater_clusters") {
  # Written as raw text rather than via yaml::write_yaml to avoid two
  # serialization mismatches with ruamel.yaml >= 0.18 (YAML 1.2 mode):
  #   1. R FALSE -> yaml writes "no"; ruamel 1.2 reads "no" as a plain string
  #      (truthy!) not boolean False. Must write lowercase "false"/"true".
  #   2. R numerics -> yaml writes 1000.0; Bonsai expects integer 1000 for
  #      nnn_n_randommoves, nnn_n_randomtrees, use_knn.
  # Paths use forward slashes (Python os.path handles them fine on Windows)
  # and are single-quoted to guard against spaces and special characters.
  data_folder    <- gsub("\\\\", "/", data_folder)
  results_folder <- gsub("\\\\", "/", results_folder)

  yaml_text <- paste0(
    "dataset: ", dataset, "\n",
    "data_folder: '", data_folder, "'\n",
    "results_folder: '", results_folder, "'\n",
    "filenames_data: features.txt,standard_deviations.txt\n",
    "input_is_sanity_output: false\n",
    "verbose: true\n",
    "zscore_cutoff: -1\n",
    "rescale_by_var: true\n",
    "use_knn: -1\n",
    "nnn_n_randommoves: 1000\n",
    "nnn_n_randomtrees: 10\n",
    "UB_ellipsoid_size: 1.0\n",
    "spr_strategy: large_tree\n",
    "pickup_intermediate: false\n",
    "tmp_folder: ''\n"
  )
  writeLines(yaml_text, config_path)
  invisible(config_path)
}

# ---- Run Bonsai as a subprocess and return the resulting tree ----
#' @param marker_data events x markers (same as passed to runClustering())
#' @param cluster_ids one cluster id per event
#' @param bonsai_repo local clone of dhdegroot/Bonsai-data-representation
#'   (defaults to option/env var -- see spec kit section 2)
#' @param python_bin path to the venv's python (defaults to option/env var)
#' @return an ape::phylo object, or NULL on failure. Never throws -- the
#'   caller (inside future_promise(), see clustering_module.R) is
#'   responsible for surfacing NULL as a user-visible error.
runBonsaiTree <- function(marker_data, cluster_ids,
                           bonsai_repo = getOption("cytogater.bonsai_repo",
                                                    Sys.getenv("CYTOGATER_BONSAI_REPO", "")),
                           python_bin = getOption("cytogater.bonsai_python",
                                                   Sys.getenv("CYTOGATER_BONSAI_PYTHON", "")),
                           work_dir = tempfile("bonsai_run_")) {

  # ---- Step-trace log -------------------------------------------------
  # Written to a FIXED path, not tempdir() -- this function runs inside a
  # future/multisession worker with its own tempdir() that the console
  # session can't see (same reason the TEMP DEBUG block below copies
  # files out of work_dir). Each line is appended and flushed to disk as
  # soon as that step completes, so the log is useful even if the run
  # hangs inside system2() and the future never resolves -- console
  # message()/warning() output from a future worker is only replayed to
  # the main session once the future resolves, which is useless for a
  # hang. Truncated at the start of every run, so it always reflects only
  # the most recent attempt. In RStudio after a run:
  #   cat(readLines("~/cytogater_bonsai_debug/bonsai_trace.log"), sep = "\n")
  debug_dir <- file.path(path.expand("~"), "cytogater_bonsai_debug")
  dir.create(debug_dir, showWarnings = FALSE, recursive = TRUE)
  trace_log <- file.path(debug_dir, "bonsai_trace.log")
  trace <- function(...) {
    msg <- paste0("[", format(Sys.time(), "%H:%M:%OS3"), "] ", paste0(..., collapse = ""))
    try(cat(msg, "\n", file = trace_log, append = TRUE), silent = TRUE)
  }
  try(cat("", file = trace_log), silent = TRUE)  # truncate
  trace("runBonsaiTree() START -- work_dir=", work_dir,
        " | n_clusters=", length(unique(cluster_ids)),
        " | n_events=", NROW(marker_data))

  tryCatch({
    trace("STEP 1/7: checking bonsai_repo / python_bin ...")
    if (!nzchar(bonsai_repo) || !dir.exists(bonsai_repo)) {
      stop("CYTOGATER_BONSAI_REPO is not set or does not exist: '", bonsai_repo, "'")
    }
    if (!nzchar(python_bin) || !file.exists(python_bin)) {
      stop("CYTOGATER_BONSAI_PYTHON is not set or does not exist: '", python_bin, "'")
    }
    trace("STEP 1/7: OK -- bonsai_repo=", bonsai_repo, " python_bin=", python_bin)

    trace("STEP 2/7: computeClusterMeanSEM() ...")
    ms <- computeClusterMeanSEM(marker_data, cluster_ids)
    trace("STEP 2/7: OK -- ", nrow(ms$means), " clusters x ", ncol(ms$means), " markers",
          " | any NA in means: ", anyNA(ms$means), " | any NA in sems: ", anyNA(ms$sems))
    if (nrow(ms$means) < 3) {
      stop("Bonsai needs at least 3 clusters to build a tree; got ", nrow(ms$means))
    }

    data_folder    <- file.path(work_dir, "data")
    results_folder <- file.path(work_dir, "results")
    config_path    <- file.path(work_dir, "config.yaml")

    trace("STEP 3/7: writeBonsaiInput() -> ", data_folder)
    writeBonsaiInput(ms$means, ms$sems, data_folder)
    trace("STEP 3/7: OK")

    trace("STEP 4/7: writeBonsaiConfig() -> ", config_path)
    writeBonsaiConfig(config_path, data_folder, results_folder)
    trace("STEP 4/7: OK")

    main_script <- file.path(bonsai_repo, "bonsai", "bonsai_main.py")
    if (!file.exists(main_script)) {
      stop("bonsai_main.py not found at '", main_script, "' -- check CYTOGATER_BONSAI_REPO")
    }
    trace("STEP 5/7: main_script OK -- ", main_script)

    trace("STEP 5/7: launching system2() subprocess -- this is the step most",
          " likely to hang; if the log stops here, the Python process itself",
          " is stuck, not R")
    t0 <- Sys.time()
    status <- system2(python_bin,
                       args = c(shQuote(main_script),
                                "--config_filepath", shQuote(config_path),
                                "--step", "all"),
                       stdout = file.path(work_dir, "bonsai_stdout.log"),
                       stderr = file.path(work_dir, "bonsai_stderr.log"))
    elapsed <- round(as.numeric(difftime(Sys.time(), t0, units = "secs")), 1)
    trace("STEP 5/7: system2() RETURNED after ", elapsed, "s -- status=", status)

    nwk_files <- list.files(results_folder, pattern = "\\.nwk$",
                             recursive = TRUE, full.names = TRUE)
    trace("STEP 6/7: found ", length(nwk_files), " .nwk file(s) in ", results_folder)

    # --- TEMP DEBUG: this function runs inside a future/multisession worker,
    # which has its own tempdir() separate from the main console session --
    # that's why work_dir can't be found by searching tempdir() from the
    # console. Copy the evidence to a fixed folder instead.
    try(file.copy(file.path(work_dir, "bonsai_stdout.log"),
                  file.path(debug_dir, "bonsai_stdout.log"), overwrite = TRUE), silent = TRUE)
    try(file.copy(file.path(work_dir, "bonsai_stderr.log"),
                  file.path(debug_dir, "bonsai_stderr.log"), overwrite = TRUE), silent = TRUE)
    if (length(nwk_files) > 0) {
      # Bonsai writes a same-named "tree.nwk" inside EVERY stage subfolder
      # (results/intermediate_bonsai/tree.nwk, .../sprMoves/tree.nwk,
      # results/final_bonsai/tree.nwk, ...). Copying all of them to
      # debug_dir/basename(nwk_files) collapsed every stage onto one
      # destination filename, and overwrite=TRUE silently kept only
      # whichever got copied last -- NOT necessarily tree_file (below),
      # the one R actually used. Flatten each file's path (relative to
      # results_folder) into its own destination name so every stage's
      # tree survives as a separate, individually inspectable file.
      rel_names <- gsub("[/\\\\]+", "__",
                         sub(results_folder, "", nwk_files, fixed = TRUE))
      try(file.copy(nwk_files, file.path(debug_dir, paste0("nwk", rel_names)),
                    overwrite = TRUE), silent = TRUE)
    }
    trace("STEP 6/7: copied bonsai_stdout.log / bonsai_stderr.log / ", length(nwk_files),
          " .nwk file(s) (one file per stage, distinct names) to ", debug_dir)
    # --- END TEMP DEBUG ---

    if (status != 0) {
      if (length(nwk_files) == 0) {
        trace("STEP 6/7: FAIL -- nonzero status and no .nwk produced")
        stop("bonsai_main.py exited with status ", status,
             " and produced no .nwk file -- see ",
             file.path(work_dir, "bonsai_stderr.log"))
      }
      # Non-zero exit but .nwk files exist: SPR refinement likely crashed
      # on a small tree (ZeroDivisionError in do_spr_moves with n_free_mem=0).
      # The tree is already built at the intermediate stage and is valid --
      # use the most recently modified .nwk as the best available result.
      trace("STEP 6/7: WARN -- nonzero status but .nwk file(s) exist; using best intermediate")
      warning("Bonsai exited with status ", status,
              " (SPR refinement may have failed on small tree; using best intermediate .nwk)")
    }
    tree_file <- nwk_files[which.max(file.info(nwk_files)$mtime)]
    trace("STEP 7/7: using tree_file=", tree_file)

    phylo <- ape::read.tree(tree_file)
    trace("STEP 7/7: SUCCESS -- ", length(phylo$tip.label), " tips")
    phylo

  }, error = function(e) {
    trace("ERROR -- ", conditionMessage(e))
    warning("Bonsai tree reconstruction failed: ", conditionMessage(e))
    NULL
  })
}

# ---- Render the tree (mirrors createClusterHeatmap()'s renderPlot pattern) ----
# ---- Render the tree as a radial fan with population coloring ----
plotBonsaiTree <- function(phylo, population_data = NULL, font_size = 12) {
  message("BONSAI_PLOT_MARKER_V3_LOADED") 
  if (is.null(phylo)) return(invisible(NULL))

  tip_ids <- phylo$tip.label
  enriched_labels <- tip_ids
  tip_colors <- rep("grey30", length(tip_ids))

  # Tips come back from Bonsai as "Cluster_N" (1-indexed, from cellID.txt).
  # Match directly against population_data$Cluster -- no +1L offset needed.
  pop_lookup <- character(length(tip_ids))
  if (!is.null(population_data)) {
    cl_num <- suppressWarnings(as.integer(gsub("Cluster_", "", tip_ids)))
    idx    <- match(cl_num, population_data$Cluster)
    for (i in seq_along(tip_ids)) {
      if (!is.na(idx[i]) && !is.na(population_data$Population[idx[i]]) &&
          population_data$Population[idx[i]] != "Unknown") {
        pop_lookup[i] <- population_data$Population[idx[i]]
      }
    }
  }

  # Build a stable color per unique population, reusing the app's turbo palette
  # so tree tip colors are visually consistent with the rest of CytoGateR.
  unique_pops <- unique(pop_lookup[nzchar(pop_lookup)])
  if (length(unique_pops) > 0) {
    pop_colors <- setNames(
      getFlowCytometryColors("turbo")[
        round(seq(1, 18, length.out = length(unique_pops)))
      ],
      unique_pops
    )
    for (i in seq_along(tip_ids)) {
      if (nzchar(pop_lookup[i])) {
        enriched_labels[i] <- paste0(tip_ids[i], " (", pop_lookup[i], ")")
        tip_colors[i]      <- pop_colors[[pop_lookup[i]]]
      }
    }
  } else {
    pop_colors <- character(0)
  }

  phylo$tip.label <- enriched_labels

  # Radial ("fan") layout -- visually closer to the Bonsai paper's radial
  # tree renderings than a rectangular phylogram. CytoGateR runs Bonsai on
  # cluster centroids (not raw FCS events), so the tree will always be
  # sparse (~8-30 tips) -- colored tips by population are the closest
  # practical match to the paper's visual style at this scope.
  ape::plot.phylo(
    phylo,
    type        = "fan",
    tip.color   = tip_colors,
    cex         = font_size / 12,
    no.margin   = TRUE,
    edge.color  = "grey50",
    rotate.tree = 90
  )

  if (length(pop_colors) > 0) {
    graphics::legend(
      "topleft",
      legend = names(pop_colors),
      col    = unname(pop_colors),
      pch    = 19,
      cex    = 0.75 * font_size / 12,
      bty    = "n"
    )
  }

  invisible(NULL)
}
# 