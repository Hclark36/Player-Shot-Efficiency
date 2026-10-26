if (!requireNamespace("jsonlite", quietly = TRUE)) stop("Install jsonlite first")
html <- paste(readLines("dashboard/index.html", warn = FALSE, encoding = "UTF-8"), collapse = "\n")
start <- '<script id="data" type="application/octet-stream">'
json <- strsplit(html, start, fixed = TRUE)[[1]][2]
json <- strsplit(json, '</script>', fixed = TRUE)[[1]][1]
json <- rawToChar(memDecompress(jsonlite::base64_dec(json), type = "gzip"))
d <- jsonlite::fromJSON(json, simplifyVector = FALSE)
ids <- vapply(d$players, function(p) p$id, character(1))
stopifnot(length(ids) > 0L, !anyDuplicated(ids), !grepl("__DASHBOARD_DATA__", html, fixed = TRUE))
for (p in d$players) for (s in p$seasons) {
  stopifnot(s$attempts == length(s$shots), is.finite(s$expected), s$expected >= 0, s$expected <= 3,
            sum(vapply(s$zones, function(z) z$attempts, numeric(1))) == s$attempts)
}
if (!file.exists("dashboard/verification.rds")) stop("Rebuild the dashboard before verifying model equivalence")
v <- readRDS("dashboard/verification.rds")
id <- "1630202"
t <- v$train_sample[v$train_sample$PLAYER_ID != id, ]
t$zone <- factor(t$BASIC_ZONE)
model <- glm(made ~ zone + splines::ns(SHOT_DISTANCE, df = 4), data = t, family = binomial())
s <- v$shots; s$zone <- factor(s$BASIC_ZONE, levels = levels(t$zone))
pred <- as.numeric(predict(model, newdata = s, type = "response")) * s$shot_value
p <- d$players[[which(ids == id)]]
for (ss in p$seasons) {
  expected <- mean(pred[s$SEASON_2 == ss$season])
  stopifnot(abs(expected - ss$expected) < 1e-5)
}
message("PASS: all shot totals, unique IDs, finite predictions, and per-shot model equivalence")
