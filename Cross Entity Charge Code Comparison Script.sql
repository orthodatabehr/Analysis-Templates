/* CROSS ENTITY CHARGE CODE COMPARISON SCRIPT
This script will summarize all charge codes and compare its utilization across all entities.
The goal is to determine which charge codes have the highest variation amongst entities within a hospital system. 
*/

/* Parameters
We want to start off setting appropriate parameters for encounter selection. 
Source System --> we want to focus on hospital billing source systems only.
Fiscal Year --> replace _FISCALYEAR_
Months --> (optional depending on which months the client has published costing)
Use the query below to determine which months mark the start and end of their fiscal year. "FiscalMonthCode" = 1 is the first month of the fiscal year. 
	select * from fw.dimfiscalmonth

To find the appropriate source system for a client, use the following query
	select * from clientdss.dimsourcesystem
*/

drop table if exists #sourcesystem
select distinct SourceSystemID
into #sourcesystem
from clientdss.DimSourceSystem
where SPHSourceSystemCategoryID = 1

drop table if exists #fiscalyear
create table #fiscalyear (fyear int)
insert into #fiscalyear (fyear) values (_FISCALYEAR_)		-- Change the Fiscal Year as you see fit.

/* Client Specific Parameters
Run the query below to determine which table contains the appropriate service lines to join to. 
Make sure to change the configuration year to the correct year. 
	
	select 
		dim.FriendlyName, dim.SQLSchemaName, dim.SQLObjectName
	from cci.configuration config
		inner join dbo.ScoreDimension dim on dim.DimensionGUID = config.ServiceLineDimensionGUID
	where 1=1
		and config.Name = '_CONFIGYEAR_'		-- Change the configuration year here

After determining the appropriate service line, store the service line table in a temp table for easier access later. 
*/

drop table if exists #serviceline
select *
into #serviceline
from fw.DimServiceLine2

/* Create temp table based on encounter summary table and incorporating parameters from above. */
drop table if exists #enc
select 
	e.EncounterID
	, e.EncounterRecordNumber
	, ent.Name as entity
	, pt.PatientTypeRollupName as patient_setting
	, sl.Name as service_line
	, md.FullName as primary_md
	, mds.Description as primary_md_spec
into #enc
from clientdss.FactPatientEncounterSummary e
	inner join clientdss.DimEntity ent on ent.EntityID = e.EntityID
	inner join fw.DimDate dd on dd.DateID = e.DischargeDateID
	inner join #serviceline sl on sl.ServiceLine2ID = e.ServiceLine2ID
	inner join fw.viewDimPatientType pt on pt.PatientTypeID = e.PatientTypeID
	inner join clientdss.DimSourceSystem ss on ss.SourceSystemID = e.SourceSystemID
	inner join dss.dimphysician md on md.PhysicianID = e.PrimaryPhysicianID
	inner join dss.DimPhysicianSpecialty mds on mds.PhysicianSpecialtyID = md.PhysicianSpecialtyID
where 1=1
	and dd.FiscalYear in (select * from #fiscalyear)
	and ss.SourceSystemID in (select * from #sourcesystem)
	and e.IsGreaterThanZeroCharge = 'Yes'

/* Create temp table based on the billing detail table tied in with the encounter table above. */
drop table if exists #bill
select 
	e.*
	, cc.CostDriver
	, cc.Rollup 
	, cc.Name as full_charge_code_description
	, sum(b.UnitsOfService) as UOS
	, sum(b.UnitsOfService * c.VariableDirectUnitCost) VDC
into #bill
from #enc e
	inner join dss.FactPatientBillingLineItemDetail b on b.EncounterID = e.EncounterID
	inner join dss.FactPatientBillingLineItemCosts c on c.PBLIDRowID = b.RowID
	inner join fw.DimChargeCode cc on cc.ChargeCodeID = b.ChargeCodeID
where 1=1
	and cc.CostDriver not in ('Excluded','')
group by 
	e.EncounterID
	, e.EncounterRecordNumber
	, e.entity
	, e.patient_setting
	, e.service_line
	, e.primary_md
	, e.primary_md_spec
	, cc.CostDriver
	, cc.[Rollup]
	, cc.Name

/* Summary billing detail costs at an encounter level */
drop table if exists #bill_enc
select distinct EncounterID, entity, patient_setting, service_line, sum(VDC) VDC 
into #bill_enc
from #bill 
group by EncounterID, entity, patient_setting, service_line

/* Sanity Check to see if columns and cost details are appropriate	
	select top 10 * from #bill_enc
*/

/* Create temp table that tracks updates by entity.
The goal of the next sections is to iterate through all entities within an organization and compare all charge codes at the entity of interest with the same charge code at other entities. 
For example, how much does knee implant A cost at Hospital A vs Hospitals B, C, D, etc.
*/
drop table if exists #entity_update_list
select top 100
	entity
	, patient_setting 
	, service_line
	, count(distinct EncounterID) cases
	, sum(VDC) VDC
	, 0 as isUpdated
into #entity_update_list
from #bill_enc 
group by
	entity
	, patient_setting
	, service_line
having 1=1
	and sum(VDC) > 10000
order by 
	VDC desc
	, cases desc

/* Create output tables for charge codes unique to entities of interest, and charge codes that overlap across multiple entities. */
drop table if exists #entity_unique_charge_codes, #entity_comparison_charge_codes
create table #entity_unique_charge_codes (
		charge_codes_unique_to_entity_of_interest varchar(1000)
		, CostDriver varchar(100)
		, ChargeCodeRollup varchar(100)
		, Entity_of_Interest varchar(100)
		, PatientSetting varchar(50)
		, ServiceLine varchar(500)
		, EOI_case_perc decimal(20,2)
		, EOI_cases int
		, EOI_tot_cases int
		, EOI_VDC decimal(20,2)
		, EOI_VDC_per_case decimal(20,2)
		)
create table #entity_comparison_charge_codes (
		Overlapping_ChargeCodes varchar(1000)
		, ImpactDollars decimal(20,2)
		, Utilization_Comparison varchar(2000)
		, CostDriver varchar(100)
		, ChargeCodeRollup varchar(100)
		, PatientSetting varchar(50)
		, ServiceLine varchar(500)
		, Entity_of_Interest varchar(200)
		, Num_Other_Entities int
		, AVG_CostPerCase_Diff decimal(20,2)
		, entity_of_interest_VDC_per_case decimal(20,2)
		, AVG_Other_entity_VDC_per_case decimal(20,2)
		, entity_of_interest_case_perc decimal(20,2)
		, AVG_Other_entity_case_perc decimal(20,2)
		, entity_of_interest_cases int
		, AVG_Other_entity_cases int
		, entity_of_interest_tot_cases int
		, AVG_Other_entity_tot_cases int
		)

/* 
This while loop serves the function of a for loop in SQL. 
As long as there are rows with isUpdated = 0, then the loop will execute.
*/
while exists (select * from #entity_update_list where isUpdated = 0)
begin

	drop table if exists #entity_patientsetting_sl
	select top 1
		entity
		, patient_setting as setting
		, service_line
	into #entity_patientsetting_sl
	from #entity_update_list
	where isUpdated = 0

	/* EOI = Entity of Interest */
	drop table if exists #EOI_case_volume
	select 
		count(distinct encounterid) cases 
	into #EOI_case_volume
	from #enc 
	where 1=1 
		and entity in (select entity from #entity_patientsetting_sl)
		and patient_setting in (select setting from #entity_patientsetting_sl)
		and service_line in (select service_line from #entity_patientsetting_sl)

	drop table if exists #other_entity_case_volumes
	select 
		entity
		, patient_setting
		, service_line
		, count(distinct encounterid) cases
	into #other_entity_case_volumes
	from #enc 
	where 1=1 
		and entity not in (select entity from #entity_patientsetting_sl)
		and patient_setting in (select setting from #entity_patientsetting_sl)
		and service_line in (select service_line from #entity_patientsetting_sl)
	group by 
		entity
		, patient_setting
		, service_line

	drop table if exists #EOI_charge_codes
	select 
		full_charge_code_description
		, CostDriver
		, Rollup as cc_rollup
		, entity
		, patient_setting
		, service_line
		, count(distinct EncounterID) as cases
		, sum(VDC) as VDC
		, sum(VDC) / cast(count(distinct EncounterID) as decimal(10,2)) as VDC_per_case
		, (select cases from #EOI_case_volume) as tot_cases
	into #EOI_charge_codes
	from #bill
	where 1=1
		and entity in (select entity from #entity_patientsetting_sl)
		and patient_setting in (select setting from #entity_patientsetting_sl)
		and service_line in (select service_line from #entity_patientsetting_sl)
	group by
		full_charge_code_description
		, CostDriver
		, [Rollup]
		, entity
		, patient_setting
		, service_line
	order by 
		VDC desc

	drop table if exists #other_ent_charge_codes
	select 
		full_charge_code_description
		, CostDriver
		, Rollup as cc_rollup
		, a.entity
		, a.patient_setting
		, a.service_line
		, count(distinct EncounterID) as cases
		, sum(VDC) as VDC
		, sum(VDC) / cast(count(distinct EncounterID) as decimal(10,2)) as VDC_per_case
		, b.cases as tot_cases
	into #other_ent_charge_codes
	from #bill a
		inner join #other_entity_case_volumes b 
			on b.entity = a.entity 
			and b.service_line = a.service_line 
			and b.patient_setting = a.patient_setting
	where 1=1
		and a.entity not in (select entity from #entity_patientsetting_sl)
		and a.patient_setting in (select setting from #entity_patientsetting_sl)
		and a.service_line in (select service_line from #entity_patientsetting_sl)
	group by
		full_charge_code_description
		, CostDriver
		, [Rollup]
		, a.entity
		, a.patient_setting
		, a.service_line
		, b.cases
	order by 
		VDC desc

	drop table if exists #comp_cc
	select 
		coalesce(a.full_charge_code_description, b.full_charge_code_description) as full_cc_description
		, coalesce(a.CostDriver, b.CostDriver) as CostDriver
		, coalesce(a.cc_rollup, b.cc_rollup) as cc_Rollup
		, coalesce(a.patient_setting, b.patient_setting) as PatientSetting
		, coalesce(a.service_line, b.service_line) as ServiceLine
		, a.entity as entity_of_interest
		, isnull(b.entity, 'Not Utilized Elsewhere') as comparison_entity
		, a.VDC_per_case - b.VDC_per_case as cost_per_case_diff
		, a.VDC_per_case as EOI_vdc_per_case
		, ISNULL(b.VDC_per_case,0) as other_entity_vdc_per_case
		, a.cases / cast(a.tot_cases as decimal(10,2)) as EOI_case_vol_perc
		, b.cases / cast(b.tot_cases as decimal(10,2)) as other_entities_case_vol_perc	
		, a.cases as EOI_cases
		, a.tot_cases as EOI_tot_cases
		, ISNULL(b.cases, 0) as other_entity_cases
		, ISNULL(b.tot_cases, 0) as other_entity_tot_cases
		, a.VDC as EOI_VDC
		, ISNULL(b.VDC, 0) as other_entity_VDC
	into #comp_cc
	from #EOI_charge_codes a 
		left join #other_ent_charge_codes b 
			on b.full_charge_code_description = a.full_charge_code_description
			and b.CostDriver = a.CostDriver
			and a.service_line = b.service_line
			and a.patient_setting = b.patient_setting
	group by 
		a.entity
		, b.entity
		, a.cases
		, b.cases
		, a.VDC
		, b.VDC
		, a.cc_rollup
		, b.cc_rollup
		, a.full_charge_code_description
		, b.full_charge_code_description
		, a.CostDriver
		, b.CostDriver
		, a.VDC_per_case
		, b.VDC_per_case
		, a.patient_setting
		, b.patient_setting
		, a.tot_cases
		, b.tot_cases
		, a.service_line
		, b.service_line

	/*
	This table will summarize all the charge codes unique to the entity of interest
	Filters:
		Total VDC > $0
	*/
	insert into #entity_unique_charge_codes (
			charge_codes_unique_to_entity_of_interest 
			, CostDriver
			, ChargeCodeRollup 
			, Entity_of_Interest
			, PatientSetting
			, ServiceLine
			, EOI_case_perc 
			, EOI_cases 
			, EOI_tot_cases 
			, EOI_VDC
			, EOI_VDC_per_case 
			)
	select distinct 
		full_cc_description as charge_codes_unique_to_entity_of_interest
		, CostDriver
		, cc_Rollup
		, entity_of_interest
		, PatientSetting
		, ServiceLine
		, EOI_case_vol_perc as entity_of_interest_case_perc
		, EOI_cases as entity_of_interest_cases
		, EOI_tot_cases as entity_of_interest_tot_cases
		, EOI_VDC as entity_of_interest_tot_VDC
		, EOI_vdc_per_case as entity_of_interest_VDC_per_case
	from #comp_cc 
	where 1=1 
		and comparison_entity = 'Not Utilized Elsewhere' 
		and EOI_VDC > 0 

	/*
	This table will summarize all the charge codes that overlap between the entity of interest and other entities
	Filters:
		Cost per Case Difference > $0 --> we want to focus only on charge codes where the entity of interest has higher costs
	*/
	insert into #entity_comparison_charge_codes (
		Overlapping_ChargeCodes
		, ImpactDollars 
		, Utilization_Comparison
		, CostDriver 
		, ChargeCodeRollup 
		, PatientSetting 
		, ServiceLine 
		, Entity_of_Interest 
		, Num_Other_Entities 
		, AVG_CostPerCase_Diff 
		, entity_of_interest_VDC_per_case
		, AVG_Other_entity_VDC_per_case
		, entity_of_interest_case_perc 
		, AVG_Other_entity_case_perc
		, entity_of_interest_cases
		, AVG_Other_entity_cases 
		, entity_of_interest_tot_cases
		, AVG_Other_entity_tot_cases 
		)
	select distinct 
		full_cc_description as overlapping_charge_codes
		, AVG(cost_per_case_diff) * EOI_cases as impact_dollars
		, case
			when EOI_case_vol_perc - avg(other_entities_case_vol_perc) > 0.05
				then 'Over 5% Higher Utilization than other entities'
			when EOI_case_vol_perc - avg(other_entities_case_vol_perc) < -0.05
				then 'Over 5% Lower Utilization than other entities'
			else 'Within 5% Utilization of other entities'
		end as utilization_comparison
		, CostDriver
		, cc_Rollup
		, PatientSetting
		, ServiceLine
		, entity_of_interest
		, count(distinct comparison_entity) as other_entities
		, AVG(cost_per_case_diff) as avg_cost_per_case_diff
		, EOI_vdc_per_case as entity_of_interest_cost_per_case
		, AVG(other_entity_vdc_per_case) as other_entities_avg_cost_per_case
		, EOI_case_vol_perc as entity_of_interest_case_perc
		, avg(other_entities_case_vol_perc) as other_entities_avg_case_perc
		, EOI_cases as entity_of_interest_cases
		, avg(other_entity_cases) as other_entities_avg_cases
		, EOI_tot_cases as entity_of_interest_tot_cases
		, avg(other_entity_tot_cases) as other_entities_avg_tot_cases
	from #comp_cc 
	where 1=1 
		and comparison_entity <> 'Not Utilized Elsewhere' 
		and cost_per_case_diff > 0
	group by
		full_cc_description
		, CostDriver
		, cc_Rollup
		, PatientSetting
		, ServiceLine
		, entity_of_interest
		, EOI_case_vol_perc
		, EOI_tot_cases
		, EOI_cases
		, EOI_vdc_per_case

	update #entity_update_list
	set isUpdated = 1
	where 1=1
		and isUpdated = 0
		and entity in (select entity from #entity_patientsetting_sl)
		and service_line in (select service_line from #entity_patientsetting_sl)
		and patient_setting in (select patient_setting from #entity_patientsetting_sl)

end 

-- Copy and Paste the below outputs into excel for Tableau. 
	select * from #entity_unique_charge_codes order by EOI_VDC desc
	select * from #entity_comparison_charge_codes order by ImpactDollars desc
