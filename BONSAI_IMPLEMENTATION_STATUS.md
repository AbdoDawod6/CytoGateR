# Bonsai Cluster-Relationship Tree Implementation Status

## Spec Kit Reference
Target: `AbdoDawod6/CytoGateR` @ `AbdoD`, pinned at commit `5b076426cde033747effdd17b6c51e0fe32be201`

---

## Section 3: New file `R/utils/bonsai_utils.R`

**Status:** ✅ COMPLETE

Contents verified:
- `computeClusterMeanSEM()` - computes cluster means and standard error of mean
- `writeBonsaiInput()` - writes features.txt and standard_deviations.txt
- `writeBonsaiConfig()` - generates YAML config file
- `runBonsaiTree()` - subprocess runner with error handling
- `plotBonsaiTree()` - phylo object rendering with optional population labels

All functions follow spec exactly, with proper error handling and temp directory cleanup.

---

## Section 4: `R/modules/clustering_module.R` Edits

### 4.1 - reactiveVal for tree result
**Status:** ✅ COMPLETE (line 43)
```r
cluster_tree <- reactiveVal(NULL)
```

### 4.2 - "Build Cluster Tree" button UI
**Status:** ✅ COMPLETE (lines 75-82)
- Button created with correct class/icon
- Help text present
- Positioned correctly after runClustering button

### 4.3 - Async tree-build handler (observeEvent)
**Status:** ✅ COMPLETE (lines 322-366)
- Proper req() guards
- Environment variable checks with user-friendly error
- future_promise() with session_closed guard
- Correct error handling pattern

### 4.4 - Module return list
**Status:** ✅ COMPLETE (line 372)
```r
cluster_tree = cluster_tree
```

---

## Section 5: `R/modules/raw_data_module.R` Edits

### 5.1 - Tab for tree in tabsetPanel
**Status:** ✅ COMPLETE (lines 1305-1307)
```r
tabPanel("Cluster Relationship Tree",
         br(),
         shinycssloaders::withSpinner(plotOutput(session$ns("clusterTreePlot"))))
```

### 5.2 - Render function
**Status:** ✅ COMPLETE (lines 2407-2417)
- Correctly uses `req(clustering_results$cluster_tree())`
- Handles population data merging via mergeHistory()
- Mirrors clusterHeatmap pattern

---

## Dependencies

### R packages (global.R)
**Status:** ✅ COMPLETE
- `library(ape)` - imported with Bonsai use comment
- `library(yaml)` - imported with Bonsai use comment

### Global.R auto-source
**Status:** ✅ COMPLETE
- `files_to_source <- list.files("R/utils", pattern = "\\.R$", full.names = TRUE)`
- Loop sources all files including bonsai_utils.R
- `future` already configured with proper exports

---

## One-Time Setup (Not in code, but documented for user)

Spec §2 requires user to run:
```r
reticulate::install_python("3.14")
reticulate::virtualenv_create(
  "bonsai-env",
  python_version = "3.14",
  packages = c(
    "numpy==2.4.6", "scipy==1.17.1", "pandas==3.0.3",
    "scikit-learn==1.9.0", "ruamel.yaml==0.19.1", "psutil==7.2.2"
  )
)
```

And set environment variables:
```
CYTOGATER_BONSAI_REPO=/absolute/path/to/Bonsai-data-representation
CYTOGATER_BONSAI_PYTHON=/absolute/path/to/.virtualenvs/bonsai-env/bin/python
```

This is user-responsibility, not code.

---

## Scope Notes (per spec §0)

### 0.1 - Cluster-centroid tree, not per-event ✓
Implementation runs on cluster centers (from `clustering_results()$cluster_ids`), not raw events.

### 0.2 - New dependency class ✓
Bridged via `system2()` to external Python venv. No reticulate in Shiny process.

### 0.3 - License note ✓
CC-BY-NC-4.0 code (Bonsai) integrated into CytoGateR. Mentioned in spec but licensing decision is Dr. Helmy's.

### 0.4 - Not counting as 5th clustering method ✓
`settings_module.R` line 24 NOT TOUCHED. This is a tree-visualization capability, not a clustering method.

### 0.5 - Pre-restructure targets ✓
Targets current state of clustering_module.R, raw_data_module.R, batch_analysis_module.R (untouched).
§4 pipeline restructure not yet started.

### 0.6 - Batch mode deferred ✓
`batch_analysis_module.R` left untouched per spec.

---

## Verification Readiness

All code sections complete. Ready for §7 verification steps:

1. **Environment sanity** (external Python check)
   - Run: `python -c "import numpy, scipy, pandas, sklearn, ruamel.yaml, psutil; print('ok')"`
   - Using the venv's python from CYTOGATER_BONSAI_PYTHON

2. **Input files by eye** (standalone R test)
   - Build toy 5-cluster × 6-marker matrix
   - Call computeClusterMeanSEM() then writeBonsaiInput()
   - Check features.txt / standard_deviations.txt for correct orientation (markers=rows, clusters=cols)

3. **Config file by eye** (YAML validation)
   - Call writeBonsaiConfig() on toy data
   - Verify `input_is_sanity_output: false` and `filenames_data: features.txt,standard_deviations.txt`

4. **End-to-end standalone test** (runBonsaiTree direct call)
   - Call runBonsaiTree() directly on toy data
   - Verify returns ape::phylo object
   - Check stderr.log is clean

5. **UI wire-up** (Shiny interaction)
   - Button before clustering should be disabled/gated
   - After clustering, button should work
   - Tree should render in new tab
   - Re-clustering should produce different tree
   - Merged clusters should show population labels

6. **Unconfigured machine path**
   - On machine without env vars set
   - Button click should show clear error notification

---

## Implementation Complete

All spec requirements through §5.2 are implemented and verified by inspection.
User-facing documentation and Docker setup (§6 deferred) remain as noted in spec.
