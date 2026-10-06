# =============================================================================
# 11_tables_figures.R
# Descriptive tables and figures.
#   Table 1      baseline characteristics, all pregnancies and MBRN GDM
#   Table S9/S10 characteristics by region and by DxRx definition
#   Figure 1     map of MBRN GDM prevalence by county, 2018 and 2023
#   Figure 2     forest plot of adjusted RRs, MBRN GDM
#   Figure S3    monthly prevalence by delivery month and case definition
#   Prevalence by county, year and definition; overlap of definitions
# Word formatting of the tables (flextable/officer) is not included here.
# Input: analysis_data (from 06), results_main_pooled_RR.csv (from 08)
# =============================================================================

source("R/00_setup.R")
library(ggplot2)
library(gtsummary)

d <- copy(analysis_data)
d[, delivery_year := year(delivery_date)]
d[, bmi_25 := factor(maternal_BMI, levels = 0:1, labels = c("<25", ">=25"))]

# -----------------------------------------------------------------------------
# Table 1 and Table S10
# -----------------------------------------------------------------------------
table_vars <- c("maternal_region", "immigrant", "maternal_education",
                "maternal_employment", "maternal_civil_status", "household_size",
                "living_space", "maternal_age", "bmi_25", "familial_diabetes",
                "asian_ethnicity", "african_ethnicity", "nulliparous_over25",
                "multiparous_over40", "previous_pregnancy_risk", "pco",
                "hypothyroidism", "ART", "maternal_smoking",
                "visits_1y_before", "visits_24w", "covid_period")

table_long <- rbind(
  d[, c(table_vars), with = FALSE][, group := "All pregnancies"],
  d[mbrn_gdm == 1,    c(table_vars), with = FALSE][, group := "MBRN GDM"],
  d[dxrx_broad == 1,  c(table_vars), with = FALSE][, group := "DxRx Broad"],
  d[dxrx_narrow == 1, c(table_vars), with = FALSE][, group := "DxRx Narrow"]
)

table1 <- tbl_summary(
  table_long, by = group,
  statistic = list(maternal_age ~ "{mean} ({sd})",
                   c(visits_1y_before, visits_24w) ~ "{median} ({p25}-{p75})",
                   all_categorical() ~ "{n} ({p}%)"),
  missing_text = "Missing"
)
table1

# Table S9: characteristics by region
table_s9 <- tbl_summary(d[, c(table_vars), with = FALSE], by = maternal_region,
                        missing_text = "Missing")

# -----------------------------------------------------------------------------
# Prevalence by county, year and case definition
# -----------------------------------------------------------------------------
prev_region_year <- d[, .(
  pregnancies = .N,
  mbrn_pct    = 100 * mean(mbrn_gdm),
  broad_pct   = 100 * mean(dxrx_broad),
  narrow_pct  = 100 * mean(dxrx_narrow)
), by = .(maternal_region, delivery_year)][order(maternal_region, delivery_year)]
fwrite(prev_region_year, "prevalence_by_region_year.csv")

# Overlap of the three definitions
overlap <- d[, .N, by = .(mbrn_gdm, dxrx_broad, dxrx_narrow)][order(-N)]
print(overlap)

# -----------------------------------------------------------------------------
# Figure 1: map, MBRN GDM prevalence 2018 and 2023
# -----------------------------------------------------------------------------
# County polygons from the csmaps package (2020 county borders, Oslo inset)
map_dt <- copy(csmaps::nor_county_map_b2020_insert_oslo_dt)
map_dt[, maternal_region := county_names[as.character(as.integer(sub("county_nor", "", location_code)))]]

prev_map <- d[delivery_year %in% c(2018, 2023),
              .(prevalence = 100 * mean(mbrn_gdm)), by = .(maternal_region, delivery_year)]
map_plot <- merge(map_dt, prev_map, by = "maternal_region", allow.cartesian = TRUE)

fig1 <- ggplot(map_plot, aes(long, lat, group = group, fill = prevalence)) +
  geom_polygon(colour = "white", linewidth = 0.15) +
  coord_quickmap() +
  facet_wrap(~ delivery_year) +
  scale_fill_gradient(low = "grey90", high = "grey10", limits = c(0, 10),
                      name = "MBRN GDM (%)") +
  theme_void()
ggsave("figure1_map_2018_2023.png", fig1, width = 8, height = 6, dpi = 320)

# -----------------------------------------------------------------------------
# Figure 2: forest plot, MBRN GDM
# -----------------------------------------------------------------------------
res <- fread("results_main_pooled_RR.csv")[outcome == "mbrn_gdm" & term != "(Intercept)"]
show_terms <- c(
  grep("^maternal_region", res$term, value = TRUE),
  grep("^immigrant|^maternal_education|^maternal_employment|^household_size|^living_space",
       res$term, value = TRUE),
  "maternal_BMI1", "familial_diabetes1", "previous_pregnancy_risk1",
  "asian_ethnicity1", "african_ethnicity1",
  grep("^covid_period", res$term, value = TRUE)
)
fp <- res[term %in% show_terms]
fp[, term := factor(term, levels = rev(show_terms))]

fig2 <- ggplot(fp, aes(x = RR, y = term)) +
  geom_vline(xintercept = 1, linetype = "dashed") +
  geom_errorbar(aes(xmin = RR_low, xmax = RR_high), width = 0.2, orientation = "y") +
  geom_point() +
  scale_x_log10() +
  labs(x = "Adjusted risk ratio (95% CI), log scale", y = NULL) +
  theme_bw()
ggsave("figure2_forest_mbrn.png", fig2, width = 8, height = 10, dpi = 320)

# -----------------------------------------------------------------------------
# Figure S3: monthly prevalence by delivery month
# -----------------------------------------------------------------------------
monthly <- d[, .(MBRN = 100 * mean(mbrn_gdm),
                 `DxRx Broad` = 100 * mean(dxrx_broad),
                 `DxRx Narrow` = 100 * mean(dxrx_narrow)),
             by = .(month = floor_date(as.Date(delivery_date), "month"))]
monthly <- melt(monthly, id.vars = "month", variable.name = "definition",
                value.name = "prevalence")

figS3 <- ggplot(monthly, aes(month, prevalence, linetype = definition)) +
  annotate("rect", xmin = as.Date("2020-03-01"), xmax = as.Date("2022-02-28"),
           ymin = -Inf, ymax = Inf, alpha = 0.15) +
  geom_line() +
  labs(x = "Delivery month", y = "GDM per 100 pregnancies", linetype = NULL) +
  theme_bw()
ggsave("figureS3_monthly_prevalence.png", figS3, width = 9, height = 5, dpi = 320)
