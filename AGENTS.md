# CytoGateR — Project Memory for Posit Assistant

## Project Overview

**Repository:** AbdoDawod6/CytoGateR @ branch `AbdoD`  
**Type:** Shiny app for flow cytometry clustering & gating analysis  
**Language:** R (Shiny framework)  
**Status:** In active development (honours thesis submission in progress)

## Core Architecture

### Key Modules (in `R/modules/`)
- `raw_data_module.R` — data loading, preprocessing, visualization (3000+ lines)
- `clustering_module.R` — 4 clustering methods (K-means, DBSCAN, FlowSOM, Phenograph) with async execution
- `batch_analysis_module.R` — batch processing (marked for restructuring §4)
- `gating_module.R` — interactive gating / population identification
- Other helpers: settings, normalization, qc, advanced gating

### Async Pattern (Framework 2.1)
All heavy computation (clustering, dimensionality reduction, Bonsai tree) uses `future_promise()`:
- Captures all inputs as locals before entering worker
- Session-closed guard prevents writing to dead reactives
- Error handler catches subprocess failures
- Pattern is consistent across all async operations

### Data Pipeline
1. Load FCS file → parse metadata, extract events × markers matrix
2. QC filtering (optional)
3. Data normalization (arcsinh, log, none)
4. Marker scaling (z-score or custom thresholds)
5. **Clustering** (user chooses method + parameters)
6. **Optional: Population identification** (heuristic-based on marker thresholds)
7. **Optional: Dimensionality reduction** (t-SNE, UMAP, PCA, MDS)
8. **Visualization & export**

## Recent Work: Bonsai Integration

### What Was Added (2026-09-23)

A new post-hoc feature that reconstructs a phylogenetic-style tree relating identified cluster centers using Bonsai (de Groot et al., Nature Biotechnology 2026).

**Implementation:**
- `R/utils/bonsai_utils.R` — 5 utility functions (mean/SEM computation, config gen, Bonsai runner, tree plotting)
- `clustering_module.R` edit — "Build Cluster Tree" button + async handler (mirrors runClustering pattern)
- `raw_data_module.R` edit — new "Cluster Relationship Tree" tab + render function
- Dependencies: `ape`, `yaml` (CRAN packages, already imported)

**User Setup (One-time, per machine):**
```bash
git clone https://github.com/dhdegroot/Bonsai-data-representation.git
git checkout b16ef6f0a164610327022c7d0b92de82b3596aad
```

```r
reticulate::virtualenv_create("bonsai-env", python_version = "3.14",
  packages = c("numpy==2.4.6", "scipy==1.17.1", "pandas==3.0.3", 
               "scikit-learn==1.9.0", "ruamel.yaml==0.19.1", "psutil==7.2.2"))
```

Set environment variables:
```
CYTOGATER_BONSAI_REPO=/absolute/path/to/Bonsai-data-representation
CYTOGATER_BONSAI_PYTHON=/absolute/path/to/bonsai-env/bin/python
```

**Key Design Decisions (awaiting Dr. Helmy approval):**
- §A: Cluster-centroid tree only (not per-event) — fast, scientifically sound
- §B: Python subprocess, not reticulate — lighter integration
- §C: CC-BY-NC-4.0 Bonsai dependency — document in README
- §D: Not a "5th method" — post-hoc visualization, separate from 4 clustering methods

**Status:** Code complete, verified, awaiting §7 testing (toy data → real data → production)

**Documentation provided:**
- `BONSAI_IMPLEMENTATION_STATUS.md` — section-by-section verification
- `BONSAI_SPEC_REVIEW_FOR_DR_HELMY.md` — gate decisions for approval
- `BONSAI_USER_SETUP_INSTRUCTIONS.md` — user guide (ready to ship)
- `IMPLEMENTATION_SUMMARY.md` — high-level overview

## Code Organization Notes

### R/utils/ (Auto-sourced by global.R)
- `clustering.R` — runClustering dispatch, utility fns
- `bonsai_utils.R` — Bonsai tree functions (NEW)
- Others: gating helpers, plotting, preprocessing, QC, etc.

### Key Reactives (raw_data_module)
- `processedData()` — cleaned, scaled matrix (events × markers)
- `clustering_results$clustering_results()` — list(cluster_ids, centers, method)
- `clustering_results$populations()` — identified populations (heuristic)
- `clustering_results$cluster_tree()` — phylo object from Bonsai (NEW)
- `mergeHistory()` — user-modified cluster assignments + population mapping

## Known Technical Debt

1. **Batch module duplication** — `batch_analysis_module.R` duplicates UI/logic from clustering_module, marked for deletion in §4 restructure
2. **License clarity** — CytoGateR's own license not yet pinned (CC-BY, CC-BY-SA, MIT, etc.)
3. **renv.lock** — currently only tracks `renv` itself, not live dependencies
4. **Docker packaging** — Phase P11 deferred; Bonsai venv will need baking into image when ready

## Data Formats

### Input
- FCS 3.0 files (parsed by flowCore)
- Supports 5–50k markers per event (practical range: 5–40 for typical cytometry)
- 50k–1M events per file

### Output
- ClusterTree visualization (ape::phylo object, rendered as phylogram)
- CSV/XLSX exports of cluster assignments, population calls, statistics

## Reviewer Comments (from manuscript)

**Comment 2:** "Missing modern unsupervised approaches"  
→ Bonsai tree reconstruction may address this as a new "tree visualization" capability (separate framing from clustering methods)

## Important Constraints

1. **Async execution:** All heavy work must run in `future_promise()` to prevent server disconnection (90s timeout)
2. **Session closure guard:** Every async handler must check `isSessionClosedGuard(session_closed)` before writing to reactives
3. **No per-event Bonsai:** By design — computational infeasibility. Cluster centers only.
4. **Clustering prerequisites:** User must run clustering before building tree (enforced by `req()` gate)

## Testing Approach

1. **Unit tests** — standalone R, not Shiny (see IMPLEMENTATION_SUMMARY.md)
2. **Integration tests** — full Shiny flow with toy FCS data
3. **Edge cases** — <3 clusters, missing config, session closure, subprocess failure

## Contact & Approvals

- **Dr. Helmy** — needs to approve §A–D gate decisions (BONSAI_SPEC_REVIEW_FOR_DR_HELMY.md)
- **Bonsai Authors** — pinned commit b16ef6f0a164610327022c7d0b92de82b3596aad; no changes to their code
- **Paper** — https://www.nature.com/articles/s41587-026-03220-2

## Files Never to Modify

- `settings_module.R` line 24 ("4 clustering methods") — keep as-is
- `renv.lock` — not live tracking, skip for now
- Bonsai source code — external dependency, never baked into CytoGateR

## Next Steps

1. ✅ Code implementation complete
2. ⏳ Dr. Helmy approves §A–D gates
3. ⏳ Run §7 verification tests (toy data, real FCS)
4. ⏳ Merge to main, tag release
5. ⏳ Docker Phase P11 integration (bake venv into image)
