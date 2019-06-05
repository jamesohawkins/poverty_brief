
********************************************************************************
//	program:			main-paper
//	task:				do file for poverty issue brief
//	project:			poverty issue brief (main paper)
//	author:				joh \ 2019-06-04
********************************************************************************

// Set file/directory macros
* directory for all results (dta and excel files)
global output 				""
* directory for OPM data from IPUMS
* sample: 1971-2018 (survey year)
global cps			 		""
* directory for SPM data from IPUMS (need replicate weights)
* sample: 2010-2018 (survey year)
global cps_replicate 		""													// separated CPS data for Figure 3 and CPS data for Figure 1 (replicate) into separate files due to file sizes. Both are from IPUMS
* directory for Historical SPM data from Center on Poverty & Social Policy at
* Columbia University
global spm_1968_2016		""													
global do_files				""


cd "$do_files"
version 15
clear all
set linesize 80

capture log close
log using "main-paper", replace text


// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
// Figure 1
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
/* SPM data from IPUMS through the University of Minnesota, see:
   https://cps.ipums.org/cps/
*/

cd "$cps_replicate"
* rename file from IPUMS as raw.dta
use raw.dta, clear
cd "$output"

// Data Cleaning
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
// Replacing with "poverty year" by subtracting 1 from survey year
tab year
replace year = year - 1

// Only keeping years that are in the supplemental pov sample (2009-2017)
keep if year >= 2009 & year <= 2017

// Removing 3/8 file for 2014
* see: https://cps.ipums.org/cps/three_eighths.shtml
tab hflag
tab hflag, nol
drop if hflag == 1

// Recoding poverty variable
tab spmpov, missing
	/* no recode needed */

// Creating two separate age variables for analysis
* see: https://cps.ipums.org/cps-action/variables/AGE#codes_section
* binned ages
gen age_bin = .
replace age_bin = 1 if age >= 0 & age <= 6
replace age_bin = 2 if age >= 7 & age <= 13
replace age_bin = 3 if age >= 14 & age <= 17
replace age_bin = 4 if age >= 18 & age <= 24
replace age_bin = 5 if age >= 25 & age <= 29
replace age_bin = 6 if age >= 30 & age <= 34
replace age_bin = 7 if age >= 35 & age <= 44
replace age_bin = 8 if age >= 45 & age <= 54
replace age_bin = 9 if age >= 55 & age <= 64
replace age_bin = 10 if age >= 65 & age <= 74
replace age_bin = 11 if age >= 75
tab age age_bin
* recode of single year ages
gen age_ = age
replace age_ = 75 if age >= 75													// combining 75+ into single bin
tab age age_

// Adjusting weights to account for pooled data
/* note: this adjustment has no effect on results for *rates* of poverty
*/
tab year
replace asecwt = asecwt / 9 if year >= 2009 & year <= 2017

// Generating binned years
/* note: bin is based on March immediately after peak until March immediately
		 before next peak; spm data unavailable for 2008; see technical appendix 
		 for additional details
*/
gen year_bin = 7 if year >= 2009 & year <= 2017									// SPM data unavailable prior to 2009

// Saving base file
compress
save spmpov_2009-2017_replicate.dta, replace

// Data Analysis
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
cd "$output"
use spmpov_2009-2017_replicate.dta, clear

// Setting survey analysis method (replicate weight)
* see: https://cps.ipums.org/cps/repwt.shtml
svyset [iw=asecwt], sdrweight(repwtp1-repwtp160) vce(sdr) mse


// 100% poverty threshold: estimates of supplemental poverty rate by age
preserve
gen spmthresh_100 = spmthresh * 1												// for consistency with code below, creating threshold for 100% of poverty (no difference from original spmpov variable)
gen spmpov_100 = (spmtotres < spmthresh_100)
tab spmpov_100 spmpov
svy: mean spmpov_100, over(age_)
/* note: mean of weighted dummy/binary variable will result in proportion of 
   population in poverty
*/
   
// Storing results
* storing estimates in matrix
matrix list r(table)
mat A = r(table)
mat se = A[2, 1..colsof(A)]														// storing se estimates
mat se = se' 																	// transforming standard errors into single list
mat list se
mat b = A[1, 1..colsof(A)]														// storing point estimates
mat b = b'																		// transforming point estimates into single list
mat list b
* creating new file with years/age variables
clear
set obs 100
gen year_bin = 7
gen age_ = .
* single observation for each separate age group
replace age_ = _n - 1 in 1/76
drop if age_ == .
* storing results into associated year/age variables
svmat b
rename b1 spmpov_mean
svmat se
rename se1 spmpov_se
gen spm_category = "100% threshold"
* saving results
save spmpov_100.dta, replace
restore

// 200% poverty thrsehold: estimates of supplemental poverty rate by age
preserve
gen spmthresh_200 = spmthresh * 2
gen spmpov_200 = (spmtotres < spmthresh_200)
tab spmpov_200
svy: mean spmpov_200, over(age_)

// Storing results
* storing estimates in matrix
matrix list r(table)
mat A = r(table)
mat se = A[2, 1..colsof(A)]														// storing se estimates
mat se = se' 																	// transforming standard errors into single list
mat list se
mat b = A[1, 1..colsof(A)]														// storing point estimates
mat b = b'																		// transforming point estimates into single list
mat list b
* creating new file with years/age variables
clear
set obs 100
gen year_bin = 7
gen age_ = .
* single observation for each separate age group
replace age_ = _n - 1 in 1/76
drop if age_ == .
* storing results into associated year/age variables
svmat b
rename b1 spmpov_mean
svmat se
rename se1 spmpov_se
gen spm_category = "200% threshold"
* saving results
save spmpov_200.dta, replace
restore

// 50% of poverty threshold (deep poverty): estimates of supplemental poverty rate by age
gen spmthresh_50 = spmthresh * .5
gen spmpov_50 = (spmtotres < spmthresh_50)
tab spmpov_50
svy: mean spmpov_50, over(age_)

// Storing results
* storing estimates in matrix
matrix list r(table)
mat A = r(table)
mat se = A[2, 1..colsof(A)]														// storing se estimates
mat se = se' 																	// transforming standard errors into single list
mat list se
mat b = A[1, 1..colsof(A)]														// storing point estimates
mat b = b'																		// transforming point estimates into single list
mat list b
* creating new file with years/age variables
clear
set obs 100
gen year_bin = 7
gen age_ = .
* loop creates single observation for each separate age group
replace age_ = _n - 1 in 1/76
drop if age_ == .
* storing results into associated year/age variables
svmat b
rename b1 spmpov_mean
svmat se
rename se1 spmpov_se
gen spm_category = "50% threshold"
* saving results
save spmpov_50.dta, replace

// Merging data for each separate threshold
use spmpov_100.dta, clear
append using spmpov_200.dta
append using spmpov_50.dta

// Upper and lower bounds on confidence interval
gen spmpov_upper = spmpov_mean + (1.96 * spmpov_se)
gen spmpov_lower = spmpov_mean - (1.96 * spmpov_se)
gen spmpov_range = spmpov_upper - spmpov_lower

// Labels for year bins
label variable year_bin
label values year_bin year_bin_lbl
label define year_bin_lbl ///
	1 "2009-2017"

// Saving final results
compress
save figure1.dta, replace
export excel using "figure1", firstrow(variables) replace


// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
// Figure 2
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
// Historic SPM data from Center on Poverty & Social Policy at Columbia
// University, available at:
// https://www.povertycenter.columbia.edu/historical-spm-data-reg 

	/* For more information on the anchored Historical SPM series, see:
	https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5131790/
	*/

// Merging/appending historic spm and ipums
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
// The following code cleans and merges historic SPM data with IPUMS data for
// the same years. The merge is separated into three chunks for survey years
// 1968-1975, 1976-1978, and 1979-2016 based on the instructions provided by
// the Center on Poverty & Social Policy at Columbia, see: 
// https://www.povertycenter.columbia.edu/s/SPM-public-use-data-documentation_02142019.pdf

/* note: see Center on Poverty & Social Policy notes about non-matches and 
   duplicates
*/

// Recoding age and sex variables from historic spm file
cd "$spm_1968_2016"
use pub_spm_master.dta, replace
* merging two age variables
replace age = a_age if age == .
* merging two sex variables
replace sex = a_sex if sex == .
tab year if age != ., missing
tab year if sex != ., missing
* saving file
compress
save pub_spm_master_reformatted.dta, replace


// Formatting historic spm data for 1968-1975 (survey year)
cd "$spm_1968_2016"
use pub_spm_master_reformatted.dta, clear
* recoding income year to survey year for merge
replace year = year + 1
* keeping relevant years for merge
keep if year >= 1968 & year <= 1975
* removing duplicate observations
sort year serial lineno sex age
quietly by year serial lineno sex age: gen dup = cond(_N==1,0,_n)
tab dup year if dup > 0
	/* 413 duplicates -- primarily concentrated in 1972 */
tab dup SPMu_Poor_Metadj_anch_cen
drop if dup > 0
* correcting for observations that do not merge correctly with IPUMS
	/* age variable missing ending zero */
replace age = 20 if year == 1968 & serial == 12987 & lineno == 3 & sex == 1
replace age = 20 if year == 1969 & serial == 45877 & lineno == 1 & sex == 1
* saving formatted historic spm file for 1968-1975
compress
save public_spm_1968_1975.dta, replace

// Formatting ipums data for 1968-1975 (survey year)
cd "$cps"
use raw.dta, clear
* keeping relevant years for merge
keep if year >= 1968 & year <= 1975
* removing duplicate observations
sort year serial lineno sex age
quietly by year serial lineno sex age:  gen dup = cond(_N==1,0,_n)
tab dup year
	/* 40 duplicates */
drop if dup > 0

// Merging ipums and historic spm for 1968-1975 (survey year)
cd "$spm_1968_2016"
merge 1:1 year serial lineno sex age using public_spm_1968_1975.dta
save spm_1968_1975_merged.dta, replace

// Formatting historic spm data for 1976-1978 (survey year)
cd "$spm_1968_2016"
use pub_spm_master_reformatted.dta, clear
* recoding income year to survey year for merge
replace year = year + 1
* keeping relevant years for merge
keep if year >= 1976 & year <= 1978
* removing duplicate observations
sort year serial pernum sex age
quietly by year serial pernum sex age:  gen dup = cond(_N==1,0,_n)
tab dup year
tab dup SPMu_Poor_Metadj_anch_cen
drop if dup > 0
	/* no duplicates */
* saving formatted historic spm file for 1976-1978
compress
save public_spm_1976_1978.dta, replace

// Formatting ipums data for 1976-1978 (survey year)
cd "$cps"
use raw.dta, clear
* keeping relevant years for merge
keep if year >= 1976 & year <= 1978
* removing duplicate observations
sort year serial pernum sex age
quietly by year serial pernum sex age:  gen dup = cond(_N==1,0,_n)
tab dup year
	/* no duplicates */
drop if dup > 0

// Merging ipums and historic spm for 1968-1975 (survey year)
cd "$spm_1968_2016"
merge 1:1 year serial pernum sex age using public_spm_1976_1978.dta
save spm_1976_1978_merged.dta, replace

// Formatting historic spm data for 1979-2016 (survey year)
cd "$spm_1968_2016"
use pub_spm_master_reformatted.dta, clear
* recoding income year to survey year for merge
replace year = year + 1
* keeping relevant years for merge
keep if year >= 1979 & year <= 2016
* removing duplicate observations
sort year serial lineno sex age
quietly by year serial lineno sex age:  gen dup = cond(_N==1,0,_n)
tab dup year if dup > 0
	/* 272 duplicates -- all prior to 1988 */
tab dup SPMu_Poor_Metadj_anch_cen
drop if dup > 0
* saving formatted historic spm file for 1979-2016
compress
save public_spm_1979_2016.dta, replace

// Formatting ipums data for 1979-2016 (survey year)
cd "$cps"
use raw.dta, clear
* keeping relevant years for merge
keep if year >= 1979 & year <= 2016
drop if hflag == 1
* removing duplicate observations
sort year serial lineno sex age
quietly by year serial lineno sex age:  gen dup = cond(_N==1,0,_n)
tab dup year if dup > 0
	/* 278 duplicates */
drop if dup > 0

// Merging ipums and historic spm for 1968-1975 (survey year)
cd "$spm_1968_2016"
merge 1:1 year serial lineno sex age using public_spm_1979_2016.dta
save spm_1979_2016_merged.dta, replace

// Appending all files
cd "$spm_1968_2016"
use spm_1968_1975_merged.dta, clear
append using spm_1976_1978_merged.dta
append using spm_1979_2016_merged.dta

// Running checks on merge
tab _merge
	/* 10,361 non-matches between IPUMS and Historical SPM data */
tab gq if _merge == 1
tab year if _merge == 1
tab year gq if _merge == 1
	/* bulk of non-matches are Group Quarters, which are excluded from
	Historical SPM data */
	/* 193 non-match Household observations in 1970 and 1972 */
tab offpov gq if _merge == 1

// Checking merge with common variable (offpov) between both data sets
gen offpov_ipums = . if offpov == 99
replace offpov_ipums = 1 if offpov == 1
replace offpov_ipums = 0 if offpov == 2
* generating offpov dummy variable to compare data sets
/* note: no data for 1968 and only checking matches */
gen offpov_check = (offpov_ipums == offpov1)
replace offpov_check = . if offpov_ipums == . & offpov1 == .
tab offpov_check year if _merge == 3 & year != 1968, missing
	/* 271 observations in 2016 that IPUMS characterizes as out of universe but
	Historical SPM data characterizes as in (official) poverty	*/

tab SPMu_Poor_Metadj_anch_cen if _merge == 3, missing

// Keeping all matched observations
keep if _merge == 3

// Adjusting marsupwt prior to 1992 (implicit decimal point)
	/* we use asecwt for all weighting but the difference between marsupwt and 
	asecwt are minor */
replace marsupwt = marsupwt / 100 if year < 1992

cd "$output"
save spm_anchored_1968-2016.dta, replace


// Data cleaning
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
cd "$output"
use spm_anchored_1968-2016.dta, clear

// Replacing with "poverty year" by subtracting 1 from survey year
tab year
replace year = year - 1

// Recoding poverty variable
tab SPMu_Poor_Metadj_anch_cen, missing
	/* no changes needed */
	
// Creating two separate age variables for analysis
* see: https://cps.ipums.org/cps-action/variables/AGE#codes_section
* binned ages
gen age_bin = .
replace age_bin = 1 if age >= 0 & age <= 6
replace age_bin = 2 if age >= 7 & age <= 13
replace age_bin = 3 if age >= 14 & age <= 17
replace age_bin = 4 if age >= 18 & age <= 24
replace age_bin = 5 if age >= 25 & age <= 29
replace age_bin = 6 if age >= 30 & age <= 34
replace age_bin = 7 if age >= 35 & age <= 44
replace age_bin = 8 if age >= 45 & age <= 54
replace age_bin = 9 if age >= 55 & age <= 64
replace age_bin = 10 if age >= 65 & age <= 74
replace age_bin = 11 if age >= 75
tab age age_bin
* recode of single year ages
gen age_ = age
replace age_ = 75 if age >= 75													// combining 75+ into single bin
tab age age_

// Generating business cycles
	/* note: bin is based on march immediately after peak until March
	immediately before next peak; see appendix for additional details */
gen year_bin = .
replace year_bin = 1 if year >= 1967 & year <= 1969								// historic SPM data unavailable prior to 1967
replace year_bin = 2 if year >= 1970 & year <= 1973
replace year_bin = 3 if year >= 1974 & year <= 1979
replace year_bin = 4 if year >= 1980 & year <= 1990
replace year_bin = 5 if year >= 1991 & year <= 2001
replace year_bin = 6 if year >= 2002 & year <= 2007
replace year_bin = 7 if year >= 2008 & year <= 2015

// Adjusting weights to account for pooled data
/* note: this adjustment has no effect on results for *rates* of poverty
*/
replace asecwt = asecwt / 3 if year >= 1967 & year <= 1969						// historic SPM data unavailable prior to 1967
replace asecwt = asecwt / 4 if year >= 1970 & year <= 1973
replace asecwt = asecwt / 6 if year >= 1974 & year <= 1979
replace asecwt = asecwt / 11 if year >= 1980 & year <= 1990
replace asecwt = asecwt / 11 if year >= 1991 & year <= 2001
replace asecwt = asecwt / 6 if year >= 2002 & year <= 2007
replace asecwt = asecwt / 8 if year >= 2008 & year <= 2015

drop _merge


// Data Analysis
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
drop if asecwt < 0																// negative weights incompatible with pw option

// Estimates of supplemental poverty rate by age and year bin
	/* note: no confidence intervals are calculated for historic spm data due to
	the significant imputation procedures that the original authors undertook
	*/
collapse (mean) mean_spm_anch = SPMu_Poor_Metadj_anch_cen ///
	[pw = asecwt], by(year_bin age_)

// Labels for business cycles
label variable year_bin
label values year_bin year_bin_lbl
label define year_bin_lbl ///
	1 "1967-1969" ///
	2 "1970-1973" ///
	3 "1974-1979" ///
	4 "1980-1990" ///
	5 "1991-2001" ///
	6 "2002-2007" ///
	7 "2008-2015"
	
rename age_ age

// Saving final results
compress
save figure2.dta, replace
export excel using "figure2", firstrow(variables) replace


// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
// Figure 3
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
cd "$cps"
use raw.dta, clear
cd "$output"

// Data Cleaning
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
// Replacing with "poverty year" by subtracting 1 from survey year
	/* see: https://cps.ipums.org/cps/poverty_notes.shtml for further discussion
	*/
tab year
replace year = year - 1

// Keeping data after 1970 (first complete business cycle with available data)
keep if year >= 1970

// Removing 3/8 file for 2014
	/* see: https://cps.ipums.org/cps/three_eighths.shtml */
tab hflag
tab hflag, nol
drop if hflag == 1

// Recoding missing income observations
replace hhincome = . if hhincome == 99999999
replace inctot = . if inctot == 99999999
replace inctot = . if inctot == 99999998
replace hhincome = . if hhincome == 99999999
replace hhincome = -9999 if hhincome == -9999997

// Calculating total household income (differs from hhincome in some years)
sort year serial
by year serial: egen inctot_house = total(inctot)
* corrects any $0 income households that are actually missing inctot data
replace inctot_house = . if inctot_house == 0 & inctot == .						// change necessary due to how egen treats missing obs

// Checking consistency between hhincome and sum of inctot in household
gen inctot_check = (hhincome == inctot_house)
replace inctot_check = 1 if hhincome == 0 & inctot_house == .
replace inctot_check = 1 if hhincome == . & inctot_house == 0
tab year inctot_check
order year serial hhincome inctot_house inctot
sort inctot_check year serial
tab year inctot_check if hhincome == 50000
	/* 4,276 hhincome observations == $50000 and do not match sum of inctot for
	household */
tab year inctot_check if hhincome == .
	/* 1,128 hhincome observations == . and do not match sum of inctot for
	household */
tab year inctot_check if hhincome <= inctot_house + 1 & hhincome >= inctot_house - 1
	/* 224 hhincome observations are within $1 of sum of inctot for household */

// Recoding poverty variable
* see: https://cps.ipums.org/cps/poverty_notes.shtml
tab offpov
tab offpov, nol
replace offpov = . if offpov == 99												// secondary individuals under 15 (1980-2018) and under 14 (1969-1979)
gen offpov_ = (offpov == 1)
drop offpov
rename offpov_ offpov

// Missing counties and metropolitan areas
replace county = . if county == 0
replace metfips = . if metfips == 99998 | metfips == 99999

// Creating two separate age variables for analysis
* see: https://cps.ipums.org/cps-action/variables/AGE#codes_section
* binned ages
gen age_bin = .
replace age_bin = 1 if age >= 0 & age <= 6
replace age_bin = 2 if age >= 7 & age <= 13
replace age_bin = 3 if age >= 14 & age <= 17
replace age_bin = 4 if age >= 18 & age <= 24
replace age_bin = 5 if age >= 25 & age <= 29
replace age_bin = 6 if age >= 30 & age <= 34
replace age_bin = 7 if age >= 35 & age <= 44
replace age_bin = 8 if age >= 45 & age <= 54
replace age_bin = 9 if age >= 55 & age <= 64
replace age_bin = 10 if age >= 65 & age <= 74
replace age_bin = 11 if age >= 75
tab age age_bin
* recode of single year ages
gen age_ = age
replace age_ = 75 if age >= 75													// combining 75+ into single bin
tab age age_

// Saving base file
compress
save offpov_1970-2017.dta, replace


// Survey Analysis Preparation
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
// Calculating means and synthetic standard errors that are more 
// accurate than assuming the sampling methodology followed a simple random 
// sample. Requires calculating simulated primary sampling units and strata.
	
	/* For more information on the methodology for simulating primary sampling
	units, see Jolliffe (2002), available 
	at: https://content.iospress.com/articles/journal-of-economic-and-social-measurement/jem00221
	*/
	
	/* For more information on the methodology for simulating strata, see 
	Davern et al. (2006), available at:
	https://journals.sagepub.com/doi/abs/10.5034/inquiryjrnl_43.3.283
	*/

// Simulated Primary Sampling Unit: creates new variable that clusters every 
// four households together based on income in ascending order (i.e., the four 
// lowest income households are clustered together, and every group of four 
// thereafter that are also clustered together for each individual year in data 
// set).
forvalues year = 1970/2017 {
	preserve
	keep if year == `year'
	sort serial
	order serial inctot_house offpov
	* generating variable for duplicates by household
	by serial: gen dup = cond(_N==1,0,_n)
	order dup
	* isolates data for one unique observation per household
	drop if dup > 1
	sort inctot_house serial
	* new variable for observation number (_n) in every fourth row
	gen count = _n if mod(_n,4) == 0
	order count
	* moves count result up by one row
	replace count = count[_n + 1]
	* replaces variable for observation number (_n) in every fourth row
	replace count = _n if mod(_n,4) == 0
	* moves count result up by one row
	replace count = count[_n + 1]
	* replaces variable for observation number (_n) in every fourth row
	replace count = _n if mod(_n,4) == 0
	* moves count result up by one row
	replace count = count[_n + 1]
	* replaces variable for observation number (_n) in every fourth row
	replace count = _n if mod(_n,4) == 0
	keep serial year count
	compress
	save offpov_1970-2017_cluster_pool`year'.dta, replace
	restore
}

// Appending all annual clustered data
clear
	forvalues year = 1970/2017 {
	append using offpov_1970-2017_cluster_pool`year'.dta
}

// Generating PSU
* generates psu variable and addresses any (missing) observations that were not
* assigned to a group of four in any given year
egen psu = group(count year), missing 
drop count

// Merging with base file
merge 1:m serial year using offpov_1970-2017.dta
drop _merge

// Generating synthetic strata based on geographic variables
egen strata = group(statefip county metfips year), missing
svyset psu [pweight=asecwt], strata(strata)
drop if asecwt < 0																// negative weights incompatible with pw option
svydes, single generate(single)
* creating separate strata for missing observations
replace county = . if single == 1
replace metfips = . if single == 1
drop strata single
egen strata = group(statefip county metfips year), missing

// Generating business cycles
* note: bin is based on march immediately after peak until March immediately
*		before next peak; spm data unavailable for 2008; see appendix for 
*		additional details
gen year_bin = 2 if year >= 1970 & year <= 1973
replace year_bin = 3 if year >= 1974 & year <= 1979
replace year_bin = 4 if year >= 1980 & year <= 1990
replace year_bin = 5 if year >= 1991 & year <= 2001
replace year_bin = 6 if year >= 2002 & year <= 2007
replace year_bin = 7 if year >= 2008 & year <= 2017

// Adjusting weights to account for pooled data
/* note: this adjustment has no effect on results for *rates* of poverty */
replace asecwt = asecwt / 10 if year >= 2008 & year <= 2017
replace asecwt = asecwt / 6 if 	year >= 2002 & year <= 2007
replace asecwt = asecwt / 11 if year >= 1991 & year <= 2001
replace asecwt = asecwt / 11 if year >= 1980 & year <= 1990
replace asecwt = asecwt / 6 if 	year >= 1974 & year <= 1979
replace asecwt = asecwt / 4 if 	year >= 1970 & year <= 1973

// Saving base file for data analysis
compress
save offpov_1970-2017_cluster_pool.dta, replace


// Data Analysis
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
cd "$output"
use offpov_1970-2017_cluster_pool.dta, clear

// Survey analysis method (synthetic)
drop if asecwt < 0																// negative weights incompatible with pw option
* setting survey method
svyset psu [pw=asecwt], strata(strata)

// 100% poverty threshold: estimates of official poverty rate by age
svy: mean offpov, over(year_bin age_)

// Storing results
* recording results in matrix
matrix list r(table)
mat A = r(table)
mat se = A[2, 1..colsof(A)]														// storing se estimates
mat se = se' 																	// transforming standard errors into single list
mat list se
mat b = A[1, 1..colsof(A)]														// storing point estimates
mat b = b'																		// transforming point estimates into single list
mat list b
* creating label for results (each label has a # for age and for the year bin)
clear
set obs 1
scalar subpop = e(over_labels)
gen subpop = subpop in 1
* delineating results with a period 
replace subpop = subinstr(subpop, `"" ""',  ".", .)
replace subpop = subinstr(subpop, `"""',  "", .)
* splitting results by period
split subpop, destring parse(.)
gen i = 1
drop subpop
* reshaping results from wide to long
reshape long subpop, i(i) j(j)
drop i
drop j
* splitting year bin and age into two separate variables
split subpop, destring
ereturn list
* renaming year bin and age variables
rename subpop1 year_bin
rename subpop2 age_
* adding variable for mean and se
svmat b
rename b1 offpov_mean
svmat se
rename se1 offpov_se

// Upper and lower bounds on confidence interval
gen offpov_upper = offpov_mean + (1.96 * offpov_se)
gen offpov_lower = offpov_mean - (1.96 * offpov_se)
gen offpov_range = offpov_upper - offpov_lower

// Labels for business cycles
label variable year_bin
label values year_bin year_bin_lbl
label define year_bin_lbl ///
	2 "1970-1973" ///
	3 "1974-1979" ///
	4 "1980-1990" ///
	5 "1991-2001" ///
	6 "2002-2007" ///
	7 "2008-2017"

compress
save figure3.dta, replace
export excel using "figure3", firstrow(variables) replace


// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
// Figure 4
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
// Historic SPM data from Center on Poverty & Social Policy at Columbia
// University, available at:
// https://www.povertycenter.columbia.edu/historical-spm-data-reg 

	/* For more information on the anchored Historical SPM series, see:
	https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5131790/
	*/

// Merging/appending historic spm and ipums
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
/* note: to create the spm_anchored_1968-2016.dta file, see code for Figure 2 */


// Data Cleaning
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
cd "$output"
use spm_anchored_1968-2016.dta, clear

// Replacing with "poverty year" by subtracting 1 from survey year
tab year
replace year = year - 1

// Recoding poverty variable
tab SPMu_Poor_Metadj_anch_cen, missing
	/* no changes needed */
	
// Creating two separate age variables for analysis
* see: https://cps.ipums.org/cps-action/variables/AGE#codes_section
* binned ages
gen age_bin = .
replace age_bin = 1 if age >= 0 & age <= 6
replace age_bin = 2 if age >= 7 & age <= 13
replace age_bin = 3 if age >= 14 & age <= 17
replace age_bin = 4 if age >= 18 & age <= 24
replace age_bin = 5 if age >= 25 & age <= 29
replace age_bin = 6 if age >= 30 & age <= 34
replace age_bin = 7 if age >= 35 & age <= 44
replace age_bin = 8 if age >= 45 & age <= 54
replace age_bin = 9 if age >= 55 & age <= 64
replace age_bin = 10 if age >= 65 & age <= 74
replace age_bin = 11 if age >= 75
tab age age_bin
* recode of single year ages
gen age_ = age
replace age_ = 75 if age >= 75													// combining 75+ into single bin
tab age age_
	
// Generating business cycles
* note: bin is based on march immediately after peak until March immediately
*		before next peak; see appendix for additional details
gen year_bin = .
replace year_bin = 1 if year >= 1967 & year <= 1969								// historic SPM data unavailable prior to 1967
replace year_bin = 2 if year >= 1970 & year <= 1973
replace year_bin = 3 if year >= 1974 & year <= 1979
replace year_bin = 4 if year >= 1980 & year <= 1990
replace year_bin = 5 if year >= 1991 & year <= 2001
replace year_bin = 6 if year >= 2002 & year <= 2007
replace year_bin = 7 if year >= 2008 & year <= 2015

// Adjusting weights to account for pooled data
/* note: this adjustment has no effect on results for *rates* of poverty
*/
replace asecwt = asecwt / 3 if year >= 1967 & year <= 1969						// historic SPM data unavailable prior to 1967
replace asecwt = asecwt / 4 if year >= 1970 & year <= 1973
replace asecwt = asecwt / 6 if year >= 1974 & year <= 1979
replace asecwt = asecwt / 11 if year >= 1980 & year <= 1990
replace asecwt = asecwt / 11 if year >= 1991 & year <= 2001
replace asecwt = asecwt / 6 if year >= 2002 & year <= 2007
replace asecwt = asecwt / 8 if year >= 2008 & year <= 2015


// Data Analysis
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
tab schlcoll
tab schlcoll, nol missing
tab schlcoll year_bin
tab schlcoll age_bin
tab age if schlcoll == 3 | schlcoll == 4
tab age if schlcoll == 5 & year >= 1985

// Dropping observations that are NIU and missing
drop if schlcoll == 0 | schlcoll == .

// Limiting to available universe for school attendance variable
	/* there are several observations that are not marked "not in universe" but
	still fall outside universe age range */
keep if age >= 16 & age <= 24
drop if year < 1985

// Calculating count of people in each business cycle, age, school attendance category, and poverty status
preserve
collapse (sum) pop = asecwt, by(SPMu_Poor_Metadj_anch_cen schlcoll year_bin age_)
save schlcoll_pop1.dta, replace
restore

// Calculating count of people in each business cycle by age
*collapse (count) pop_total = asecwt (mean) pov = SPMu_Poor_Metadj_anch_cen [pw = asecwt], by(year_bin age_)
collapse (sum) pop_total = asecwt, by(year_bin age_)

save schlcoll_pop2.dta, replace

// Merging files
use schlcoll_pop1.dta, clear
merge m:1 year_bin age_ using schlcoll_pop2.dta
drop _merge

// Calculating percent in poverty for each school attendance category, age, and business cycle
gen pct = pop / pop_total

// Labels for business cycles
label variable year_bin
label values year_bin year_bin_lbl
label define year_bin_lbl ///
	4 "1985-1990" ///
	5 "1991-2001" ///
	6 "2002-2007" ///
	7 "2008-2015"

save figure4.dta, replace
export excel using "figure4", firstrow(variables) replace


// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
// Figure 5
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
// Historic SPM data from Center on Poverty & Social Policy at Columbia
// University, available at:
// https://www.povertycenter.columbia.edu/historical-spm-data-reg 

/* For more information on the anchored Historical SPM series, see:
https://www.ncbi.nlm.nih.gov/pmc/articles/PMC5131790/
*/

// Merging/appending historic spm and ipums
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
/* note: to create the spm_anchored_1968-2016.dta file, see code for Figure 2 */


// Data Cleaning
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
cd "$output"
use spm_anchored_1968-2016.dta, clear

// Replacing with "poverty year" by subtracting 1 from survey year
tab year
replace year = year - 1

// Recoding poverty variable
tab SPMu_Poor_Metadj_anch_cen, missing
drop if SPMu_Poor_Metadj_anch_cen == .
	
// Creating two separate age variables for analysis
* see: https://cps.ipums.org/cps-action/variables/AGE#codes_section
* binned ages
gen age_bin = .
replace age_bin = 1 if age >= 0 & age <= 6
replace age_bin = 2 if age >= 7 & age <= 13
replace age_bin = 3 if age >= 14 & age <= 17
replace age_bin = 4 if age >= 18 & age <= 24
replace age_bin = 5 if age >= 25 & age <= 29
replace age_bin = 6 if age >= 30 & age <= 34
replace age_bin = 7 if age >= 35 & age <= 44
replace age_bin = 8 if age >= 45 & age <= 54
replace age_bin = 9 if age >= 55 & age <= 64
replace age_bin = 10 if age >= 65 & age <= 74
replace age_bin = 11 if age >= 75
tab age age_bin
* recode of single year ages
gen age_ = age
replace age_ = 75 if age >= 75													// combining 75+ into single bin
tab age age_
	
// Generating business cycles
* note: bin is based on march immediately after peak until March immediately
*		before next peak; see appendix for additional details
gen year_bin = .
replace year_bin = 1 if year >= 1967 & year <= 1969								// historic SPM data unavailable prior to 1967
replace year_bin = 2 if year >= 1970 & year <= 1973
replace year_bin = 3 if year >= 1974 & year <= 1979
replace year_bin = 4 if year >= 1980 & year <= 1990
replace year_bin = 5 if year >= 1991 & year <= 2001
replace year_bin = 6 if year >= 2002 & year <= 2007
replace year_bin = 7 if year >= 2008 & year <= 2015

// Adjusting weights to account for pooled data
/* note: this adjustment has no effect on results for *rates* of poverty */
replace asecwt = asecwt / 3 if year >= 1967 & year <= 1969					// historic SPM data unavailable prior to 1967
replace asecwt = asecwt / 4 if year >= 1970 & year <= 1973
replace asecwt = asecwt / 6 if year >= 1974 & year <= 1979
replace asecwt = asecwt / 11 if year >= 1980 & year <= 1990
replace asecwt = asecwt / 11 if year >= 1991 & year <= 2001
replace asecwt = asecwt / 6 if year >= 2002 & year <= 2007
replace asecwt = asecwt / 8 if year >= 2008 & year <= 2015
	

// Data Analysis
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
drop if asecwt < 0																// negative weights incompatible with pw option

// Generating counterfactual resource and poverty variables without certain
// government assistance
* pre-tax/transfer
gen pre_res = SPMu_Resources2 - [SPMu_SNAPSub - SPMu_CapHouseSub - SPMu_SchLunch - SPMu_EngVal - SPMu_WICval - SPMu_Stimulus - SPMu_FedEcRecov - SPMu_FedTax - SPMu_FICA - SPMu_stTax - SPMu_Welf - SPMu_SSI - SPMu_SS - SPMu_UE2]
gen pre_pov = (pre_res < SPMu_PovThreshold1_cen_Metadj)

* pre-eitc
gen pre_res_eitc = SPMu_Resources2 - SPMu_EITC
gen pre_eitc = (pre_res_eitc < SPMu_PovThreshold1_cen_Metadj)
tab pre_eitc SPMu_Poor_Metadj_anch_cen, missing

* pre-social security
gen pre_res_ss = SPMu_Resources2 - SPMu_SS
gen pre_ss = (pre_res_ss < SPMu_PovThreshold1_cen_Metadj)

* pre-tax market income
gen pre_res_market = SPMu_totval
gen pre_market = (pre_res_market < SPMu_PovThreshold1_cen_Metadj)

// Estimates of pre-assistance poverty rate by age and year bin
	/* note: no confidence intervals are calculated for historic spm data due to 
	the significant imputation procedures that the original authors undertook to
	create the data set
	*/
collapse (mean) mean_spm_anch = SPMu_Poor_Metadj_anch_cen ///
	(mean) mean_spm_anch_eitc = pre_eitc 									///
	(mean) mean_spm_anch_prepov = pre_pov 									///
	(mean) mean_spm_anch_ss = pre_ss 										///
	(mean) mean_spm_anch_mark = pre_market									///
	[pw = asecwt], by(year_bin age_)
	
// Labels for business cycles
label variable year_bin
label values year_bin year_bin_lbl
label define year_bin_lbl ///
	1 "1967-1969" ///
	2 "1970-1973" ///
	3 "1974-1979" ///
	4 "1980-1990" ///
	5 "1991-2001" ///
	6 "2002-2007" ///
	7 "2008-2015"
	
// Check
gen cond = (mean_spm_anch_eitc == mean_spm_anch)
tab cond year_bin, missing
drop cond

// Saving base file
compress
save figure5.dta, replace
export excel using "figure5", firstrow(variables) replace


// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
// Figure 6
// = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = = =
/* See output from Figure 2 */

