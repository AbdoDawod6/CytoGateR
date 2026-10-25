# Clustering utility functions for Flow Cytometry Analysis

# Function to run K-means clustering
runKmeansClustering <- function(marker_data, num_clusters = 8) {
  set.seed(123)  # For reproducibility
  
  tryCatch({
    # Run K-means
    km <- kmeans(marker_data, centers = num_clusters, nstart = 10)
    cluster_ids <- km$cluster
    
    # Store cluster centers for intensity profiles
    centers <- km$centers
    colnames(centers) <- colnames(marker_data)
    
    # Create results object
    results <- list(
      cluster_ids = cluster_ids,
      centers = centers,
      method = "K-means"
    )
    
    return(results)
  }, error = function(e) {
    warning("K-means clustering failed: ", e$message)
    return(NULL)
  })
}

# ---- DBSCAN Clustering ----
runDbscanClustering <- function(marker_data, eps = 0.5, minPts = 5) {
  tryCatch({
    # Scale data for DBSCAN
    scaled_markers <- scale(marker_data)
    
    # Run DBSCAN
    dbscan_result <- dbscan::dbscan(scaled_markers, eps = eps, minPts = minPts)
    cluster_ids <- dbscan_result$cluster
    
    # Handle noise points (cluster 0)
    if (any(cluster_ids == 0)) {
      max_cluster <- max(cluster_ids)
      cluster_ids[cluster_ids == 0] <- max_cluster + 1
    }
    
    # Calculate cluster centers (mean of each cluster)
    unique_clusters <- sort(unique(cluster_ids))
    centers <- t(sapply(unique_clusters, function(cl) {
      colMeans(marker_data[cluster_ids == cl, , drop = FALSE])
    }))
    
    colnames(centers) <- colnames(marker_data)
    rownames(centers) <- paste("Cluster", unique_clusters)
    
    # Create results object
    results <- list(
      cluster_ids = cluster_ids,
      centers = centers,
      method = "DBSCAN"
    )
    
    return(results)
  }, error = function(e) {
    warning("DBSCAN clustering failed: ", e$message)
    return(NULL)
  })
}

# ---- FlowSOM Clustering ----
runFlowSomClustering <- function(marker_data, xdim = 6, ydim = 6, n_metaclusters = 12, rlen = 10) {
  tryCatch({
    # Create a flowFrame from the matrix with proper marker names
    marker_matrix <- as.matrix(marker_data)
    colnames(marker_matrix) <- colnames(marker_data)
    fcs_data <- flowCore::flowFrame(marker_matrix)
    
    # Set proper column names in the flowFrame parameters
    params <- flowCore::parameters(fcs_data)
    params$name <- colnames(marker_data)
    params$desc <- colnames(marker_data)
    flowCore::parameters(fcs_data) <- params
    
    # Use ReadInput to properly prepare the data for FlowSOM
    fsom_input <- FlowSOM::ReadInput(fcs_data, transform = FALSE, scale = FALSE)
    
    # Build the SOM with validated parameters
    fsom <- FlowSOM::BuildSOM(
      fsom_input, 
      colsToUse = NULL,  # Use all columns
      xdim = xdim,       # Validated x dimension
      ydim = ydim,       # Validated y dimension
      rlen = rlen,       # Training iterations
      silent = FALSE     # Show progress
    )
    
    # Get metaclusters
    # Computed directly via hierarchical clustering + cutree instead of
    # FlowSOM::MetaClustering()'s auto-selecting wrapper -- that wrapper
    # (a) auto-picks the "best" k up to `max` via its own stability
    # criterion and can silently return fewer groups than requested
    # (confirmed: returned 3 instead of 12), and (b) in this installed
    # FlowSOM version has no `min` parameter to pin the search down
    # (confirmed: "unused argument (min = 12)"). cutree(..., k = ) always
    # returns exactly k groups, independent of FlowSOM's internal API.
    som_dist    <- stats::dist(fsom$map$codes)
    som_hclust  <- stats::hclust(som_dist, method = "average")
    metacl      <- stats::cutree(som_hclust, k = n_metaclusters)
  
    
    # Get cluster IDs for each cell
    # First map to SOM clusters
    cell_som_clusters <- fsom$map$mapping[,1]
    # Then map to metaclusters
    cell_metaclusters <- metacl[cell_som_clusters]
    
    # Calculate metacluster centers (mean of each cluster)
    unique_clusters <- sort(unique(cell_metaclusters))
    centers <- t(sapply(unique_clusters, function(cl) {
      colMeans(marker_data[cell_metaclusters == cl, , drop = FALSE])
    }))
    
    colnames(centers) <- colnames(marker_data)
    rownames(centers) <- paste("Cluster", unique_clusters)
    
    # Create results object
    results <- list(
      cluster_ids = cell_metaclusters,
      centers = centers,
      som_object = fsom,
      som_clusters = cell_som_clusters,
      metaclusters = metacl,
      method = "FlowSOM"
    )
    
    return(results)
  }, error = function(e) {
    warning("FlowSOM clustering failed: ", e$message)
    return(NULL)
  })
}

# ---- Phenograph Clustering ----
runPhenographClustering <- function(marker_data, k = 30) {
  tryCatch({
    # Run Phenograph
    pheno_result <- Rphenograph(as.matrix(marker_data), k = k)
    
    # Get cluster IDs
    cluster_ids <- as.numeric(membership(pheno_result[[2]]))
    
    # Calculate cluster centers (mean of each cluster)
    unique_clusters <- sort(unique(cluster_ids))
    centers <- t(sapply(unique_clusters, function(cl) {
      colMeans(marker_data[cluster_ids == cl, , drop = FALSE])
    }))
    
    colnames(centers) <- colnames(marker_data)
    rownames(centers) <- paste("Cluster", unique_clusters)
    
    # Create results object
    results <- list(
      cluster_ids = cluster_ids,
      centers = centers,
      pheno_object = pheno_result,
      method = "Phenograph"
    )
    
    return(results)
  }, error = function(e) {
    warning("Phenograph clustering failed: ", e$message)
    return(NULL)
  })
}

# ---- Unified Dispatcher ----
`%||%` <- function(a, b) if (!is.null(a)) a else b

runClustering <- function(marker_data, method, params = list()) {
  switch(method,
         "K-means" = runKmeansClustering(marker_data, params$num_clusters %||% 8),
         "DBSCAN"  = runDbscanClustering(marker_data, params$eps %||% 0.5, params$minPts %||% 5),
         "FlowSOM" = runFlowSomClustering(marker_data,
                                          xdim = params$xdim %||% 6,
                                          ydim = params$ydim %||% 6,
                                          n_metaclusters = params$n_metaclusters %||% 12,
                                          rlen = params$rlen %||% 10),
         "Phenograph" = runPhenographClustering(marker_data, params$k %||% 30),
         stop("Unsupported clustering method"))
}

# ---- Cell Type Identification ----
identify_cell_populations <- function(cluster_centers, marker_names,
                                      high_threshold = 0.5,
                                      low_threshold = -0.4,
                                      min_confidence = 0.3) {

  # Create results dataframe
  results <- data.frame(
    Cluster = 1:nrow(cluster_centers),
    Population = rep("Unknown", nrow(cluster_centers)),
    Confidence = rep(0, nrow(cluster_centers)),
    MatchDetails = rep("", nrow(cluster_centers)),
    stringsAsFactors = FALSE
  )

  # Define cell population templates based on this panel
  cell_population_templates <- list(
    "Total T cells" = list(
      high = c("CD3"),
      medium = c(),
      low = c("MHCII")
    ),
    "CD4+ T cells" = list(
      high = c("CD3", "CD4"),
      medium = c(),
      low = c()
    ),
    "CD8+ T cells" = list(
      high = c("CD3"),
      medium = c(),
      low = c("CD4")
    ),
    "T helper 1 (TH1)" = list(
      high = c("CD3", "CD4", "CXCR3"),
      medium = c(),
      low = c("FOXP3")
    ),
    "T regulatory (Treg)" = list(
      high = c("CD3", "CD4", "FOXP3"),
      medium = c(),
      low = c("CXCR3")
    ),
    "T follicular helper (TFH)" = list(
      high = c("CD3", "CD4", "CXCR5", "BCL6"),
      medium = c(),
      low = c()
    ),
    "B cells" = list(
      high = c("MHCII"),
      medium = c(),
      low = c("CD3")
    ),

    # -- PBMC memory/lineage panel additions (CD3/CD4/CD8/CD19/CD14/CD45RA/CCR7) --
    # B cells and monocytes called directly off their defining markers,
    # since this panel has them (the original template above proxies B
    # cells off MHCII because its panel lacks CD19).
    "B cells (CD19+)" = list(
      high = c("CD19"),
      medium = c(),
      low = c("CD3", "CD14")
    ),
    "Monocytes" = list(
      high = c("CD14"),
      medium = c(),
      low = c("CD3", "CD19")
    ),

    # CD4+ T cell memory/naive subsets (Sallusto scheme: CD45RA x CCR7)
    "Naive CD4+ T cells" = list(
      high = c("CD3", "CD4", "CD45RA", "CCR7"),
      medium = c(),
      low = c()
    ),
    "Central Memory CD4+ T cells" = list(
      high = c("CD3", "CD4", "CCR7"),
      medium = c(),
      low = c("CD45RA")
    ),
    "Effector Memory CD4+ T cells" = list(
      high = c("CD3", "CD4"),
      medium = c(),
      low = c("CD45RA", "CCR7")
    ),
    "TEMRA CD4+ T cells" = list(
      high = c("CD3", "CD4", "CD45RA"),
      medium = c(),
      low = c("CCR7")
    ),

    # CD8+ T cell memory/naive subsets (same scheme, called off the real
    # CD8 marker this panel has -- more specific than the existing
    # "CD8+ T cells" template above, which proxies off low CD4 for a
    # panel that lacks CD8 entirely)
    "Naive CD8+ T cells" = list(
      high = c("CD3", "CD8", "CD45RA", "CCR7"),
      medium = c(),
      low = c()
    ),
    "Central Memory CD8+ T cells" = list(
      high = c("CD3", "CD8", "CCR7"),
      medium = c(),
      low = c("CD45RA")
    ),
    "Effector Memory CD8+ T cells" = list(
      high = c("CD3", "CD8"),
      medium = c(),
      low = c("CD45RA", "CCR7")
    ),
    "TEMRA CD8+ T cells" = list(
      high = c("CD3", "CD8", "CD45RA"),
      medium = c(),
      low = c("CCR7")
    )
  )

  # Function to clean and standardize marker names
  clean_marker_name <- function(name) {
    # Convert to uppercase
    name <- toupper(name)

    # Remove common prefixes/suffixes and special characters
    name <- gsub("FL[0-9]+-[A-Z]+ *- *", "", name)
    name <- gsub(" +[A-Z0-9]+(-[A-Z0-9]+)*$", "", name)
    name <- gsub("[-_\\s]+", "", name)

    return(name)
  }

  # Manual mapping for the specific markers in your dataset
  manual_mapping <- list(
    # Original channel names
    "FL5-A - CD3 FITC FITC-A" = "CD3",
    "FL13-A - CD4 APCCy7 APC-A750-A" = "CD4",
    "FL11-A - MHC II AF647 APC-A" = "MHCII",
    "FL12-A - Foxp3 A700 APC-A700-A" = "FOXP3",
    "FL1-A - CXCR5 BV421 PB450-A" = "CXCR5",
    "FL6-A - CXCR3 PE PE-A" = "CXCR3",  # Added CXCR3 marker
    "FL7-A - BCl6 PE PE-A" = "BCL6",
    "FL10-A - Ki67 PECy7 PC7-A" = "KI67",
    "FL3-A - Live Dead BV570 Violet610-A" = "LIVEDEAD",

    # Channel numbers alone
    "FL5-A" = "CD3",
    "FL13-A" = "CD4",
    "FL11-A" = "MHCII",
    "FL12-A" = "FOXP3",
    "FL1-A" = "CXCR5",
    "FL6-A" = "CXCR3",  # Added CXCR3 marker
    "FL7-A" = "BCL6",
    "FL10-A" = "KI67",
    "FL3-A" = "LIVEDEAD",

    # Direct marker names
    "CD3" = "CD3",
    "CD4" = "CD4",
    "MHC" = "MHCII",
    "FOXP3" = "FOXP3",
    "CXCR5" = "CXCR5",
    "CXCR3" = "CXCR3",  # Added CXCR3 marker
    "BCL6" = "BCL6",
    "KI67" = "KI67",
    "DEAD" = "LIVEDEAD",

    # PBMC memory/lineage panel (test_PBMC_10k.fcs) -- exact $PnN channel
    # names, mapped directly since clean_marker_name()'s suffix-stripping
    # regex requires a space before the fluorophore tag and these are
    # hyphenated with no space (e.g. "CD3-FITC", not "CD3 FITC").
    "CD3-FITC"      = "CD3",
    "CD4-PE"        = "CD4",
    "CD8-APC"       = "CD8",
    "CD19-BV421"    = "CD19",
    "CD14-PerCP"    = "CD14",
    "LD-BV510"      = "LIVEDEAD",
    "CD45RA-PE-Cy7" = "CD45RA",
    "CCR7-APC-H7"   = "CCR7"
  )

  # Apply standardization to marker names
  normalized_markers <- sapply(marker_names, clean_marker_name)

  # Map markers using our manual mapping
  mapped_markers <- sapply(seq_along(marker_names), function(i) {
    raw <- marker_names[i]
    norm <- normalized_markers[i]
    manual_mapping[[raw]] %||% manual_mapping[[norm]] %||% norm
  })

  # Calculate z-scores for all markers across clusters
  z_scores <- apply(cluster_centers, 2, function(x) {
    if (sd(x, na.rm=TRUE) == 0) rep(0, length(x)) else (x - mean(x, na.rm=TRUE)) / sd(x, na.rm=TRUE)
  })

  # Add column names back to z-scores matrix
  colnames(z_scores) <- colnames(cluster_centers)

  # For each cluster, compare expression profile to templates
  for (i in 1:nrow(cluster_centers)) {
    best_match <- "Unknown"
    best_score <- 0
    best_weight <- 0  # track specificity so more-specific templates win ties
    best_details <- ""

    # Compare with each reference profile
    for (pop_name in names(cell_population_templates)) {
      template <- cell_population_templates[[pop_name]]
      score <- 0
      total_weight <- 0
      match_details <- c()

      # Check for high-expression markers
      for (marker in template$high) {
        idx <- which(mapped_markers == marker)
        if (length(idx)) {
          z <- z_scores[i, idx[1]]
          total_weight <- total_weight + 1
          if (!is.na(z) && z > high_threshold) {
            score <- score + 1
            match_details <- c(match_details, paste0(marker_names[idx[1]], "(+)"))
          }
        }
      }

      # Check for medium-expression markers
      for (marker in template$medium) {
        idx <- which(mapped_markers == marker)
        if (length(idx)) {
          z <- z_scores[i, idx[1]]
          total_weight <- total_weight + 0.7
          if (!is.na(z) && z > -0.2 && z < 0.7) {
            score <- score + 0.7
            match_details <- c(match_details, paste0(marker_names[idx[1]], "(~)"))
          }
        }
      }

      # Check for low-expression markers
      for (marker in template$low) {
        idx <- which(mapped_markers == marker)
        if (length(idx)) {
          z <- z_scores[i, idx[1]]
          total_weight <- total_weight + 0.5
          if (!is.na(z) && z < low_threshold) {
            score <- score + 0.5
            match_details <- c(match_details, paste0(marker_names[idx[1]], "(-)"))
          }
        }
      }

      # Calculate weighted confidence score
      if (total_weight > 0) {
        confidence <- score / total_weight
        # Prefer higher confidence; break ties in favour of more-specific
        # templates (higher total_weight) so e.g. "Naive CD4+ T cells"
        # (weight 4) beats the generic "CD4+ T cells" (weight 2) when both
        # score 100%.
        is_better <- confidence > min_confidence &&
          (confidence > best_score ||
             (isTRUE(all.equal(confidence, best_score)) && total_weight > best_weight))
        if (is_better) {
          best_score  <- confidence
          best_weight <- total_weight
          best_match  <- pop_name
          best_details <- paste(match_details, collapse = ", ")
        }
      }
    }

    # Assign the best matching population
    results$Population[i] <- best_match
    results$Confidence[i] <- round(best_score * 100, 1)
    results$MatchDetails[i] <- best_details
  }

  return(results)
}