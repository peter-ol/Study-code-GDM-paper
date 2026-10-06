# =============================================================================
# 05_gdm_definitions.R
# Three GDM case definitions:
#   mbrn_gdm   GDM recorded in the Medical Birth Registry (primary outcome)
#   dxrx_broad DxRx Broad  (diagnoses + dispensings, includes unspecified O24.9)
#   dxrx_narrow DxRx Narrow (diagnoses + dispensings, excludes any E10-E14 history)
# Input:  pregnancies (from 04), kuhr and npr (from 02), lmr
# Output: pregnancies with the three outcome variables
# =============================================================================

source("R/00_setup.R")

# -----------------------------------------------------------------------------
# 1. MBRN GDM
# -----------------------------------------------------------------------------
pregnancies[, mbrn_gdm := as.integer(fcoalesce(as.integer(mbrn_diabetes), 0L) == mbrn_gdm_value)]

# -----------------------------------------------------------------------------
# 2. Records needed for the DxRx algorithms
# -----------------------------------------------------------------------------
dm_dx <- rbind(
  kuhr[, .(person_id, contact_date, code)],
  npr[,  .(person_id, contact_date, code)]
)
dm_dx <- dm_dx[
  code_in(code, c(gdm_codes$gdm, gdm_codes$gdm_unspecified, gdm_codes$pregestational)) |
  code_starts_with(code, gdm_codes$diabetes_prefix)
]

# LMR: person_id, dispense_date, atc
lmr <- as.data.table(read_source("lmr"))[person_id %in% pregnancies$mother_id]
lmr <- lmr[code_starts_with(atc, gdm_codes$antidiabetic_atc)]
lmr[, dispense_date := as.IDate(dispense_date)]

# Pregnancy windows
win <- pregnancies[!is.na(mother_id), .(
  row_id,
  person_id      = mother_id,
  conception     = conception_date,
  t1_end         = conception_date + t1_end_days,
  t2_start       = conception_date + t2_start_days,
  rx_window_from = conception_date - rx_lookback_days,
  delivery       = delivery_date
)]

# -----------------------------------------------------------------------------
# 3. Diagnosis-based components (KUHR + NPR)
# -----------------------------------------------------------------------------
d <- merge(dm_dx, win, by = "person_id", allow.cartesian = TRUE)
d[, `:=`(
  # Inclusion: GDM code from week 14 to delivery
  gdm_dx         = code_in(code, gdm_codes$gdm) &
                   contact_date >= t2_start & contact_date <= delivery,
  # Inclusion (Broad only): unspecified diabetes in pregnancy, week 14 to delivery
  unspec_dx      = code_in(code, gdm_codes$gdm_unspecified) &
                   contact_date >= t2_start & contact_date <= delivery,
  # Exclusion: GDM code already in the first 13 weeks
  early_gdm      = code_in(code, gdm_codes$gdm) &
                   contact_date >= conception & contact_date <= t1_end,
  # Exclusion: pre-existing diabetes in pregnancy (O24.0-O24.3)
  pregest_dx     = code_in(code, gdm_codes$pregestational) &
                   contact_date >= conception & contact_date <= delivery
)]
dx_flags <- d[, .(
  gdm_dx     = any(gdm_dx),
  unspec_dx  = any(unspec_dx),
  early_gdm  = any(early_gdm),
  pregest_dx = any(pregest_dx)
), by = row_id]

# -----------------------------------------------------------------------------
# 4. Dispensing-based components (LMR)
# -----------------------------------------------------------------------------
r <- merge(lmr[, .(person_id, dispense_date)], win, by = "person_id",
           allow.cartesian = TRUE)
r[, `:=`(
  # Inclusion: antidiabetic dispensing from week 14 to delivery
  gdm_rx     = dispense_date >= t2_start & dispense_date <= delivery,
  # Exclusion: antidiabetic dispensing from 180 days before conception
  #            to the end of week 13
  pregest_rx = dispense_date >= rx_window_from & dispense_date <= t1_end
)]
rx_flags <- r[, .(gdm_rx = any(gdm_rx), pregest_rx = any(pregest_rx)), by = row_id]

# -----------------------------------------------------------------------------
# 5. Any diabetes code (E10-E14) in the mother's records (Narrow only)
# -----------------------------------------------------------------------------
# All KUHR and NPR records available for the mother (2008-2023).
ever_dm_mothers <- unique(dm_dx[code_starts_with(code, gdm_codes$diabetes_prefix), person_id])

# -----------------------------------------------------------------------------
# 6. Combine
# -----------------------------------------------------------------------------
flags <- win[, .(row_id, person_id)]
flags <- merge(flags, dx_flags, by = "row_id", all.x = TRUE)
flags <- merge(flags, rx_flags, by = "row_id", all.x = TRUE)
lgl <- c("gdm_dx", "unspec_dx", "early_gdm", "pregest_dx", "gdm_rx", "pregest_rx")
for (v in lgl) set(flags, which(is.na(flags[[v]])), v, FALSE)
flags[, ever_dm := person_id %in% ever_dm_mothers]

flags[, `:=`(
  dxrx_broad = as.integer(
    (gdm_dx | unspec_dx | gdm_rx) &
    !(early_gdm | pregest_dx | pregest_rx)
  ),
  dxrx_narrow = as.integer(
    (gdm_dx | gdm_rx) &
    !(early_gdm | pregest_dx | pregest_rx | ever_dm)
  )
)]

pregnancies <- merge(pregnancies, flags[, .(row_id, dxrx_broad, dxrx_narrow)],
                     by = "row_id", all.x = TRUE)
pregnancies[is.na(dxrx_broad),  dxrx_broad := 0L]
pregnancies[is.na(dxrx_narrow), dxrx_narrow := 0L]

# -----------------------------------------------------------------------------
# 7. Agreement between the three definitions
# -----------------------------------------------------------------------------
overlap <- pregnancies[, .N, by = .(mbrn_gdm, dxrx_broad, dxrx_narrow)][order(-N)]
print(overlap)
