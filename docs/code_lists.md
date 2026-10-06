# Code lists and time windows

Codes are ICD-10 (NPR and KUHR), ICPC-2 (KUHR) and ATC (LMR). Dots were removed before matching, so O24.4 and O244 are the same code. Time windows are counted from the estimated conception date (delivery date minus gestational length in days).

## GDM case definitions

DxRx Narrow and DxRx Broad were adapted from the algorithms developed in the ConcePTION project (Mølgaard-Nielsen et al., BMJ Open 2025;15(10):e102343, https://doi.org/10.1136/bmjopen-2025-102343).

| Component | Codes | Source | Time window | DxRx Narrow | DxRx Broad | MBRN GDM |
|---|---|---|---|---|---|---|
| GDM in birth registry | Diabetes field = GDM | MBRN | Current pregnancy | | | Include |
| GDM diagnosis | ICD-10 O24.4; ICPC-2 W85 | KUHR, NPR | Week 14 to delivery | Include | Include | |
| Unspecified diabetes in pregnancy | ICD-10 O24.9 | KUHR, NPR | Week 14 to delivery | | Include | |
| Antidiabetic dispensing | ATC A10A, A10B, A10X | LMR | Week 14 to delivery | Include | Include | |
| Early GDM diagnosis | ICD-10 O24.4; ICPC-2 W85 | KUHR, NPR | Conception to end of week 13 | Exclude | Exclude | |
| Pre-existing diabetes in pregnancy | ICD-10 O24.0–O24.3 | KUHR, NPR | Conception to delivery | Exclude | Exclude | |
| Antidiabetic dispensing before or in early pregnancy | ATC A10A, A10B, A10X | LMR | 180 days before conception to end of week 13 | Exclude | Exclude | |
| Diabetes in the mother's records | ICD-10 E10–E14 (all subcodes) | KUHR, NPR | Any record 2008–2023 | Exclude | | |

"Include" components are combined with OR. "Exclude" components are combined with AND NOT. Week 14 starts on day 92. The end of week 13 is day 91.

Pregnancies with MBRN-recorded diabetes other than GDM (type 1, type 2, other or unknown diabetes, antidiabetic treatment without diagnosis) were removed from the cohort before the outcomes were defined.

## Covariates from KUHR and NPR

Codes are matched on the start of the code, so E66 also matches E66.0 to E66.9.

| Covariate | Codes | Time window |
|---|---|---|
| Obesity (used when MBRN BMI is missing) | ICD-10 E66; ICPC-2 T82 | 360 days before to 90 days after conception |
| Previous pregnancy complication | ICD-10 O66.0, O66.2 (shoulder dystocia), P08.0 (exceptionally large baby), O14 (pre-eclampsia); ICPC-2 W81 | Before conception |
| Own code for family history of diabetes | ICD-10 Z83.3 | Before conception |
| PMOS | ICD-10 E28.2; ICPC-2 T99.0072, T99.0069 | Up to delivery |
| Hypothyroidism | ICD-10 E03.3; ICPC-2 T86 | Up to delivery |
| Hypertension in pregnancy | ICD-10 O13; ICPC-2 W81 | Conception to delivery |
| Diabetes in relatives (family history) | ICD-10 E10–E14; ICPC-2 T89, T90 | Before the index delivery |

## Covariates from MBRN

| Covariate | Definition |
|---|---|
| Maternal age | Age at delivery, continuous |
| Pre-pregnancy BMI | Below 25 vs 25 kg/m² or more |
| Nulliparous and older than 25 | Parity 0 and age above 25 |
| Multiparous and older than 40 | Parity 1 or more and age above 40 |
| Earlier pregnancy with risk factor | Earlier birth of the same mother with GDM, pre-eclampsia, eclampsia, HELLP, hypertension, or birthweight 4500 g or more |
| Hypertension in pregnancy | Pre-eclampsia, eclampsia, HELLP or hypertension in the current pregnancy, or a code in KUHR/NPR |
| Smoking before pregnancy | No, occasionally, daily, unreported |
| Assisted reproductive technology | Yes/no |
| Plural pregnancy | Yes/no |

## Primary care visits (KUHR)

| Covariate | Definition |
|---|---|
| Visits in the year before pregnancy | Number of distinct contact dates from 365 days before conception up to the day before conception |
| Visits in the first 24 weeks | Number of distinct contact dates from conception to day 167 |

## Region codes

Counties before the 2020 reform were mapped to the 2020 counties.

| 2020 county | Code | Earlier county codes mapped to it |
|---|---|---|
| Oslo | 03 | |
| Rogaland | 11 | |
| Møre og Romsdal | 15 | |
| Nordland | 18 | |
| Viken | 30 | 01, 02, 06 |
| Innlandet | 34 | 04, 05 |
| Vestfold og Telemark | 38 | 07, 08 |
| Agder | 42 | 09, 10 |
| Vestland | 46 | 12, 14 |
| Trøndelag | 50 | |
| Troms og Finnmark | 54 | 19, 20 |
