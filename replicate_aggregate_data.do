
///////////////////////////////////////////////////////////////////////
///// Replicate global and regional poverty estimates /////////////////
///////////////////////////////////////////////////////////////////////



// Get population data 
pip tables, clear table(pop) 
rename value pop
rename data_level reporting_level

tempfile pop 
save `pop'


// Obtain country and regional list 
pip tables, table(country_list)  clear
keep region_code region country_code country_name africa_split_code africa_split
rename region region_name  //would be nice region would be labelled like this from the backend

tempfile countrylist 
save `countrylist'

// Obtain lineup poverty estimates
pip, clear fillgaps  povline(2.15)

replace headcount = 100*headcount
keep country_code reporting_level welfare_type year poverty_line headcount
isid country_code year reporting_level poverty_line
rename headcount hc 

// Combine data sets
merge m:1 country_code year reporting_level using `pop', nogen 
keep if reporting_level=="national" | inlist(country_code,"ARG")  // SUR is now national


br if (country_code=="GHA" | country_code=="ERI") & year==2019  // Check if observations have been created all okay

merge m:1 country_code using `countrylist', nogen  // Merge with country and regional list

// Get Africa split
preserve 
	keep if inlist(africa_split_code,"AFW","AFE")
	replace region_code = africa_split_code
	gen subregion = 1
	replace region_name = africa_split

	tempfile subreg 
	save `subreg'
restore 

append using `subreg'

// Estimate regional poverty estimates
bysort region_code year: egen hc_reg_avg = wtmean(hc),weight(pop)

egen hc_reg_avg_ssa_ = mean(hc_reg_avg) if region_code=="SSA",by(region_code year)
egen hc_reg_avg_ssa = mean(hc_reg_avg_ssa_ ),by(year)
replace hc_reg_avg = hc_reg_avg_ssa if subregion==1

// Assign countries with missing data regional poverty rate
replace hc = hc_reg_avg if missing(hc)&!missing(hc_reg_avg) 

drop if inlist(country_code,"ARG") & reporting_level=="national"  // SUR is now national

// Estimate global poverty
preserve 
drop if subregion==1    // Remove duplicates of African countries
	collapse (mean) hc [aw=pop],by(year)
	gen region_code = "WLD"
	gen region_name = "World"

	tempfile wld 
	save `wld'
restore 

// Estimate regional poverty rates
collapse (mean) hc [aw=pop],by(region_code region_name year)

// Pool together regional and global poverty estimates
append using `wld'
rename hc hc_own

tempfile hc_own 
save `hc_own'



// Get regional aggregates provided in PIP
pip wb, clear  povline(2.15) 
replace headcount = 100*headcount
keep headcount region_code region_name year
rename headcount hc_pip 

*Combine data sets
merge 1:1 region_code year using `hc_own', nogen

*Check replication
gen double d_hc = round(abs(hc_pip-hc_own),0.01) 
sum d_hc 
assert round(`r(mean)') == 0

// Keep only relevant years
drop if year<1981
drop if year>=2023

// Look at the largest differences
order region_name region_code year hc_pip hc_own d_hc
gsort - d_hc 
br 

// Look at difference for SSA at $2.15
sort region_code year
br if region_code=="SSA" 


// Look at difference for the world at $2.15
sort region_code year
br if region_code=="WLD" 
