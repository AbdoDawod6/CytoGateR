# Bonsai Feature — Test Execution & Verification Notes

**Date:** 2026-09-23  
**Test File:** `test_bonsai_cluster_tree.R` (provided by user)  
**Status:** Ready to execute; environment check complete

---

## What the Test Does

The file `test_bonsai_cluster_tree.R` is a comprehensive smoke test that:

1. **Generates synthetic PBMC data** (5 populations, 7 markers, 2,000 events)
   - CD4 T cells (CD3+, CD4+, FOXP3-)
   - CD8 T cells (CD3+, CD4-, CXCR3+)
   - Tregs (CD3+, CD4+, FOXP3+)
   - TFH (CD3+, CD4+, CXCR5+, BCL6+)
   - B cells (CD3-, MHCII+)

2. **Runs K-means clustering** (k=5) using existing `runClustering()` function

3. **Identifies populations** using existing `identify_cell_populations()` heuristic

4. **Calls `runBonsaiTree()`** to reconstruct a phylogenetic tree on cluster centers

5. **Renders the tree** using `plotBonsaiTree()` and saves PNG output

6. **Validates expectations:**
   - CD4, Treg, TFH should cluster together (all CD3+CD4+)
   - CD8 should branch separately (CD3+CD4-)
   - B cell should be far from T cells

---

## Prerequisites for Running

Before executing `test_bonsai_cluster_tree.R`, ensure:

### 1. Environment Variables Set
```r
Sys.getenv("CYTOGATER_BONSAI_REPO")     # should be non-empty
Sys.getenv("CYTOGATER_BONSAI_PYTHON")   # should be non-empty
```

Add to `.Renviron` (in CytoGateR root or user home):
```
CYTOGATER_BONSAI_REPO=/path/to/Bonsai-data-representation
CYTOGATER_BONSAI_PYTHON=/path/to/bonsai-env/bin/python
```

### 2. R Packages Installed
```r
install.packages(c("ape", "yaml"))
```

### 3. Python Venv Ready
```bash
python /path/to/bonsai-env/bin/python -c "import numpy, scipy, pandas, sklearn, ruamel.yaml, psutil; print('OK')"
# Should print: OK
```

### 4. Bonsai Repo Cloned (Pinned Commit)
```bash
git clone https://github.com/dhdegroot/Bonsai-data-representation.git
cd Bonsai-data-representation
git checkout b16ef6f0a164610327022c7d0b92de82b3596aad
```

---

## How to Run the Test

### Option 1: Interactive (Recommended for First Run)
```r
# In RStudio, with CytoGateR as working directory:
source("test_bonsai_cluster_tree.R")

# Produces:
#   - Console output showing clustering results, populations, tree structure
#   - PNG file: bonsai_tree_test_output.png (viewable in any image viewer)
```

### Option 2: Headless
```bash
cd /c/Users/abdel/Documents/CytoGateR
Rscript test_bonsai_cluster_tree.R
```

### Option 3: From R Console
```r
setwd("C:/Users/abdel/Documents/CytoGateR")
source("test_bonsai_cluster_tree.R")
```

---

## Expected Output

### Console Output (Markers of Success)
```
Synthetic data: 2000 events x 7 markers, 5 true populations
Running K-means clustering (k=5)...
Clustering done: 5 clusters found

True populations vs. discovered clusters:
              cluster
true_pop      1   2   3   4   5
  B cell    400   0   0   0   0    (perfectly separated)
  CD4 T cell  0 398   2   0   0    (mostly together)
  CD8 T cell  0   0   0 400   0    (perfectly separated)
  TFH         0   1   0   0 399    (mostly together)
  Treg        0   1   0   0 399    (mostly together)

Identifying cell populations from cluster centers...
Population identifications:
  Cluster Population Confidence Count
  1       B cell       0.95       400
  2       CD4 T cell   0.88       398
  3       ...
  4       CD8 T cell   0.92       400
  5       TFH          0.85       399

======================================================================
Building Bonsai cluster relationship tree...
======================================================================
Tree reconstructed successfully!
Cluster tips in tree: 5
Tree structure:
Phylogenetic tree with 5 tips and 4 internal nodes.
tip.label:
 [1] "Cluster_1" "Cluster_2" "Cluster_3" "Cluster_4" "Cluster_5"
...

✓ Test complete!
✓ Output saved to: bonsai_tree_test_output.png
======================================================================
SMOKE TEST PASSED ✓
```

### PNG File
Open `bonsai_tree_test_output.png` in any image viewer to see:
- Phylogram (tree drawn as branches)
- Cluster labels on tips
- Population labels if identified (e.g., "Cluster_2 (CD4 T cell)")
- Scale bar at bottom

**Expected topology:**
```
                    ┌─── Cluster_1 (B cell)
        ┌───────────┤
    ────┤           └─── Cluster_4 (CD8 T cell)
        │
        └─ ┌─── Cluster_2 (CD4 T cell)
           ├─── Cluster_3 (Treg)
           └─── Cluster_5 (TFH)
```

(T cell clusters should be closer to each other than to B cell)

---

## Troubleshooting

### Error: "Bonsai is not configured on this machine"
**Cause:** `CYTOGATER_BONSAI_REPO` or `CYTOGATER_BONSAI_PYTHON` not set  
**Fix:**
```r
Sys.setenv(CYTOGATER_BONSAI_REPO = "/full/path/to/Bonsai-data-representation")
Sys.setenv(CYTOGATER_BONSAI_PYTHON = "/full/path/to/bonsai-env/bin/python")
# Then re-run the test
```

### Error: "bonsai_main.py not found"
**Cause:** Path to Bonsai repo is incorrect  
**Fix:**
```bash
# Verify the repo has bonsai/bonsai_main.py:
ls /path/to/Bonsai-data-representation/bonsai/bonsai_main.py
# Should exist; if not, re-clone per prerequisites
```

### Error: "Python exited with status 1"
**Cause:** Bonsai subprocess failed (missing package, corrupted data, etc.)  
**Debug:**
```r
# Manually test Python venv:
system2(Sys.getenv("CYTOGATER_BONSAI_PYTHON"), 
        c("-c", "import numpy, scipy, pandas, sklearn, ruamel.yaml, psutil; print('OK')"))
# Should return 0 (success) and print OK
```

### Error: "Bonsai needs at least 3 clusters"
**Cause:** K-means failed to find 5 clusters (shouldn't happen with synthetic data)  
**Fix:** Check `runClustering()` output in console; may indicate deeper issue

### Timeout or Hang
**Cause:** Bonsai subprocess is slow or blocked  
**Action:** Wait ~30 seconds; Bonsai's first run can be slow. If still hung after 1 min:
```r
# Kill the R session and check manually:
system2(Sys.getenv("CYTOGATER_BONSAI_PYTHON"), 
        c("--version"))  # Should return instantly
```

---

## Verification Checklist

After running the test successfully, verify:

| Step | Check | Status |
|------|-------|--------|
| 1 | `test_bonsai_cluster_tree.R` runs without crashing | [ ] |
| 2 | K-means clustering completes (5 clusters found) | [ ] |
| 3 | Population identification works | [ ] |
| 4 | `runBonsaiTree()` returns a phylo object (not NULL) | [ ] |
| 5 | `bonsai_tree_test_output.png` is created | [ ] |
| 6 | PNG shows phylogram with 5 tips | [ ] |
| 7 | Tree topology matches population relationships (see Expected Output) | [ ] |
| 8 | Population labels appear on tree tips | [ ] |

**If all 8 pass:** ✅ Bonsai feature is working correctly

---

## Next Steps After Test Passes

1. **Run on real FCS data:**
   - Load an actual PBMC FCS file
   - Preprocess (QC, normalization, scaling)
   - Run clustering (any method)
   - Click "Build Cluster Tree" in Shiny UI
   - Verify tree appears in new tab

2. **Test error paths:**
   - Unset `CYTOGATER_BONSAI_REPO` → button click should show error notification
   - Run clustering with <3 clusters → button click should show "needs 3+" error
   - Close browser mid-tree-build → no crash, silent discard

3. **Test UI flow:**
   - Re-run clustering with different method → rebuild tree → verify tree changes
   - Merge clusters via "Merge Similar Clusters" → rebuild tree → verify population labels update

4. **Documentation:**
   - Verify user setup instructions work for someone else
   - Test on Windows/macOS/Linux if possible
   - Confirm troubleshooting section covers common issues

---

## Reference

**Test File:** `test_bonsai_cluster_tree.R` (provided 2026-09-23)  
**Bonsai Repo:** github.com/dhdegroot/Bonsai-data-representation  
**Pinned Commit:** b16ef6f0a164610327022c7d0b92de82b3596aad

---

## Notes for Implementation Verification

This test file was **designed to be runnable standalone** (outside Shiny) to verify the feature before integrating into the app. It:

- ✅ Uses existing CytoGateR utility functions (runClustering, identify_cell_populations)
- ✅ Calls new Bonsai functions directly (computeClusterMeanSEM, runBonsaiTree, plotBonsaiTree)
- ✅ Avoids Shiny reactives and async patterns (not needed in standalone R)
- ✅ Includes realistic PBMC population simulation
- ✅ Saves PNG output for visual inspection
- ✅ Has clear success/failure criteria

**If this test passes, the feature is verified ready for Shiny integration testing (step 5 of §7 in spec kit).**

