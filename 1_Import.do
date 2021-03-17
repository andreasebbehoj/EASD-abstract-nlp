***** 1_Import.do *****
capture: mkdir 1_Input
capture: mkdir 2_Data
capture: mkdir 3_Output

*** Import embase abstracts
import delimited "1_Input/EASD_2009-2015.csv", clear case(lower) varnames(1) stringcols(_all)
tempfile import1 
save `import1', replace

import delimited "1_Input/EASD_2016-2020.csv", clear case(lower) varnames(1) stringcols(_all)
tempfile import2 
save `import2', replace

use `import1', clear
append using `import2'


*** Format vars
rename ïtitle title
rename publicationyear year
destring year, replace


*** Drop useless vars
* Empty vars
qui: count 
local obsno=`r(N)'
ds
foreach var in `r(varlist)' {
    qui: count if mi(`var')
	if `r(N)'==`obsno' {
	    di "`var' empty, dropped"
		drop `var'
	}
}

* Other uninteresting vars
drop sourcetitle publicationtype source fullrecordentrydate volume issue dateofpublication conferencedate conferencename conferencelocation conferencedate issn bookpublisher articlelanguage summarylanguage pui fulltextlink copyright openurllink doi


*** Find page
gen page = real(substr(firstpage, 2, .)), after(title)
sort year page
drop if mi(page) 

* Fix errors
replace page = page-500 if inrange(page, 518, 519) & year==2020 // S518-S519, should have been s18-s19


*** Format abstract text
** Add capital headers
foreach string in "Background and aims:" "Background:" "Aims:" "Introduction:" "Materials and methods:" "Methods:" "Materials:" "Conclusion:" {
    local stub = substr(lower("`string'"), 1, 4)
	capture: gen repl_`stub' = .
	
	di "`string'"
	
	* Variations of string
	local strings = `" "`string'" "' ///
		+ `" " "' + subinstr("`string'", " ", "", 2) + `" " "' /// Both spaces
		+ `" " "' + subinstr("`string'", "and", "&", 1) + `" " "' // & / and
	
	local chars = length("`string'")
	forvalues x = 1/`chars' { // typos missing one char
	    local add = substr("`string'", 1, `x'-1) + substr("`string'", `x'+1, .)
		local strings =  `"`strings' "' + `" "`add'" "'
	}
	
	foreach variation of local strings {
	    qui: recode repl_`stub' (.=1) if strpos(abstract, "`variation'")
		qui: replace abstract = subinstr(abstract, "`variation'", upper("`string'"), 1)
	}
	
	count if mi(repl_`stub')
}

* Manual corrections
egen repl_miss = rowmiss(repl_back repl_mate repl_conc)
sort repl_conc

drop if mi(repl_conc) & repl_miss!=3 // incomplete abstracts, excluding unstructured abstracts
drop repl_*



*** Define oral/poster
** Define program
capture: program drop oral
program define oral
syntax, Year(integer) OPages(string) PPages(string)

di "`year' (oral pages: `opages') (poster pages: `ppages')"
recode oral (.=1) if year==`year' & inrange(page, `opages')
recode oral (.=0) if year==`year' & inrange(page, `ppages')

* If missing
qui: count if mi(oral) & year==`year'
if `r(N)'>0 {
    di "Missing oral/poster category: `r(N)'"
	list title firstpage lastpage page pui if mi(oral)
}

end


** Apply to each year
gen oral = ., after(title)
label define oral_ 0 "Poster" 1 "Oral"
label value oral oral_

oral, year(2010) op("7, 115") pp("116, 533")

oral, year(2011) op("7, 116") pp("117, 519")
recode oral (0=1) if year==2011 & title=="A wireless, fully implantable continuous glucose sensor"

oral, year(2012) op("7, 117") pp("118, 515")
oral, year(2013) op("7, 116") pp("117, 543")
oral, year(2014) op("7, 117") pp("118, 539")
oral, year(2015) op("1, 133") pp("134, 582")
oral, year(2016) op("1, 135") pp("136, 557")
oral, year(2017) op("3, 124") pp("125, 582")
oral, year(2018) op("3, 134") pp("135, 594")
oral, year(2020) op("3, 133") pp("134, 465")

assert !mi(oral) | year==2009

drop firstpage lastpage 


*** Export
sort year page
gen id =_n
order id year page oral title abstract

save 2_Data/Abstracts.dta, replace
export excel using 2_Data/Abstracts.xlsx, firstrow(variables) nolabel replace
export delimited using "2_Data/Abstracts.csv", delimiter(tab) replace