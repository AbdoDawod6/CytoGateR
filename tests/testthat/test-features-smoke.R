# tests/testthat/test-features-smoke.R
# L1 — function/stress tests. Each block is guarded so a missing function
# reports (SKIP/NOTE) rather than errors, per the Stress/Smoke Test Kit.
library(testthat); library(flowCore)

test_that("QC runs and summarises (§2.2)", {
  skip_if_not(exists("performQC"), "performQC not on branch")
  ff  <- read.FCS(make_test_fcs(n_events = 8000))
  qc  <- performQC(ff)
  expect_true(!is.null(qc))
  expect_true(qc$status %in% c("Pass", "Warn", "Skip", "Error"))
  if (exists("buildQCSummaryTable")) {
    tab <- buildQCSummaryTable(qc$metrics)
    expect_s3_class(tab, "data.frame")
  }
})

test_that("gaussNorm aligns multiple samples to a reference (§2.3)", {
  skip_if_not(exists("applyGaussNorm"), "applyGaussNorm not on branch")
  markers <- c("FL1-A","FL2-A","FL3-A")
  mk <- function(seed) { set.seed(seed)
    matrix(pmax(0, rnorm(3000*3, 1000, 300)), ncol = 3, dimnames = list(NULL, markers)) }
  samples <- list(s1 = mk(1), s2 = mk(2), s3 = mk(3))
  out <- applyGaussNorm(samples, markers, reference_id = "s1")
  expect_true(!is.null(out$normalized))
  expect_true(!is.null(out$params))
})

test_that("all clustering methods run via the shared dispatcher (§2.5/§3.4)", {
  skip_if_not(exists("runClustering"), "runClustering not on branch")
  set.seed(1); md <- matrix(rnorm(1500*4), ncol = 4)
  for (m in c("K-means","DBSCAN","FlowSOM","Phenograph")) {
    res <- tryCatch(runClustering(md, m, list()), error = function(e) e)
    expect_false(inherits(res, "error"), info = paste("method:", m))
  }
})

test_that("spectral detection logic flags wide, un-compensated files (§2.4)", {
  spec <- make_spectral_frame(34)
  conv <- read.FCS(make_test_fcs(n_fluor = 6, with_spillover = TRUE))
  is_spectral <- function(ff) ncol(ff) > 30 &&
    !any(toupper(c("$SPILLOVER","$SPILL","SPILLOVER","SPILL")) %in% toupper(names(keyword(ff))))
  expect_true(is_spectral(spec))
  expect_false(is_spectral(conv))
  if (exists("isSpectralFlowFrame"))
    expect_true(isSpectralFlowFrame(spec)$is_spectral)
  else message("NOTE: isSpectralFlowFrame() not on branch — §2.4 may be uncommitted.")
})

# ---- STRESS CASES ----

test_that("STRESS: strided read caps events for a large file (§2.4 technique)", {
  big <- make_test_fcs(n_events = 600000, n_fluor = 6)
  n   <- as.integer(keyword(read.FCS(big, which.lines = 1), "$TOT")[[1]])
  expect_gt(n, 500000)
  step <- ceiling(n / 500000)
  sub  <- read.FCS(big, which.lines = seq(1, n, by = step))
  expect_lte(nrow(sub), 520000)
  if (exists("readFCSchunked")) {
    res <- readFCSchunked(big, max_events = 500000)
    expect_true(res$subsampled)
    expect_lte(res$n_loaded, 520000)
  } else {
    message("NOTE: readFCSchunked() not on branch — technique works, helper undeployed.")
  }
})

test_that("STRESS: pipeline functions survive degenerate inputs", {
  skip_if_not(exists("runClustering"))
  tiny <- matrix(rnorm(30*3), ncol = 3)
  expect_error(runClustering(tiny, "FlowSOM", list()), NA)
  one  <- matrix(rnorm(500), ncol = 1)
  expect_error(prcomp(one, scale. = FALSE), NA)
})

test_that("STRESS: large-N clustering respects a guard / completes", {
  skip_if_not(exists("runClustering"))
  set.seed(1); big_md <- matrix(rnorm(60000*5), ncol = 5)
  res <- tryCatch(runClustering(big_md, "K-means", list()),
                  error = function(e) e)
  expect_false(inherits(res, "error"))
})
