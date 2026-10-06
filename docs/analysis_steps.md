# Analysis steps

This document describes each step of the analysis in the order it was run. Each section matches one script in the `R/` folder. The codes used in each step are listed in [code_lists.md](code_lists.md).

The pregnancy is the unit of analysis. A woman can contribute more than one pregnancy. All registries were linked using the mother's encrypted personal identification number.

---

## Step 1. Pregnancy file and sociodemographic linkage

Script: `R/01_build_pregnancy_file.R`

**Pregnancies.** We selected all births in MBRN with a delivery date from 1 January 2018 to 31 December 2023. Each row is one pregnancy. We estimated the conception date as the delivery date minus the gestational length in days recorded in MBRN. Gestational length in MBRN is mainly based on the ultrasound-estimated due date.

**Region of residence.** Region was the mother's county of residence in the year of delivery, from Statistics Norway. If this was missing, we used the county recorded in the housing register for the same year. Counties before the 2020 reform were mapped to the 2020 counties, giving 11 regions. Oslo was the reference region.

**Education.** We used the mother's highest completed education in the delivery year. If this was missing, we used the closest later year first and then the closest earlier year. Levels were grouped as no or primary, secondary, and tertiary education.

**Employment.** We first used the occupation field in MBRN. If this was missing, we used the labour market status from Statistics Norway in the delivery year. Wage earners and self-employed women were classified as employed. Women outside the workforce, unemployed women and non-wage earners were classified as unemployed or outside the workforce. If both were missing and the woman had an occupation code in Statistics Norway in the delivery year or the nearest year, she was classified as employed.

**Civil status.** We used MBRN first, with three groups: married or registered partner, cohabitant, and single (including divorced, separated and widowed). If MBRN was missing, we used civil status from Statistics Norway in the delivery year.

**Household size.** Number of persons in the household in the delivery year: small (1–2), medium (3–4) and large (5 or more).

**Living space per capita.** We divided the floor area of the dwelling by the number of persons in the household. We compared this value with the average in the same county:

- overcrowded: 50% of the county average or less
- typical: above 50% of the county average and up to the average
- spacious: above the county average

**Immigration background.** From the Statistics Norway immigration category:

- Norwegian-born, no immigrant background (including persons born abroad to Norwegian-born parents)
- foreign-born immigrant
- Norwegian-born to immigrant parents (including persons with one foreign-born parent)
- other or unclassified (adopted from abroad, foreign-born with one Norwegian parent)

**World region of family origin.** We used the Statistics Norway parent identifiers to find the mother's parents and grandparents. For the mother and each of these persons we recorded the world region of birth. A heritage indicator (Norwegian, European, African, Asian, Americas/Oceania) was 1 if the mother or any of her parents or grandparents was born in that region. These indicators are not mutually exclusive.

**Immigration date.** We recorded the mother's immigration date to Norway. This was used for the one-year look-back exclusion (Step 6).

---

## Step 2. Diagnoses in primary and secondary care

Script: `R/02_registry_diagnoses.R`

We read all KUHR claims (2008–2023) and all NPR episodes (2008–2023) for the mothers in the cohort. NPR included somatic care, mental health care, substance use treatment and contract specialists. For NPR, the contact date was the admission date. If this was missing, we used 31 December of the episode year.

Each record was linked to every pregnancy of the same mother. A covariate was set to 1 if at least one record with a matching code fell inside the time window for that pregnancy:

| Covariate | Time window |
|---|---|
| Obesity | 360 days before to 90 days after conception |
| Previous pregnancy complication | Any time before conception |
| Family history of diabetes (own code) | Any time before conception |
| PMOS | Any time up to delivery |
| Hypothyroidism | Any time up to delivery |
| Hypertension in pregnancy | Conception to delivery |

**Primary care visits.** We counted the number of distinct contact dates in KUHR in two windows:

- 365 days before conception
- from conception to the end of gestational week 24 (day 167)

---

## Step 3. Family history of diabetes

Script: `R/03_family_history.R`

1. We identified the mother's parents through the Statistics Norway family identifiers.
2. Siblings were all other persons with the same mother or the same father as the index mother.
3. We searched KUHR and NPR for diabetes codes (type 1, type 2 or unspecified) among these relatives.
4. A relative counted only if the diagnosis was recorded before the delivery date of the index pregnancy.

Coding:

- 1: at least one parent or sibling with diabetes
- 0: relatives were identified, but none had diabetes
- unknown: no relatives could be identified

If the value was unknown and the mother had her own code for family history of diabetes before conception, we set the value to 1. Unknown family history was mostly found among immigrant mothers, whose relatives often live outside Norway. We therefore kept "unknown" as a separate category in all models and did not impute it.

---

## Step 4. Clinical, guideline-related and time covariates

Script: `R/04_covariates.R`

**Pre-pregnancy BMI.** We used BMI from MBRN. If BMI was missing and the mother had an obesity code around conception (Step 2), she was classified as BMI 25 kg/m² or more. Because a diagnosis code does not give an exact BMI, BMI was modelled as a binary variable: below 25 or 25 kg/m² and above.

**Parity and age.** Two guideline risk groups: nulliparous and older than 25 years, and multiparous and older than 40 years.

**Previous pregnancy-related risk factors.** Set to 1 if either was true:

- a code for shoulder dystocia, a large baby or pre-eclampsia in KUHR or NPR before conception
- an earlier birth of the same mother in MBRN (all years) with GDM, pre-eclampsia, eclampsia, HELLP, hypertension, or birthweight of 4500 g or more

**Other clinical covariates.**

- Smoking before pregnancy (MBRN): no, occasionally, daily. Missing was kept as "unreported".
- Assisted reproductive technology (MBRN). Missing was coded as no.
- PMOS and hypothyroidism from Step 2.
- Plural pregnancy (MBRN).

**Delivery period.** Pregnancies were grouped by delivery date into pre-COVID-19 (before 17 February 2020), during COVID-19 (17 February 2020 to 13 February 2022) and post-COVID-19 (after 13 February 2022).

**Season.** The calendar month of conception was included as a categorical variable.

---

## Step 5. GDM case definitions

Script: `R/05_gdm_definitions.R`

We used three case definitions. The two DxRx definitions were adapted from the registry-based algorithms developed in the ConcePTION project (Mølgaard-Nielsen et al., BMJ Open 2025;15(10):e102343, https://doi.org/10.1136/bmjopen-2025-102343). The time windows are counted from the estimated conception date. "Week 14" means day 92 onwards. "First 13 weeks" means day 0 to day 91.

**MBRN GDM (primary outcome).** GDM recorded in the diabetes field of MBRN.

**DxRx Broad.** A pregnancy was GDM if at least one of these was present from gestational week 14 to delivery:

- a GDM code in KUHR or NPR
- an unspecified diabetes in pregnancy code in KUHR or NPR
- a dispensing of an antidiabetic drug in LMR

**DxRx Narrow.** A pregnancy was GDM if at least one of these was present from gestational week 14 to delivery:

- a GDM code in KUHR or NPR
- a dispensing of an antidiabetic drug in LMR

**Exclusions for both DxRx definitions.** A pregnancy was not counted as GDM if any of these was present:

- a GDM code in the first 13 weeks (suggests diabetes before pregnancy)
- a pre-existing diabetes in pregnancy code from conception to delivery
- a dispensing of an antidiabetic drug from 180 days before conception to the end of week 13

**Extra exclusion for DxRx Narrow.** A pregnancy was not counted as GDM if the mother had any type 1, type 2 or other diabetes code (E10–E14) in KUHR or NPR.

Every DxRx Narrow case is therefore also a DxRx Broad case. We described the overlap between the three definitions by cross-tabulation.

---

## Step 6. Exclusions and the analytic cohort

Script: `R/06_cohort_selection.R`

We excluded pregnancies in this order and counted the number excluded, and the number with MBRN GDM, at each step (Figure S1):

1. missing mother ID
2. missing maternal region of residence
3. unrealistic maternal age (younger than 15 or older than 49 years)
4. pregnancy duration shorter than 20 weeks (140 days), or missing gestational length
5. missing one-year look-back, defined as immigration to Norway less than 365 days before conception
6. MBRN-recorded diabetes other than GDM (type 1, type 2, other or unknown diabetes, and antidiabetic treatment without a diagnosis)

The final cohort included 300 824 pregnancies.

---

## Step 7. Multiple imputation

Script: `R/07_multiple_imputation.R`

Before imputation we reduced missing data with the registry linkage described in Steps 1–4. Remaining missing values were imputed with multiple imputation by chained equations.

- Number of imputed datasets: 20. Iterations: 10. Seed: 2025.
- Binary variables: logistic regression.
- Categorical variables with more than two levels: multinomial regression.
- Numeric variables: predictive mean matching.
- The outcomes (all three GDM definitions) and region were complete. They were used as predictors in the imputation models but were not imputed.
- All analysis covariates were included in the imputation model. Identifiers and dates were not used as predictors.
- Family history of diabetes was not imputed. "Unknown" was a separate category.

---

## Step 8. Modified Poisson regression

Script: `R/08_modified_poisson.R`

**Model.** We estimated risk ratios (RR) with a Poisson generalised linear model with a log link and a binary outcome. Standard errors were cluster-robust (HC0) with clustering on the mother, because a woman can have more than one pregnancy.

**Covariates in the main model.** Region (Oslo as reference), employment, civil status, education, household size, living space, immigration background, maternal age (continuous), BMI 25 or more, family history of diabetes, nulliparous and older than 25, multiparous and older than 40, previous pregnancy-related risk factors, PMOS, ART, hypothyroidism, smoking, delivery period, primary care visits in the year before pregnancy, primary care visits in the first 24 weeks, Asian, African, European and Americas/Oceania heritage, plural pregnancy and conception month.

**Pooling.** The model was fitted in each of the 20 imputed datasets. Log-RRs and their robust variances were combined with Rubin's rules. We then exponentiated the pooled estimate and its 95% confidence interval.

**Model checks** (first imputed dataset, MBRN GDM):

- generalised variance inflation factors for collinearity
- Pearson dispersion
- area under the ROC curve
- calibration by deciles of predicted risk
- Pearson and standardised residuals, and Cook's distance

**Subgroup: mothers with immigrant background.** The same model was fitted only among foreign-born mothers and Norwegian-born mothers with immigrant parents (Table S5).

**Sensitivity: any GDM definition.** The outcome was GDM by MBRN, DxRx Broad or DxRx Narrow. The same model and pooling were used (Table S6).

**Sensitivity: complete-case analysis.** We repeated the any GDM model without imputation. Only pregnancies with no missing value in any covariate were included. This model also included hypertension in pregnancy.

---

## Step 9. Socioeconomic indices and region x SES interaction

Script: `R/09_ses_index_interaction.R`

This was an exploratory analysis to see if socioeconomic gradients differed by region.

1. We used five categorical socioeconomic variables: education, employment, household size, living space and civil status. Immigration background was not included.
2. We ran an ordinal principal component analysis (`ordPens::ordPCA`) in the first imputed dataset and kept two components.
3. The loadings from this dataset were used to calculate the component scores in all 20 datasets.
4. The first component was mainly education, employment and living space. We reversed its sign so that a higher value means a more advantaged position. We called it the economic index.
5. The second component was mainly household size and civil status. We called it the social index.
6. Both indices were standardised to mean 0 and SD 1 within each dataset.
7. We fitted modified Poisson models with region x economic index and region x social index interaction terms. The five original SES variables were replaced by the two indices. The other covariates were the same as in the main model. Robust (HC0) standard errors were used.
8. Estimates were pooled with Rubin's rules. Only the interaction terms are reported (Table S3).

---

## Step 10. Interrupted time-series analysis

Script: `R/10_interrupted_time_series.R`

**Monthly series.** For each month we counted the number of pregnancies and the number of GDM cases. The primary time scale was the estimated pregnancy-start (conception) month. The series started in April 2017. To make sure every month had complete follow-up to delivery, the series stopped 10 months before the last delivery date in the data.

**Model terms.**

- `t`: continuous month index (pre-COVID-19 trend)
- calendar month as fixed effects (seasonality)
- step change at March 2020
- slope change from March 2020
- step change at March 2022
- slope change from March 2022

**Main model.** A generalised linear model for the monthly counts (cases and non-cases) with a logit link. We used a quasibinomial family to allow for overdispersion and Newey–West standard errors (lag 12 months) to allow for serial correlation.

**Overall COVID-19 deviation.** Joint Wald test of the four interruption terms.

**Counterfactual.** The no-COVID-19 trajectory was predicted with the four interruption terms set to zero. The baseline trend and calendar-month effects were kept. We drew 2000 sets of coefficients from a multivariate normal distribution with the estimated coefficients and Newey–West covariance. The fitted and counterfactual curves are the mean of these draws, and the 95% bands are the 2.5th and 97.5th percentiles. Predictions were back-transformed from the logit scale to cases per 100 pregnancies.

**Regional analyses.** The same model was fitted for each county. Regional Wald p-values were adjusted for multiple testing with the Benjamini–Hochberg method.

**Sensitivity analyses.**

- Time scale: interruption dates moved 4 months earlier, interruption dates moved 6 months later, and delivery month instead of conception month.
- Seasonality: Fourier terms (two harmonics) instead of calendar-month fixed effects.
- Model form: ARIMA errors on the empirical logit of monthly prevalence, with automatic order selection and Fourier seasonality.
- Model form: Bayesian binomial model with a logit link and Fourier seasonality. Priors were normal(0, 2) for the coefficients and normal(0, 5) for the intercept. We used 4 chains of 4000 iterations with 2000 warm-up. This model was fitted for the national series only.
- One-break models: a single step and slope change at March 2020 for the GLM, ARIMA and Bayesian models.

The ITS results were interpreted descriptively.

---

## Step 11. Tables and figures

Script: `R/11_tables_figures.R`

- Table 1 and Table S10: characteristics of all pregnancies and of pregnancies with GDM by each definition. Mean (SD) for maternal age, median (IQR) for visits, n (%) for categories.
- Table S9: characteristics by region.
- Crude GDM prevalence by county, delivery year and case definition.
- Figure 1: county map of crude MBRN GDM prevalence in 2018 and 2023 (2020 county borders).
- Figure 2: forest plot of the pooled adjusted RRs for MBRN GDM, log scale.
- Figure 3: observed, fitted and counterfactual monthly prevalence from the main ITS model (Step 10).
- Figure S3: monthly GDM prevalence by delivery month for the three case definitions.
