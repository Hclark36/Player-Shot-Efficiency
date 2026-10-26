# Searchable shot efficiency dashboard

**[Download the dashboard HTML](https://github.com/Hclark36/Player-Shot-Efficiency/raw/refs/heads/main/dashboard/index.html)** and open the downloaded file in Chrome, Safari, Edge, or Firefox. No R installation or server is required to explore the precomputed results.

GitHub's normal HTML file view shows source code. Click **Download raw file** on `index.html`, or download the repository and open `dashboard/index.html` locally. This repository does not currently publish the dashboard as a hosted website.

## Use the dashboard

- Type part of a player's name in **Search player name**; accents are optional.
- Choose a player from the filtered list.
- Select a season to update the shot chart and zone breakdown. All retained attempts are plotted.
- Choose **Download player CSV** to export the selected player's results.
- Open **Methods, data coverage, and interpretation** for eligibility and model limitations.

The player list is limited to the downloaded source data. Missing players are not assigned zero performance.

## Rebuild from the original notebook

The original RMD is unchanged. A separate script reads its code chunks and prepares all-player results. Run the following in the RStudio **Console**, with the repository as your working directory:

```r
install.packages(c("knitr", "jsonlite", "arrow")) # first time only
source("scripts/build_dashboard.R")
```

Or use the **Terminal**:

```sh
Rscript scripts/build_dashboard.R
```

The first build downloads public NBA data. Subsequent builds reuse the notebook's data cache. The shot-efficiency build can take several minutes because it fits a separate leave-player-out benchmark for each player.

The script writes `dashboard/index.html` with all required data and charts embedded; `dashboard/template.html` contains the interface. Rebuilding replaces the HTML snapshot, not the RMD. Player names require a UTF-8 locale, which the script selects when necessary. Source data and model files are not embedded beyond the displayed player results.

The league benchmark preserves the notebook model: logistic regression on zone and a distance spline, with each player excluded from the training season. Grouped binomial counts are used for speed, with spline knots taken from the original per-shot distance distribution. All retained attempts appear on the chart. The dashboard does not add season-change bootstrap calculations; its zone shooting intervals are Wilson intervals.

## Verification

After a rebuild, run `source("scripts/verify_dashboard.R")` in the RStudio Console. This checks player IDs, finite values, and dashboard integrity and compares grouped predictions against an ungrouped per-shot fit.

Generated data caches and verification files are excluded from Git. Commit the regenerated `dashboard/index.html` when updating the published snapshot.
