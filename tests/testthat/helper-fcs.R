# tests/testthat/helper-fcs.R
# Build a synthetic FCS with known properties for testing/stress.
make_test_fcs <- function(path = tempfile(fileext = ".fcs"),
                          n_events = 5000, n_fluor = 6,
                          with_spillover = TRUE, seed = 1) {
  set.seed(seed)
  n_col <- n_fluor + 2                                   # + FSC-A, SSC-A
  m <- matrix(pmax(0, rnorm(n_events * n_col, 1000, 300)),
              nrow = n_events, ncol = n_col)
  colnames(m) <- c("FSC-A", "SSC-A", sprintf("FL%d-A", seq_len(n_fluor)))
  ff <- flowCore::flowFrame(m)
  if (with_spillover) {                                  # conventional file: carries a spillover keyword
    sp <- diag(n_col); dimnames(sp) <- list(colnames(m), colnames(m))
    flowCore::keyword(ff)[["$SPILLOVER"]] <- sp
  }
  flowCore::write.FCS(ff, path)
  path
}

# An in-memory spectral-like frame (>30 channels, NO spillover keyword) —
# used to test detection logic without a disk round-trip.
make_spectral_frame <- function(n_channels = 34, n_events = 500, seed = 2) {
  set.seed(seed)
  m <- matrix(pmax(0, rnorm(n_events * n_channels, 500, 150)),
              nrow = n_events, ncol = n_channels)
  colnames(m) <- sprintf("V%d-A", seq_len(n_channels))
  flowCore::flowFrame(m)                                 # no $SPILLOVER keyword set
}
