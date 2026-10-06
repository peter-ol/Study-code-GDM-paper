# =============================================================================
# 02_registry_diagnoses.R
# Diagnosis flags from primary care (KUHR) and secondary care (NPR), and the
# number of primary care contacts before and during pregnancy.
# Input:  pregnancies (from 01)
# Output: pregnancies with diagnosis flags and visit counts
# =============================================================================

source("R/00_setup.R")

mother_ids <- unique(pregnancies[!is.na(mother_id), mother_id])

# -----------------------------------------------------------------------------
# 1. Read the diagnosis records for the mothers
# -----------------------------------------------------------------------------
# KUHR: one file per year 2008-2023. Columns: person_id, contact_date, code.
kuhr <- as.data.table(read_source("kuhr"))[person_id %in% mother_ids]
kuhr[, contact_date := as.IDate(contact_date)]

# NPR: somatic and mental health care, substance use treatment and contract
# specialists, 2008-2023. Columns: person_id, admission_date, year, code.
# When the admission date is missing, 31 December of the episode year is used.
npr <- as.data.table(read_source("npr"))[person_id %in% mother_ids]
npr[, contact_date := fifelse(!is.na(admission_date),
                              as.IDate(admission_date),
                              as.IDate(paste0(year, "-12-31")))]

diagnoses <- rbind(
  kuhr[, .(person_id, contact_date, code, source = "KUHR")],
  npr[,  .(person_id, contact_date, code, source = "NPR")]
)

# -----------------------------------------------------------------------------
# 2. Flag each record by code group
# -----------------------------------------------------------------------------
for (g in names(covariate_codes)) {
  diagnoses[, (g) := code_starts_with(code, covariate_codes[[g]])]
}
keep <- diagnoses[, Reduce(`|`, .SD), .SDcols = names(covariate_codes)]
diagnoses <- diagnoses[keep]

# Link every record to every pregnancy of the same mother
dx <- merge(
  diagnoses,
  pregnancies[!is.na(mother_id), .(row_id, person_id = mother_id,
                                   conception_date, delivery_date)],
  by = "person_id", allow.cartesian = TRUE
)

# -----------------------------------------------------------------------------
# 3. Apply the time window for each code group
# -----------------------------------------------------------------------------
dx[, `:=`(
  # From 360 days before to 90 days after conception
  obesity_dx = obesity &
    contact_date >= conception_date - obesity_before &
    contact_date <= conception_date + obesity_after,
  # Before conception
  previous_complication_dx = previous_complication & contact_date <= conception_date,
  family_history_dx        = family_history        & contact_date <= conception_date,
  # Any time up to delivery
  pcos_dx                  = pcos                  & contact_date <= delivery_date,
  hypothyroidism_dx        = hypothyroidism        & contact_date <= delivery_date,
  # During pregnancy
  pregnancy_hypertension_dx = pregnancy_hypertension &
    contact_date >= conception_date & contact_date <= delivery_date
)]

flag_cols <- grep("_dx$", names(dx), value = TRUE)
dx_flags <- dx[, lapply(.SD, function(x) as.integer(any(x))), by = row_id, .SDcols = flag_cols]

pregnancies <- merge(pregnancies, dx_flags, by = "row_id", all.x = TRUE)
for (v in flag_cols) set(pregnancies, which(is.na(pregnancies[[v]])), v, 0L)

# -----------------------------------------------------------------------------
# 4. Primary care contacts (all KUHR claims, any code)
# -----------------------------------------------------------------------------
# Number of distinct contact dates
#   - in the 365 days before conception
#   - from conception to the end of gestational week 24
visits <- merge(
  unique(kuhr[, .(person_id, contact_date)]),
  pregnancies[!is.na(mother_id), .(row_id, person_id = mother_id, conception_date)],
  by = "person_id", allow.cartesian = TRUE
)
visit_counts <- visits[, .(
  visits_1y_before = uniqueN(contact_date[contact_date >= conception_date - 365 &
                                          contact_date <  conception_date]),
  visits_24w       = uniqueN(contact_date[contact_date >= conception_date &
                                          contact_date <= conception_date + week24_days])
), by = row_id]

pregnancies <- merge(pregnancies, visit_counts, by = "row_id", all.x = TRUE)
pregnancies[is.na(visits_1y_before), visits_1y_before := 0L]
pregnancies[is.na(visits_24w),       visits_24w := 0L]

# The NPR and KUHR records are kept for the GDM algorithms in step 05
# and the family history in step 03.
