# Use a UTF-8 locale so accented player names survive import and export.
if (!l10n_info()[["UTF-8"]]) {
  for (locale in c("en_US.UTF-8", "C.UTF-8", "English_United States.utf8")) {
    suppressWarnings(try(Sys.setlocale("LC_CTYPE", locale), silent = TRUE))
    if (l10n_info()[["UTF-8"]]) break
  }
}
if (!l10n_info()[["UTF-8"]]) stop("A UTF-8 locale is required to preserve player names.")
# Reads code chunks without editing or rendering the source notebook.
read_chunks <- function(path) {
  lines <- readLines(path, warn = FALSE, encoding = "UTF-8")
  chunks <- list(); code <- character(); inside <- FALSE; label <- ""
  for (line in lines) {
    if (!inside && grepl("^```\\{r", line)) {
      inside <- TRUE; code <- character()
      label <- sub("^```\\{r\\s*([^,}]*).*$", "\\1", line)
    } else if (inside && grepl("^```\\s*$", line)) {
      chunks[[length(chunks) + 1L]] <- list(label = trimws(label), code = paste(code, collapse = "\n"))
      inside <- FALSE
    } else if (inside) code <- c(code, line)
  }
  chunks
}
write_dashboard <- function(payload) {
  template <- paste(readLines("dashboard/template.html", warn = FALSE, encoding = "UTF-8"), collapse = "\n")
  json <- jsonlite::toJSON(payload, auto_unbox = TRUE, dataframe = "rows", digits = 7, na = "null", null = "null")
  # Prevent source data from closing the embedded JSON script element.
  json <- gsub("<", "\\u003c", json, fixed = TRUE)
  compressed <- tempfile(fileext = ".gz")
  con <- gzfile(compressed, "wb"); writeBin(charToRaw(enc2utf8(json)), con); close(con)
  json <- jsonlite::base64_enc(readBin(compressed, "raw", n = file.info(compressed)$size))
  unlink(compressed)
  marker <- "__DASHBOARD_DATA__"
  parts <- strsplit(template, marker, fixed = TRUE)[[1]]
  stopifnot(length(parts) == 2L)
  writeLines(paste0(parts[1], json, parts[2]), "dashboard/index.html", useBytes = TRUE)
  message("Built dashboard/index.html for ", length(payload$players), " players.")
}
if (!file.exists("dashboard/template.html")) stop("Run this script from the repository root.")
for (pkg in c("knitr", "jsonlite")) if (!requireNamespace(pkg, quietly = TRUE)) stop("Install package: ", pkg)
options(timeout = max(600, getOption("timeout")))
dir.create("dashboard", showWarnings = FALSE)

if (!requireNamespace("arrow", quietly = TRUE)) stop("Install package: arrow")
e <- new.env(parent = globalenv())
chunks <- read_chunks("PlayerShotChart_Efficiency_Reusable.Rmd")
# Only the original data preparation chunks are needed; model fitting below is per player.
wanted <- c("settings", "load-data", "load-third-season", "clean-shots", "shot-scope", "standardize-third-season")
for (label in wanted) {
  hit <- Filter(function(x) identical(x$label, label), chunks)
  if (length(hit) != 1L) stop("Expected one source chunk: ", label)
  eval(parse(text = hit[[1]]$code), envir = e)
}
cols <- c("SEASON_2", "SEASON_END_YEAR", "GAME_ID", "PLAYER_ID", "PLAYER_NAME", "BASIC_ZONE", "SHOT_DISTANCE", "LOC_X", "LOC_Y", "made", "shot_value", "points")
shots <- rbind(e$shots_clean[, cols], e$shots_2026_clean[, cols])
shots <- shots[e$in_scope(shots), , drop = FALSE]
stopifnot(nrow(shots) > 0L, all(is.finite(shots$LOC_X)), all(is.finite(shots$LOC_Y)))
shots$PLAYER_ID <- as.character(shots$PLAYER_ID)
# Binomial sufficient statistics preserve the original per-shot likelihood while
# making one leave-player-out fit per player practical.
train <- subset(shots, SEASON_END_YEAR == e$training_year)
league_cells <- aggregate(cbind(makes = train$made, attempts = rep(1L, nrow(train))) ~ BASIC_ZONE + SHOT_DISTANCE, data = train, FUN = sum)
player_cells <- aggregate(cbind(makes = train$made, attempts = rep(1L, nrow(train))) ~ PLAYER_ID + BASIC_ZONE + SHOT_DISTANCE, data = train, FUN = sum)
key <- function(d) paste(d$BASIC_ZONE, d$SHOT_DISTANCE, sep = "|")
cell_key <- key(league_cells)
ids <- sort(unique(shots$PLAYER_ID)); players <- list(); skipped <- list()
for (id in ids) {
  s <- shots[shots$PLAYER_ID == id, , drop = FALSE]
  pc <- player_cells[player_cells$PLAYER_ID == id, , drop = FALSE]
  fit_data <- league_cells
  m <- match(key(pc), cell_key)
  fit_data$makes[m] <- fit_data$makes[m] - pc$makes
  fit_data$attempts[m] <- fit_data$attempts[m] - pc$attempts
  fit_data <- fit_data[fit_data$attempts > 0, , drop = FALSE]
  fit_data$zone <- factor(fit_data$BASIC_ZONE)
  result <- tryCatch({
    # Derive knots from the ungrouped leave-player-out training distances.
    basis <- splines::ns(train$SHOT_DISTANCE[train$PLAYER_ID != id], df = 4)
    spline_knots <- attr(basis, "knots"); spline_boundary <- attr(basis, "Boundary.knots")
    model <- glm(cbind(makes, attempts - makes) ~ zone + splines::ns(SHOT_DISTANCE, knots = spline_knots, Boundary.knots = spline_boundary), data = fit_data, family = binomial())
    if (!model$converged) stop("Model did not converge")
    s$zone <- factor(s$BASIC_ZONE, levels = levels(fit_data$zone))
    s$prob <- as.numeric(predict(model, newdata = s, type = "response"))
    if (any(!is.finite(s$prob))) stop("Unrecognized zone or nonfinite prediction")
    s$expected <- s$prob * s$shot_value
    summarize <- function(d) {
      n <- nrow(d); makes <- sum(d$made); p <- makes/n; z <- qnorm(.975)
      center <- (p + z*z/(2*n))/(1+z*z/n)
      half <- z*sqrt(p*(1-p)/n+z*z/(4*n*n))/(1+z*z/n)
      list(attempts = n, makes = makes, fg = 100*p, actual = sum(d$points)/n,
           expected = sum(d$expected)/n, above = 100*sum(d$points-d$expected)/n,
           lower = 100*(center-half), upper = 100*(center+half))
    }
    seasons <- lapply(sort(unique(s$SEASON_2)), function(year) {
      d <- s[s$SEASON_2 == year, , drop = FALSE]
      zones <- lapply(sort(unique(d$BASIC_ZONE)), function(zone) {
        zd <- d[d$BASIC_ZONE == zone, , drop = FALSE]
        c(list(name = zone, share = 100*nrow(zd)/nrow(d)), summarize(zd))
      })
      # Plot all retained attempts; coordinates are rounded for file size only.
      pts <- lapply(seq_len(nrow(d)), function(i) c(round(d$LOC_X[i], 2), round(d$LOC_Y[i], 2), d$made[i]))
      c(list(season = year, zones = zones, shots = pts), summarize(d))
    })
    list(id = id, name = as.character(tail(s$PLAYER_NAME, 1)), seasons = seasons)
  }, error = function(err) {skipped[[length(skipped)+1L]] <<- list(id = id, reason = conditionMessage(err)); NULL})
  if (!is.null(result)) players[[length(players)+1L]] <- result
  if (length(players) %% 50L == 0L) message("Computed ", length(players), " player profiles")
}
if (!length(players)) stop("No player profiles built")
# Repair UTF-8 names that the archive has already decoded as Latin-1.
# IDs remain authoritative; this only changes display labels.
repair_name <- function(x) {
  candidate <- suppressWarnings(iconv(x, from = "UTF-8", to = "latin1"))
  if (is.na(candidate)) return(x)
  Encoding(candidate) <- "UTF-8"
  if (validUTF8(candidate)) candidate else x
}
players <- lapply(players, function(p) {p$name <- repair_name(p$name); p})
players <- players[order(vapply(players, function(p) p$name, character(1))) ]
write_dashboard(list(kind = "shot", title = "Player Shot Efficiency", built = as.character(Sys.Date()), default = "1630202", players = players, skipped = skipped, training_year = e$training_year, source_sha = unname(tools::md5sum("PlayerShotChart_Efficiency_Reusable.Rmd"))))
# Keep sufficient statistics and a small sample for meaningful equivalence checks.
saveRDS(list(league_cells = league_cells, player_cells = player_cells, shots = shots[shots$PLAYER_ID == "1630202", ], train_sample = train[, c("PLAYER_ID", "BASIC_ZONE", "SHOT_DISTANCE", "made")]), "dashboard/verification.rds")
