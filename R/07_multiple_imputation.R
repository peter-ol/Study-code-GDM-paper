# =============================================================================
# 07_multiple_imputation.R
# Multiple imputation by chained equations (m = 20).
# Input:  analysis_data (from 06)
# Output: imp (mids object), saved to disk
# =============================================================================

source("R/00_setup.R")
library(mice)

df <- copy(analysis_data)

# -----------------------------------------------------------------------------
# 1. Variable types and reference categories
# -----------------------------------------------------------------------------
df[, `:=`(
  maternal_region = factor(maternal_region, levels = c(
    "Oslo", "Vestfold og Telemark", "Viken", "Trondelag", "More og Romsdal",
    "Agder", "Rogaland", "Vestland", "Troms og Finnmark", "Innlandet", "Nordland")),
  maternal_employment   = factor(maternal_employment, levels = c("Unemployed", "Employed")),
  maternal_civil_status = factor(maternal_civil_status,
                                 levels = c("Single", "Cohabitant", "Married/registered partner")),
  maternal_education    = factor(maternal_education, levels = c("No/Primary", "Secondary", "Tertiary")),
  household_size        = factor(household_size, levels = c("small", "medium", "large")),
  living_space          = factor(living_space, levels = c("overcrowded", "typical", "spacious")),
  immigrant             = factor(immigrant, levels = c(
    "Norwegian-born, no immigrant background", "Norwegian-born to immigrant parents",
    "Immigrant (foreign-born)", "Other/Unclassified")),
  maternal_smoking      = factor(maternal_smoking, levels = c("No", "Occasionally", "Daily", "Unreported")),
  familial_diabetes     = factor(familial_diabetes, levels = c("0", "1", "missing")),
  covid_period          = factor(covid_period, levels = c("Pre-COVID", "During COVID", "Post-COVID")),
  month                 = factor(month, levels = 1:12)
)]

# All other 0/1 variables become factors so they are imputed with logistic models
id_vars <- c("row_id", "mother_id", "conception_date", "delivery_date")
binary_vars <- setdiff(names(df)[sapply(df, function(x) uniqueN(na.omit(x)) == 2)], id_vars)
df[, (binary_vars) := lapply(.SD, function(x) if (is.factor(x)) x else factor(x)),
   .SDcols = binary_vars]

# -----------------------------------------------------------------------------
# 2. Imputation methods
# -----------------------------------------------------------------------------
# Binary factors: logistic regression. Factors with >2 levels: multinomial
# regression. Numeric variables: predictive mean matching.
meth <- make.method(df)
for (v in names(df)) {
  x <- df[[v]]
  meth[v] <- if (is.factor(x) && nlevels(x) == 2) "logreg" else
             if (is.factor(x) && nlevels(x) > 2)  "polyreg" else
             if (is.numeric(x))                   "pmm" else ""
}

# Outcomes and region are complete. They are used as predictors only.
predictor_only <- c("maternal_region", "mbrn_gdm", "dxrx_broad", "dxrx_narrow")
meth[c(predictor_only, id_vars)] <- ""

# -----------------------------------------------------------------------------
# 3. Predictor matrix
# -----------------------------------------------------------------------------
pred <- make.predictorMatrix(df)
pred[c(predictor_only, id_vars), ] <- 0   # not imputed
pred[, predictor_only] <- 1               # but used to predict other variables
pred[, id_vars] <- 0                      # identifiers and dates are not predictors
diag(pred) <- 0

# -----------------------------------------------------------------------------
# 4. Run
# -----------------------------------------------------------------------------
imp <- mice(
  data            = df,
  method          = meth,
  predictorMatrix = pred,
  m               = 20,
  maxit           = 10,
  seed            = 2025,
  printFlag       = TRUE
)

# Convergence and observed vs imputed values
plot(imp)

saveRDS(imp, "mice_imputation_object.rds")
