
drop table if exists #NewYear_config
create table #NewYear_config (config int)
insert into #NewYear_config (config) select 2023

drop table if exists #OldYear_config
create table #OldYear_config (config int)
insert into #OldYear_config (config) select 2022

drop table if exists #sourcesystem
select distinct SourceSystemID
into #sourcesystem
from clientdss.DimSourceSystem
where SPHSourceSystemCategoryID = 1

drop table if exists #enc_denom
select 
	e.EncounterID
	, e.EncounterRecordNumber
	, ent.Name as entity
	, pt.PatientTypeRollupName as patient_setting
	, sl.Name as service_line
	-- Specific to HSS 2984
	, md.CustomHSSMDName as attend_md
	, md.CustomHSSSpecialty as attend_md_spec
into #enc_denom
from clientdss.FactPatientEncounterSummary e
	inner join clientdss.DimEntity ent on ent.EntityID = e.EntityID
	inner join fw.DimDate dd on dd.DateID = e.DischargeDateID
	inner join fw.viewDimPatientType pt on pt.PatientTypeID = e.PatientTypeID
	inner join clientdss.DimSourceSystem ss on ss.SourceSystemID = e.SourceSystemID
	-- Specific to HSS 2984
	inner join fw.DimServiceLine2 sl on sl.ServiceLine2ID = e.ServiceLine2ID
	inner join dss.DimPhysician md on md.PhysicianID = e.AttendPhysicianID
where 1=1
	and dd.FiscalYear in (select config - 1 from #NewYear_config)
	and ss.SourceSystemID in (select * from #sourcesystem)
	and e.IsGreaterThanZeroCharge = 'Yes'

drop table if exists #bill_numerator
select 
	e.*
	, cc.CostDriver
	, cc.Rollup 
	, cc.Name as full_charge_code_description
	, sum(b.UnitsOfService) as UOS
	, sum(b.UnitsOfService * c.VariableDirectUnitCost) VDC
into #bill_numerator
from #enc_denom e
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
	, e.attend_md
	, e.attend_md_spec
	, cc.CostDriver
	, cc.[Rollup]
	, cc.Name

drop table if exists #recent_config_md_summary
select distinct 
	md.CustomHSSMDName as PhysicianName
	, md.CustomHSSSpecialty
	, viewopp.OpportunityKey
	, viewopp.CaseTypeName
	, viewopp.CostDriver
	, viewopp.ServiceLineName
	, config.Name as config_year
	, count(distinct esi.EncounterId) as cases
	, sum(esi.SavingsMedian) as median_ID_variation
into #recent_config_md_summary
from cci.VariationEncounterSavingInfo esi
	inner join cci.viewVariationOpportunity viewopp on viewopp.OpportunityGuid = esi.OpportunityGUID
	inner join cci.Configuration config on config.ConfigurationGUID = viewopp.ConfigurationGuid
	inner join dss.DimPhysician md on md.PhysicianID = esi.PhysicianID
where 1=1
	and config.FiscalYearID in (select config from #NewYear_config)
group by
	md.CustomHSSMDName
	, md.CustomHSSSpecialty
	, viewopp.OpportunityKey
	, viewopp.CaseTypeName
	, viewopp.CostDriver
	, viewopp.ServiceLineName
	, config.Name 
order by 
	median_ID_variation desc
	, cases desc

drop table if exists #old_config_md_summary
select distinct 
	md.CustomHSSMDName as PhysicianName
	, md.CustomHSSSpecialty
	, viewopp.OpportunityKey
	, viewopp.CaseTypeName
	, viewopp.CostDriver
	, viewopp.ServiceLineName
	, config.Name as config_year
	, count(distinct esi.EncounterId) as cases
	, sum(esi.SavingsMedian) as median_ID_variation
into #old_config_md_summary
from cci.VariationEncounterSavingInfo esi
	inner join cci.viewVariationOpportunity viewopp on viewopp.OpportunityGuid = esi.OpportunityGUID
	inner join cci.Configuration config on config.ConfigurationGUID = viewopp.ConfigurationGuid
	inner join dss.DimPhysician md on md.PhysicianID = esi.PhysicianID
where 1=1
	and config.FiscalYearID in (select config from #OldYear_config)
group by
	md.CustomHSSMDName
	, md.CustomHSSSpecialty
	, viewopp.OpportunityKey
	, viewopp.CaseTypeName
	, viewopp.CostDriver
	, viewopp.ServiceLineName
	, config.Name 
order by 
	median_ID_variation desc
	, cases desc

drop table if exists #comparison
select 
	coalesce(old.PhysicianName, new.PhysicianName) as PhysicianName
	, coalesce(old.CustomHSSSpecialty, new.CustomHSSSpecialty) as HSS_Specialty
	, coalesce(old.CaseTypeName, new.CaseTypeName) as CaseTypeName
	, coalesce(old.ServiceLineName, new.ServiceLineName) as ServiceLine
	, coalesce(old.CostDriver, new.CostDriver) as CostDriver
	, 'FY2022' as OldYear
	, 'FY2023' as NewYear
	, isnull(old.OpportunityKey,'NA') as OldYear_OppKey
	, isnull(new.OpportunityKey,'NA') as NewYear_OppKey
	, isnull(old.cases,0) as OldYear_Cases
	, isnull(new.cases,0) as NewYear_Cases
	, isnull(round(old.median_ID_variation,2),0) as OldYear_MedIV
	, isnull(round(new.median_ID_variation,2),0) as NewYear_MedIV
into #comparison
from #old_config_md_summary old
	full outer join #recent_config_md_summary new 
		on new.PhysicianName = old.PhysicianName 
		and new.CaseTypeName = old.CaseTypeName 
		and new.CustomHSSSpecialty = old.CustomHSSSpecialty
		and new.ServiceLineName = old.ServiceLineName
		and new.CostDriver = old.CostDriver

		-- select * from #comparison

drop table if exists #md_overlapping_opps
select 
	*
into #md_overlapping_opps
from #comparison
where 1=1
	and OldYear_OppKey <> 'NA'
	and NewYear_OppKey <> 'NA'

	-- select * from #md_overlapping_opps order by NewYear_MedIV desc

drop table if exists #md_unique_newyear_opps
select 
	*
into #md_unique_newyear_opps
from #comparison
where 1=1
	and OldYear_OppKey = 'NA'
	and NewYear_OppKey <> 'NA'

	-- select * from #md_unique_newyear_opps order by NewYear_MedIV desc

drop table if exists #UpdateList
select 		
	0 as isUpdated
	, *
into #UpdateList
from #md_overlapping_opps
where 1=1
	and NewYear_MedIV >= 10000
order by 
	NewYear_MedIV desc
	, NewYear_Cases desc

	-- select * from #UpdateList
	-- select distinct NewYear_OppKey from #UpdateList

drop table if exists #physician_unique_charge_codes, #physician_comparison_charge_codes
create table #physician_unique_charge_codes (
					charge_codes_unique_to_physician_of_interest varchar(1000)
					, CostDriver varchar(100)
					, ChargeCodeRollup varchar(100)
					, PatientSetting varchar(50)
					, Specialty varchar(100)
					, ServiceLine varchar(500)
					, Physician_of_Interest varchar(200)
					, physician_of_interest_case_perc decimal(20,2)
					, physician_of_interest_cases int
					, physician_of_interest_tot_cases int
					, physician_of_interest_tot_VDC decimal(20,2)
					, physician_of_interest_VDC_per_case decimal(20,2)
				)
create table #physician_comparison_charge_codes (
					Overlapping_ChargeCodes varchar(1000)
					, ImpactDollars decimal(20,2)
					, Utilization_Comparison varchar(2000)
					, CostDriver varchar(100)
					, ChargeCodeRollup varchar(100)
					, PatientSetting varchar(50)
					, Specialty varchar(100)
					, ServiceLine varchar(500)
					, Physician_of_Interest varchar(200)
					, Num_Other_Physicians int
					, AVG_CostPerCase_Diff decimal(20,2)
					, physician_of_interest_VDC_per_case decimal(20,2)
					, AVG_Other_physician_VDC_per_case decimal(20,2)
					, physician_of_interest_case_perc decimal(20,2)
					, AVG_Other_physician_case_perc decimal(20,2)
					, physician_of_interest_cases int
					, AVG_Other_physician_cases int
					, physician_of_interest_tot_cases int
					, AVG_Other_physician_tot_cases int
				)

while exists (select * from #UpdateList where isUpdated = 0)
Begin
	
	drop table if exists #md_name_opp_id
	select top 1 
		PhysicianName
		, NewYear_OppKey as OppID
	into #md_name_opp_id
	from #UpdateList
	where isUpdated = 0

	drop table if exists #physician_case_volumes_opp
	select distinct 
		md.CustomHSSMDName as PhysicianName
		, md.CustomHSSSpecialty as Specialty
		, viewopp.OpportunityKey
		, esi.CaseTypeName
		, esi.CostDriver
		, esi.PatientTypeRollupType
		, viewopp.ServiceLineName
		, count(distinct esi.EncounterId) as cases
		, sum(SavingsMedian) as Median_IV
	into #physician_case_volumes_opp
	from cci.VariationEncounterSavingInfo esi 
		inner join cci.viewVariationOpportunity viewopp on viewopp.OpportunityGuid = esi.OpportunityGUID
		inner join dss.DimPhysician md on md.PhysicianID = esi.PhysicianID
	where 1=1
		and viewopp.OpportunityKey in (select oppid from #md_name_opp_id)
	group by 
		md.CustomHSSMDName
		, md.CustomHSSSpecialty
		, viewopp.OpportunityKey
		, esi.CaseTypeName
		, esi.CostDriver
		, esi.PatientTypeRollupType
		, viewopp.ServiceLineName

	drop table if exists #specialty
	select distinct Specialty
	into #specialty
	from #physician_case_volumes_opp
	where 1=1
		and PhysicianName in (select PhysicianName from #md_name_opp_id)
		and OpportunityKey in (select oppid from #md_name_opp_id)

	drop table if exists #service_line
	select distinct ServiceLineName
	into #service_line
	from #physician_case_volumes_opp
	where 1=1
		and PhysicianName in (select PhysicianName from #md_name_opp_id)
		and OpportunityKey in (select oppid from #md_name_opp_id)		

	drop table if exists #cost_driver
	select distinct CostDriver
	into #cost_driver
	from #physician_case_volumes_opp
	where 1=1
		and PhysicianName in (select PhysicianName from #md_name_opp_id)
		and OpportunityKey in (select oppid from #md_name_opp_id)

	drop table if exists #patient_setting
	select distinct PatientTypeRollupType
	into #patient_setting
	from #physician_case_volumes_opp
	where 1=1
		and PhysicianName in (select PhysicianName from #md_name_opp_id)
		and OpportunityKey in (select oppid from #md_name_opp_id)

	drop table if exists #POI_charge_codes
	select 
		full_charge_code_description
		, b.CostDriver
		, b.Rollup as cc_rollup
		, b.attend_md
		, b.patient_setting
		, b.attend_md_spec
		, b.service_line
		, count(distinct b.EncounterID) as cases
		, sum(VDC) as VDC
		, sum(VDC) / cast(count(distinct b.EncounterID) as decimal(10,2)) as VDC_per_case
		, ptr_totals.cases as tot_cases
	into #POI_charge_codes
	from #bill_numerator b
		inner join (select PatientTypeRollupType, cases from #physician_case_volumes_opp where PhysicianName in (select PhysicianName from #md_name_opp_id)) ptr_totals 
			on ptr_totals.PatientTypeRollupType = b.patient_setting
	where 1=1
		and attend_md in (select PhysicianName from #md_name_opp_id)
		and b.CostDriver in (select CostDriver from #cost_driver)
		and b.service_line in (select ServiceLineName from #service_line)
	group by
		full_charge_code_description
		, b.CostDriver
		, b.[Rollup]
		, b.attend_md
		, b.patient_setting
		, b.attend_md_spec
		, b.service_line
		, ptr_totals.cases
	order by 
		VDC desc

	drop table if exists #other_md_charge_codes
	select 
		full_charge_code_description
		, b.CostDriver
		, b.Rollup as cc_rollup
		, b.attend_md
		, b.patient_setting
		, b.attend_md_spec
		, b.service_line
		, count(distinct b.EncounterID) as cases
		, sum(VDC) as VDC
		, sum(VDC) / cast(count(distinct b.EncounterID) as decimal(10,2)) as VDC_per_case
		, ptr_totals.cases as tot_cases
	into #other_md_charge_codes
	from #bill_numerator b
		inner join (select PhysicianName, PatientTypeRollupType, cases from #physician_case_volumes_opp where PhysicianName not in (select PhysicianName from #md_name_opp_id)) ptr_totals 
			on ptr_totals.PatientTypeRollupType = b.patient_setting
			and ptr_totals.PhysicianName = b.attend_md
	where 1=1
		and attend_md not in (select PhysicianName from #md_name_opp_id)
		and attend_md_spec in (select specialty from #specialty)
		and b.CostDriver in (select CostDriver from #cost_driver)
		and b.service_line in (select ServiceLineName from #service_line)
	group by
		full_charge_code_description
		, b.CostDriver
		, b.[Rollup]
		, b.attend_md
		, b.patient_setting
		, b.attend_md_spec
		, b.service_line
		, ptr_totals.cases
	order by 
		VDC desc

	drop table if exists #comp_cc
	select 
		coalesce(a.full_charge_code_description, b.full_charge_code_description) as full_cc_description
		, coalesce(a.CostDriver, b.CostDriver) as CostDriver
		, coalesce(a.cc_rollup, b.cc_rollup) as cc_Rollup
		, coalesce(a.patient_setting, b.patient_setting) as PatientSetting
		, coalesce(a.attend_md_spec, b.attend_md_spec) as Specialty
		, coalesce(a.service_line, b.service_line) as ServiceLine
		, a.attend_md as physician_of_interest
		, isnull(b.attend_md, 'Not Utilized Elsewhere') as comparison_physician
		, a.VDC_per_case - b.VDC_per_case as cost_per_case_diff
		, a.VDC_per_case as POI_vdc_per_case
		, ISNULL(b.VDC_per_case,0) as other_physician_vdc_per_case
		, a.cases / cast(a.tot_cases as decimal(10,2)) as POI_case_vol_perc
		, b.cases / cast(b.tot_cases as decimal(10,2)) as other_physician_case_vol_perc	
		, a.cases as POI_cases
		, a.tot_cases as POI_tot_cases
		, ISNULL(b.cases, 0) as other_physician_cases
		, ISNULL(b.tot_cases, 0) as other_physician_tot_cases
		, a.VDC as POI_VDC
		, ISNULL(b.VDC, 0) as other_physician_VDC
	into #comp_cc
	from #POI_charge_codes a 
		left join #other_md_charge_codes b 
			on b.full_charge_code_description = a.full_charge_code_description
			and b.CostDriver = a.CostDriver
			and a.attend_md_spec = b.attend_md_spec
	group by 
		a.attend_md
		, b.attend_md
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
		, a.attend_md_spec
		, b.attend_md_spec
		, a.service_line
		, b.service_line

	insert into #physician_unique_charge_codes (
						charge_codes_unique_to_physician_of_interest
						, CostDriver
						, ChargeCodeRollup 
						, PatientSetting
						, Specialty 
						, ServiceLine
						, Physician_of_Interest 
						, physician_of_interest_case_perc 
						, physician_of_interest_cases
						, physician_of_interest_tot_cases
						, physician_of_interest_tot_VDC
						, physician_of_interest_VDC_per_case
					)
	select distinct 
		full_cc_description
		, CostDriver
		, cc_Rollup
		, PatientSetting
		, Specialty
		, ServiceLine
		, physician_of_interest
		, POI_case_vol_perc
		, POI_cases 
		, POI_tot_cases 
		, POI_VDC 
		, POI_vdc_per_case 
	from #comp_cc 
	where 1=1 
		and comparison_physician = 'Not Utilized Elsewhere' 
		and POI_VDC > 0 

	insert into #physician_comparison_charge_codes (
						Overlapping_ChargeCodes 
						, ImpactDollars 
						, Utilization_Comparison 
						, CostDriver
						, ChargeCodeRollup
						, PatientSetting
						, Specialty 
						, ServiceLine
						, Physician_of_Interest
						, Num_Other_Physicians
						, AVG_CostPerCase_Diff 
						, physician_of_interest_VDC_per_case
						, AVG_Other_physician_VDC_per_case
						, physician_of_interest_case_perc 
						, AVG_Other_physician_case_perc
						, physician_of_interest_cases
						, AVG_Other_physician_cases
						, physician_of_interest_tot_cases
						, AVG_Other_physician_tot_cases 
					)
	select distinct 
		full_cc_description 
		, AVG(cost_per_case_diff) * POI_cases 
		, case
			when POI_case_vol_perc - avg(other_physician_case_vol_perc) > 0.05
				then 'Over 5% Higher Utilization than other physicians'
			when POI_case_vol_perc - avg(other_physician_case_vol_perc) < -0.05
				then 'Over 5% Lower Utilization than other physicians'
			else 'Within 5% Utilization of other physicians'
		end 
		, CostDriver
		, cc_Rollup
		, PatientSetting
		, Specialty
		, ServiceLine
		, physician_of_interest
		, count(distinct comparison_physician) 
		, AVG(cost_per_case_diff) 
		, POI_vdc_per_case 
		, AVG(other_physician_vdc_per_case)
		, POI_case_vol_perc 
		, avg(other_physician_case_vol_perc) 
		, POI_cases 
		, avg(other_physician_cases) 
		, POI_tot_cases 
		, avg(other_physician_tot_cases)
	from #comp_cc 
	where 1=1 
		and comparison_physician <> 'Not Utilized Elsewhere' 
		and cost_per_case_diff > 0
	group by
		full_cc_description
		, CostDriver
		, cc_Rollup
		, PatientSetting
		, Specialty
		, ServiceLine
		, physician_of_interest
		, POI_case_vol_perc
		, POI_tot_cases
		, POI_cases
		, POI_vdc_per_case

	update #UpdateList 
	set isUpdated = 1 
	where 1=1 
		and isUpdated = 0
		and PhysicianName in (select PhysicianName from #md_name_opp_id)
		and NewYear_OppKey in (select OppID from #md_name_opp_id)
End;

	select * from #physician_unique_charge_codes order by physician_of_interest_tot_VDC desc
	select * from #physician_comparison_charge_codes order by ImpactDollars desc

	-- select distinct Physician_of_interest from #physician_comparison_charge_codes

	-- select * from #UpdateList


	select * from #physician_comparison_charge_codes where Physician_of_Interest like '%gausden%' and Overlapping_ChargeCodes like '%semi%private%'


	select distinct
		Overlapping_ChargeCodes
		, Specialty
		, PatientSetting
		, CostDriver
		, avg(ImpactDollars) avg_impactdollars
		, count(distinct Physician_of_Interest) mds
		, sum(Num_Other_Physicians) other_mds
	from #physician_comparison_charge_codes
	where 1=1
		and Overlapping_ChargeCodes not in (
					'SUP73778 - VIZADISC HIP PROCEDURE TRK KIT'
					,'SUP75129 - VIZADISC KNEE PROCEDURE KIT'
					,'SUP63884 - KIT CHKPT FEMORAL and TIBIAL'
					,'SUP65573 - PIN BONE 4 X 80MM STERILE'
					,'SUP63882 - PIN BONE 4MM X 140MM (STERILE)'
					,'SUP82590 - CHECKPOINT 3.5 HEX IMPACTION'
					,'SUP129709 - CAMERA DRAPE'
					,'SUP129710 - REFLECTIVE LOCALIZATION MARKERS'
					,'SUP129711 - PELVIC SCREW'
					,'SUP103503 - NAVIGATION UNIT ORTHO PLUS'
					,'SUP146141 - TUBE RIO SYSTEM IRRIGATION'
					,'SUP159910 - MICS IRRIGATION CLIP'
					,'SUP166455 - MICS 6MM BALL BURR'
					,'SUP146143 - SCREW FEMORAL G2 LONG'
					,'SUP143651 - BLADE SAW MICS STD ST'
					,'SUP143654 - BONE PIN 4X110MM STERILE'
					,'SUP189998 - SET NAVITAGS STRL SGLE USE'
					,'SUP189999 - DRAPE NAVISWISS STRL SGLE USE'
					,'SUP190047 - BONE PIN 3.2MM 110MM'
					,'SUP195503 - TUBE CORI IRRIGATION-SUCTION'
					,'SUP195504 - BURR 5MM CORI CYLINDRICAL'
					,'SUP195946 - BURR 6MM CORI CYLINDRICAL'
					,'SUP207993 - BLADE SAW OSCIILLATING VELYS'
					,'SUP207994 - ARRAY SET KNEE VELYS PURESIGHT'
					,'SUP207995 - PIN DRILL 100MM X 4MM VELYS ARray'
					,'SUP207996 - PIN DRILL 125MM X 4MMVELYS ARRay'
					,'SUP207997 - PIN DRILL 175MM X 4MMVELYS ARRay'
					,'SUP207998 - DRAPE FOR VELYS DEVICE STRL'
					,'SUP207999 - DRAPE FOR VELYS SATELLITE STATION STRL'
					,'SUP212540 - DRAPE MONITOR ROSA HIP'
					,'SUP212541 - PIN CAS FIX FLTD 3.2X80MM STRLE'
					,'SUP212542 - PIN CAS FIX FLTD 3.2X150MM STRLE'
					,'SUP212543 - NAVITRACKER KIT A - KNEE'
					,'SUP212729 - DRAPE ROSA ROBOTIC UNIT'
											)
	group by 
		Overlapping_ChargeCodes
		, Specialty
		, PatientSetting
		, CostDriver
	order by 
		avg_impactdollars desc

		


drop table if exists #md_name
create table #md_name (name varchar(50))
insert into #md_name (name) values ('Della Valle, Alejandro')	

drop table if exists #NewYear_OppKey
create table #NewYear_OppKey (oppid varchar(10))
insert into #NewYear_OppKey (oppid) values ('UV - 2737')


drop table if exists #physician_case_volumes_opp
select distinct 
	md.CustomHSSMDName as PhysicianName
	, md.CustomHSSSpecialty as Specialty
	, viewopp.OpportunityKey
	, esi.CaseTypeName
	, esi.CostDriver
	, esi.PatientTypeRollupType
	, viewopp.ServiceLineName
	, count(distinct esi.EncounterId) as cases
	, sum(SavingsMedian) as Median_IV
into #physician_case_volumes_opp
from cci.VariationEncounterSavingInfo esi 
	inner join cci.viewVariationOpportunity viewopp on viewopp.OpportunityGuid = esi.OpportunityGUID
	inner join dss.DimPhysician md on md.PhysicianID = esi.PhysicianID
where 1=1
	and viewopp.OpportunityKey in (select oppid from #NewYear_OppKey)
group by 
	md.CustomHSSMDName
	, md.CustomHSSSpecialty
	, viewopp.OpportunityKey
	, esi.CaseTypeName
	, esi.CostDriver
	, esi.PatientTypeRollupType
	, viewopp.ServiceLineName

drop table if exists #specialty
select distinct Specialty
into #specialty
from #physician_case_volumes_opp
where 1=1
	and PhysicianName in (select name from #md_name)
	and OpportunityKey in (select oppid from #NewYear_OppKey)

drop table if exists #service_line
select distinct ServiceLineName
into #service_line
from #physician_case_volumes_opp
where 1=1
	and PhysicianName in (select name from #md_name)
	and OpportunityKey in (select oppid from #NewYear_OppKey)		

drop table if exists #cost_driver
select distinct CostDriver
into #cost_driver
from #physician_case_volumes_opp
where 1=1
	and PhysicianName in (select name from #md_name)
	and OpportunityKey in (select oppid from #NewYear_OppKey)

drop table if exists #patient_setting
select distinct PatientTypeRollupType
into #patient_setting
from #physician_case_volumes_opp
where 1=1
	and PhysicianName in (select name from #md_name)
	and OpportunityKey in (select oppid from #NewYear_OppKey)



drop table if exists #POI_charge_codes
select 
	full_charge_code_description
	, b.CostDriver
	, b.Rollup as cc_rollup
	, b.attend_md
	, b.patient_setting
	, b.attend_md_spec
	, count(distinct b.EncounterID) as cases
	, sum(VDC) as VDC
	, sum(VDC) / cast(count(distinct b.EncounterID) as decimal(10,2)) as VDC_per_case
	, ptr_totals.cases as tot_cases
into #POI_charge_codes
from #bill_numerator b
	inner join (select PatientTypeRollupType, cases from #physician_case_volumes_opp where PhysicianName in (select name from #md_name)) ptr_totals 
		on ptr_totals.PatientTypeRollupType = b.patient_setting
where 1=1
	and attend_md in (select name from #md_name)
	and b.CostDriver in (select CostDriver from #cost_driver)
	and b.service_line in (select ServiceLineName from #service_line)
group by
	full_charge_code_description
	, b.CostDriver
	, b.[Rollup]
	, b.attend_md
	, b.patient_setting
	, b.attend_md_spec
	, ptr_totals.cases
order by 
	VDC desc



drop table if exists #other_md_charge_codes
select 
	full_charge_code_description
	, b.CostDriver
	, b.Rollup as cc_rollup
	, b.attend_md
	, b.patient_setting
	, b.attend_md_spec
	, count(distinct b.EncounterID) as cases
	, sum(VDC) as VDC
	, sum(VDC) / cast(count(distinct b.EncounterID) as decimal(10,2)) as VDC_per_case
	, ptr_totals.cases as tot_cases
into #other_md_charge_codes
from #bill_numerator b
	inner join (select PhysicianName, PatientTypeRollupType, cases from #physician_case_volumes_opp where PhysicianName not in (select name from #md_name)) ptr_totals 
		on ptr_totals.PatientTypeRollupType = b.patient_setting
		and ptr_totals.PhysicianName = b.attend_md
where 1=1
	and attend_md not in (select name from #md_name)
	and attend_md_spec in (select specialty from #specialty)
	and b.CostDriver in (select CostDriver from #cost_driver)
	and b.service_line in (select ServiceLineName from #service_line)
group by
	full_charge_code_description
	, b.CostDriver
	, b.[Rollup]
	, b.attend_md
	, b.patient_setting
	, b.attend_md_spec
	, ptr_totals.cases
order by 
	VDC desc


drop table if exists #comp_cc
select 
	coalesce(a.full_charge_code_description, b.full_charge_code_description) as full_cc_description
	, coalesce(a.CostDriver, b.CostDriver) as CostDriver
	, coalesce(a.cc_rollup, b.cc_rollup) as cc_Rollup
	, coalesce(a.patient_setting, b.patient_setting) as PatientSetting
	, coalesce(a.attend_md_spec, b.attend_md_spec) as Specialty
	, a.attend_md as physician_of_interest
	, isnull(b.attend_md, 'Not Utilized Elsewhere') as comparison_physician
	, a.VDC_per_case - b.VDC_per_case as cost_per_case_diff
	, a.VDC_per_case as POI_vdc_per_case
	, ISNULL(b.VDC_per_case,0) as other_physician_vdc_per_case
	, a.cases / cast(a.tot_cases as decimal(10,2)) as POI_case_vol_perc
	, b.cases / cast(b.tot_cases as decimal(10,2)) as other_physician_case_vol_perc	
	, a.cases as POI_cases
	, a.tot_cases as POI_tot_cases
	, ISNULL(b.cases, 0) as other_physician_cases
	, ISNULL(b.tot_cases, 0) as other_physician_tot_cases
	, a.VDC as POI_VDC
	, ISNULL(b.VDC, 0) as other_physician_VDC
into #comp_cc
from #POI_charge_codes a 
	left join #other_md_charge_codes b 
		on b.full_charge_code_description = a.full_charge_code_description
		and b.CostDriver = a.CostDriver
		and a.attend_md_spec = b.attend_md_spec
group by 
	a.attend_md
	, b.attend_md
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
	, a.attend_md_spec
	, b.attend_md_spec


/*
This table will summarize all the charge codes unique to the physician of interest
Filters:
	Total VDC > $0
*/
drop table if exists #physician_unique_charge_codes
select distinct 
	full_cc_description as charge_codes_unique_to_physician_of_interest
	, CostDriver
	, cc_Rollup
	, PatientSetting
	, Specialty
	, physician_of_interest
	, POI_case_vol_perc as physician_of_interest_case_perc
	, POI_cases as physician_of_interest_cases
	, POI_tot_cases as physician_of_interest_tot_cases
	, POI_VDC as physician_of_interest_tot_VDC
	, POI_vdc_per_case as physician_of_interest_VDC_per_case
into #physician_unique_charge_codes
from #comp_cc 
where 1=1 
	and comparison_physician = 'Not Utilized Elsewhere' 
	and POI_VDC > 0 

/*
This table will summarize all the charge codes that overlap between the physician of interest and other physicians
Filters:
	Cost per Case Difference > $0 --> we want to focus only on charge codes where the physician of interest has higher costs
*/
drop table if exists #physician_comparison_charge_codes
select distinct 
	full_cc_description as overlapping_charge_codes
	, AVG(cost_per_case_diff) * POI_cases as impact_dollars
	, case
		when POI_case_vol_perc - avg(other_physician_case_vol_perc) > 0.05
			then 'Over 5% Higher Utilization than other physicians'
		when POI_case_vol_perc - avg(other_physician_case_vol_perc) < -0.05
			then 'Over 5% Lower Utilization than other physicians'
		else 'Within 5% Utilization of other physicians'
	end as utilization_comparison
	, CostDriver
	, cc_Rollup
	, PatientSetting
	, Specialty
	, physician_of_interest
	, count(distinct comparison_physician) as other_physicians
	, AVG(cost_per_case_diff) as avg_cost_per_case_diff
	, POI_vdc_per_case as physician_of_interest_cost_per_case
	, AVG(other_physician_vdc_per_case) as other_physician_avg_cost_per_case
	, POI_case_vol_perc as physician_of_interest_case_perc
	, avg(other_physician_case_vol_perc) as other_physician_avg_case_perc
	, POI_cases as physician_of_interest_cases
	, avg(other_physician_cases) as other_physician_avg_cases
	, POI_tot_cases as physician_of_interest_tot_cases
	, avg(other_physician_tot_cases) as other_physician_avg_tot_cases
into #physician_comparison_charge_codes
from #comp_cc 
where 1=1 
	and comparison_physician <> 'Not Utilized Elsewhere' 
	and cost_per_case_diff > 0
group by
	full_cc_description
	, CostDriver
	, cc_Rollup
	, PatientSetting
	, Specialty
	, physician_of_interest
	, POI_case_vol_perc
	, POI_tot_cases
	, POI_cases
	, POI_vdc_per_case


-- Copy and Paste the below outputs into excel in separate sheets. 
select * from #physician_unique_charge_codes order by physician_of_interest_tot_VDC desc
select * from #physician_comparison_charge_codes order by impact_dollars desc
