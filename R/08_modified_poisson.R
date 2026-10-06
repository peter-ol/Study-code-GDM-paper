# =============================================================================
# 08_modified_poisson.R
# Modified Poisson regression with cluster-robust standard errors, pooled over
# the 20 imputed datasets with Rubin's rules.
#   A. Main models for the three GDM definitions        (Table S4, Figure 2)
#   B. Model checks on the first imputed dataset
#   C. Mothers with immigrant background only            (Table S5)
#   D. Any GDM definition                                (Table S6)
#   E. Complete-case analysis of any GDM definition
# Input:  imp (from 07), analysis_data (from 06)
# =============================================================================

source("R/00_setup.R")
library(mice)
library(sandwich)
library(lmtest)

imp <- readRDS("mice_imputation_object.rds")

outcomes <- c("mbrn_gdm", "dxrx_broad", "dxrx_narrow")

covariates <- c(
  "maternal_region",
  "maternal_employment", "maternal_civil_status", "maternal_education",
  "household_size", "living_space", "immigrant",
  "maternal_age", "maternal_BMI", "familial_diabetes",
  "nulliparous_over25", "multiparous_over40", "previous_pregnancy_risk",
  "pco", "ART", "hypothyroidism", "maternal_smoking",
  "covid_period", "visits_1y_before", "visits_24w",
  "asian_ethnicity", "african_ethnicity", "european_ethnicity",
  "americas_oceania_ethnicity", "plural_pregnancy", "month"
)

# Completed datasets with numeric 0/1 outcomes
completed <- lapply(complete(imp, action = "all"), function(d) {
  for (v in outcomes) d[[v]] <- as.numeric(as.character(d[[v]]))
  d
})

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
# Poisson model with log link. Cluster-robust (HC0) variance with clustering
# on the mother, because a woman can have more than one pregnancy.
fit_modified_poisson <- function(data, outcome, predictors, cluster = "mother_id") {
  f   <- reformulate(predictors, response = outcome)
  fit <- glm(f, data = data, family = poisson(link = "log"))
  V   <- if (is.null(cluster)) vcovHC(fit, type = "HC0")
         else vcovCL(fit, cluster = data[[cluster]], type = "HC0")
  list(fit = fit, vcov = V)
}

# Rubin's rules on the log-RR scale, then exponentiated
pool_rr <- function(fits, label) {
  terms <- names(coef(fits[[1]]$fit))
  rbindlist(lapply(terms, function(tm) {
    q  <- sapply(fits, function(x) coef(x$fit)[tm])
    u  <- sapply(fits, function(x) diag(x$vcov)[tm])
    ps <- pool.scalar(Q = q, U = u, n = Inf, k = 1)
    se <- sqrt(ps$t)
    data.table(outcome = label, term = tm,
               log_rr = ps$qbar, se = se,
               RR      = exp(ps$qbar),
               RR_low  = exp(ps$qbar - 1.96 * se),
               RR_high = exp(ps$qbar + 1.96 * se),
               p_value = 2 * pnorm(abs(ps$qbar / se), lower.tail = FALSE))
  }))
}

run_mi_models <- function(data_list, outcome, predictors, cluster = "mother_id") {
  fits <- lapply(data_list, fit_modified_poisson,
                 outcome = outcome, predictors = predictors, cluster = cluster)
  pool_rr(fits, outcome)
}

# -----------------------------------------------------------------------------
# A. Main models
# -----------------------------------------------------------------------------
results_main <- rbindlist(lapply(outcomes, function(o) run_mi_models(completed, o, covariates)))
fwrite(results_main, "results_main_pooled_RR.csv")

# -----------------------------------------------------------------------------
# B. Model checks (first completed dataset, MBRN GDM)
# -----------------------------------------------------------------------------
d1  <- completed[[1]]
fit <- glm(reformulate(covariates, response = "mbrn_gdm"),
           data = d1, family = poisson(link = "log"))

# Collinearity: generalised variance inflation factors, GVIF^(1/(2*df))
print(car::vif(fit))

# Dispersion
sum(residuals(fit, type = "pearson")^2) / fit$df.residual

# Discrimination
pROC::auc(pROC::roc(d1$mbrn_gdm, fitted(fit), quiet = TRUE))

# Calibration by decile of predicted risk
d1$pred <- fitted(fit)
calib <- as.data.table(d1)[, .(mean_pred = mean(pred), observed = mean(mbrn_gdm), n = .N),
                           by = .(decile = cut(pred, quantile(pred, 0:10 / 10),
                                               include.lowest = TRUE))]
setorder(calib, mean_pred)
print(calib)

# Residual plots and Cook's distance
par(mfrow = c(2, 2))
plot(fitted(fit), residuals(fit, type = "pearson"),
     xlab = "Fitted values", ylab = "Pearson residuals"); abline(h = 0, lty = 2)
qqnorm(residuals(fit, type = "pearson")); qqline(residuals(fit, type = "pearson"))
plot(fitted(fit), rstandard(fit),
     xlab = "Fitted values", ylab = "Standardised residuals"); abline(h = c(-2, 0, 2), lty = c(2, 1, 2))
plot(cooks.distance(fit), type = "h", ylab = "Cook's distance")

# -----------------------------------------------------------------------------
# C. Mothers with immigrant background
# -----------------------------------------------------------------------------
# Foreign-born mothers and Norwegian-born mothers with immigrant parents
immigrant_groups <- c("Norwegian-born to immigrant parents", "Immigrant (foreign-born)")
completed_imm <- lapply(completed, function(d) {
  d <- d[d$immigrant %in% immigrant_groups, ]
  d$immigrant <- droplevels(d$immigrant)
  d
})
results_immigrant <- rbindlist(lapply(outcomes, function(o)
  run_mi_models(completed_imm, o, covariates)))
fwrite(results_immigrant, "results_immigrant_only_pooled_RR.csv")

# -----------------------------------------------------------------------------
# D. Any GDM definition (MBRN or DxRx Broad or DxRx Narrow)
# -----------------------------------------------------------------------------
completed_any <- lapply(completed, function(d) {
  d$any_gdm <- as.numeric(d$mbrn_gdm == 1 | d$dxrx_broad == 1 | d$dxrx_narrow == 1)
  d
})
results_any <- run_mi_models(completed_any, "any_gdm", covariates)
fwrite(results_any, "results_any_gdm_pooled_RR.csv")

# -----------------------------------------------------------------------------
# E. Complete-case analysis, any GDM definition
# -----------------------------------------------------------------------------
# Pregnancies with no missing value in any model covariate. No imputation.
cc_covariates <- c(covariates, "pregnancy_hypertension")
cc <- complete(imp, action = 0L)          # original data with missing values
cc$any_gdm <- as.numeric(as.character(cc$mbrn_gdm) == "1" |
                         as.character(cc$dxrx_broad) == "1" |
                         as.character(cc$dxrx_narrow) == "1")
cc <- cc[complete.cases(cc[, cc_covariates]), ]
cat("Complete-case cohort:", nrow(cc), "pregnancies,", sum(cc$any_gdm), "with any GDM\n")

cc_fit <- fit_modified_poisson(cc, "any_gdm", cc_covariates)
cc_tab <- coeftest(cc_fit$fit, vcov. = cc_fit$vcov)
results_cc <- data.table(term    = rownames(cc_tab),
                         RR      = exp(cc_tab[, 1]),
                         RR_low  = exp(cc_tab[, 1] - 1.96 * cc_tab[, 2]),
                         RR_high = exp(cc_tab[, 1] + 1.96 * cc_tab[, 2]),
                         p_value = cc_tab[, 4])
fwrite(results_cc, "results_complete_case_any_gdm_RR.csv")
