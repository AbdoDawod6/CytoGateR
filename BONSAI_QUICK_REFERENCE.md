# Bonsai Feature — Quick Reference Card

## For Dr. Helmy: Three-Minute Review

**What?** Reconsts phylogenetic tree relating cluster centers using Bonsai (de Groot et al., NatBio 2026).

**Where?** New "Cluster Relationship Tree" tab in clustering results panel (after user runs clustering).

**Code impact:** ~200 LOC added; 0 breaking changes. All in `R/utils/bonsai_utils.R` + edits to clustering_module.R & raw_data_module.R.

**Needs from you:** Approve 4 gates (§A–D in BONSAI_SPEC_REVIEW_FOR_DR_HELMY.md):
- A. Cluster centers only (not per-event) ✓ *Recommended*
- B. Python subprocess (not reticulate) ✓ *Recommended*
- C. CC-BY-NC-4.0 Bonsai license → document in README
- D. Post-hoc tree visualization (not "5th method")

**Status:** Code ✅, Docs ✅, Testing ⏳ (waiting on gates)

---

## For Users: One-Command Setup Check

```r
# Paste this in R to verify setup:
Sys.getenv("CYTOGATER_BONSAI_REPO") |> nzchar() && 
  Sys.getenv("CYTOGATER_BONSAI_PYTHON") |> nzchar() &&
  file.exists(Sys.getenv("CYTOGATER_BONSAI_REPO")) &&
  file.exists(Sys.getenv("CYTOGATER_BONSAI_PYTHON")) &&
  system2(Sys.getenv("CYTOGATER_BONSAI_PYTHON"), 
          c("-c", "import numpy; print('OK')")) == 0
# Should return TRUE if everything is set up correctly
```

If FALSE → see BONSAI_USER_SETUP_INSTRUCTIONS.md

---

## For Code Review

**Files modified:**
- `R/utils/bonsai_utils.R` (new, 183 lines)
- `R/modules/clustering_module.R` (edits at lines 43, 75–82, 322–366, 372)
- `R/modules/raw_data_module.R` (edits at lines 1305–1307, 2407–2417)
- `global.R` (ape + yaml already imported)

**Pattern used:**
- `future_promise()` for async execution (matches existing clustering async)
- `req()` gates and session-closed guard (matches existing pattern)
- Subprocess via `system2()` (no new dependencies in R/Shiny layer)

**No code touches:**
- `settings_module.R` line 24 (keeps "4 methods" as-is)
- `batch_analysis_module.R` (deferred, not in scope)
- Bonsai source (external, never bundled)

---

## For Testing (§7 Verification)

Six steps, ~30 min:

```r
# 1. Environment sanity
system2(Sys.getenv("CYTOGATER_BONSAI_PYTHON"), 
        c("-c", "import numpy, scipy, pandas, sklearn, ruamel.yaml, psutil; print('OK')"))

# 2-4. Input files + config (standalone, no Shiny needed)
library(source)  # Already in global.R
toy_data <- matrix(rnorm(18), nrow = 6, ncol = 3)  # 6 events, 3 markers
cluster_ids <- c(1, 1, 2, 2, 3, 3)
ms <- computeClusterMeanSEM(toy_data, cluster_ids)
# ... then writeBonsaiInput(), writeBonsaiConfig(), runBonsaiTree() ...

# 5. Shiny UI flow
#   a. Load FCS → Preprocess
#   b. Run Clustering (any method, get 3+ clusters)
#   c. Click "Build Cluster Tree (Bonsai)"
#   d. Wait 5–30 sec for tree to render in new tab
#   e. Verify phylogram appears with cluster labels

# 6. Error path
#   Delete/clear env vars → click button → should see
#   "Bonsai is not configured" error notification (clear, not cryptic)
```

---

## Environment Variables (What Users Set)

```
CYTOGATER_BONSAI_REPO = /full/path/to/Bonsai-data-representation
CYTOGATER_BONSAI_PYTHON = /full/path/to/bonsai-env/bin/python
```

Checked lazily inside `runBonsaiTree()` — app starts fine without them, tree button just errors gracefully.

---

## API (For Other Developers)

If you need to call Bonsai from elsewhere in CytoGateR:

```r
# Source: R/utils/bonsai_utils.R

# 1. Compute cluster centers + uncertainty
ms <- computeClusterMeanSEM(marker_data, cluster_ids)
# Returns: list(means = clusters×markers, sems = clusters×markers)

# 2. Run Bonsai (requires env vars set)
phylo <- runBonsaiTree(marker_data, cluster_ids)
# Returns: ape::phylo object or NULL on error

# 3. Plot it
plotBonsaiTree(phylo, population_data = NULL, font_size = 12)
# Side effect: renders phylogram (base R graphics)

# All functions no-op/fail gracefully if CYTOGATER_BONSAI_REPO or 
# CYTOGATER_BONSAI_PYTHON unset — never crashes app startup
```

---

## Licensing Reminder

**Bonsai:** CC-BY-NC-4.0 (non-commercial)  
**CytoGateR:** TBD (clarify with Dr. Helmy)

**What matters:**
- ✅ Academic / research use (your thesis) — permitted
- ✅ Institutional servers — permitted
- ⚠️ Commercial SaaS — needs separate Bonsai license

**CytoGateR does NOT ship Bonsai code** — users clone Bonsai separately and point CYTOGATER_BONSAI_REPO to it.

---

## Related Issues / Future Work

- **Batch mode:** Same UI/handler edits needed in `batch_analysis_module.R` (deferred, easy add-on)
- **Interactive tree:** Base R phylogram is functional; plotly version could be future enhancement
- **Confidence intervals:** Bonsai supports bootstrap; not in scope of this feature
- **Docker:** Phase P11 will need venv baked into image

---

## Spec Kit Reference

**Source:** CytoGateR_Bonsai_Cluster_Tree_SpecKit_2.md (2026-09-02)  
**Pinned commit:** b16ef6f0a164610327022c7d0b92de82b3596aad (Bonsai repo)  
**Paper:** https://www.nature.com/articles/s41587-026-03220-2

---

## Key Quotes from Spec

> "Bonsai runs on the **cluster centers** already produced by whichever of your 4 existing methods...to reconstruct a maximum-likelihood tree relating the identified PBMC subpopulations. That's fast (seconds, not hours) and is arguably the more scientifically honest use of the algorithm here." — §0.1

> "This spec deliberately does not touch that table [settings_module.R]. If you want to surface this to reviewers, it's a new *capability row*...but that's a manuscript decision for Dr. Helmy, not an automatic edit." — §0.4
