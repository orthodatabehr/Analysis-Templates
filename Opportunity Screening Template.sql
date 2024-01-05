/* This script can be adapted to add opportunities to the first-pass screening output for a client database. */

-- Include fiscal years of interest by replacing ****
drop table if exists #fiscalyears_of_interest
create table #fiscalyears_of_interest (fyear int)
insert into #fiscalyears_of_interest (fyear) values (****),(****)

-- Create the template output table
drop table if exists #output
create table #output (
	fiscalyear int
	, OpportunityName varchar(1000)
	, OpportunityType varchar(1000)
	, Category varchar(1000)
	, AdditionalInfo varchar(1000)
	, TotalCases int
	, TotalUOS decimal(20,2)
	, TotalVDC decimal(20,2)
	)

/*
Note: The code block from this point onwards can be copied and re-used depending on the number of opportunities of interest. 
OPPORTUNITY NAME
OPPORTUNITY TYPE - type of intervention that we are recommending (e.g. reduction, substitution, etc) 
CATEGORY - charge code categorization (e.g., Supplies - implants)
Summarize by ADDITIONAL INFORMATION - specific description of supply/drug/manufacturer
*/
drop table if exists #opp_cc
select 
	ChargeCodeID
	, Name as FullDescription
	, CostDriver
	, Rollup
into #opp_cc
from fw.DimChargeCode
where 1=1
  /* 
  replace _TESTSTRING_ with the description keywords that you want to be searching on.
  replace _CATEGORY_ with the category of interest. 
  */
	and (
		Name like '%_TESTSTRING_%'
		or Name like '%_TESTSTRING_%'
		)
	and CostDriver = '_CATEGORY_'

drop table if exists #opp_summary
select 
	b.FiscalYearID
	, cc.FullDescription
	, b.EncounterID
	, sum(b.UnitsOfService) UOS
	, sum(b.UnitsOfService * c.VariableDirectUnitCost) VDC
into #opp_summary
from dss.FactPatientBillingLineItemDetail b
	left join dss.factpatientbillinglineitemcosts c on c.PBLIDRowID = b.RowID
	inner join #opp_cc cc on cc.ChargeCodeID = b.ChargeCodeID
where 1=1
	and b.FiscalYearID in (select * from #fiscalyears_of_interest)
group by
	b.FiscalYearID
	, cc.FullDescription
	, b.EncounterID

/* TO UPDATE THIS SPECIFIC ENTITY ENTRY IN THE #OUTPUT TABLE
	Make modifications to the above temp tables for this opportunity as necessary and re-run them. 

	Delete the old entries in the #output table using this DELETE FROM statement below. 

		delete from #output
		where OpportunityName = '_OPPORTUNITY NAME_'

	Afterwards, run the INSERT INTO statement underneath.
*/

insert into #output (fiscalyear, OpportunityName, OpportunityType, Category, AdditionalInfo, TotalCases, TotalUOS, TotalVDC)
select distinct 
	FiscalYearID
	, '_OPPORTUNITY NAME_'
	, '_OPPORTUNITY TYPE_'
	, '_CATEGORY_'
	, FullDescription
	, count(distinct encounterid)
	, sum(uos)
	, sum(VDC)  
from #opp_summary 
group by FiscalYearID, FullDescription

	-- select * from #output
