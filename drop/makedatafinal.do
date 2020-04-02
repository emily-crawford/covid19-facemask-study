#delimit ;
clear;
set more off;

local drop = "D:\Dropbox (yale som economics)";
local datadir = "`drop'\COVID-19 Masks\Data";
local logdir = "`drop'\COVID-19 Masks\Logfiles";

local c_date= subinstr("$S_DATE", " ", "", .);

local makegraph = 0;
*local outcome = "confirmedcases";
local outcome = "confirmeddeaths";

capture log close;

log using "`logdir'\makedata`c_date'_`outcome'.log", replace;

clear;

**Load Oxford data and update date format;
insheet using "`datadir'\OxCGRT_Download_latest_data.csv";
rename countryname country;
tostring date, usedisplayformat replace;
gen newdate = date(date,"YMD");
tempfile oxdata;
save `oxdata', replace;

*Load infection rate and death data;
clear;
insheet using "`datadir'\Reports.csv";


/*;
**When not commented out, create a list of countries and states in the data;

*Create country and (country, state) csvs;
preserve;
keep country state;
sort country state;
gen hascomma = strpos(state,",");
drop if hascomma != 0;
drop hascomma;
drop if state == "";
duplicates drop;
outsheet using "`datadir'\allcountrystates.csv", comma replace;
restore;

preserve;
keep country;
sort country;
duplicates drop;
outsheet using "`datadir'\allcountries.csv", comma replace;
restore;
*/;

**Rename countries so that they merge with mask data;
replace country = "United States of America" if country == "United States";
replace country = "Russia" if strpos(country,"Russia");
replace country = "Iran" if strpos(country,"Iran");
replace country = "South Korea" if country == "Korea, Republic of";
replace country = "Taiwan" if strpos(country,"Taiwan");

*Merge in mask data and keep only countries with non-missing data;
preserve;
clear;
insheet using "`datadir'\graph_mask_requirements_v3B.csv";
tempfile maskdata;
save `maskdata', replace;
restore;

merge m:1 country using `maskdata';
assert _merge != 2;
keep if mask_n != .;
drop _merge;


*Update date information;
gen date = substr(update_time,1,10);
replace date = subinstr(date,"-","",.);

keep country state county city date population confirmed deaths negative pending total_hospitalized_patients mask_n db_source_name;
duplicates drop;

*Drop dates with missing case and death information;
drop if confirmed == . | deaths == .;
gen newdate = date(date,"YMD");

*Drop final date since data may be incomplete;
egen maxdate = max(newdate);
drop if newdate == maxdate;
drop maxdate;



*For debugging;
*sort country date state county city;
*outsheet using sortedreports.csv, comma replace;


********************************************************************************************************;
**SECTION 1: CLEAN DATA;
********************************************************************************************************;

replace state = "NA" if state == "";
replace county = "NA" if county == "";
replace city = "NA" if city == "";
replace country = "French Polynesia" if state == "French Polynesia";
egen region = group(country state county city);
sort region newdate;

*Decide what sources to keep for each country;
rename db_source_name source;
egen eachcountrysource = tag(country newdate source);
bys country newdate: egen sumsource = sum(eachcountrysource);
tab sumsource;

*If multiple records from the same source on the same date, keep only largest;
bys region source newdate: gen numrecords = _N;
bys region source newdate: egen maxconfirmed = max(confirmed);
keep if confirmed == maxconfirmed;
bys region source newdate: egen maxdeaths = max(deaths);
keep if deaths == maxdeaths;
bys region source newdate: gen numrecords2 = _N;
assert numrecords2 == 1;
drop numrecords maxconfirmed maxdeaths numrecords2;

*In the US, Johns Hopkins data is redundant on days with COVID Project data;
drop if source == "Johns Hopkins CSSE" & sumsource == 2 & country == "United States of America";
*EU data is redundant with Johns Hopkins Data;
drop if source == "EU Data";
*Covid-19 Israel is redundant with Johns Hopkins Data;
drop if source == "Covid-19 Israel";
*Japan tracker is redundant with Johns Hopkins Data;
drop if source == "Japan COVID-19 Coronavirus Tracker";
*COVID-19-SG is redundant with Johns Hopkins Data;
drop if source == "COVID-19-SG";
*Korean data is redundant with Johns Hopkins Data;
drop if source == "Korean Data";
*Deal with redundant "UK" observations in UK;
drop if state == "UK" & country == "United Kingdom";
*Deal with "whole country" observations not labeled as "NA";
replace state = "NA" if state == country;

drop region;
egen region = group(country state county city);
bys region newdate: gen counter = _N;
tab counter;
tab country if counter != 1;
sort country newdate state source;
assert counter == 1;


/*;
*For debugging, check countries where one region is large, confirm we're not double-counting;
drop totinfect percinfect;
bys country newdate: egen totinfect = sum(confirmed);
gen percinfect = confirmed/totinfect;
list country state county city newdate percinfect confirmed totinfect if percinfect > 0.2 & percinfect != 1;
*/;


**Impute missing dates with the last non-missing value

*Create a dataset with every region date;
preserve;
keep newdate;
duplicates drop;
gen join = 1;
tempfile alldates;
save `alldates', replace;
restore;

preserve;
keep country region state county city;
duplicates drop;
gen join = 1;
joinby join using `alldates';
tempfile allregiondates;
save `allregiondates', replace;
restore;

merge 1:1  region newdate using `allregiondates';
assert _merge == 3 | _merge == 2;

bys  region: egen mindate = min(newdate);
*All regions extend to the final date for that country;
bys  country: egen maxdate = max(newdate);
keep if newdate >= mindate & newdate <= maxdate;
drop mindate maxdate;

sort region newdate;
by region: replace confirmed = confirmed[_n-1] if missing(confirmed);
by region: replace deaths = deaths[_n-1] if missing(deaths);
drop _merge;
*If no earlier nonmissing values, set to 0;
replace confirmed = 0 if confirmed == .;
replace deaths = 0 if deaths == .;

*If cumulative cases or deaths decline, replace all earlier larger values;
*For example, if cases are 10, 30, 58, 28, 55, 100, 120 -- we would update to: 10, 28, 28, 55, 100, 120 ;
gen confirmeddiff = confirmed-confirmed[_n-1] if region == region[_n-1];
gen deathdiff = deaths-deaths[_n-1] if region == region[_n-1];
gen flag = 1 if confirmeddiff < 0 | deathdiff < 0;
bys region: egen maxflag = max(flag);
egen totflag = max(maxflag);
local totflag = totflag;
while(`totflag' > 0) {;
gen flagdate = newdate if flag == 1;
bys region: egen mindate = min(flagdate);
gen flagconfirm = confirmed if newdate == mindate;
bys region: egen maxflagconfirm = max(flagconfirm);
*list country region date confirmed flagconfirm newdate mindate if country == "Japan";
*assert 1 == 0;
replace confirmed = maxflagconfirm if confirmed > maxflagconfirm & newdate <= mindate;
gen flagdeaths = deaths if newdate == mindate;
bys region: egen maxflagdeaths = max(flagdeaths);
replace deaths = maxflagdeaths if deaths > maxflagdeaths & newdate <= mindate;
replace flag = 0 if newdate == mindate;
drop maxflag totflag flagdate flagconfirm flagdeaths mindate maxflagconfirm maxflagdeaths;
bys region: egen maxflag = max(flag);
egen totflag = sum(maxflag);
local totflag = totflag;
display "totflag is `totflag'";
};
drop maxflag totflag;


*If "state" = "country", drop all other states to avoid double-counting;
gen statecountry = (state == country);
bys country newdate: egen maxstatecountry = max(statecountry);
drop if maxstatecountry == 1 & statecountry != 1;
drop statecountry maxstatecountry;

*If "state" = "county", drop all other counties to avoid double-counting;
gen statecounty = (state == county);
replace statecounty = 1 if county == "";
replace statecounty = 1 if county == "NA";
bys country state newdate: egen maxstatecounty = max(statecounty);
drop if maxstatecounty == 1 & statecounty != 1;
drop statecounty maxstatecounty;

*If "county" = "city", drop all other cities to avoid double-counting;
gen countycity = (county == city);
replace countycity = 1 if city == "";
replace countycity = 1 if city == "NA";
bys country state county newdate: egen maxcountycity = max(countycity);
drop if maxcountycity == 1 & countycity != 1;
drop countycity maxcountycity;

********************************************************************************************************;
**SECTION 2: Merge in Policy Data;
********************************************************************************************************;

*Rename countries so that they merge with Oxford data;

replace country = "United States" if country == "United States of America";
replace country = "Czech Republic" if country == "Czechia";

merge m:1 country newdate using `oxdata';
tab _merge;

*Confirm that all mask wearing countries merge;
*Check countries which never merge in either direction;
bys country: egen maxmerge = max(_merge);
tab country if _merge == 1 & maxmerge != 3;
tab country if _merge == 2 & maxmerge != 3;
bys country: egen maskmax = max(mask_n);
assert maxmerge == 3 if maskmax == 1;
drop maxmerge maskmax;

drop if _merge == 2;
rename _merge origmerge;

drop confirmedcases confirmeddeaths;
rename confirmed confirmedcases;
rename deaths confirmeddeaths;
rename date origdate;
rename newdate date;

********************************************************************************************************;
**SECTION 3: Create regression variables;
********************************************************************************************************;

if("`outcome'" == "confirmedcases") {;
local start = "pos100";
};

if("`outcome'" == "confirmeddeaths") {;
local start = "death10";
};
local geog = "country";
*keep if county == state | state == "";

preserve;
gen regcount = 1;
collapse (sum) confirmedcases confirmeddeaths regcount, by(`geog' date);
*Find a date with at least 100 infections;
gen pos100 = (confirmedcases >= 100) & confirmedcases != .;
*Find date with at least 10 deaths;
gen death10 = (confirmeddeaths >= 10) & confirmeddeaths != .;


*gen ln`outcome' = ln(`outcome');
*list `geog' date `outcome' ln`outcome' pos100 regcount if country == "Brazil", clean;
*assert 1 == 0;

keep `geog' date `start' `outcome';
keep if `start' > 0;
rename `outcome' init;
bys `geog': egen mindate = min(date);
keep if date == mindate;
keep `geog' mindate init;
duplicates drop;
tempfile mindate;
save `mindate', replace;
restore;

capture drop mindate;
merge m:1 `geog' using `mindate';
assert _merge == 3 | _merge == 1;
drop _merge;
tab mindate;

gen twoweeks = mindate+14;
gen onemonth = mindate+28;
gen days10 = mindate+10;

*Create regression variables;
preserve;
keep if date == mindate;
keep `geog' mindate s1_s-s11_in;
duplicates drop;
bys `geog': gen counter = _N;
list if counter > 1;
assert counter == 1;
local regvar = "s1_schoolclosing s2_workplace s3_cancel s4_closepublic s5_publicinfo s6_restriction s7_international s8_fiscal s9_monet s10_emerg s11_invest";
foreach x of local regvar {;
rename `x' init_`x';
gen blank_`x' = (init_`x' == .);
replace init_`x' = 0 if init_`x' == .;
};

keep `geog' init_* blank_*;
tempfile initvars;
save `initvars', replace;
restore;

preserve;
gen enddate = mindate + 7;
keep if date >= mindate & date <= enddate;
keep `geog' date s1_s-s11_in;
duplicates drop;
bys `geog': gen counter = _N;
assert counter <= 8;
local regvar = "s1_schoolclosing s2_workplace s3_cancel s4_closepublic s5_publicinfo s6_restriction s7_international s8_fiscal s9_monet s10_emerg s11_invest";
gen avgcount = 1;
collapse (mean) `regvar' (sum) avgcount, by(`geog');
foreach x of local regvar {;
rename `x' avg_var_`x';
gen avg_blank_`x' = (avg_var_`x' == .);
replace avg_var_`x' = 0 if avg_var_`x' == .;
};
keep `geog' avg_* avgcount;
tempfile avgvars;
save `avgvars', replace;
restore;



gen time = date-mindate;
keep if time >= 0 & time != .;

*Populate missing mask values;
bys country: egen maskmax = max(mask_n);
replace mask_n = maskmax if mask_n == .;
*Is mask data consistent within every country?;
gen masktest = mask_n;
replace masktest = 2 if masktest == .;
bys country: egen sdmask = sd(masktest);
by country: gen countdate = _N;
assert sdmask == 0 | countdate == 1;
drop masktest sdmask countdate;

sort country time;
tab country if mask_n != .;
tab mask_n;

********************************************************************************************************;
**SECTION 4: Create graph;
********************************************************************************************************;

if(`makegraph' == 1) {;
collapse (sum) `outcome' population (mean) mask_n, by(`geog' time);

gen ln`outcome' = ln(`outcome');
drop ln`outcome';

replace country = "USA" if strpos(country,"United States");
bys `geog': egen maxpop = max(population);
*Replace population for missing countries w/ > 5 million;
tab country if maxpop == 0;
*Replace population for missing countries w/ > 5 million;
replace maxpop = 7392000 if country == "Hong Kong";
replace maxpop = 5603000 if country == "Denmark";
replace maxpop = 17180000 if country == "Netherlands";
replace maxpop = 66990000 if country == "France";
replace maxpop = 66440000 if country == "United Kingdom";
assert maxpop != .;
*Max population is total population of all infected regions;
keep if maxpop > 5e6;
*keep if time <= 20;
gen ln`outcome' = ln(`outcome');
keep if mask_norm_sick != .;
drop `outcome' maxpop population mask_norm_sick;

sort country time;
drop if ln`outcome' == .;
*Only keep countries with at least 8 days of data after baseline;
bys country: gen numdays = _N;
keep if numdays >= 8;
drop numdays;
*Use reshape by country;
replace country = subinstr(country," ","",.);
reshape wide lnconfirmedcases, i(time) j(country) string;
*w/ 5 million cutoff
*outsheet using "`datadir'\countrygraph.csv", comma replace;
outsheet using "`datadir'\countrygraphG.csv", comma replace;

foreach x of varlist * {;
display "`x'";
assert `x' >= `x'[_n-1] if `x'[_n-1] != .;
};

assert 1 == 0;
};


********************************************************************************************************;
**SECTION 4: Run cross-country regression;
********************************************************************************************************;

*Create average growth rate;
replace population = 0 if population == .;
sort `geog' time;

/*;
*For debugging;
collapse (sum) confirmedcases confirmeddeaths (sum) population (mean) mask_n, by(`geog' date);
sort country date;
list country date confirmedcases confirmeddeaths if country == "Australia";
list country date confirmedcases confirmeddeaths if country == "Austria";
assert 1 == 0;
*/;

collapse (sum) `outcome' (sum)  population (mean) mask_n, by(`geog' time);

*For countries with only regional data, population is actually the sum of the population of infected regions;
bys `geog': egen maxpop = max(population);

tab country if maxpop == 0;
*Replace population for missing countries w/ > 5 million;
replace maxpop = 7392000 if country == "Hong Kong";
replace maxpop = 5603000 if country == "Denmark";
replace maxpop = 17180000 if country == "Netherlands";
replace maxpop = 66990000 if country == "France";
replace maxpop = 66440000 if country == "United Kingdom";


tab country if mask_n != .;
sort country time;
assert maxpop != .;
*Max population is total population of all infected regions;
keep if maxpop > 5e6;
keep if time <= 30;
*Compute ln`outcome' at max time and inittime;
gen ln`outcome' = ln(`outcome');
drop if time == .;
drop if ln`outcome' == .;

bys `geog': egen maxtime = max(time);
gen maxlntemp = ln`outcome' if time == maxtime;
bys `geog': egen maxln = max(maxlntemp);
gen initln = ln`outcome' if time == 0;
bys `geog': egen minln = max(initln);
gen growthrate = (maxln-minln)/maxtime;

keep if time == maxtime;
sort `geog';
keep if maxtime >= 8;

list `geog' maxtime growthrate, clean;

merge m:1 country using `initvars';
assert _merge != 1;
keep if _merge == 3;
drop _merge;

merge m:1 country using `avgvars';
assert _merge != 1;
keep if _merge == 3;
drop _merge;

assert avgcount == 8;

*Control mean;
sum growthrate if mask_n == 1;
*Treatment mean;
sum growthrate if mask_n == 0;
*No controls;
regress growthrate mask_n, robust;
drop init_s5-init_s11;
drop blank_s5-blank_s11;
drop avg_var_s5-avg_var_s11;
drop avg_blank_s5-avg_blank_s11;
*Baseline policy controls and testing;
regress growthrate mask_n init_* blank_*, robust;
*Average policy controls and testing;
regress growthrate mask_n avg_var* avg_blank_*, robust;
