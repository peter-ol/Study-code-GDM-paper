# =============================================================================
# 06_cohort_selection.R
# Exclusions and the analytic cohort (Supplementary Figure S1).
# Input:  pregnancies (from 05)
# Output: analysis_data (one row per pregnancy), flowchart counts
# =============================================================================

source("R/00_setup.R")

cohort <- copy(pregnancies)
flow <- data.table(step = "Pregnancies in MBRN 2018-2023",
                   n_left = nrow(cohort), n_excluded = NA_integer_,
                   gdm_excluded = NA_integer_)

# Remove the rows that meet `rule` and log how many were removed
exclude <- function(dt, rule, label) {
  drop <- dt[, eval(rule)]
  drop[is.na(drop)] <- FALSE
  flow <<- rbind(flow, data.table(
    step         = label,
    n_left       = sum(!drop),
    n_excluded   = sum(drop),
    gdm_excluded = sum(dt$mbrn_gdm[drop] == 1L, na.rm = TRUE)
  ))
  dt[!drop]
}

cohort <- exclude(cohort, quote(is.na(mother_id)),
                  "Missing mother ID")
cohort <- exclude(cohort, quote(is.na(maternal_region)),
                  "Missing maternal region of residence")
cohort <- exclude(cohort, quote(is.na(maternal_age) | maternal_age < 15 | maternal_age > 49),
                  "Unrealistic maternal age (<15 or >49 years)")
cohort <- exclude(cohort, quote(is.na(conception_date) |
                                  delivery_date - conception_date < min_gest_days),
                  "Pregnancy duration <20 weeks")
cohort <- exclude(cohort, quote(lookback_missing_1y == 1L),
                  "Missing one-year look-back before pregnancy")
cohort <- exclude(cohort, quote(mbrn_diabetes %in% mbrn_other_dm_values),
                  "MBRN-recorded diabetes other than GDM")

print(flow)

# -----------------------------------------------------------------------------
# Analysis file
# -----------------------------------------------------------------------------
analysis_vars <- c(
  # identifiers and dates (not used as predictors)
  "row_id", "mother_id", "conception_date", "delivery_date",
  # outcomes
  "mbrn_gdm", "dxrx_broad", "dxrx_narrow",
  # exposure
  "maternal_region",
  # sociodemographic
  "maternal_employment", "maternal_civil_status", "maternal_education",
  "household_size", "living_space", "immigrant",
  "asian_ethnicity", "african_ethnicity", "european_ethnicity",
  "americas_oceania_ethnicity",
  # clinical and guideline-related
  "maternal_age", "maternal_BMI", "familial_diabetes", "nulliparous_over25",
  "multiparous_over40", "previous_pregnancy_risk", "pco", "ART",
  "hypothyroidism", "maternal_smoking", "pregnancy_hypertension",
  "plural_pregnancy",
  # health service use and time
  "visits_1y_before", "visits_24w", "covid_period", "month"
)
analysis_data <- cohort[, ..analysis_vars]

# Family history: unknown is kept as its own category, not imputed
analysis_data[, familial_diabetes := fifelse(is.na(familial_diabetes), "missing",
                                             as.character(familial_diabetes))]
analysis_data[, maternal_region := county_names[as.character(maternal_region)]]
