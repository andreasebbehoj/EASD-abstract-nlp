***** 1_Import.do *****
capture: mkdir 1_Input
capture: mkdir 2_Data
capture: mkdir 3_Output


*** Define program for importing embase excel files
capture: program drop embaseimport
program define embaseimport
syntax , File(string) clear POral(string) PPost(string)
import excel `file', clear case(lower) firstrow allstring 

drop if strpos(title, "European Association for the Study of Diabetes") & strpos(title, "Annual Meeting")

gen page = real(substr(firstpage, 2, .))
sort page

order firstpage page, after(title)

gen oral = 1 if inrange(page, `poral'), after(title)
recode oral (.=0) if inrange(page, `ppost')

qui: count if mi(oral)
if `r(N)'>0 {
    di "Missing oral/poster category:"
	list title firstpage lastpage page pui if mi(oral)
}

label define oral_ 0 "Poster" 1 "Oral"
label value oral oral_
end


*** Importing and formatting data
** 2018
embaseimport, f("1_Input/EmbaseEASD2018") clear poral("3, 134") ppost("135, 594")
tempfile abs2018
save `abs2018', replace


** 2020
embaseimport, f("1_Input/EmbaseEASD2020") clear poral("3, 133") ppost("134, 465")

* Wrong pages, should have been 18-19
recode oral (.=1) if inrange(page, 518, 519) 
replace firstpage = "S" + substr(first, 3, 2) if inrange(page, 518, 519)
replace page = page-500 if inrange(page, 518, 519)
sort page

tempfile abs2020
save `abs2020', replace



*** Combine files
clear
foreach y in 2018 2020 {
    append using `abs`y''
}

** Delete empty vars
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

** Drop useless vars
drop sourcetitle publicationtype source fullrecordentrydate firstpage lastpage volume issue dateofpublication conferencedate conferencename conferencelocation conferencedate issn bookpublisher articlelanguage summarylanguage pui fulltextlink copyright openurllink doi

** Format values
destring publicationyear, replace


*** Format abstracts
** Add capital headers
foreach string in "Background and aims:" "Materials and methods:" "Conclusion:" {
    local stub = substr(lower("`string'"), 1, 4)
	di "`stub'"
	gen repl_`stub' = 1 if strpos(abstract, "`string'")
	replace abstract = subinstr(abstract, "`string'", upper("`string'"), 1)
}

* Manual corrections
sort repl_back
replace abstract = subinstr(abstract, "Backgroundandaims:" , upper("Background and aims:"), 1)

*slist if mi(repl_conc)
drop if mi(repl_conc) // incomplete abstracts

sort repl_mate
*slist if mi(repl_mate)
replace abstract = subinstr(abstract, "Materials andmethods:" , upper("Materials and methods:"), 1)
recode repl_mate (.=1) if strpos(abstract, upper("Materials and methods:"))
sort repl_mate

assert strpos(abstract, upper("Background and aims:")) & strpos(abstract, upper("Materials and methods:")) & strpos(abstract, upper("Conclusion:"))
drop repl_*



*** Export
sort publicationyear page
gen id =_n
order id publicationyear page oral title abstract

save 2_Data/Abstracts.dta, replace
export excel using 2_Data/Abstracts.xlsx, firstrow(variables) nolabel replace
export delimited using "2_Data/Abstracts.csv", delimiter(tab) replace