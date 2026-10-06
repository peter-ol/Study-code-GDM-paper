# =============================================================================
# 09_ses_index_interaction.R
# Exploratory region x socioeconomic interaction models (Table S3).
#   1. Ordinal PCA of five socioeconomic variables -> economic and social index
#   2. Modified Poisson models with region x index interaction terms
# Input:  imp (from 07)
# =============================================================================

source("R/00_setup.R")
library(mice)
library(ordPens)
library(sandwich)

imp <- readRDS("mice_imputation_object.rds")
completed <- complete(imp, action = "all")
outcomes  <- c("mbrn_gdm", "dxrx_broad", "dxrx_narrow")

ses_vars <- c("maternal_education", "maternal_employment", "household_size",
              "living_space", "maternal_civil_status")

# Ordinal variables as integer scores (factor level order)
ses_matrix <- function(d) {
  as.matrix(data.frame(lapply(d[, ses_vars], function(x) as.integer(as.factor(x)))))
}

# -----------------------------------------------------------------------------
# 1. Ordinal PCA in the first completed dataset
# -----------------------------------------------------------------------------
pca_fit <- ordPCA(H = ses_matrix(completed[[1]]), p = 2)

var_explained <- pca_fit$pca$sdev^2 / sum(pca_fit$pca$sdev^2)
print(round(var_explained[1:2], 3))   # PC1 = economic, PC2 = social
print(pca_fit$A[, 1:2])               # loadings

# The same loadings are applied to every completed dataset.
# PC1 is reversed so that a higher value means a more advantaged position.
# Both indices are standardised to mean 0 and SD 1 within each dataset.
completed_pca <- lapply(completed, function(d) {
  scores <- ses_matrix(d) %*% pca_fit$A[, 1:2]
  d$economic_index <- as.numeric(scale(-scores[, 1]))
  d$social_index   <- as.numeric(scale(scores[, 2]))
  for (v in outcomes) d[[v]] <- as.numeric(as.character(d[[v]]))
  d
})

# -----------------------------------------------------------------------------
# 2. Interaction models
# -----------------------------------------------------------------------------
# The five SES variables are replaced by the two indices.
other_covariates <- c(
  "maternal_age", "maternal_BMI", "familial_diabetes", "nulliparous_over25",
  "multiparous_over40", "previous_pregnancy_risk", "pco", "ART",
  "hypothyroidism", "maternal_smoking", "covid_period",
  "visits_1y_before", "visits_24w", "immigrant", "asian_ethnicity",
  "african_ethnicity", "european_ethnicity", "americas_oceania_ethnicity",
  "plural_pregnancy", "month"
)

fit_interaction <- function(d, outcome) {
  f <- as.formula(paste(
    outcome, "~ maternal_region * economic_index + maternal_region * social_index +",
    paste(other_covariates, collapse = " + ")
  ))
  fit <- glm(f, data = d, family = poisson(link = "log"))
  list(fit = fit, vcov = vcovHC(fit, type = "HC0"))
}

# pool_rr() as defined in 08_modified_poisson.R
pool_rr <- function(fits, label) {
  terms <- names(coef(fits[[1]]$fit))
  rbindlist(lapply(terms, function(tm) {
    q  <- sapply(fits, function(x) coef(x$fit)[tm])
    u  <- sapply(fits, function(x) diag(x$vcov)[tm])
    ps <- pool.scalar(Q = q, U = u, n = Inf, k = 1)
    se <- sqrt(ps$t)
    data.table(outcome = label, term = tm, RR = exp(ps$qbar),
               RR_low = exp(ps$qbar - 1.96 * se), RR_high = exp(ps$qbar + 1.96 * se),
               p_value = 2 * pnorm(abs(ps$qbar / se), lower.tail = FALSE))
  }))
}

results_interaction <- rbindlist(lapply(outcomes, function(o) {
  pool_rr(lapply(completed_pca, fit_interaction, outcome = o), o)
}))

interaction_terms <- results_interaction[grepl("maternal_region.*:(economic|social)_index", term)]
fwrite(interaction_terms, "results_region_ses_interaction.csv")
