# =============================================================================
# 01_build_pregnancy_file.R
# Builds one row per pregnancy (delivery 2018-2023) from the Medical Birth
# Registry and links the sociodemographic information from Statistics Norway.
# Output: pregnancies (data.table)
# =============================================================================

source("R/00_setup.R")

# -----------------------------------------------------------------------------
# 1. Births from the Medical Birth Registry (MBRN)
# -----------------------------------------------------------------------------
# Columns used: mother_id, child_id, father_id, delivery_date, gest_days,
# maternal_age, parity, bmi_prepregnancy, mbrn_diabetes, smoking_before,
# art, civil_status_mbrn, occupation_mbrn, plural_pregnancy, birthweight,
# preeclampsia, eclampsia, hellp, hypertension_alone
mbrn_all <- as.data.table(read_source("mbrn"))
mbrn_all[, delivery_date := as.IDate(delivery_date)]

pregnancies <- mbrn_all[delivery_date >= study_start & delivery_date <= study_end]
pregnancies[, `:=`(
  row_id          = .I,
  delivery_year   = year(delivery_date),
  # Estimated conception date = delivery date minus gestational length in days
  conception_date = delivery_date - gest_days
)]

# Helper table used for all yearly SSB look-ups
index_mother <- pregnancies[!is.na(mother_id),
                            .(row_id, person_id = mother_id, delivery_year)]

# -----------------------------------------------------------------------------
# 2. Region of residence (county) at delivery
# -----------------------------------------------------------------------------
# Main source: county of residence in the delivery year.
# Fallback: county recorded in the housing register for the delivery year.
residence <- as.data.table(read_source("ssb_residence"))   # person_id, year, county
housing   <- as.data.table(read_source("ssb_housing"))     # person_id, year, county,
                                                           # persons_household, floor_area_m2
residence[, county := harmonise_county(county)]
housing[,   county := harmonise_county(county)]

region <- merge(index_mother,
                residence[, .(person_id, delivery_year = year, county_res = county)],
                by = c("person_id", "delivery_year"), all.x = TRUE)
region <- merge(region,
                housing[, .(person_id, delivery_year = year, county_house = county)],
                by = c("person_id", "delivery_year"), all.x = TRUE)
region[, maternal_region := fcoalesce(county_res, county_house)]
pregnancies[region, on = "row_id", maternal_region := i.maternal_region]

# -----------------------------------------------------------------------------
# 3. Household size and living space per capita (delivery year)
# -----------------------------------------------------------------------------
hh <- merge(index_mother,
            housing[, .(person_id, delivery_year = year, county_house = county,
                        persons_household, floor_area_m2)],
            by = c("person_id", "delivery_year"), all.x = TRUE)

hh[, household_size := fcase(
  is.na(persons_household) | persons_household == 0, NA_character_,
  persons_household <= 2, "small",
  persons_household <= 4, "medium",
  persons_household >= 5, "large"
)]

# Square metres per person, compared with the average in the same county
hh[, sqm_capita := fifelse(persons_household > 0, floor_area_m2 / persons_household, NA_real_)]
hh[sqm_capita == 0, sqm_capita := NA_real_]
hh[, county_mean_sqm := mean(sqm_capita, na.rm = TRUE), by = county_house]
hh[, living_space := fcase(
  is.na(sqm_capita),                     NA_character_,
  sqm_capita <= 0.5 * county_mean_sqm,   "overcrowded",
  sqm_capita <= county_mean_sqm,         "typical",
  sqm_capita >  county_mean_sqm,         "spacious"
)]
pregnancies[hh, on = "row_id", `:=`(household_size = i.household_size,
                                    living_space   = i.living_space)]

# -----------------------------------------------------------------------------
# 4. Education (delivery year, otherwise nearest available year)
# -----------------------------------------------------------------------------
education <- as.data.table(read_source("ssb_education"))   # person_id, year, value
edu <- pick_nearest_year(index_mother, education)
edu[, maternal_education := fcase(
  value %in% c("IU", "GS"),         "No/Primary",
  value == "VGS",                   "Secondary",
  value %in% c("FS", "UHK", "UHL"), "Tertiary",
  default = NA_character_
)]
pregnancies[edu, on = "row_id", maternal_education := i.maternal_education]

# -----------------------------------------------------------------------------
# 5. Employment
# -----------------------------------------------------------------------------
# Step 1: occupation field in MBRN (1 = not employed, 2/3 = employed).
# Step 2: if missing, labour market status from SSB in the delivery year.
# Step 3: if still missing, an occupation code in SSB in the delivery year or
#         the nearest year is taken as evidence of employment.
pregnancies[, maternal_employment := fcase(
  occupation_mbrn %in% c(2L, 3L), "Employed",
  occupation_mbrn == 1L,          "Unemployed",
  default = NA_character_
)]

labour <- as.data.table(read_source("ssb_labour"))          # person_id, year, status
lab <- merge(index_mother,
             labour[, .(person_id, delivery_year = year, status)],
             by = c("person_id", "delivery_year"))
lab[, employment_ssb := fcase(
  status %in% c(1L, 2L),             "Employed",
  status %in% c(0L, 3L, 4L, 9L),     "Unemployed",
  default = NA_character_
)]
pregnancies[lab, on = "row_id",
            maternal_employment := fcoalesce(maternal_employment, i.employment_ssb)]

occupation <- as.data.table(read_source("ssb_occupation"))  # person_id, year, value
occ <- pick_nearest_year(index_mother, occupation)
pregnancies[occ, on = "row_id",
            maternal_employment := fifelse(is.na(maternal_employment) & !is.na(i.value),
                                           "Employed", maternal_employment)]

# -----------------------------------------------------------------------------
# 6. Civil status
# -----------------------------------------------------------------------------
# Step 1: MBRN (1 = married/registered partner, 2 = cohabitant,
#         3, 4, 9 = single, divorced, widowed or other).
# Step 2: if missing, SSB civil status in the delivery year
#         (2, 6 = married/registered partner, other codes = single).
pregnancies[, maternal_civil_status := fcase(
  civil_status_mbrn == 1L,                 "Married/registered partner",
  civil_status_mbrn == 2L,                 "Cohabitant",
  civil_status_mbrn %in% c(3L, 4L, 9L),    "Single",
  default = NA_character_
)]

civil <- as.data.table(read_source("ssb_civil_status"))      # person_id, year, status
civ <- merge(index_mother,
             civil[, .(person_id, delivery_year = year, status)],
             by = c("person_id", "delivery_year"))
civ[, civil_ssb := fcase(
  status %in% c(2L, 6L),                       "Married/registered partner",
  status %in% c(1L, 3L, 4L, 5L, 7L, 8L, 9L),   "Single",
  default = NA_character_
)]
pregnancies[civ, on = "row_id",
            maternal_civil_status := fcoalesce(maternal_civil_status, i.civil_ssb)]

# -----------------------------------------------------------------------------
# 7. Immigration background and world region of family origin
# -----------------------------------------------------------------------------
# population: person_id, immigration_category (A-G), birth_region (V0-V5),
#             parent_mother_id, parent_father_id
population <- unique(as.data.table(read_source("ssb_population")), by = "person_id")

population[, immigrant := fcase(
  immigration_category %in% c("A", "G"), "Norwegian-born, no immigrant background",
  immigration_category == "B",           "Immigrant (foreign-born)",
  immigration_category %in% c("C", "F"), "Norwegian-born to immigrant parents",
  immigration_category %in% c("D", "E"), "Other/Unclassified",
  default = NA_character_
)]
pregnancies[population, on = c(mother_id = "person_id"), immigrant := i.immigrant]

# World region of birth for the mother, her parents and her grandparents.
# A heritage indicator is 1 if any of these persons was born in that region.
# The indicators are therefore not mutually exclusive.
region_of <- function(code) fcase(
  code == "V0",             "norwegian",
  code == "V1",             "european",
  code == "V2",             "african",
  code == "V3",             "asian",
  code %in% c("V4", "V5"),  "americas_oceania",
  default = NA_character_
)

ancestors <- population[, .(person_id,
                            mother_of = parent_mother_id,
                            father_of = parent_father_id)]
lineage <- pregnancies[!is.na(mother_id), .(row_id, self = mother_id)]
lineage[ancestors, on = c(self = "person_id"), `:=`(mo = i.mother_of, fa = i.father_of)]
lineage[ancestors, on = c(mo = "person_id"),   `:=`(mo_mo = i.mother_of, mo_fa = i.father_of)]
lineage[ancestors, on = c(fa = "person_id"),   `:=`(fa_mo = i.mother_of, fa_fa = i.father_of)]

lineage_long <- melt(lineage, id.vars = "row_id",
                     value.name = "person_id", na.rm = TRUE)[, variable := NULL]
lineage_long[population, on = "person_id", origin := region_of(i.birth_region)]

heritage <- dcast(lineage_long[!is.na(origin)], row_id ~ origin,
                  fun.aggregate = function(x) as.integer(length(x) > 0),
                  value.var = "origin")
heritage_cols <- c("norwegian", "european", "african", "asian", "americas_oceania")
for (h in setdiff(heritage_cols, names(heritage))) heritage[, (h) := 0L]
setnames(heritage, heritage_cols, paste0(heritage_cols, "_ethnicity"))
pregnancies <- merge(pregnancies, heritage, by = "row_id", all.x = TRUE)
for (h in paste0(heritage_cols, "_ethnicity")) {
  set(pregnancies, which(is.na(pregnancies[[h]])), h, 0L)
}

# -----------------------------------------------------------------------------
# 8. Immigration date (used for the one-year look-back exclusion)
# -----------------------------------------------------------------------------
migration <- as.data.table(read_source("ssb_migration"))     # person_id, immigration_date
pregnancies[migration, on = c(mother_id = "person_id"),
            immigration_date := as.IDate(i.immigration_date)]

# Less than one year of residence in Norway before conception
pregnancies[, lookback_missing_1y := as.integer(
  !is.na(immigration_date) & immigration_date > conception_date - 365
)]
