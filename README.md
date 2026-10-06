# Regional, socioeconomic, and immigration-related variation in gestational diabetes in Norway, 2018–2023

Analysis code for the manuscript:

> Olteanu P-I, Hayati S, van Gelder MMHJ, Nordeng H. *Regional, socioeconomic, and immigration-related variation in gestational diabetes in Norway - a nationwide registry-based study, 2018–2023.* Submitted to the International Journal of Epidemiology.

This repository contains the R scripts used to build the study cohort, define gestational diabetes mellitus (GDM), and run the analyses reported in the main text and the Supplementary Material. The scripts are cleaned versions of the code used for the paper. We reorganised them in the order of the analysis and added comments. Variable names were changed to descriptive names, and file paths were removed.

## Data

The study used linked data from the Medical Birth Registry of Norway (MBRN), the Norwegian Patient Registry (NPR), the Norway Control and Payment of Primary Health Care Refunds (KUHR), the Norwegian Prescribed Drug Registry (LMR) and Statistics Norway (SSB). The data cannot be shared because of Norwegian privacy legislation and registry regulations. Access can be requested from each data holder, with the necessary ethical and legal approvals.

The scripts will not run without these data. To run them on a local copy, edit `read_source()` in `R/00_setup.R` so that it returns each source file with the column names described there.

## Repository structure

```
README.md                       this file
LICENSE                         MIT licence
docs/analysis_steps.md          step-by-step description of the methods and algorithms
docs/code_lists.md              diagnosis, procedure and ATC codes, with time windows
R/00_setup.R                    packages, study dates, code lists, helper functions
R/01_build_pregnancy_file.R     pregnancies 2018-2023 and sociodemographic linkage
R/02_registry_diagnoses.R       diagnosis flags from KUHR and NPR, primary care visits
R/03_family_history.R           family history of diabetes in parents and siblings
R/04_covariates.R               clinical, guideline-related and time covariates
R/05_gdm_definitions.R          MBRN GDM, DxRx Broad and DxRx Narrow
R/06_cohort_selection.R         exclusions and the analytic cohort
R/07_multiple_imputation.R      multiple imputation by chained equations (m = 20)
R/08_modified_poisson.R         main models, subgroup and sensitivity analyses
R/09_ses_index_interaction.R    ordinal PCA and region x SES interaction models
R/10_interrupted_time_series.R  interrupted time-series analysis and sensitivity models
R/11_tables_figures.R           descriptive tables and figures
```

## Analysis steps and where they are reported

| Step | Script | What it does | Manuscript |
|---|---|---|---|
| 1 | `01_build_pregnancy_file.R` | One row per pregnancy. Region, education, employment, civil status, household, living space, immigration background | Methods; Table S2 |
| 2 | `02_registry_diagnoses.R` | Diagnosis codes in primary and secondary care with time windows. Primary care contacts | Table S2 |
| 3 | `03_family_history.R` | Diabetes in first-degree relatives through family linkage | Table S2; Supplementary Methods |
| 4 | `04_covariates.R` | BMI, parity and age groups, previous pregnancy risk, smoking, ART, PMOS, hypothyroidism, delivery period | Table S2 |
| 5 | `05_gdm_definitions.R` | Three GDM case definitions. DxRx Broad and Narrow are adapted from the ConcePTION algorithms (Mølgaard-Nielsen et al., BMJ Open 2025) | Table S1 |
| 6 | `06_cohort_selection.R` | Exclusions | Figure S1 |
| 7 | `07_multiple_imputation.R` | Multiple imputation | Supplementary Methods |
| 8 | `08_modified_poisson.R` | Modified Poisson regression, immigrant subgroup, any GDM definition, complete-case analysis | Figure 2; Tables S4–S6 |
| 9 | `09_ses_index_interaction.R` | Economic and social index, region x SES interaction | Table S3 |
| 10 | `10_interrupted_time_series.R` | Monthly GDM prevalence across the COVID-19 period | Figure 3; Table S7; Figure S2 |
| 11 | `11_tables_figures.R` | Baseline tables, map, forest plot, monthly prevalence | Table 1; Figures 1–2; Figure S3; Tables S9–S10 |

A plain-language description of every step is given in [docs/analysis_steps.md](docs/analysis_steps.md). All codes and time windows are listed in [docs/code_lists.md](docs/code_lists.md).

## Software

All analyses were done in R version 4.4.1. Main packages:

- `data.table` and `lubridate` for data management
- `mice` for multiple imputation
- `sandwich` and `lmtest` for robust and cluster-robust variance and coefficient tests
- `ordPens` for ordinal principal component analysis. This package has been removed from CRAN. Version 1.1.0 can be installed from the CRAN archive with `install.packages("https://cran.r-project.org/src/contrib/Archive/ordPens/ordPens_1.1.0.tar.gz", repos = NULL, type = "source")`. It needs `ordinalNet`, which is also in the CRAN archive, and Rtools on Windows
- `MASS` for simulation of model coefficients
- `forecast` for ARIMA models
- `brms` for Bayesian models
- `car` and `pROC` for model checks
- `ggplot2`, `gtsummary` and `csmaps` for tables, figures and maps

## Licence

The code is released under the MIT licence. See [LICENSE](LICENSE).

## Contact

Petrica-Ioan Olteanu, Pharmacoepidemiology and Drug Safety Research Group, Department of Pharmacy, University of Oslo. Email: petricao@uio.no
