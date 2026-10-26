# NBA Player Shot Efficiency

## Interactive player dashboard

**[Open the dashboard folder](dashboard/)** for the searchable player dashboard and instructions. **[Download the standalone HTML](https://github.com/Hclark36/Player-Shot-Efficiency/raw/refs/heads/main/dashboard/index.html)** and open it in a browser. Search player names, switch profiles, select seasons, and download player results as CSV. No R server is required. GitHub's normal file view shows HTML source; download the file to use the dashboard.

The original RMD is unchanged. To rebuild the dashboard in RStudio, run `source("scripts/build_dashboard.R")` from the repository root after installing the packages listed in [dashboard/README.md](dashboard/README.md).


An R Markdown project that examines how an NBA player's shot selection and scoring efficiency change across seasons. It compares actual shooting results with a league-wide benchmark to help answer:

**Did a player's efficiency change because of where they shot, or because they made more or fewer shots than expected from those locations?**

The notebook is currently configured for **Payton Pritchard** across **2023–24, 2024–25, and 2025–26**.

## What the project does

- Downloads and combines league-wide shot data from two sources.
- Cleans shot outcomes, dates, and point values, and standardizes coordinates across sources.
- Summarizes field-goal percentage, shot distribution, and points per attempt by season and court zone.
- Fits logistic regression models using court zone and shot distance.
- Evaluates predictions on later seasons using log loss, Brier score, and calibration tables.
- Compares a selected player's actual scoring with expected scoring.
- Uses game-level bootstrap resampling to estimate uncertainty in season-to-season changes.
- Produces shot charts, zone-distribution charts, and actual-versus-expected efficiency plots.

## Methodology

### League benchmark

The analysis excludes the selected player from the league training and evaluation samples. It compares three approaches:

1. A constant probability based on the training season's league field-goal percentage.
2. A logistic regression model using court zone.
3. A logistic regression model using court zone and a natural spline for shot distance with four degrees of freedom.

The main restricted-scope models train on **2023–24**, validate on **2024–25**, and are evaluated without refitting on **2025–26**. The same zone-and-distance benchmark is applied to the selected player's shots across all three seasons.

The notebook first explores the broader shot sample, then restricts the main efficiency analysis to attempts **under 40 feet and outside the Backcourt zone**. This is a practical scope rule rather than an official definition of a heave.

### Efficiency measures

| Measure | Meaning |
| --- | --- |
| Field-goal percentage | Makes divided by attempts |
| Share of attempts | Percentage of a season's attempts taken in a given zone |
| Expected points | Predicted make probability multiplied by the shot's two- or three-point value |
| Points above expected | Actual field-goal points minus expected points |
| Points above expected per 100 attempts | Actual-minus-expected points scaled to 100 field-goal attempts |

Season-to-season scoring changes are separated into changes in the modeled value of the shot mix and changes in performance relative to that benchmark.

### Uncertainty

The notebook calculates Wilson intervals for zone-level shooting percentages and uses **5,000 bootstrap repetitions** for selected season comparisons. Bootstrap samples resample whole games, keeping shots from the same game together. The league model remains fixed during resampling.

## Data sources

- **2023–24 and 2024–25:** [DomSamangy/NBA_Shots_04_25](https://github.com/DomSamangy/NBA_Shots_04_25), using the ZIP files labeled by season-ending year.
- **2025–26:** [cdechoch/nba-data-archive](https://huggingface.co/datasets/cdechoch/nba-data-archive), using `per_season/shotdetail/2025.parquet`. The notebook checks that this file contains regular-season attempts.

Data downloads are cached in `data/raw/`. The notebook also saves intermediate RDS files there. Downloaded datasets and rendered reports are not included in this repository.

## Getting started

You will need R and an R Markdown environment, such as RStudio. Rendering from the command line also requires Pandoc, which is bundled with RStudio.

1. Clone or download this repository.
2. Open `PlayerShotChart_Efficiency_Reusable.Rmd` in RStudio.
3. Install the required packages:

   ```r
   install.packages(c("rmarkdown", "knitr", "arrow"))
   ```

4. Run the notebook chunks in order or use **Knit** to generate the HTML notebook. The first run requires internet access to download the source data.

You can also render from R with the repository as your working directory:

```r
rmarkdown::render("PlayerShotChart_Efficiency_Reusable.Rmd")
```

Most data manipulation, modeling, and plotting use base R. The distance model uses `splines`, which ships with R.

## Analyzing another player

Update both values in the **Settings** chunk:

```r
player_id <- 1630202
player_name <- "Payton Pritchard"
```

Use the player's NBA ID and the name as recorded in the source data. The notebook checks that the selected ID matches the supplied name.

Then rerun the full notebook. Changing players updates the selected-player data and excludes that player from the league benchmark.

**Current reuse notes:** Some headings and written interpretations still refer to the original Cason Wallace analysis. Those passages are not generated dynamically and must be revised before presenting results for another player. Several data-loading paths, season labels, and comparisons also remain fixed to 2023–24 through 2025–26; changing only the year settings will not fully adapt the analysis to a new season window.

## Interpreting the results

The benchmark describes expected shooting based on **zone and distance**. It does not account for defender proximity, shot-clock pressure, passing quality, or player role. Points above expected should therefore be read as performance relative to this model, rather than a complete measure of player value or proof of a causal effect.

Free throws are excluded. Small samples can produce large apparent differences, and the uncertainty calculations do not include uncertainty from refitting the league model. Source coverage should be checked before treating a season as complete or extending conclusions to postseason play.

## Repository contents

- [PlayerShotChart_Efficiency_Reusable.Rmd](PlayerShotChart_Efficiency_Reusable.Rmd) — data preparation, modeling, evaluation, tables, and visualizations.
- [README.md](README.md) — project overview and instructions.

## Author

[Hunter Clark](https://github.com/Hclark36)
