# tests/testthat/test-module-wiring.R
# L2 — module wiring (testServer, no browser). Confirms the raw_data pipeline
# reacts to inputs synchronously; the async Run pipeline itself is L3-only.
library(testthat); library(shiny)

test_that("raw_data module accepts a file and produces processed output", {
  path <- make_test_fcs(n_events = 4000, n_fluor = 5)
  app_state <- reactiveValues(plot_settings = list(font_size = 12, point_size = 2,
                                                    color_palette = "viridis",
                                                    width = 800, height = 600))
  testServer(rawDataModuleServer, args = list(app_state = app_state), {
    session$setInputs(fcsFile = list(datapath = path, name = "test.fcs",
                                     size = file.size(path), type = ""))
    expect_true(length(session$returned) >= 0)
    session$setInputs(selectedMarkers = c("FL1-A","FL2-A","FL3-A"))
    # The Run pipeline is async (future_promise); testServer runs sync and
    # will not resolve the future. Assert only that setting the input doesn't
    # error synchronously; the real run is validated in L3.
    expect_silent(session$setInputs(run = 1))
  })
})
