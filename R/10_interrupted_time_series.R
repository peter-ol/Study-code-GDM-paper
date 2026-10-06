# =============================================================================
# 10_interrupted_time_series.R
# Interrupted time-series (ITS) analysis of monthly GDM prevalence before,
# during and after the COVID-19 restriction period (Figure 3, Table S7,
# Figure S2).
#
# Main model: two-break GLM, logit link, calendar-month fixed effects.
# Sensitivity: other time scales, Fourier seasonality, ARIMA errors,
#              Bayesian binomial model, and one-break versions.
# Input: analysis_data (from 06). Not imputed. Region is complete.
# =============================================================================

source("R/00_setup.R")
library(sandwich)
library(lmtest)
library(MASS)
library(forecast)
library(ggplot2)
have_brms <- requireNamespace("brms", quietly = TRUE)

its_df   <- as.data.frame(analysis_data)
outcomes <- c("mbrn_gdm", "dxrx_broad", "dxrx_narrow")

n_draws <- 2000L    # simulation draws for fitted and counterfactual bands
nw_lag  <- 12L      # Newey-West lag (months)
set.seed(2025)

# -----------------------------------------------------------------------------
# 1. Time scales
# -----------------------------------------------------------------------------
# Conception-month series start in April 2017 and stop 10 months before the
# last delivery, so that every included month has complete follow-up.
analysis_start_conception <- as.Date("2017-04-01")
followup_cutoff <- floor_date(max(as.Date(its_df$delivery_date)) %m-% months(10), "month")

series_specs <- list(
  conception_primary = list(time_var = "conception_date", lag = 0L,
                            start = analysis_start_conception, truncate = TRUE,  min_pts = 12L),
  conception_lag4    = list(time_var = "conception_date", lag = -4L,
                            start = analysis_start_conception, truncate = TRUE,  min_pts = 1L),
  conception_lag6    = list(time_var = "conception_date", lag = 6L,
                            start = analysis_start_conception, truncate = TRUE,  min_pts = 1L),
  delivery_secondary = list(time_var = "delivery_date",   lag = 0L,
                            start = NULL,                    truncate = FALSE, min_pts = 12L)
)

# -----------------------------------------------------------------------------
# 2. Monthly series with the interruption terms
# -----------------------------------------------------------------------------
make_monthly_series <- function(df, outcome, spec, region = NULL) {
  if (!is.null(region)) df <- df[df$maternal_region == region, ]
  df$series_month <- floor_date(as.Date(df[[spec$time_var]]), "month")
  if (!is.null(spec$start)) df <- df[df$series_month >= spec$start, ]
  if (spec$truncate)        df <- df[df$series_month <= followup_cutoff, ]

  m <- as.data.table(df)[, .(n = .N, cases = sum(get(outcome) == 1)), by = series_month]
  setorder(m, series_month)
  m[, `:=`(noncases = n - cases,
           t = .I - 1L,
           month_of_year = factor(month(series_month), levels = 1:12))]

  # Interruption dates, shifted by `lag` months in the sensitivity series
  start_m <- floor_date(its_covid_start %m+% months(spec$lag), "month")
  end_m   <- floor_date(its_covid_end   %m+% months(spec$lag), "month")
  t_start <- m[series_month >= start_m, min(t)]
  t_end   <- m[series_month >= end_m,   min(t)]

  m[, `:=`(
    # two-break terms
    during           = as.integer(series_month >= start_m),     # step at COVID start
    time_after_start = fifelse(series_month >= start_m, t - t_start + 1L, 0L), # slope change
    post             = as.integer(series_month >= end_m),       # step at COVID end
    time_after_end   = fifelse(series_month >= end_m, t - t_end + 1L, 0L),     # slope change
    # Fourier terms (K = 2)
    sin1 = sin(2 * pi * t / 12), cos1 = cos(2 * pi * t / 12),
    sin2 = sin(4 * pi * t / 12), cos2 = cos(4 * pi * t / 12)
  )]
  # one-break terms
  m[, `:=`(covid_step = during, covid_slope = time_after_start)]
  m[, segment := fcase(series_month < start_m, "pre",
                       series_month < end_m,   "during",
                       default = "post")]
  m[]
}

break_terms <- list(
  two_break = c("during", "time_after_start", "post", "time_after_end"),
  one_break = c("covid_step", "covid_slope")
)
season_terms <- list(month_fe = "month_of_year",
                     fourier  = c("sin1", "cos1", "sin2", "cos2"))

# -----------------------------------------------------------------------------
# 3. Model fitters
# -----------------------------------------------------------------------------
# Joint Wald test of the COVID terms
wald_test <- function(b, V, terms) {
  b <- b[terms]; V <- V[terms, terms]
  stat <- as.numeric(t(b) %*% solve(V, b))
  c(chisq = stat, df = length(terms),
    p = pchisq(stat, df = length(terms), lower.tail = FALSE))
}

# GLM on monthly counts (cases, non-cases), logit link. Quasibinomial to allow
# for overdispersion, with Newey-West (HAC) standard errors for serial
# correlation. Counterfactual = all COVID terms set to zero.
fit_its_glm <- function(m, breaks = "two_break", season = "month_fe") {
  terms <- c("t", season_terms[[season]], break_terms[[breaks]])
  fit <- glm(reformulate(terms, response = "cbind(cases, noncases)"),
             family = quasibinomial(link = "logit"), data = m)
  V <- NeweyWest(fit, lag = nw_lag, prewhite = FALSE, adjust = TRUE)

  X_fit <- model.matrix(fit)
  X_cf  <- X_fit
  X_cf[, colnames(X_cf) %in% break_terms[[breaks]]] <- 0

  # Uncertainty bands from 2000 draws of the coefficients
  draws <- mvrnorm(n_draws, mu = coef(fit), Sigma = V)
  p_fit <- plogis(draws %*% t(X_fit))
  p_cf  <- plogis(draws %*% t(X_cf))

  list(
    coefs = data.table(term = names(coef(fit)), estimate = coef(fit),
                       se = sqrt(diag(V)),
                       p  = coeftest(fit, vcov. = V)[, 4]),
    wald  = wald_test(coef(fit), V, break_terms[[breaks]]),
    curves = data.table(
      series_month = m$series_month,
      observed = 100 * m$cases / m$n,
      fitted   = 100 * colMeans(p_fit),
      fit_low  = 100 * apply(p_fit, 2, quantile, 0.025),
      fit_high = 100 * apply(p_fit, 2, quantile, 0.975),
      counterfactual = 100 * colMeans(p_cf),
      cf_low   = 100 * apply(p_cf, 2, quantile, 0.025),
      cf_high  = 100 * apply(p_cf, 2, quantile, 0.975)
    ),
    overdispersion = sum(residuals(fit, type = "pearson")^2) / fit$df.residual,
    ljung_box_p    = Box.test(residuals(fit, type = "pearson"), lag = 12, type = "Ljung-Box")$p.value
  )
}

# ARIMA errors on the empirical logit of the monthly prevalence
fit_its_arima <- function(m, breaks = "two_break") {
  y <- qlogis((m$cases + 0.5) / (m$n + 1))
  X <- as.matrix(m[, c("t", season_terms$fourier, break_terms[[breaks]]), with = FALSE])
  fit <- auto.arima(y, xreg = X, seasonal = FALSE, stepwise = FALSE, approximation = FALSE)
  V <- fit$var.coef
  list(coefs = data.table(term = names(coef(fit)), estimate = coef(fit), se = sqrt(diag(V))),
       wald  = wald_test(coef(fit), V, break_terms[[breaks]]))
}

# Bayesian binomial model, weakly informative priors (national series only)
fit_its_bayes <- function(m, breaks = "two_break") {
  terms <- c("t", season_terms$fourier, break_terms[[breaks]])
  fit <- brms::brm(
    as.formula(paste("cases | trials(n) ~", paste(terms, collapse = " + "))),
    data = m, family = binomial(link = "logit"),
    prior = c(brms::prior(normal(0, 2), class = "b"),
              brms::prior(normal(0, 5), class = "Intercept")),
    chains = 4, iter = 4000, warmup = 2000, seed = 2025,
    control = list(adapt_delta = 0.95), refresh = 0
  )
  list(coefs = as.data.table(brms::fixef(fit), keep.rownames = "term"))
}

# -----------------------------------------------------------------------------
# 4. Run: national and regional series
# -----------------------------------------------------------------------------
regions <- sort(unique(its_df$maternal_region))
summary_rows <- list()
main_curves  <- list()

for (spec_name in names(series_specs)) {
  spec <- series_specs[[spec_name]]
  for (o in outcomes) {
    for (reg in c("All Norway", regions)) {
      m <- make_monthly_series(its_df, o, spec,
                               region = if (reg == "All Norway") NULL else reg)
      if (any(table(factor(m$segment, levels = c("pre", "during", "post"))) < spec$min_pts)) next

      # Main model and GLM sensitivity models
      for (breaks in names(break_terms)) for (season in names(season_terms)) {
        res <- fit_its_glm(m, breaks, season)
        summary_rows[[length(summary_rows) + 1]] <- data.table(
          series = spec_name, outcome = o, region = reg, model = "GLM",
          breaks = breaks, seasonality = season,
          p_wald = res$wald["p"], overdispersion = res$overdispersion,
          ljung_box_p = res$ljung_box_p,
          res$coefs[term %in% break_terms[[breaks]], .(term, estimate, se, p)]
        )
        if (spec_name == "conception_primary" && breaks == "two_break" && season == "month_fe") {
          main_curves[[paste(o, reg)]] <- res$curves[, `:=`(outcome = o, region = reg)]
        }
      }

      # ARIMA sensitivity models
      for (breaks in names(break_terms)) {
        res <- tryCatch(fit_its_arima(m, breaks), error = function(e) NULL)
        if (is.null(res)) next
        summary_rows[[length(summary_rows) + 1]] <- data.table(
          series = spec_name, outcome = o, region = reg, model = "ARIMA",
          breaks = breaks, seasonality = "fourier", p_wald = res$wald["p"],
          res$coefs[term %in% break_terms[[breaks]], .(term, estimate, se)]
        )
      }

      # Bayesian sensitivity models, national series only
      if (have_brms && reg == "All Norway") {
        for (breaks in names(break_terms)) {
          res <- fit_its_bayes(m, breaks)
          summary_rows[[length(summary_rows) + 1]] <- data.table(
            series = spec_name, outcome = o, region = reg, model = "Bayesian",
            breaks = breaks, seasonality = "fourier",
            res$coefs[term %in% break_terms[[breaks]],
                      .(term, estimate = Estimate, se = Est.Error, low = Q2.5, high = Q97.5)]
          )
        }
      }
    }
  }
}

its_summary <- rbindlist(summary_rows, fill = TRUE)

# Regional Wald p-values adjusted for multiple testing (Benjamini-Hochberg)
# within each series, outcome and model
wald_by_region <- unique(its_summary[, .(series, outcome, model, breaks, seasonality, region, p_wald)])
wald_by_region[region != "All Norway",
               p_wald_fdr := p.adjust(p_wald, method = "fdr"),
               by = .(series, outcome, model, breaks, seasonality)]

fwrite(its_summary,    "its_coefficients_all_models.csv")
fwrite(wald_by_region, "its_wald_tests.csv")

# -----------------------------------------------------------------------------
# 5. Figure 3: national series, main model
# -----------------------------------------------------------------------------
curves <- rbindlist(main_curves)[region == "All Norway"]
outcome_labels <- c(mbrn_gdm = "MBRN GDM", dxrx_broad = "DxRx Broad", dxrx_narrow = "DxRx Narrow")
curves[, outcome := factor(outcome_labels[outcome], levels = outcome_labels)]

fig3 <- ggplot(curves, aes(series_month)) +
  geom_ribbon(aes(ymin = cf_low,  ymax = cf_high),  alpha = 0.15) +
  geom_ribbon(aes(ymin = fit_low, ymax = fit_high), alpha = 0.25) +
  geom_line(aes(y = counterfactual), linetype = "dashed") +
  geom_line(aes(y = fitted)) +
  geom_point(aes(y = observed), size = 0.8) +
  geom_vline(xintercept = c(its_covid_start, its_covid_end), linetype = "dashed") +
  facet_wrap(~ outcome, ncol = 1) +
  labs(x = "Estimated pregnancy-start month", y = "GDM per 100 pregnancies") +
  theme_bw()
ggsave("figure3_its_national.png", fig3, width = 8, height = 9, dpi = 320)
