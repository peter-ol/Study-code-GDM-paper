# =============================================================================
# 04_covariates.R
# Clinical, guideline-related and temporal covariates.
# Input:  pregnancies (from 03), mbrn_all (from 01)
# Output: pregnancies with the analysis covariates
# =============================================================================

source("R/00_setup.R")

# -----------------------------------------------------------------------------
# 1. Pre-pregnancy BMI
# -----------------------------------------------------------------------------
# MBRN BMI first. If BMI is missing, an obesity code in KUHR or NPR around
# conception (step 02) is used. Modelled as <25 vs >=25 kg/m2.
pregnancies[, maternal_BMI := fcase(
  !is.na(bmi_prepregnancy) & bmi_prepregnancy <  25, 0L,
  !is.na(bmi_prepregnancy) & bmi_prepregnancy >= 25, 1L,
  is.na(bmi_prepregnancy)  & obesity_dx == 1L,       1L,
  default = NA_integer_
)]

# -----------------------------------------------------------------------------
# 2. Parity and age (guideline risk groups)
# -----------------------------------------------------------------------------
pregnancies[, `:=`(
  nulliparous_over25 = fifelse(is.na(parity) | is.na(maternal_age), NA_integer_,
                               as.integer(parity == 0 & maternal_age > 25)),
  multiparous_over40 = fifelse(is.na(parity) | is.na(maternal_age), NA_integer_,
                               as.integer(parity > 0 & maternal_age > 40))
)]

# -----------------------------------------------------------------------------
# 3. Previous pregnancy-related GDM risk factors
# -----------------------------------------------------------------------------
# (a) Codes for shoulder dystocia, large baby or pre-eclampsia in KUHR/NPR
#     before conception (step 02).
# (b) An earlier birth of the same mother in MBRN (all years) with GDM,
#     pre-eclampsia, eclampsia, HELLP, hypertension, or birthweight >= 4500 g.
mbrn_all[, prev_risk := as.integer(
  mbrn_diabetes == mbrn_gdm_value | preeclampsia == 1 | eclampsia == 1 |
  hellp == 1 | hypertension_alone == 1 | birthweight >= 4500
)]
earlier <- merge(
  pregnancies[!is.na(mother_id), .(row_id, mother_id, index_date = delivery_date)],
  mbrn_all[prev_risk == 1L, .(mother_id, risk_date = delivery_date)],
  by = "mother_id", allow.cartesian = TRUE
)[risk_date < index_date, unique(row_id)]

pregnancies[, previous_pregnancy_risk := as.integer(
  previous_complication_dx == 1L | row_id %in% earlier
)]

# -----------------------------------------------------------------------------
# 4. Other clinical covariates
# -----------------------------------------------------------------------------
pregnancies[, `:=`(
  # Smoking before pregnancy (MBRN). Missing is kept as "Unreported".
  maternal_smoking = fcase(
    smoking_before == 1L, "No",
    smoking_before == 2L, "Occasionally",
    smoking_before == 3L, "Daily",
    default = "Unreported"
  ),
  # Assisted reproductive technology (MBRN). Missing = no.
  ART            = fifelse(is.na(art), 0L, as.integer(art == 1)),
  pco            = pcos_dx,
  hypothyroidism = hypothyroidism_dx,
  # Hypertension in pregnancy: KUHR/NPR code or MBRN pre-eclampsia,
  # eclampsia, HELLP or hypertension
  pregnancy_hypertension = as.integer(
    pregnancy_hypertension_dx == 1L |
    (!is.na(preeclampsia) & preeclampsia == 1) | (!is.na(eclampsia) & eclampsia == 1) |
    (!is.na(hellp) & hellp == 1) | (!is.na(hypertension_alone) & hypertension_alone == 1)
  )
)]

# -----------------------------------------------------------------------------
# 5. Time variables
# -----------------------------------------------------------------------------
pregnancies[, `:=`(
  # Delivery period
  covid_period = fcase(
    delivery_date <  covid_start_delivery, "Pre-COVID",
    delivery_date <= covid_end_delivery,   "During COVID",
    delivery_date >  covid_end_delivery,   "Post-COVID"
  ),
  # Calendar month of conception (seasonality)
  month = month(conception_date)
)]

# -----------------------------------------------------------------------------
# 6. Region labels
# -----------------------------------------------------------------------------
pregnancies[, maternal_region_name := county_names[as.character(maternal_region)]]
