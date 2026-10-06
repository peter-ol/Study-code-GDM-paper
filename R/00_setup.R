# =============================================================================
# 00_setup.R
# Packages, study constants, code lists and small helper functions.
# All other scripts start with source("R/00_setup.R").
#
# The registry data are stored on a secure research server and cannot be shared.
# File locations are therefore not included. Edit read_source() so that it
# returns each source file as a data.table with the column names used below.
# =============================================================================

suppressPackageStartupMessages({
  library(data.table)
  library(lubridate)
})

# -----------------------------------------------------------------------------
# Data access
# -----------------------------------------------------------------------------
# Expected sources (one call per source):
#   "mbrn"               Medical Birth Registry, all births (also before 2018)
#   "ssb_residence"      county of residence, one row per person and year
#   "ssb_housing"        household size, floor area and county, per person and year
#   "ssb_education"      highest education level, per person and year
#   "ssb_labour"         labour market status, per person and year
#   "ssb_occupation"     occupation code (STYRK-08), per person and year
#   "ssb_civil_status"   civil status, per person and year
#   "ssb_population"     fixed information: immigration category, world region
#                        of birth, mother id and father id
#   "ssb_migration"      first immigration date
#   "kuhr"               primary care claims 2008-2023 (person, date, code)
#   "npr"                secondary care episodes 2008-2023 (person, date, code)
#   "lmr"                dispensed prescriptions (person, date, ATC code)
# If read_source() is already defined (for example in a local, unshared
# script), that definition is kept.
if (!exists("read_source", mode = "function")) {
  read_source <- function(name) {
    stop("Edit read_source() to load '", name, "' from your secure data location.")
  }
}

# -----------------------------------------------------------------------------
# Study period and time windows
# -----------------------------------------------------------------------------
study_start <- as.IDate("2018-01-01")   # first delivery date
study_end   <- as.IDate("2023-12-31")   # last delivery date

# Delivery period used as a covariate in the regression models
covid_start_delivery <- as.IDate("2020-02-17")
covid_end_delivery   <- as.IDate("2022-02-13")

# Interruption months used in the interrupted time-series analysis
its_covid_start <- as.Date("2020-03-01")
its_covid_end   <- as.Date("2022-03-01")

# Windows in days from the estimated conception date
t1_end_days      <- 13 * 7        # end of 13 completed gestational weeks
t2_start_days    <- 13 * 7 + 1    # start of gestational week 14
week24_days      <- 167           # end of the first 24 gestational weeks
rx_lookback_days <- 180           # antidiabetic use before conception
obesity_before   <- 360           # obesity code window before conception
obesity_after    <- 90            # obesity code window after conception
min_gest_days    <- 140           # 20 gestational weeks

# -----------------------------------------------------------------------------
# Code lists (ICD-10, ICPC-2 and ATC). Dots are removed before matching.
# -----------------------------------------------------------------------------
# Covariates. Matched on the start of the code (prefix match).
covariate_codes <- list(
  diabetes               = c("E10", "E11", "E12", "E13", "E14", "T89", "T90"),
  obesity                = c("E66", "T82"),
  previous_complication  = c("O660", "O662", "P080", "O14", "W81"),
  pcos                   = c("E282", "T990072", "T990069"),
  hypothyroidism         = c("E033", "T86"),
  pregnancy_hypertension = c("O13", "W81"),
  family_history         = c("Z833")
)

# GDM algorithms. Matched on the full code, except where marked as prefix.
gdm_codes <- list(
  gdm               = c("O244", "W85"),
  gdm_unspecified   = c("O249"),
  pregestational    = c("O240", "O241", "O242", "O243"),
  diabetes_prefix   = c("E10", "E11", "E12", "E13", "E14"),
  antidiabetic_atc  = c("A10A", "A10B", "A10X")
)

# MBRN diabetes variable: 4 = gestational diabetes.
# 1, 2, 3 and 5 = type 1, type 2, other/unknown diabetes and antidiabetic
# treatment without diagnosis. These pregnancies are excluded.
mbrn_gdm_value        <- 4L
mbrn_other_dm_values  <- c(1L, 2L, 3L, 5L)

# -----------------------------------------------------------------------------
# Counties
# -----------------------------------------------------------------------------
# Counties before the 2020 reform are mapped to the 2020 counties.
harmonise_county <- function(x) {
  x <- as.integer(x)
  x[x == 99L] <- NA_integer_
  fcase(
    x %in% c(1L, 2L, 6L), 30L,    # Ostfold, Akershus, Buskerud -> Viken
    x %in% c(4L, 5L),     34L,    # Hedmark, Oppland -> Innlandet
    x %in% c(7L, 8L),     38L,    # Vestfold, Telemark -> Vestfold og Telemark
    x %in% c(9L, 10L),    42L,    # Aust-Agder, Vest-Agder -> Agder
    x %in% c(12L, 14L),   46L,    # Hordaland, Sogn og Fjordane -> Vestland
    x %in% c(19L, 20L),   54L,    # Troms, Finnmark -> Troms og Finnmark
    default = x
  )
}

county_names <- c(
  "3"  = "Oslo",
  "11" = "Rogaland",
  "15" = "More og Romsdal",
  "18" = "Nordland",
  "30" = "Viken",
  "34" = "Innlandet",
  "38" = "Vestfold og Telemark",
  "42" = "Agder",
  "46" = "Vestland",
  "50" = "Trondelag",
  "54" = "Troms og Finnmark"
)

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
# Upper case, no dots or spaces
norm_code <- function(x) toupper(gsub("[^A-Za-z0-9]", "", as.character(x)))

# TRUE if the code starts with any of the prefixes
code_starts_with <- function(x, prefixes) {
  x <- norm_code(x)
  out <- rep(FALSE, length(x))
  for (p in norm_code(prefixes)) out <- out | (!is.na(x) & startsWith(x, p))
  out
}

# TRUE if the code is exactly one of the codes
code_in <- function(x, codes) norm_code(x) %in% norm_code(codes)

# Pick the value from the delivery year. If it is missing, use the closest later
# year first and then the closest earlier year.
# long_dt: person_id, year, value
pick_nearest_year <- function(index_dt, long_dt) {
  m <- merge(
    index_dt[, .(row_id, person_id, delivery_year)],
    long_dt[!is.na(value)],
    by = "person_id", allow.cartesian = TRUE
  )
  m[, `:=`(
    later_first = fifelse(year >= delivery_year, 0L, 1L),
    distance    = abs(year - delivery_year)
  )]
  setorder(m, row_id, later_first, distance)
  m[, .SD[1], by = row_id][, .(row_id, value, value_year = year)]
}
