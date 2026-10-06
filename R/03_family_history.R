# =============================================================================
# 03_family_history.R
# Family history of diabetes in first-degree relatives (parents and siblings).
# Input:  pregnancies (from 02), population (from 01)
# Output: pregnancies$familial_diabetes  (1 / 0 / NA = unknown)
# =============================================================================

source("R/00_setup.R")

# -----------------------------------------------------------------------------
# 1. Identify parents and siblings of each mother
# -----------------------------------------------------------------------------
# population: person_id, parent_mother_id, parent_father_id (from SSB)
fam <- population[, .(person_id, parent_mother_id, parent_father_id)]

# Siblings = other persons with the same mother or the same father
sib_by_mother <- fam[!is.na(parent_mother_id),
                     .(sibling_id = person_id), by = parent_mother_id]
sib_by_father <- fam[!is.na(parent_father_id),
                     .(sibling_id = person_id), by = parent_father_id]

mothers <- fam[person_id %in% pregnancies$mother_id]

relatives <- unique(rbind(
  mothers[!is.na(parent_mother_id), .(mother_id = person_id, relative_id = parent_mother_id)],
  mothers[!is.na(parent_father_id), .(mother_id = person_id, relative_id = parent_father_id)],
  merge(mothers[, .(mother_id = person_id, parent_mother_id)],
        sib_by_mother, by = "parent_mother_id")[, .(mother_id, relative_id = sibling_id)],
  merge(mothers[, .(mother_id = person_id, parent_father_id)],
        sib_by_father, by = "parent_father_id")[, .(mother_id, relative_id = sibling_id)]
))
relatives <- relatives[relative_id != mother_id]

# -----------------------------------------------------------------------------
# 2. Diabetes diagnoses among relatives (KUHR 2008-2023 and NPR)
# -----------------------------------------------------------------------------
# Read the full KUHR and NPR files again, now for the relatives.
relative_ids <- unique(relatives$relative_id)
kuhr_rel <- as.data.table(read_source("kuhr"))[person_id %in% relative_ids]
npr_rel  <- as.data.table(read_source("npr"))[person_id %in% relative_ids]
npr_rel[, contact_date := fifelse(!is.na(admission_date),
                                  as.IDate(admission_date),
                                  as.IDate(paste0(year, "-12-31")))]

rel_dm <- rbind(
  kuhr_rel[code_starts_with(code, covariate_codes$diabetes),
           .(relative_id = person_id, contact_date = as.IDate(contact_date))],
  npr_rel[code_starts_with(code, covariate_codes$diabetes),
          .(relative_id = person_id, contact_date)]
)

# A relative counts if the diagnosis was recorded before the index delivery
match_dt <- merge(
  merge(pregnancies[!is.na(mother_id), .(row_id, mother_id, delivery_date)],
        relatives, by = "mother_id", allow.cartesian = TRUE),
  rel_dm, by = "relative_id", allow.cartesian = TRUE
)[contact_date < delivery_date, unique(row_id)]

# -----------------------------------------------------------------------------
# 3. Final coding
# -----------------------------------------------------------------------------
# 1  = at least one relative with diabetes
# 0  = relatives identified, none with diabetes
# NA = no relatives identified (unknown). Mostly mothers whose family lives
#      outside Norway. Kept as a separate "missing" category in the models.
# A mother's own code for family history of diabetes (Z83.3) before conception
# sets an unknown value to 1.
has_family <- unique(relatives$mother_id)

pregnancies[, familial_diabetes := fcase(
  row_id %in% match_dt,          1L,
  mother_id %in% has_family,     0L,
  default = NA_integer_
)]
pregnancies[is.na(familial_diabetes) & family_history_dx == 1L, familial_diabetes := 1L]
