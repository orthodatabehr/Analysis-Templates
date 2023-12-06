

/* MULTI-ENTITY CLIENT UV OPPORTUNITY CHARGE CODE ANALYSIS 
This script is designed to investigate in-tool opportunities and compare charge code utilization across entities.

It starts off with a YOY comparison of in-tool UV opportunities. 

The second section of the script will look into ONE specific tool-generated opportunity and compare utilization of those charge codes within that UV opp compared 
to utilization of those charge codes at other entities. 

For example, if "Aquamantys" charge code was found to be used at Entity A, Aquamantys utilization will be compared across all Entities and its utilization details and cost 
will be compared to the opportunity entity. 

This script works best for clients with multiple entities of relatively comparable volume. Clients where there is 1 entity or 1 main entity will require a different approach.
*/



/*	YOY IN-TOOL OPPORTUNITY COMPARISON
We are first creating 3 temp tables with UV opportunity details in each one. 

The years are chosen using Configuration Tracking Periods. Thus, make sure to use the correct tracking period for a client for each of the years.
Remember that the tracking period of FY2023 will entail a baseline period of FY2022 (for most clients).

Use the query below to determine which configuration years you want to examine. The End dates for the baseline period is included. 
	select name, variationenddate from cci.configuration

If you don't want to use 3 time periods, please refer to a commented query below. 
*/

drop table if exists #timepoint_1
create table #timepoint_1 (config_year varchar(10))
insert into #timepoint_1 (config_year) values ('FY2023')	-- Make sure that the config year is accurate

drop table if exists #timepoint_2
create table #timepoint_2 (config_year varchar(10))
insert into #timepoint_2 (config_year) values ('FY2024')	-- Make sure that the config year is accurate



/* 
For these opportunity tables, year3 refers to the most recent config year and year 1 refers to the oldest config year. 
Opportunities with less than $100,000 in Identified Variation are EXCLUDED.
Only UV opportunities are INCLUDED.
*/
drop table if exists #year2
select 
	uv.*
into #year2
from cci.viewVariationOpportunity uv
	inner join cci.Configuration config on config.ConfigurationGUID = uv.ConfigurationGUID
where 1=1
	and OpportunityKey like 'UV%'
	and config.Name in (select config_year from #timepoint_2)
	and IdentifiedSavings >= 100000
order by 
	IdentifiedSavings desc

drop table if exists #year1
select 
	uv.*
into #year1
from cci.viewVariationOpportunity uv
	inner join cci.Configuration config on config.ConfigurationGUID = uv.ConfigurationGUID
where 1=1
	and OpportunityKey like 'UV%'
	and config.Name in (select config_year from #timepoint_1)
	and IdentifiedSavings >= 100000
order by 
	IdentifiedSavings desc

drop table if exists #yoy_comparison
select 
	coalesce(a.CaseTypeName, b.CaseTypeName) as CaseType
	, coalesce(a.EntityName, b.EntityName) as Entity
	, coalesce(a.ServiceLineName, b.ServiceLineName) as ServiceLine
	, coalesce(a.CostDriver, b.CostDriver) as CostDriver
	, a.OpportunityGuid as year1_OppGUID
	, b.OpportunityGuid as year2_OppGUID
	, a.OpportunityKey as year1_OppKey
	, b.OpportunityKey as year2_OppKey
	, a.IdentifiedSavings as year1_IV
	, b.IdentifiedSavings as year2_IV
	, a.Cases as year1_cases
	, b.Cases as year2_cases
into #yoy_comparison
from #year1 a 
	full outer join #year2 b 
		on a.CaseTypeGuid = b.CaseTypeGuid
		and a.ServiceLineId = b.ServiceLineId
		and a.EntityId = b.EntityId
		and a.CostDriver = b.CostDriver
where 1=1
	and a.OpportunityGuid is not null
	and b.OpportunityGuid is not null

drop table if exists #yoy_comparison_perc
select	
	*
	, (year2_IV - year1_IV) / cast(year1_IV as decimal(10,2)) as IV_perc_change
	, (year2_cases - year1_cases) / cast(year1_cases as decimal(10,2)) as cases_perc_change
into #yoy_comparison_perc
from #yoy_comparison


/* 
The below query will show you a subset of tool-generated UV opportunities with case volume % changes and total Identified Variation % changes. 

If you want to receive a full list of UV opps without filters, run the query before the 'WHERE' clause. 

Naming convention for % Changes are as follows:
	RECENT --> Between Year 2 and Year 3
	OLD --> Between Year 1 and Year 2
	OVERALL --> Between Year 1 and Year 3

You can also modify the filters on the list of opps by changing statements under the 'WHERE' clause. 
Current filters are as follows:
	POSITIVE RECENT Identified Variation % Change 
	RECENT Identified Variation % Change > RECENT Case volume % Change 
	RECENT Identified Variation % Change > OLD Identified Variation % Change

The above filters will show all system-identified opportunities that have an Identified Variation $ INCREASE that exceeds their Case Volume % Change and their prior year % Change.
*/
select * 
from #yoy_comparison_perc 

where 1=1
	and IV_perc_change > 0
	and IV_perc_change > cases_perc_change
order by 
	year2_IV desc



----------------------------------------- Part 2 - YOY Charge Code Exploration ----------------------------------------- 
/*
At this point you should have a list of opportunities that fit the filtering criteria that you have set. 
This could be a viable output for a client should they be interested. 
	See Essentia System-Identified Opportunity Trending (Ask Shannon/Teddy) for client feedback on this type of output. 

You can select a Opportunity GUIDs from year 1 and year 2 to examine. 

 
*/
drop table if exists #timepoint1_opp_GUID
create table #timepoint1_opp_GUID (opp_GUID varchar(50))
insert into #timepoint1_opp_GUID (opp_GUID) values ('58A77F33-E2D8-4A34-B644-46C9E1A09C6A')		-- When Copy & Pasting here, make sure to not remove the single quotes.

drop table if exists #timepoint2_opp_GUID
create table #timepoint2_opp_GUID (opp_GUID varchar(50))
insert into #timepoint2_opp_GUID (opp_GUID) values ('D22DEB3E-3898-469D-BF12-FFB113FB6068')		-- When Copy & Pasting here, make sure to not remove the single quotes.

-- This temp table will identify all encounters in the opportunity of interest with POSITIVE Identified Variation (old name = Median Savings)
drop table if exists #T1_opp_positive_savings_encounter_info
select 
	case 
		when ct.CaseTypeCategory = 2
			then 'Patient Population Case Type'
		else 'Regular Case Type'
	end as Case_Type_Category
	, i.*
into #T1_opp_positive_savings_encounter_info
from cci.VariationEncounterSavingInfo i
	inner join dss.DimCaseType ct on ct.CaseTypeId = i.CaseTypeId
where 1=1
	and OpportunityGUID in (select opp_GUID from #timepoint1_opp_GUID)
	and SavingsMedian > 0

drop table if exists #T2_opp_positive_savings_encounter_info
select 
	case 
		when ct.CaseTypeCategory = 2
			then 'Patient Population Case Type'
		else 'Regular Case Type'
	end as Case_Type_Category
	, i.*
into #T2_opp_positive_savings_encounter_info
from cci.VariationEncounterSavingInfo i
	inner join dss.DimCaseType ct on ct.CaseTypeId = i.CaseTypeId
where 1=1
	and OpportunityGUID in (select opp_GUID from #timepoint2_opp_GUID)
	and SavingsMedian > 0

/*
	select count(distinct encounterid) from #T1_opp_positive_savings_encounter_info
	select count(distinct encounterid) from #T2_opp_positive_savings_encounter_info

	select top 10 * from #T1_opp_positive_savings_encounter_info
	select top 10 * from #T2_opp_positive_savings_encounter_info
*/

-- These temp tables are created solely to provide a denominator value of total cases in the opportunities' case type and entity. 
drop table if exists #T1_case_volume
select 
	e.EncounterID
	, e.EncounterRecordNumber
into #T1_case_volume
from clientdss.FactPatientEncounterSummary e 
	inner join clientdss.DimEntity ent on ent.EntityID = e.EntityID
	inner join fw.DimDate dd on dd.DateID = e.DischargeDateID
where 1=1
	and dd.FiscalYear in (select distinct b.FiscalYearID - 1 from #year1 a inner join cci.configuration b on a.ConfigurationGuid = b.ConfigurationGUID)
	and ent.FwEntityID in (select distinct EntityID from #T1_opp_positive_savings_encounter_info)
	and (
			-- To account for patient population case types
			e.EncounterID in (
								select EncounterID 
								from dss.FactPatientEncounterClinicalIndicator e 
									inner join dss.DimCaseType ct on ct.ClinicalIndicatorID = e.ClinicalIndicatorID
								where 1=1
									and ct.CaseTypeId in (select distinct CaseTypeId from #T1_opp_positive_savings_encounter_info)
							)
			or
			e.CaseTypeId in (select distinct CaseTypeId from #T1_opp_positive_savings_encounter_info)
		)

drop table if exists #T2_case_volume
select 
	e.EncounterID
	, e.EncounterRecordNumber
into #T2_case_volume
from clientdss.FactPatientEncounterSummary e 
	inner join clientdss.DimEntity ent on ent.EntityID = e.EntityID
	inner join fw.DimDate dd on dd.DateID = e.DischargeDateID
where 1=1
	and dd.FiscalYear in (select distinct b.FiscalYearID - 1 from #year2 a inner join cci.configuration b on a.ConfigurationGuid = b.ConfigurationGUID)
	and ent.FwEntityID in (select distinct EntityID from #T2_opp_positive_savings_encounter_info)
	and (
			-- To account for patient population case types
			e.EncounterID in (
								select EncounterID 
								from dss.FactPatientEncounterClinicalIndicator e 
									inner join dss.DimCaseType ct on ct.ClinicalIndicatorID = e.ClinicalIndicatorID
								where 1=1
									and ct.CaseTypeId in (select distinct CaseTypeId from #T2_opp_positive_savings_encounter_info)
							)
			or
			e.CaseTypeId in (select distinct CaseTypeId from #T2_opp_positive_savings_encounter_info)
		)

/*
	select count(distinct encounterid) from #T1_case_volume
	select count(distinct encounterid) from #T2_case_volume
*/

-- These temp tables include charge code details for encounters with POSITIVE SAVINGS in the opportunities of interest
drop table if exists #T1_charge_code_encounter_info
select 
	cc.name as chargecode_description
	, e.EntityID as fwentityid
	, e.EntityName
	, e.CaseTypeId
	, e.CaseTypeName
	, e.CostDriver
	, cc.Rollup
	, b.encounterid
	, sum(b.unitsofservice) UOS
	, sum(b.unitsofservice * c.variabledirectunitcost) VDC
into #T1_charge_code_encounter_info
from dss.FactPatientBillingLineItemDetail b
	inner join #T1_opp_positive_savings_encounter_info e on e.EncounterId = b.encounterid
	inner join dss.FactPatientBillingLineItemCosts c on c.PBLIDRowID = b.ROWID
	inner join fw.DimChargeCode cc on cc.chargecodeid = b.chargecodeid
	inner join clientdss.FactPatientEncounterSummary pes on pes.EncounterID = e.EncounterId
where 1=1
	and cc.costdriver in (select distinct CostDriver from #T1_opp_positive_savings_encounter_info)
group by 
	cc.name
	, e.EntityID
	, e.EntityName
	, e.CaseTypeId
	, e.CaseTypeName
	, e.CostDriver
	, cc.[Rollup]
	, b.EncounterID

drop table if exists #T2_charge_code_encounter_info
select 
	cc.name as chargecode_description
	, e.EntityID as fwentityid
	, e.EntityName
	, e.CaseTypeId
	, e.CaseTypeName
	, e.CostDriver
	, cc.Rollup
	, b.encounterid
	, sum(b.unitsofservice) UOS
	, sum(b.unitsofservice * c.variabledirectunitcost) VDC
into #T2_charge_code_encounter_info
from dss.FactPatientBillingLineItemDetail b
	inner join #T2_opp_positive_savings_encounter_info e on e.EncounterId = b.encounterid
	inner join dss.FactPatientBillingLineItemCosts c on c.PBLIDRowID = b.ROWID
	inner join fw.DimChargeCode cc on cc.chargecodeid = b.chargecodeid
	inner join clientdss.FactPatientEncounterSummary pes on pes.EncounterID = e.EncounterId
	inner join dss.DimPhysician md on md.PhysicianID = pes.AttendPhysicianID
where 1=1
	and cc.costdriver in (select distinct CostDriver from #T2_opp_positive_savings_encounter_info)
group by 
	cc.name
	, e.EntityID
	, e.EntityName
	, e.CaseTypeId
	, e.CaseTypeName
	, e.CostDriver
	, cc.[Rollup]
	, b.EncounterID

/*
	select top 10 * from #T1_charge_code_encounter_info
	select top 10 * from #T2_charge_code_encounter_info
*/

-- These temp tables will be joined together to get the YOY Comparison summaries at a charge code + physician level
drop table if exists #T1_chargecode_summary
select 
	chargecode_description
	, count(distinct EncounterID) as cases
	, sum(uos) as UOS
	, sum(VDC) as VDC
	, Rollup as ChargeCodeRollup
	, CostDriver 
	, EntityName as Entity
	, CaseTypeName as CaseType
into #T1_chargecode_summary
from #T1_charge_code_encounter_info
group by 
	chargecode_description
	, [Rollup]
	, CostDriver 
	, EntityName 
	, CaseTypeName 
having 1=1
	and sum(VDC) > 0

drop table if exists #T2_chargecode_summary
select 
	chargecode_description
	, count(distinct EncounterID) as cases
	, sum(uos) as UOS
	, sum(VDC) as VDC
	, Rollup as ChargeCodeRollup
	, CostDriver 
	, EntityName as Entity
	, CaseTypeName as CaseType
into #T2_chargecode_summary
from #T2_charge_code_encounter_info
group by 
	chargecode_description
	, [Rollup]
	, CostDriver 
	, EntityName 
	, CaseTypeName 
having 1=1
	and sum(VDC) > 0

/*
	select top 10 * from #T1_chargecode_summary
	select top 10 * from #T2_chargecode_summary
*/

-- Combine these 2 time period summaries to provide a YOY perspective on Charge Codes that are used from 1 year to the next for each entity
drop table if exists #YOY_entity_chargecode_comparison
select 
	coalesce(b.chargecode_description, a.chargecode_description) as chargecode_description
	, coalesce(b.entity, a.entity) as Entity
	, isnull(a.uos,0) / nullif(cast(a.cases as decimal(10,2)),0) as T1_UOS_per_case
	, isnull(b.uos,0) / nullif(cast(b.cases as decimal(10,2)),0) as T2_UOS_per_case
	, isnull(a.vdc,0) / nullif(cast(a.cases as decimal(10,2)),0) as T1_VDC_per_case
	, isnull(b.vdc,0) / nullif(cast(b.cases as decimal(10,2)),0) as T2_VDC_per_case
	, isnull(b.vdc,0) / nullif(cast(b.cases as decimal(10,2)),0) - isnull(a.vdc,0) / nullif(cast(a.cases as decimal(10,2)),0) as VDC_per_case_diff
	, isnull(a.cases, 0) / isnull((select cast(count(distinct EncounterID) as decimal(10,2)) from #T1_case_volume), 0) as T1_case_perc
	, isnull(b.cases, 0) / isnull((select cast(count(distinct EncounterID) as decimal(10,2)) from #T2_case_volume), 0) as T2_case_perc
	, isnull(a.cases, 0) as T1_cases
	, isnull((select count(distinct EncounterID) from #T1_case_volume), 0) as T1_tot_cases
	, isnull(b.cases, 0) as T2_cases
	, isnull((select count(distinct EncounterID) from #T2_case_volume), 0) as T2_tot_cases
	, isnull(a.uos,0) as T1_UOS
	, isnull(b.uos,0) as T2_UOS
	, isnull(a.vdc,0) as T1_VDC
	, isnull(b.vdc,0) as T2_VDC
	, coalesce(b.CaseType, a.CaseType) as CaseType
	, coalesce(b.CostDriver, a.CostDriver) as CostDriver
	, coalesce(b.ChargeCodeRollup, a.ChargeCodeRollup) as ChargeCodeRollup
into #YOY_entity_chargecode_comparison
from #T1_chargecode_summary a 
	full outer join #T2_chargecode_summary b 
		on b.chargecode_description = a.chargecode_description

/*	
	select top 10 * from #YOY_entity_chargecode_comparison
*/


drop table if exists #overlapping_charge_codes
select 
	chargecode_description as overlapping_chargecode
	, VDC_per_case_diff * T2_cases as T2_Impact_Dollars
	, case	
		when (T2_case_perc - T1_case_perc) > 0.05
			then 'Higher Recent Utilization'
		when (T2_case_perc - T1_case_perc) < 0.05
			then 'Lower Recent Utilization'
		else
			'Within 5% Utilization'
	end as Utilization_Comparison_YOY
	, Entity
	, CaseType
	, CostDriver
	, ChargeCodeRollup
	, VDC_per_case_diff
	, T1_case_perc
	, T2_case_perc
	, T1_cases
	, T2_cases
	, T1_UOS
	, T2_UOS
	, T1_UOS_per_case
	, T2_UOS_per_case
	, T1_VDC
	, T2_VDC
	, T1_VDC_per_case
	, T2_VDC_per_case
into #overlapping_charge_codes
from #YOY_entity_chargecode_comparison
where 1=1
	and T1_cases <> 0
	and T2_cases <> 0
	and VDC_per_case_diff > 0

drop table if exists #T1_unique_charge_codes
select 
	chargecode_description as T1_unique_charge_codes
	, T1_UOS_per_case
	, T1_VDC_per_case
	, Entity
	, CaseType
	, CostDriver
	, ChargeCodeRollup
	, T1_case_perc
	, T1_cases
	, T1_UOS
	, T1_VDC
into #T1_unique_charge_codes
from #YOY_entity_chargecode_comparison
where 1=1
	and T2_cases = 0
	and T1_cases <> 0

drop table if exists #T2_unique_charge_codes
select 
	chargecode_description as T2_unique_charge_codes
	, T2_UOS_per_case
	, T2_VDC_per_case
	, Entity
	, CaseType
	, CostDriver
	, ChargeCodeRollup
	, T2_case_perc
	, T2_cases
	, T2_UOS
	, T2_VDC
into #T2_unique_charge_codes
from #YOY_entity_chargecode_comparison
where 1=1
	and T1_cases = 0
	and T2_cases <> 0

/*
	select top 100 * from #overlapping_charge_codes order by T2_Impact_Dollars desc
	select top 100 * from #T1_unique_charge_codes
	select top 100 * from #T2_unique_charge_codes
*/

-- These temp tables will be joined together to get the YOY Comparison summaries at a Rollup + Entity level
drop table if exists #T1_RU_summary
select 
	Rollup as ChargeCodeRollup
	, count(distinct EncounterID) as cases
	, (select count(distinct EncounterID) from #T1_case_volume) as tot_cases
	, sum(uos) as UOS
	, sum(VDC) as VDC
	, CostDriver 
	, EntityName as Entity
	, CaseTypeName as CaseType
into #T1_RU_summary
from #T1_charge_code_encounter_info
group by 
	[Rollup]
	, CostDriver 
	, EntityName 
	, CaseTypeName 
having 1=1
	and sum(VDC) > 0

drop table if exists #T2_RU_summary
select 
	Rollup as ChargeCodeRollup
	, count(distinct EncounterID) as cases
	, (select count(distinct EncounterID) from #T2_case_volume) as tot_cases
	, sum(uos) as UOS
	, sum(VDC) as VDC
	, CostDriver 
	, EntityName as Entity
	, CaseTypeName as CaseType
into #T2_RU_summary
from #T2_charge_code_encounter_info
group by 
	[Rollup]
	, CostDriver 
	, EntityName 
	, CaseTypeName 
having 1=1
	and sum(VDC) > 0

/*
	select top 10 * from #T1_RU_summary
	select top 10 * from #T2_RU_summary
*/

-- Combine these 2 time period summaries to provide a YOY perspective at a physician + Rollup level
drop table if exists #YOY_RU_comparison
select 
	coalesce(b.chargecoderollup, a.chargecoderollup) as ChargeCodeRollup
	, isnull(a.cases, 0) as T1_cases
	, isnull(a.tot_cases, 0) as T1_tot_cases
	, isnull(b.cases, 0) as T2_cases
	, isnull(b.tot_cases, 0) as T2_tot_cases
	, isnull(a.uos,0) as T1_UOS
	, isnull(b.uos,0) as T2_UOS
	, isnull(a.vdc,0) as T1_VDC
	, isnull(b.vdc,0) as T2_VDC
	, coalesce(b.entity, a.entity) as Entity
	, coalesce(b.CaseType, a.CaseType) as CaseType
	, coalesce(b.CostDriver, a.CostDriver) as CostDriver
into #YOY_RU_comparison
from #T1_RU_summary a 
	full outer join #T2_RU_summary b 
		on b.ChargeCodeRollup = a.ChargeCodeRollup

drop table if exists #YOY_RU_comparison_perc
select 
	ChargeCodeRollup
	, T1_cases / nullif(cast(T1_tot_cases as decimal(10,2)),0) as T1_case_perc
	, T2_cases / nullif(cast(T2_tot_cases as decimal(10,2)),0) as T2_case_perc
	, T1_UOS / nullif(cast(T1_cases as decimal(10,2)),0) as T1_UOS_per_case
	, T2_UOS / nullif(cast(T2_cases as decimal(10,2)),0) as T2_UOS_per_case
	, T1_VDC / nullif(cast(T1_cases as decimal(10,2)),0) as T1_VDC_per_case
	, T2_VDC / nullif(cast(T2_cases as decimal(10,2)),0) as T2_VDC_per_case
	, T2_VDC / nullif(cast(T2_cases as decimal(10,2)),0) - T1_VDC / nullif(cast(T1_cases as decimal(10,2)),0) as VDC_per_case_diff
	, Entity
	, CaseType
	, CostDriver
	, T1_cases
	, T2_cases
	, T1_UOS
	, T2_UOS
	, T1_VDC
	, T2_VDC
into #YOY_RU_comparison_perc
from #YOY_RU_comparison

/*
	select top 100 * from #YOY_RU_comparison
	select top 100 * from #YOY_RU_comparison_perc
*/

drop table if exists #overlapping_RU
select 
	ChargeCodeRollup as overlapping_Rollup
	, VDC_per_case_diff * T2_cases as T2_Impact_Dollars
	, case	
		when (T2_case_perc - T1_case_perc) > 0.05
			then 'Higher Recent Utilization'
		when (T2_case_perc - T1_case_perc) < 0.05
			then 'Lower Recent Utilization'
		else
			'Within 5% Utilization'
	end as Utilization_Comparison_YOY
	, Entity
	, CaseType
	, CostDriver
	, VDC_per_case_diff
	, T1_case_perc
	, T2_case_perc
	, T1_cases
	, T2_cases
	, T1_UOS
	, T2_UOS
	, T1_UOS_per_case
	, T2_UOS_per_case
	, T1_VDC
	, T2_VDC
	, T1_VDC_per_case
	, T2_VDC_per_case
into #overlapping_RU
from #YOY_RU_comparison_perc
where 1=1
	and T1_cases <> 0
	and T2_cases <> 0
	and VDC_per_case_diff > 0

drop table if exists #T1_unique_RU
select 
	ChargeCodeRollup as T1_unique_rollups
	, T1_UOS_per_case
	, T1_VDC_per_case
	, Entity
	, CaseType
	, CostDriver
	, T1_case_perc
	, T1_cases
	, T1_UOS
	, T1_VDC
into #T1_unique_RU
from #YOY_RU_comparison_perc
where 1=1
	and T2_cases = 0
	and T1_cases <> 0

drop table if exists #T2_unique_RU
select 
	ChargeCodeRollup as T2_unique_RU
	, T2_UOS_per_case
	, T2_VDC_per_case
	, Entity
	, CaseType
	, CostDriver
	, T2_case_perc
	, T2_cases
	, T2_UOS
	, T2_VDC
into #T2_unique_RU
from #YOY_RU_comparison_perc
where 1=1
	and T1_cases = 0
	and T2_cases <> 0

/*
	select * from #overlapping_RU order by T2_Impact_Dollars desc
	select * from #T1_unique_RU
	select * from #T2_unique_RU
*/