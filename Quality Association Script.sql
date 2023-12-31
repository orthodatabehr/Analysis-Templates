/* This query will isolate all potential factors related to a particular QVI while pulling patients withOUT QVIs for comparison. */

/*
Enter the Fiscal Year you want to use for this analysis
Replace **** with numerical Fiscal year value.
*/
drop table if exists #FiscalYear;
create table #FiscalYear (Value int);
insert into #FiscalYear (Value) select ****; 

/* 
Enter the quality event you want to use for this analysis
Replace NAME with quality event of interest.
Use this query below if you wanted to choose from existing list:
	select Name from dss.qvilineitem
*/
drop table if exists #QVILI;
create table #QVILI (Value varchar(500));
insert into #QVILI (Value) select 'NAME';


/* Enter the Population you want to use for this query. 
For a patient population use the following query 
	select Name from dss.dimclinicalindicator
For a casetypefamily use the following query 
	select Name from dss.casetypefamily
Once selected replace NAME with population of interest.
*/
create table #Population (Value varchar(500));
insert into #Population (Value) select 'NAME';

-- Create temp table for encounter level information
drop table if exists #encounters;
select distinct 
	pes.EncounterID
	, ctf.Name as MSDRGCaseTypeFamily
	, ci.Name as PatientPopulation
	, dd.FiscalYear
	, sph.Name as SourceSystemCategory
	, ptr.Type as PatientSetting
	, md.FullName as AttendPhysicianName
	, mdspec.Description as AttendPhysicianSpecialty
	, entity.Description as Entity
	, agegroup.Name as AgeCohort
	, pes.AgeID as Age
	, gender.Description as Gender
	, repaprdrg.APRROM as RiskOfMortality
	, repaprdrg.APRSOI as SeverityOfIllness
	, pes.LengthOfStay as LOS
	, pes.PrimaryQVIID
into #encounters
from clientdss.FactPatientEncounterSummary pes
	inner join fw.DimPatientType pt on pt.PatientTypeID = pes.PatientTypeID
	inner join fw.DimPatientTypeRollup ptr on ptr.PatientTypeRollupID = pt.PatientTypeRollupID
	inner join clientdss.DimSourceSystem ss on ss.SourceSystemID = pes.SourceSystemID
	inner join dss.DimSPHSourceSystemCategory sph on sph.SPHSourceSystemCategoryID = ss.SPHSourceSystemCategoryID
	inner join fw.DimDate dd on dd.DateID = pes.DischargeDateID
	inner join dss.CaseTypeFamily ctf on ctf.CaseTypeFamilyID = pes.MSDRGCaseTypeFamilyID and ctf.Name in (select PopulationName from #Population) 
	left join dss.FactPatientEncounterClinicalIndicator eci on eci.EncounterID = pes.EncounterID 
	left join dss.DimClinicalIndicator ci on ci.ClinicalIndicatorID = eci.ClinicalIndicatorID and ci.Name in (select PopulationName from #Population) 
	inner join dss.DimPhysician md on md.PhysicianID = pes.AttendPhysicianID 
	inner join dss.DimPhysicianSpecialty mdspec on mdspec.PhysicianSpecialtyID = md.PhysicianSpecialtyID 
	inner join clientdss.DimEntity entity on entity.EntityID = pes.EntityID
	inner join fw.DimAgeCohort agegroup on agegroup.AgeCohortID = pes.AgeCohortID
	inner join dss.DimGender gender on gender.GenderID = pes.GenderID
	inner join dss.DimAPRDRG repaprdrg on repaprdrg.APRDRGID = pes.ReportingAPRDRGID
where 1=1
and dd.FiscalYear in (select value from #FiscalYear)
and sph.Name = 'Hospital Billing'
and pes.IsGreaterThanZeroCharge = 'Yes'
and ptr.Type in ('Inpatient','IP')
and pes.AttendPhysicianID <> 0; 

/* Sanity check for desired columns
select top 10 * from #encounters
*/

--Using Procedure of Interest as reference point for administration of treatment 
drop table if exists #procdates;
select distinct
	  pbl.EncounterID
	, pbl.ServiceDateID 
	, pbl.ServiceDateTime
into #procdates
from dss.FactPatientBillingLineItemDetail pbl
	inner join #encounters e on e.EncounterID = pbl.EncounterID
	inner join dss.DimCPT cpt on cpt.CPTID = pbl.BilledCPTID
where 1=1
and CPTCode in ('*****')		-- fill in CPT code of interest

/* Sanity check
select * from #procdates order by EncounterID, ServiceDateID
*/
	
--Ranking procedure dates in order of occurrence 
drop table if exists #rankedprocdates;
select 
	ROW_NUMBER() over(partition by EncounterID order by ServiceDateID) as ProcOrder
	, * 
into #rankedprocdates
from #procdates 
order by EncounterID, ProcOrder

--Create Max procedure table to isolate patients with single procedure of interest
drop table if exists #maxprocorder
select 
	EncounterID 
	, max(ProcOrder) as maxproc 
into #maxprocorder
from #rankedprocdates group by EncounterID order by maxproc DESC

/* Single intervention encounters
We are identifying single intervention encounters to have clear perioperative periods defined.
*/
drop table if exists #single_proc_encounters
select * 
into #single_proc_encounters
from #maxprocorder
where maxproc = 1
	
/* Quality Event Encounters with single procedure of interest */
drop table if exists #fyear_QVIgroup
select
	  qvili.Name as QVI
	, e.FiscalYear
	, e.Entity				
	, e.EncounterID
	, e.MSDRGCaseTypeFamily
	, e.PatientPopulation
	, e.AttendPhysicianName				
	, e.AttendPhysicianSpecialty					
	, e.AgeCohort
	, e.Age
	, e.Gender
	, e.RiskOfMortality				
	, e.SeverityOfIllness				
	, e.LOS
	, e.PatientSetting
	, case 
		when datediff(day,procdate.ServiceDateTime, bdetail.ServiceDateTime) < 0
			then 'Before Proc'
		when datediff(day,procdate.ServiceDateTime, bdetail.ServiceDateTime) > 0
			then 'After Proc'
		when datediff(day,procdate.ServiceDateTime, bdetail.ServiceDateTime) = 0
			then 'Day of Proc'
		else 'NA' 
	end as DateOfService
	, m.maxproc as total_proc
	, procdate.ServiceDateTime as proc_date
	, bdetail.ServiceDateTime as chargeservicedate
	, ub.CostDriver as CostDriver
	, cc.Description as ChargeCodeDesc
	, sum(bcost.VariableDirectUnitCost * bdetail.UnitsOfService) as VDC
into #fyear_QVIgroup			
from #encounters e
	inner join #single_proc_encounters m on m.EncounterID = e.EncounterID
	inner join #rankedprocdates procdate on procdate.EncounterID = m.EncounterID	
	inner join dss.FactPatientBillingLineItemDetail bdetail on bdetail.EncounterID = e.EncounterID
	inner join dss.DimUBRevenueCode ub on ub.UBRevenueCodeID = bdetail.UBRevenueCodeID
	inner join fw.DimChargeCode cc on cc.ChargeCodeID = bdetail.ChargeCodeID
	left join dss.FactPatientBillingLineItemCosts bcost on bcost.PBLIDRowID = bdetail.RowID
	inner join dss.FactPatientEncounterQVILineItem pesqvi on pesqvi.EncounterID = e.EncounterID		
	inner join dss.QVILineItem qvili on qvili.QVILineItemID = pesqvi.QVILineItemID						
where 1=1
	and ub.CostDriver <> 'Excluded'				
	and (qvili.Name in (select value from #QVILI))								
group by
	  qvili.Name
	, e.FiscalYear
	, e.Entity				
	, e.EncounterID
	, e.MSDRGCaseTypeFamily
	, e.PatientPopulation
	, e.AttendPhysicianName				
	, e.AttendPhysicianSpecialty					
	, e.AgeCohort
	, e.Age
	, e.Gender
	, e.RiskOfMortality				
	, e.SeverityOfIllness				
	, e.LOS
	, e.PatientSetting
	, procdate.ServiceDateTime
	, bdetail.ServiceDateTime 
	, ub.CostDriver
	, cc.Description
	, m.maxproc
	, procdate.ProcOrder

/* Control (NO Quality Event Encounters) with single procedure of interest */
drop table if exists #fyear_controlgroup
select
	'' as QVI
	,e.FiscalYear
	, e.Entity				
	, e.EncounterID
	, e.MSDRGCaseTypeFamily
	, e.PatientPopulation
	, e.AttendPhysicianName				
	, e.AttendPhysicianSpecialty					
	, e.AgeCohort
	, e.Age
	, e.Gender
	, e.RiskOfMortality				
	, e.SeverityOfIllness				
	, e.LOS
	, e.PatientSetting
	, case 
		when datediff(day,procdate.ServiceDateTime, bdetail.ServiceDateTime) < 0
			then 'Before Proc'
		when datediff(day,procdate.ServiceDateTime, bdetail.ServiceDateTime) > 0
			then 'After Proc'
		when datediff(day,procdate.ServiceDateTime, bdetail.ServiceDateTime) = 0
			then 'Day of Proc'
		else 'NA' 
	end as DateOfService
	, s.maxproc as tot_proc
	, procdate.ServiceDateTime as surgerdate
	, bdetail.ServiceDateTime as chargeservicedate
	, ub.CostDriver as CostDriver
	, cc.Description as ChargeCodeDesc
	, sum(bcost.VariableDirectUnitCost * bdetail.UnitsOfService) as VDC
into #fyear_controlgroup			
from #encounters e
	inner join #single_proc_encounters s on s.EncounterID = e.EncounterID
	inner join #rankedprocdates procdate on procdate.EncounterID = e.EncounterID
	inner join dss.FactPatientBillingLineItemDetail bdetail on bdetail.EncounterID = e.EncounterID
	inner join dss.DimUBRevenueCode ub on ub.UBRevenueCodeID = bdetail.UBRevenueCodeID
	inner join fw.DimChargeCode cc on cc.ChargeCodeID = bdetail.ChargeCodeID
	left join dss.FactPatientBillingLineItemCosts bcost on bcost.PBLIDRowID = bdetail.RowID
where 1=1
	and ub.CostDriver <> 'Excluded'										
	and e.PrimaryQVIID = 0					
group by
	e.FiscalYear
	, e.Entity				
	, e.EncounterID
	, e.MSDRGCaseTypeFamily
	, e.PatientPopulation
	, e.AttendPhysicianName				
	, e.AttendPhysicianSpecialty					
	, e.AgeCohort
	, e.Age
	, e.Gender
	, e.RiskOfMortality				
	, e.SeverityOfIllness				
	, e.LOS
	, e.PatientSetting
	, procdate.ServiceDateTime
	, bdetail.ServiceDateTime 
	, ub.CostDriver
	, cc.Description
	, s.maxproc


/* Cost Driver Level Summary for Quality Event Group and Control Group */
select 
	distinct CostDriver
	, count(distinct EncounterID) as qvi_cases
	, (select count(distinct EncounterID) from #fyear_QVIgroup) as qvi_totcases
	, sum(VDC)/count(distinct EncounterID) as VDC_per_case
from #fyear_QVIgroup 
group by 
	CostDriver

select 
	distinct CostDriver
	, count(distinct EncounterID) as con_cases
	, (select count(distinct EncounterID) from #fyear_controlgroup) as con_totcases
	, sum(VDC)/count(distinct EncounterID) as VDC_per_case
from #fyear_controlgroup 
group by 
	CostDriver



/* 
This section is a manual calculation of Chi-squared Test for Independence.
*/

--Dropping temporary tables for ease of re-running queries
drop table if exists #base_metrics;
drop table if exists #row_metrics;
drop table if exists #col_metrics;
drop table if exists #expected;
drop table if exists #diff;
drop table if exists #stat_sig;

--Base Metrics
select 
	coalesce(con.CostDriver, qvi.CostDriver) as CostDriver		
	, count(distinct qvi.EncounterID) as qvi_trmt
	, (select count(distinct EncounterID) from #fyear_QVIgroup) as qvi_tot
	, count(distinct con.EncounterID) as con_trmt
	, (select count(distinct EncounterID) from #fyear_controlgroup) as con_tot
into #base_metrics
from #fyear_QVIgroup qvi
	full outer join #fyear_controlgroup con  on con.CostDriver = qvi.CostDriver
group by con.CostDriver;

--ROW METRICS (according to excel file table)
--Includes QVI treatment/no treatment/total/percentages, Control treatment/no treatment/total/percentages 
select 
	CostDriver
	, qvi_trmt
	, qvi_tot - qvi_trmt as qvi_no_trmt
	, qvi_tot
	, cast(qvi_trmt*100.00/qvi_tot as decimal(19,2)) as qvi_trmt_perc
	, con_trmt
	, con_tot - con_trmt as con_no_trmt
	, con_tot	 
	, cast(con_trmt*100.00/con_tot as decimal(19,2)) as con_trmt_perc
into #row_metrics
from #base_metrics ;


--COLUMN METRICS (according to excel file table)
--Includes treatment totals, no treatment totals, and grand total
select 
	CostDriver
	, cast(qvi_trmt + con_trmt as decimal(19,2)) as trmt_tot
	, cast(qvi_no_trmt + con_no_trmt as decimal(19,2))as no_trmt_tot
	, cast(qvi_tot + con_tot as decimal (19,2)) as grand_tot
into #col_metrics
from #row_metrics ;

--EXPECTED VALUES (according to excel file table)
select 
	ro.CostDriver as CostDriver
	, cast(ro.qvi_tot * col.trmt_tot / col.grand_tot as decimal(19,2)) as exp_qvi_trmt --TC edit, had to swap as decimal for as int so that the value can be squared in the #diff table next
	, cast(ro.qvi_tot * col.no_trmt_tot / col.grand_tot as decimal(19,2)) as exp_qvi_no_trmt
	, cast(ro.con_tot * col.trmt_tot / col.grand_tot as decimal(19,2)) as exp_con_trmt
	, cast(ro.con_tot * col.no_trmt_tot / col.grand_tot as decimal(19,2)) as exp_con_no_trmt
into #expected
from #row_metrics ro
inner join #col_metrics col on ro.CostDriver = col.CostDriver;

--DIFFERENCE BETWEEN EXPECTED AND ACTUAL (according to excel file table)
select 
	e.CostDriver
	, ISNULL(abs(r.qvi_trmt - e.exp_qvi_trmt) * abs(r.qvi_trmt - e.exp_qvi_trmt) / NULLIF(e.exp_qvi_trmt,0),0) as diff_qvi_trmt --TC edit, had to add ISNULL and NULLIF statements to prevent divide by 0 error
	, ISNULL(abs(r.qvi_no_trmt - e.exp_qvi_no_trmt) * abs(r.qvi_trmt - e.exp_qvi_trmt) / NULLIF(e.exp_qvi_no_trmt,0),0) as diff_qvi_no_trmt
	, ISNULL(abs(r.con_trmt - e.exp_con_trmt)  * abs(r.qvi_trmt - e.exp_qvi_trmt) / NULLIF(e.exp_con_trmt,0),0) as diff_con_trmt
	, ISNULL(abs(r.con_no_trmt - e.exp_con_no_trmt) * abs(r.qvi_trmt - e.exp_qvi_trmt) / NULLIF(e.exp_con_no_trmt,0),0) as diff_con_no_trmt
into #diff
from #expected e
inner join #row_metrics r on r.CostDriver = e.CostDriver;

-- Statistical Significance Table that outputs significance of Quality group vs Control
-- E.g., "Statistically Higher Utilization" implies quality event utilization is significantly different than Control Group Utilization
select 
	d.CostDriver
	, case
		when ((diff_qvi_trmt + diff_qvi_no_trmt + diff_con_trmt + diff_con_no_trmt) > 3.841)
			and (r.qvi_trmt_perc > r.con_trmt_perc)
			then 'Statistically Higher Utilization'
		when ((diff_qvi_trmt + diff_qvi_no_trmt + diff_con_trmt + diff_con_no_trmt) > 3.841)
			and (r.qvi_trmt_perc < r.con_trmt_perc)
			then 'Statistically Lower Utilization'
		else 'Not Statistical Difference'
	  end as significance
into #stat_sig
from #diff d
inner join #row_metrics r on r.CostDriver = d.CostDriver;
