# Bonsai Cluster-Relationship Tree — One-Time Setup Guide

**What this does:** Enables the "Build Cluster Tree" feature in CytoGateR. This reconstructs a phylogenetic-style tree showing relationships between your identified cell clusters.

**Time required:** ~10 minutes (mostly waiting for package downloads)

**OS:** Windows / macOS / Linux (these instructions are platform-agnostic)

---

## Step 1: Clone the Bonsai Repository

Clone the Bonsai source code to a **stable location** (not inside CytoGateR, and not a temp folder):

```bash
git clone https://github.com/dhdegroot/Bonsai-data-representation.git
cd Bonsai-data-representation
git checkout b16ef6f0a164610327022c7d0b92de82b3596aad
```

This gives you the exact version that CytoGateR expects. Note the full path to this directory — you'll need it in Step 3.

**Example paths:**
- Windows: `C:\Users\YourName\tools\Bonsai-data-representation`
- macOS/Linux: `/home/yourname/tools/Bonsai-data-representation` or `~/tools/Bonsai-data-representation`

---

## Step 2: Create a Python Virtual Environment

Open R and run:

```r
reticulate::install_python("3.14")
reticulate::virtualenv_create(
  "bonsai-env",
  python_version = "3.14",
  packages = c(
    "numpy==2.4.6", 
    "scipy==1.17.1", 
    "pandas==3.0.3",
    "scikit-learn==1.9.0", 
    "ruamel.yaml==0.19.1", 
    "psutil==7.2.2"
  )
)
```

This creates an isolated Python environment in your R user library directory (typically `~/.virtualenvs/bonsai-env/` on Unix, or `C:\Users\YourName\AppData\Local\R\cache\R\renv\` on Windows).

**Note:** If you already have Python 3.14 installed system-wide and want to use it instead:

```r
reticulate::virtualenv_create(
  "bonsai-env",
  python = "/path/to/your/python3.14",  # or "C:\\Python314\\python.exe"
  packages = c(...)
)
```

---

## Step 3: Get Paths to Environment Variables

After Step 2, find the path to the venv's Python executable:

**In R:**
```r
reticulate::virtualenv_python("bonsai-env")
# Copy the output — it will be something like:
# /home/yourname/.virtualenvs/bonsai-env/bin/python (Unix)
# C:\Users\YourName\AppData\Local\r-miniconda3\envs\bonsai-env\Scripts\python.exe (Windows)
```

You now have two paths:
1. **CYTOGATER_BONSAI_REPO** = the full path to your cloned Bonsai directory from Step 1
2. **CYTOGATER_BONSAI_PYTHON** = the full path to the venv's python from the command above

---

## Step 4: Set Environment Variables

Choose *one* of these methods:

### Option A: Project-Level (Recommended for Teams)

Create a `.Renviron` file in your CytoGateR project root:

```bash
# File: .gitignore_this_file.Renviron (or just .Renviron if you're not sharing)
CYTOGATER_BONSAI_REPO=/absolute/path/to/Bonsai-data-representation
CYTOGATER_BONSAI_PYTHON=/absolute/path/to/bonsai-env/bin/python
```

Then in RStudio, go to **Tools** → **Project Options** → **Build Tools**  
And in **Environment**, reference this file (or just ensure it's in your working directory — R will auto-read `.Renviron` if present).

**Better practice:** Add `.Renviron` to `.gitignore` so local paths don't leak into version control:
```
.Renviron
.env
```

### Option B: User-Level (Permanent)

Edit your user's `.Renviron` file (not the project one):

**On Windows:** Run `usethis::edit_r_environ()` in R, add the two lines above, save

**On macOS/Linux:** Edit `~/.Renviron` with a text editor, add the two lines, save

This makes the environment variables available to *all* R sessions on your machine.

### Option C: At Startup (Temporary, for Testing)

Add to your R session before starting the Shiny app:
```r
Sys.setenv(CYTOGATER_BONSAI_REPO = "/path/to/Bonsai-data-representation")
Sys.setenv(CYTOGATER_BONSAI_PYTHON = "/path/to/bonsai-env/bin/python")
```

(Not recommended for daily use—you'd need to do this every session.)

---

## Step 5: Verify Setup

**In a fresh R console** (to ensure `.Renviron` was read), run:

```r
# Check that variables are set
Sys.getenv("CYTOGATER_BONSAI_REPO")
Sys.getenv("CYTOGATER_BONSAI_PYTHON")

# Check that the venv's Python can import required packages
system2(Sys.getenv("CYTOGATER_BONSAI_PYTHON"), 
        args = c("-c", "import numpy, scipy, pandas, sklearn, ruamel.yaml, psutil; print('OK')"))

# Should print: "OK"
```

If you see "OK", setup is complete. If you see an error, go back to Step 2 and verify the venv was created correctly.

---

## Step 6: Start CytoGateR

```r
shiny::runApp("path/to/CytoGateR")
# or just click Run App in RStudio
```

Once the app loads, you should see a new button in the Clustering panel:  
**"Build Cluster Tree (Bonsai)"**

---

## Using the Feature

1. **Load a FCS file** and preprocess it
2. **Run Clustering** (K-means, DBSCAN, FlowSOM, or Phenograph) — get 3+ clusters
3. **Click "Build Cluster Tree (Bonsai)"** — a progress notification appears
4. **Wait ~5–30 seconds** (depending on number of clusters and markers)
5. **View the tree** in the new **"Cluster Relationship Tree"** tab

The tree shows your clusters as leaves and reconstructs a phylogenetic-style backbone showing which clusters are most similar.

---

## Troubleshooting

### "Bonsai is not configured on this machine"
- Set `CYTOGATER_BONSAI_REPO` and `CYTOGATER_BONSAI_PYTHON` (see Step 4)
- Restart R / restart RStudio (to re-read `.Renviron`)

### "bonsai_main.py not found"
- Check that `CYTOGATER_BONSAI_REPO` points to the correct directory
- Verify the directory contains `bonsai/bonsai_main.py`

### "Python exited with status 1"
- Check `~/.Renviron` or `.Renviron` for typos in the paths
- Try running the venv's Python directly in a terminal: `$CYTOGATER_BONSAI_PYTHON --version`
- Check that the venv has all required packages: `pip list` in the venv

### "Bonsai needs at least 3 clusters"
- The tree feature requires 3+ clusters to build a tree
- Re-run clustering with parameters that produce more clusters

### "ModuleNotFoundError: No module named 'bonsai'"
- This is expected — Bonsai runs as a subprocess (not imported in R)
- If you see this error in the R console, it means the Python subprocess call failed
- Double-check paths and venv contents

---

## Advanced: Using a System Python Instead

If you prefer to manage Python outside of R:

```bash
# Create the venv yourself
python3.14 -m venv ~/my-bonsai-venv
source ~/my-bonsai-venv/bin/activate  # or: my-bonsai-venv\Scripts\activate on Windows
pip install numpy==2.4.6 scipy==1.17.1 pandas==3.0.3 scikit-learn==1.9.0 ruamel.yaml==0.19.1 psutil==7.2.2
deactivate
```

Then set the env vars to point to that venv's python:
```r
Sys.setenv(CYTOGATER_BONSAI_PYTHON = "~/my-bonsai-venv/bin/python")
```

---

## Support

If setup fails:
1. Verify all paths are absolute (not relative) and exist: `dir.exists(Sys.getenv("CYTOGATER_BONSAI_REPO"))`
2. Check that Python can be run: `system(paste(Sys.getenv("CYTOGATER_BONSAI_PYTHON"), "--version"))`
3. Consult the CytoGateR repository Issues or contact Dr. Helmy

---

## Reference

- **Bonsai paper:** de Groot et al., *Nature Biotechnology* (2026)  
  https://www.nature.com/articles/s41587-026-03220-2
- **Bonsai code:** https://github.com/dhdegroot/Bonsai-data-representation
- **CytoGateR repo:** https://github.com/AbdoDawod6/CytoGateR
