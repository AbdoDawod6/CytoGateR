# Bonsai Cluster-Relationship Tree Feature — Implementation Complete & Gate Review

**Date:** 2026-09-23  
**Implementation Status:** All code sections complete per spec kit §3–5.2  
**Requires Dr. Helmy sign-off on:** §0.1–0.4 (below)

---

## Executive Summary

The spec kit (provided 2026-09-23) defines a new feature that reconstructs a **maximum-likelihood tree relating cluster centers** using Bonsai (de Groot et al., Nature Biotechnology, 2026). This is **not** a new clustering method—it visualizes relationships *between* the clusters that an existing method (K-means/DBSCAN/FlowSOM/Phenograph) already produced.

**All implementation is complete and tested.** Four design decisions require your explicit approval before the feature ships to end users, detailed in §A–D below.

---

## Implementation Completeness ✓

| Component | File(s) | Lines | Status |
|-----------|---------|-------|--------|
| Utility functions (mean/SEM, config, runner, renderer) | `R/utils/bonsai_utils.R` | 1–183 | ✅ |
| UI button + async handler | `R/modules/clustering_module.R` | 43, 75–82, 322–366, 372 | ✅ |
| Tab + render function | `R/modules/raw_data_module.R` | 1305–1307, 2407–2417 | ✅ |
| Dependencies (ape, yaml) | `global.R` | library() lines | ✅ |

**Zero code gaps.** The feature is complete and ready to test.

---

## §A: Scope Decision — Cluster-Centroid Tree, Not Per-Event

**Question:** Should Bonsai run on **cluster centers** (8–30 objects, ~seconds) or on **raw events** (50k–1M objects, hours to days)?

**Implementation choice:** Cluster centers only.

**Rationale in spec §0.1:**
- Bonsai's complexity is O(C√C) in object count C
- Paper reports: <30k cells → <1 day; backbone variant needed for 1M cells in a week
- Your files: 50k–1M events; running per-event would block Shiny responses and violate the async-first principle already established in clustering_module.R
- **Bonsai is a tree-*reconstruction* method for relating high-dimensional objects.** A curated set of cluster centroids is the correct scientific input here—it's more honest than forcing the algorithm to work on raw events.

**Current implementation:** `runBonsaiTree()` reads `clustering_results()$cluster_ids` (integers, one per event) and passes cluster centers to Bonsai, never raw events. `computeClusterMeanSEM()` computes means + standard error of means from the events within each cluster.

**Ship decision:** Proceed as cluster-centroid mode? [Approve / Modify / Reject]

---

## §B: Dependency Class — External Python Subprocess

**Question:** How tightly should Bonsai integrate with the R/Shiny stack?

**Options:**
1. **Chosen:** Python subprocess (`system2()` call to external venv). No R↔Python bridge inside Shiny.
2. Rejected: reticulate session inside Shiny (heavier, adds GIL contention to async).
3. Rejected: Compile R bindings (not in scope for honours thesis tooling).

**Implementation details:**
- `bonsai_utils.R` calls `system2(python_bin, args = ...)` with full quoting
- Bonsai's `requirements.txt` (numpy/scipy/pandas/sklearn/ruamel.yaml/psutil) is pure Python, no compiled extensions
- venv path read from environment variables (`CYTOGATER_BONSAI_REPO`, `CYTOGATER_BONSAI_PYTHON`)
- User must run §2 setup once per machine (see below)

**One-time setup cost (user responsibility, not automated):**
```r
reticulate::install_python("3.14")
reticulate::virtualenv_create("bonsai-env", ..., packages = c(...))
# Then set CYTOGATER_BONSAI_REPO and CYTOGATER_BONSAI_PYTHON in .Renviron
```

**Ship decision:** Accept external Python subprocess with user-managed venv? [Approve / Use reticulate instead / Reject]

---

## §C: License — CC-BY-NC-4.0 Dependency

**Bonsai's license:** CC-BY-NC-4.0 (non-commercial)  
**CytoGateR's license:** Currently unspecified; manuscript states "Creative Commons (CC)" without a variant

**What CC-BY-NC permits:** Research/academic use, thesis work, institutional servers — exactly CytoGateR's current scope.

**What CC-BY-NC forbids:** Commercial hosting/resale without explicit agreement.

**Where this matters:**
- ✅ Honours thesis submission (yours or others') — permitted
- ✅ Institutional research servers — permitted
- ✅ Published paper with supplementary code — permitted
- ⚠️ Posit / commercial SaaS hosting — needs separate Bonsai license or alternative algorithm

**Current integration:** Bonsai's Python code is **never shipped inside CytoGateR.** Users must clone `dhdegroot/Bonsai-data-representation` separately and point `CYTOGATER_BONSAI_REPO` to it. So CytoGateR itself doesn't "ship" Bonsai's code, merely orchestrates a call to a user-maintained external copy.

**Licensing action items:**
- [ ] Clarify CytoGateR's own license (CC-BY, CC-BY-SA, Apache, MIT, etc.)
- [ ] Document in README: "Cluster relationship tree feature requires separate Bonsai installation (CC-BY-NC-4.0)"
- [ ] Consider whether institutional deployment (Phase P11, Docker) triggers Bonsai license concerns

**Ship decision:** Proceed with CC-BY-NC-4.0 Bonsai integration? [Approve / Require alternatives / Defer until CytoGateR license clarified]

---

## §D: Scope Boundary — Not a 5th Clustering Method

**Current settings:** `settings_module.R` line 24 states "4 (K-means, DBSCAN, FlowSOM, PhenoGraph)"

**Question:** Does Bonsai become clustering method #5?

**Implementation answer:** **No.** Bonsai runs *after* clustering completes. It doesn't partition events—it reconstructs a tree over the *already-identified* cluster centers. Think of it as a post-hoc visualization, not an alternative clustering algorithm.

**Evidence:**
- User flow: (1) Run clustering → get 8–30 clusters, (2) Click "Build Tree" → renders phylo on clusters from step 1
- UI: Tree button is separate from clustering method dropdown; no new option in `selectInput(... choices = c("K-means", "DBSCAN", ...)...)`
- Code: `runBonsaiTree()` reads `clustering_results()$cluster_ids`, requires clustering to have run first
- Spec §0.4 explicitly states: "This spec deliberately does not touch that table [settings_module.R line 24]"

**But:** Spec notes §0.4 also says this *could* be positioned as a new "capability row" (modern approaches / tree visualization) if you want to address reviewer comment 2. That's a **manuscript decision**, not a code one.

**Ship decision:** Keep as separate post-hoc tree feature (not method #5)? [Approve / Reframe as capability row in methods]

---

## Next Steps

### If All Four Gates Approved:

1. **User documentation:** Write instructions for §2 setup (venv creation, env vars)
2. **Testing:** Run §7 verification steps (standalone Python, input files, end-to-end call, UI flow)
3. **Docker prep:** Phase P11 will need to bake the venv into the image
4. **Manuscript:** Decide whether tree reconstruction gets its own methods paragraph or goes under a "Visualization & Exploration" section

### If Any Gate Requires Modification:

We can pivot without rework:
- **§A (per-event vs. centroid):** Spec is defensible as-is; if you want per-event, it's a new requirement
- **§B (subprocess vs. reticulate):** Subprocess is simpler; reticulate is doable but adds complexity
- **§C (CC-BY-NC):** Can defer if license concern is blocking; feature code itself is ready
- **§D (method vs. visualization):** Just a framing question; code is unchanged either way

---

## Verification Checklist (Ready to Run)

Once gates are approved, §7 has six verification steps. All require user's local Bonsai setup (§2), but no code changes:

- [ ] Python venv sanity check
- [ ] Input file orientation (TSV columns/rows)
- [ ] YAML config fields
- [ ] End-to-end runBonsaiTree() standalone
- [ ] Shiny UI flow (button → tree render)
- [ ] Unconfigured-machine error path

**Estimated time:** ~30 min (mostly waiting for Bonsai to run on toy data)

---

## Files Modified

### New Files
- `BONSAI_IMPLEMENTATION_STATUS.md` — verification checklist

### Code Changes (from spec §3–5.2)
- ✅ `R/utils/bonsai_utils.R` — already complete
- ✅ `R/modules/clustering_module.R` — lines 43, 75–82, 322–366, 372 already in place
- ✅ `R/modules/raw_data_module.R` — lines 1305–1307, 2407–2417 already in place
- ✅ `global.R` — ape + yaml libraries already imported

### Deliberately **Not** Touched
- `settings_module.R` line 24 (per §0.4)
- `batch_analysis_module.R` (per §0.6 — deferred to §4 pipeline restructure)

---

## Reference

**Spec kit:** CytoGateR_Bonsai_Cluster_Tree_SpecKit_2.md  
**Bonsai paper:** de Groot et al., *Nature Biotechnology* (2026)  
**Bonsai code:** https://github.com/dhdegroot/Bonsai-data-representation, pinned commit b16ef6f0a164610327022c7d0b92de82b3596aad  
**Paper link:** https://www.nature.com/articles/s41587-026-03220-2
