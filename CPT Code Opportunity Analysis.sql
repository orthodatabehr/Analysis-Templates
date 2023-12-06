/* CPT Code Opportunity Script
This script will summarize the utilization and costs of a selection of CPT codes. 
Most commonly used for laboratory and imaging CPT codes to determine potential savings. 
*/

/* PARAMETERS
Modify these parameters depending on the test you want to analyze

Create temp table of CPT Codes. Modify CPT codes as necessary. 
If additional CPT codes are needed, add another line starting with "insert into ...". 
If a CPT code is not needed, comment out the "insert into ..." line.  
*/
drop table if exists #cpt_codes
create table #cpt_codes (cptcodes varchar(50))
insert into #cpt_codes (cptcodes) select '_CPTCode_'

drop table if exists #cost_driver
create table #cost_driver (cost_driver varchar(50))
insert into #cost_driver (cost_driver) select '_COSTDRIVER_'

drop table if exists #fiscal_year
create table #fiscal_year (fyear int)
insert into #fiscal_year (fyear) select #FISCALYEAR#

/* SPH Source System Category set to 1 to include Hospital Billing encounters */
drop table if exists #sourcesystem
select SourceSystemID
from clientdss.dimSourceSystem
where SPHSourceSystemCategoryID = 1

drop table if exists #PatientTypeRollup
create table #PatientTypeRollup (ptr varchar(10))
insert into #PatientTypeRollup (ptr) select 'Inpatient'

drop table if exists #CTFMapping
select 
	ctf.CaseTypeFamilyID
	, ctf.Name as CTF
	, msmap.MSDRGCode
	, msmap.ICD10Code
	, cptmap.CPTCode
into #CTFMapping
from dss.CaseTypeFamily ctf
	left join dss.CaseTypeFamilyMappingICD10 msmap on msmap.CaseTypeFamilyID = ctf.CaseTypeFamilyID and msmap.CaseTypeFamilyVersionID = 2
	left join dss.CaseTypeFamilyMappingCPT cptmap on cptmap.CaseTypeFamilyID = ctf.CaseTypeFamilyID and cptmap.CaseTypeFamilyVersionID = 2

/* Create temp table of encounter level detail using parameters above */
drop table if exists #enc
select 
	pes.EncounterID
	, pes.EncounterRecordNumber
	, sl.Name as service_line					
	, ptr.Type as patient_setting
	, ent.Name as entity
	, pbl.ServiceDateID
	, pbl.ServiceDateTime
	, md.FullName as ordering_md_name			
	, mdspec.Name as ordering_md_spec
	, CPTCode as cpt_code
	, CPTName as cpt_description
	, sum(pbl.UnitsOfService) as UOS
	, pbc.VariableDirectUnitCost as VDC_unit
	, sum(pbl.UnitsOfService*pbc.VariableDirectUnitCost) as VDC
into #enc
from clientdss.FactPatientEncounterSummary pes 
  inner join dss.FactPatientBillingLineItemDetail pbl on pbl.EncounterID = pes.EncounterID
  left join dss.FactPatientBillingLineItemCosts pbc on pbc.PBLIDRowID = pbl.RowID
  inner join fw.DimChargeCode cc on cc.ChargeCodeID = pbl.ChargeCodeID
  inner join dss.DimCPT cpt on cpt.CPTID = pbl.BilledCPTID
  inner join dss.DimPhysician md on md.PhysicianID = pbl.OrderPhysicianID
  inner join dss.DimPhysicianSpecialty mdspec on mdspec.PhysicianSpecialtyID = md.PhysicianSpecialtyID
  inner join fw.DimServiceLine2 sl on sl.ServiceLine2ID = pes.ServiceLine2ID								-- change this to the primary service line defined by client
  inner join fw.DimPatientType ptype on ptype.PatientTypeID = pes.PatientTypeID
  inner join fw.DimPatientTypeRollup ptr on ptr.PatientTypeRollupID = ptype.PatientTypeRollupID
  inner join dss.DimICD10DX pdx on pdx.ICD10DXID = pes.ICD10DXPrimaryDiagID
  inner join clientdss.DimLocation loc on loc.LocationID = pes.LocationID
  inner join clientdss.DimEntity ent on ent.EntityID = pes.EntityID
  inner join fw.DimDate dd on dd.DateID = pes.DischargeDateID
  inner join clientdss.DimSourceSystem ss on ss.SourceSystemID = pes.SourceSystemID
where 1=1
	and cpt.CPTCode in (select cptcodes from #cpt_codes)
	and dd.FiscalYear in (select fyear from #fiscal_year)
	and cc.CostDriver in (select cost_driver from #cost_driver)
	and ptr.[Type] in (select ptr from #PatientTypeRollup)					
	and ss.SourceSystemID in (select ssid from #sourcesystem)
group by 
	pes.EncounterID
	, pes.EncounterRecordNumber
	, sl.Name 				
	, ptr.[Type] 
	, ent.Name
	, pbl.ServiceDateID
	, pbl.ServiceDateTime
	, md.FullName 
	, mdspec.Name 
	, CPTCode
	, cpt.CPTName
	, pbc.VariableDirectUnitCost 
order by 
	EncounterID
	, ServiceDateID

/* Pull a "Clean" version of encounter temp table that only contains encounters with positive UOS and VCD */
drop table if exists #enc_cleaned
select *
into #enc_cleaned
from #enc
where 1=1
	and EncounterID not in (select distinct EncounterID from #enc where uos <= 0)
	and EncounterID not in (select distinct EncounterID from #enc where VDC <= 0)
	
/* CPT Code Ranking
Depending on the test, create a rank for different types of test
Goal is to count the least informative/complex test as the excess test
E.g., if a patient received both a CBC with differential and a regular CBC, the regular CBC will be counted as the excess test
*/
drop table if exists #enc_cc_rank
select 
	case 
		when cpt_code = '_MoreComplexCPT_'		
			then 'A'
		when cpt_code = '_LessComplexCPT'
			then 'B'
		/* add additional when clauses as appropriate
    when cpt_code = '_CPTCode_'
			then 'C' */
		else 'NA'
	end as cc_rank
	, *
into #enc_cc_rank
from #enc_cleaned

/* Index the table by EncounterID, then ServiceDateID, then by cc_rank for row by row comparison later */
drop table if exists #enc_indexed_ranked
select 
	ROW_NUMBER() over(order by EncounterID, ServiceDateID, cc_rank) as row_num
	, *
into #enc_indexed_ranked
from #enc_cc_rank
where 1=1
order by 
	EncounterID
	, ServiceDateID
	, cc_rank

/* Create a temporary table with encounters joined to itself but one row below to compare a row with row below */
drop table if exists #categorized
select 
	case 
		when a.EncounterRecordNumber = b.EncounterRecordNumber and a.ServiceDateID = b.ServiceDateID 
			then 'same day'
		else 'NA'
	end as same_day
	, case	
		when a.EncounterRecordNumber = b.EncounterRecordNumber
			then b.ServiceDateID - a.ServiceDateID
		else 99999		--99999 indicates a new encounter
	end as date_diff
	, b.row_num as b_row
	, b.EncounterRecordNumber b_ern
	, b.ServiceDateTime b_time
	, b.UOS as b_uos
into #categorized
from #enc_indexed_ranked a
full outer join #enc_indexed_ranked b on b.row_num = a.row_num + 1
order by a.row_num

/* Create a temporary table with all rows with a "same day" label or if the UOS > 1 (different ordering MD) */
drop table if exists #same_day_encounters
select 
	cat.same_day
	, cat.date_diff
	, enc.*
	, case 
		when cat.same_day = 'same day'
			then VDC
		when cat.same_day = 'NA' and UOS > 1
			then (UOS -1) * VDC_unit
		else 0
	end as same_day_excess_VDC
	, case	
		when cat.same_day = 'same day'
			then UOS
		else UOS-1
	end as same_day_excess_UOS
into #same_day_encounters
from #enc_indexed_ranked as enc
inner join #categorized cat on cat.b_ern = enc.EncounterRecordNumber and cat.b_time = enc.ServiceDateTime and cat.b_row = enc.row_num
where 1=1
	and enc.EncounterRecordNumber in (select b_ern from #categorized where same_day = 'same day' or (same_day = 'NA' and b_uos > 1))
order by 
	row_num

		-- select * from #same_day_encounters order by row_num

/* Create a temporary table with all rows with a date difference of 1 (subsequent day tests) */
drop table if exists #subseq_day_encounters
select 
	cat.date_diff
	, enc.*
	, case	
		when cat.date_diff = 1
			then VDC_unit
		else 0
	end as subseq_day_excess_VDC
	, case 
		when cat.date_diff = 1
			then 1
		else 0
	end as subseq_day_excess_UOS
into #subseq_day_encounters
from #enc_indexed_ranked as enc
inner join #categorized cat on cat.b_ern = enc.EncounterRecordNumber and cat.b_time = enc.ServiceDateTime and cat.b_row = enc.row_num
where 1=1
	and enc.EncounterRecordNumber in (select b_ern from #categorized where date_diff = 1)
order by 
	row_num

		-- select * from #subseq_day_encounters order by row_num

/* Create an output table for Opportunity Metrics */
drop table if exists #output
create table #output (
						fiscalyear int
						, SameDayExcessTests int
						, SameDayExcessVDC float
						, ConsecutiveDailyTests int
						, ConsecutiveDailyVDC float
						, TotalExcessTests int
						, TotalExcessVDC float
						, SameDaySavings_75 float
						, ConsecutiveDailySavings_50 float
						, TotalSavings float
					)
insert into #output (
						fiscalyear
						, SameDayExcessTests
						, SameDayExcessVDC
						, ConsecutiveDailyTests
						, ConsecutiveDailyVDC
						, TotalExcessTests
						, TotalExcessVDC
						, SameDaySavings_75
						, ConsecutiveDailySavings_50
						, TotalSavings
					)
select 
	(select fyear from #fiscal_year)
	, (select sum(same_day_excess_UOS) from #same_day_encounters)
	, (select sum(same_day_excess_VDC) from #same_day_encounters)
	, (select sum(subseq_day_excess_UOS) from #subseq_day_encounters)
	, (select sum(subseq_day_excess_VDC) from #subseq_day_encounters)
	, (select sum(same_day_excess_UOS) from #same_day_encounters) + (select sum(subseq_day_excess_UOS) from #subseq_day_encounters)
	, (select sum(same_day_excess_VDC) from #same_day_encounters) + (select sum(subseq_day_excess_VDC) from #subseq_day_encounters)
	, (select sum(same_day_excess_VDC) from #same_day_encounters) * 0.75
	, (select sum(subseq_day_excess_VDC) from #subseq_day_encounters) * 0.5
	, ((select sum(same_day_excess_VDC) from #same_day_encounters) * 0.75) + ((select sum(subseq_day_excess_VDC) from #subseq_day_encounters) * 0.5)

/* This output temp table will show the potential savings dollars for reduction of same day duplicate and consecutive daily tests/procedures. */
select * from #output
