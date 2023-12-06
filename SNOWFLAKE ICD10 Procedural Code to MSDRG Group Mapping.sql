-- Query ICD10 PX Table to determine nomenclature mapping
select top 10 * from datalake_sandbox.data.icd10pcs;

-- Query to find a client's specific 
select orgpinacct, orgpindb, concat('P_', replace(DatabaseGUID, '-')) as DBGuid
from salesforce_client_reference
where orgpindb = ****           -- replace **** with client org pin
;

/* Make sure to replace **CLIENTDATABASEGUID** with appropriate database GUID pulled from above query */
select top 10 * from **CLIENTDATABASEGUID**.dss.dimicd10dx;


create or replace temp table icd10px_msdrg_icd10dx_comparison as
select 
	e.EncounterID
    	, e.encounterrecordnumber
	, prim_dx.Name as prim_icd10dx_description
	, ms.Name msdrg_fulldescription
    	, to_numeric(ms.msdrgcode) as msdrg_numeric
    	/* We are going to create a case when to categorize MSDRG into larger body systems based on AAPC Major Diagnostic Categories (MDC) */
	, case 
		when to_numeric(ms.msdrgcode) between 1 and 19 then 'Solid Organ transplant, ECMO, Tracheostomy, Bone Marrow Transplant, Immunotherapies'
		when to_numeric(ms.msdrgcode) between 20 and 103 then 'Nervous System'
		when to_numeric(ms.msdrgcode) between 113 and 125 then 'Eye'
		when to_numeric(ms.msdrgcode) between 135 and 159 then 'Ear, Nose, Mouth, Throat'
		when to_numeric(ms.msdrgcode) between 163 and 208 then 'Respiratory System'
		when to_numeric(ms.msdrgcode) between 212 and 320 then 'Circulatory System'
		when to_numeric(ms.msdrgcode) between 321 and 399 then 'Digestive System'
		when to_numeric(ms.msdrgcode) between 405 and 446 then 'Hepatobiliary System, Pancreas'
		when to_numeric(ms.msdrgcode) between 453 and 566 then 'MSK, Connective Tissue'
		when to_numeric(ms.msdrgcode) between 570 and 607 then 'Skin, Subcutaneous Tissue, Breast'
		when to_numeric(ms.msdrgcode) between 614 and 645 then 'Endocrine, Nutritional, Metabolic Diseases & Disorders'
		when to_numeric(ms.msdrgcode) between 650 and 700 then 'Kidney, Urinary Tract'
		when to_numeric(ms.msdrgcode) between 707 and 730 then 'Male Reproductive System'
		when to_numeric(ms.msdrgcode) between 734 and 761 then 'Female Reproductive System'
		when to_numeric(ms.msdrgcode) between 789 and 795 then 'Newborns, Other Neonates with Conditions Originating in Perinatal Period'
		when to_numeric(ms.msdrgcode) between 799 and 804 or to_numeric(ms.msdrgcode) between 808 and 816 then 'Blood, Blood-forming Organs, Immunologic Disorders'
		when to_numeric(ms.msdrgcode) between 820 and 830 or to_numeric(ms.msdrgcode) between 834 and 849 then 'Myeloproliferative Diseases/Disorders, Poorly Differentiated Neoplasms'
		when to_numeric(ms.msdrgcode) between 768 and 788 or to_numeric(ms.msdrgcode) between 796 and 798 or to_numeric(ms.msdrgcode) between 805 and 807 or to_numeric(ms.msdrgcode) between 817 and 819 or to_numeric(ms.msdrgcode) between 831 and 833 then 'Pregnancy, Childbirth, Puerperium'
		when to_numeric(ms.msdrgcode) between 853 and 872 then 'Infectious/Parasitic Disease, Systemic/Unspecified Sites'
		when to_numeric(ms.msdrgcode) between 876 and 887 then 'Mental Diseases & Disorders'
		when to_numeric(ms.msdrgcode) between 894 and 897 then 'Alcohol/Drug Abuse, Alcohol/Drug Induced Organic Mental Disorders'
		when to_numeric(ms.msdrgcode) between 901 and 923 then 'Injuries, Poisonings, Toxic Effects of Drugs'
		when to_numeric(ms.msdrgcode) between 927 and 935 then 'Burns'
		when to_numeric(ms.msdrgcode) between 939 and 951 then 'Factors Influencing Health Status, Other Contacts with Health Services'
		when to_numeric(ms.msdrgcode) between 955 and 965 then 'Multiple Significant Trauma'
		when to_numeric(ms.msdrgcode) between 969 and 977 then 'Human Immunodeficiency Virus Infections'
		when to_numeric(ms.msdrgcode) between 981 and 989 then 'OR Procedure Unrelated to Principal Diagnosis w/ or w/o CCMCC'
		when to_numeric(ms.msdrgcode) = 998 then 'Principal Diagnosis Invalid as Discharge Diagnosis'
		else 'Ungroupable'
	end as MSDRG_groupings       
	, px.Name as icd10px_fulldescription
	, px_detail.SequenceNumberID
        , icd10px_mapping.labelone as Section
	, concat(icd10px_mapping.labeltwo,'-',icd10px_mapping.labelfour) as body_system_part
	, icd10px_mapping.labeltwo as Body_System
	, icd10px_mapping.labelfour as Body_Part    
from **CLIENTDATABASEGUID**.clientdss.FactPatientEncounterSummary e 
	inner join **CLIENTDATABASEGUID**.dss.FactPatientICD10ProceduralDetail px_detail on px_detail.EncounterID = e.encounterid
	inner join **CLIENTDATABASEGUID**.dss.DimICD10PX px on px.icd10pxid = px_detail.icd10pxid
	inner join **CLIENTDATABASEGUID**.dss.DimICD10DX prim_dx on prim_dx.ICD10DXID = e.ICD10DXPrimaryDiagID
	inner join **CLIENTDATABASEGUID**.dss.dimmsdrg ms on ms.msdrgid = e.MSDRGID
	inner join **CLIENTDATABASEGUID**.fw.DimDate dd on dd.DateID = e.DischargeDateID
   	left join datalake_sandbox.data.icd10pcs icd10px_mapping on icd10px_mapping.icd10pcscode = px.icd10pxcode
where 1=1
	and dd.FiscalYear = 2023
order by 
	e.EncounterID
	, px_detail.SequenceNumberID
;

/* Sanity check to ensure that query is built properly */
select * 
from icd10px_msdrg_icd10dx_comparison;

/* Encounter level MSDRG grouping and body system comparison */
select 
	encounterid
	, MSDRG_groupings
	, body_system_part 
from icd10px_msdrg_icd10dx_comparison 
order by 
	encounterid
	, sequencenumberid;

/* Using MSDRG groupings, identify all encounter level information where the MSDRG Grouping is "Principal Diagnosis Invalid as Discharge Diagnosis" */
select * 
from icd10px_msdrg_icd10dx_comparison 
where msdrg_fulldescription ilike '% 98%';

/* Aggregated view to see which ICD10 Procedural Body Systems are most commonly matched with each MSDRG grouping */
select distinct 
	MSDRG_groupings
	, body_system_part
	, count(distinct encounterid) as cases
	, count(*) as icd10px_codes 
from icd10px_msdrg_icd10dx_comparison 
group by 
	msdrg_groupings
	, body_system_part 
order by 
	msdrg_groupings
	, cases desc
	, icd10px_codes desc;
