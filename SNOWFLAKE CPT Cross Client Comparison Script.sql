/* CPT Code Utilization Benchmarking
Different client versions should be committed on separate branches.
*/

/*
Create temp table of all encounter level summary information for all inpatients in Fiscal Year of Interest. 
This table will provide the denominators for the % of use for our billed CPT of interest. 
Also including filters for health systems based on Health System characteristics from above. 
Filters are applied with AND. If client wants to expand comparison cohort to compare, will adjust.
*/
create or replace temp table enc as 
select distinct
    sys_crit.client as client_name
    , sys_crit.clienttype
    , sys_crit.censusregion as client_region
    , sys_crit.operatingexpense as client_OpEx
    , ent_crit.sphentityalias as entity_name
    , ent_crit.censusregion as entity_region
    , ent_crit.isamc as entity_AMC
    , ent_crit.isurban as entity_urban
    , ent_crit.entitytype
    , ent_crit.operatingexpense as entity_OpEx
    , ent_crit.bedsize as entity_bedsize
    , e.orgpin
    , e.strataid
    , e.sphmsdrgcode
    , e.primarycptcode
    , e.dischargedate
    , year(e.dischargedate) as dc_year
    , e.primaryicd10dxcode
    , e.sphagerollup
    , e.encounterid
    , case 
        when sys_crit.client ilike '%_CLIENTNAME_%' then 1 -- Make sure to replace "_CLIENTNAME_" here with client name. 
        else 0 
    end as clientofinterest
    , case
        when ent_crit.sphentityid = ### then '_ENTITYNAME_' -- Make sure to fill in entity ID and Entity Name
        when ent_crit.sphentityid = ### then '_ENTITYNAME_' -- Make sure to fill in entity ID and Entity Name
        when ent_crit.sphentityid = ### then '_ENTITYNAME_' -- Make sure to fill in entity ID and Entity Name
        else 'Other Entities'
    end as entities_of_interest
from datalake_prod.mart.view_encounter_summary e
    inner join datalake_prod.config.system_criteria sys_crit 
        on sys_crit.orgpin = e.orgpin 
        and sys_crit.strataid = e.strataid
    inner join datalake_prod.config.entity_criteria ent_crit 
        on ent_crit.orgpin = e.orgpin
        and ent_crit.strataid = e.strataid
        and ent_crit.sphentityid = e.sphentityid
where 1=1
    and sphsourcesystemcategory = '_CLIENT_SOURCE_SYSTEM_CATEGORY_' -- Fill in client source system category
    and patienttyperollup = '_PATIENTSETTING_' -- Fill in patient setting of interest (e.g., inpatinent, outpatient, etc) 
    and year(e.dischargedate) = ####  -- Fill in Fiscal Year of Interest
    and (
        /* Fill in system level characteristics and entity level characteristics using the queries below. 
        System Level Characteristics - fill in client orgpin.
            select top 10 * from datalake_prod.config.system_criteria 
            where orgpin = _ClientOrgPin_
            ; 
                
        Entity Level Characteristics - ill in client orgpin.
            select * from datalake_prod.config.entity_criteria
            where orgpin = _ClientOrgPin_
            ;
        Use the information from the above 2 queries to fill in the where clauses below.
        Note: System and Entity characteristics are included using OR statements to include ALL other clients with ANY of these characteristics to incorporate a larger comparison cohort. */
        sys_crit.clienttype = '_CLIENTTYPE_'
        or sys_crit.censusregion = '_CLIENT_CENSUS_REGION_'
        or sys_crit.operatingexpense = '_CLIENT_OPEX_'
        or ent_crit.entitytype = '_ENTITYTYPE_'
        or ent_crit.operatingexpense = '_ENTITY_OPEX_'
        or ent_crit.bedsize = '_ENTITY_BED_SIZE_'
    )
group by 
    sys_crit.client
    , sys_crit.clienttype
    , sys_crit.censusregion 
    , sys_crit.operatingexpense 
    , ent_crit.sphentityalias 
    , ent_crit.censusregion 
    , ent_crit.isamc
    , ent_crit.entitytype
    , ent_crit.operatingexpense 
    , ent_crit.bedsize
    , ent_crit.sphentityid
    , ent_crit.isurban
    , e.orgpin
    , e.strataid
    , e.sphmsdrgcode
    , e.dischargedate
    , e.primarycptcode
    , e.primaryicd10dxcode
    , e.sphagerollup
    , e.encounterid
;
    /* Determine the appropriate number of comparison clients */
    select distinct clientofinterest, count(distinct client_name) clients from enc group by clientofinterest;

    /* Confirm end date of analysis */
    select max(dischargedate) from enc where clientofinterest = 1;
    
/*
Create temp table of all billing information for all clients with Billed CPT = #####.
This table will provide the numerators for the % of use for this particular CPT code. 
*/
create or replace temp table billing as
select distinct
    e.encounterid
    , e.client_name
    , e.clienttype
    , e.client_region
    , e.client_opex
    , e.entity_name
    , e.entity_region
    , e.entity_amc
    , e.entitytype
    , e.entity_bedsize
    , e.entity_opex
    , e.entity_urban
    , e.orgpin
    , e.strataid
    , e.sphmsdrgcode
    , e.primarycptcode
    , e.dc_year
    , e.dischargedate
    , e.primaryicd10dxcode
    , e.sphagerollup
    , e.clientofinterest
    , e.entities_of_interest
    , b.servicedateid
    , b.servicedate
    , b.billedcptid
    , b.billedcptcode
    , b.billedcptdescription
    , b.sphchargecodecostdriver
    , concat(e.encounterid,b.servicedateid) enc_date_id        -- needed to create this concat to isolate unique encounter & service date pairings
    , sum(b.totalunitsofservice) as UnitsOfService
    , sum(b.variabledirectcost) as VariableDirectCost
from datalake_prod.mart.VIEW_encounter_billing_summary b
    inner join enc e 
        on e.encounterid = b.encounterid
        and e.orgpin = b.orgpin
        and e.strataid = b.strataid
where 1=1
    and b.billedcptcode = '_CPTCODE_'
group by 
    e.encounterid
    , e.client_name
    , e.clienttype
    , e.client_region
    , e.client_opex
    , e.entity_name
    , e.entity_region
    , e.entity_amc
    , e.entitytype
    , e.entity_bedsize
    , e.entity_opex
    , e.entity_urban
    , e.orgpin
    , e.strataid
    , e.sphmsdrgcode
    , e.primarycptcode
    , e.dc_year
    , e.dischargedate
    , e.primaryicd10dxcode
    , e.sphagerollup
    , e.clientofinterest
    , e.entities_of_interest
    , b.servicedateid
    , b.servicedate
    , b.billedcptid
    , b.billedcptcode
    , b.billedcptdescription
    , b.sphchargecodecostdriver
;
  
    /* Determine the number of clients in cohort with CPT of interest */
    select distinct clientofinterest, count(distinct client_name) clients from billing group by clientofinterest;
    /* Confirm CPT code of interest is selected */
    select distinct billedcptcode, billedcptdescription from billing;
    /* Confirm end date of time frame of included patient encounters. */
    select max(dischargedate) from billing where clientofinterest = 1;
    
    /* CPT Utilization: Client of Interest vs ALL other Health Systems with same client type */
    select distinct 
        clientofinterest
        , clienttype
        , count(distinct encounterid) cases
        , sum(UnitsOfService) UOS
        , count(distinct enc_date_id) as patient_days 
        , round(sum(UnitsOfService) / cast(count(distinct encounterid) as decimal(10,2)),1) as UOS_per_case
        , round(sum(UnitsOfService) / cast(count(distinct enc_date_id) as decimal(10,2)),1) as UOS_per_patientday
    from billing where clienttype = '_CLIENTTYPE_' group by clientofinterest, clienttype;

    /* CPT Utilization: Client of Interest vs ALL other Health Systems with same census region */
    select distinct 
        clientofinterest
            , client_region
            , count(distinct encounterid) cases
            , sum(UnitsOfService) UOS
            , count(distinct enc_date_id) as patient_days
            , round(sum(UnitsOfService) / cast(count(distinct encounterid) as decimal(10,2)),1) as UOS_per_case
            , round(sum(UnitsOfService) / cast(count(distinct enc_date_id) as decimal(10,2)),1) as UOS_per_patientday
    from billing where client_region = '_CLIENT_CENSUS_REGION_' group by clientofinterest, client_region;

    /* CPT Utilization: Client of Interest vs ALL other Health Systems with same operating expense */
    select distinct 
        clientofinterest
        , client_OpEx
        , count(distinct encounterid) cases
        , sum(UnitsOfService) UOS
        , count(distinct enc_date_id) as patient_days
        , round(sum(UnitsOfService) / cast(count(distinct encounterid) as decimal(10,2)),1) as UOS_per_case
        , round(sum(UnitsOfService) / cast(count(distinct enc_date_id) as decimal(10,2)),1) as UOS_per_patientday
    from billing where client_OpEx = '_CLIENT_OPEX_' group by clientofinterest, client_OpEx;

    /* CPT Utilization: Client Entities (Hospitals) of Interest vs ALL other Health Systems with same Entity Types */
    select distinct 
        entities_of_interest
        , entitytype
        , count(distinct encounterid) cases
        , sum(UnitsOfService) UOS
        , count(distinct enc_date_id) as patient_days
        , round(sum(UnitsOfService) / cast(count(distinct encounterid) as decimal(10,2)),1) as UOS_per_case
        , round(sum(UnitsOfService) / cast(count(distinct enc_date_id) as decimal(10,2)),1) as UOS_per_patientday
    from home_glucose_billing where entitytype = '_ENTITYTYPE_' group by entities_of_interest, entitytype;

    /* CPT Utilization: Client Entities (Hospitals) of Interest vs ALL other Health Systems with same Operating Expense */
    select distinct 
        entities_of_interest
        , entity_OpEx
        , count(distinct encounterid) as cases
        , sum(UnitsOfService) UOS
        , count(distinct enc_date_id) as patient_days
        , round(sum(UnitsOfService) / cast(count(distinct encounterid) as decimal(10,2)),1) as UOS_per_case
        , round(sum(UnitsOfService) / cast(count(distinct enc_date_id) as decimal(10,2)),1) as UOS_per_patientday
    from billing where entity_OpEx in ('_ENTITY_OPEX_','_ENTITY_OPEX_') group by entities_of_interest, entity_OpEx order by entity_opex;

    /* CPT Utilization: Client Entities (Hospitals) of Interest vs ALL other Health Systems with same Entity Bed Sizes */
    select distinct 
        entities_of_interest
        , entity_bedsize
        , count(distinct encounterid) as cases
        , sum(UnitsOfService) UOS
        , count(distinct enc_date_id) as patient_days
        , round(sum(UnitsOfService) / cast(count(distinct encounterid) as decimal(10,2)),1) as UOS_per_case
        , round(sum(UnitsOfService) / cast(count(distinct enc_date_id) as decimal(10,2)),1) as UOS_per_patientday
    from billing where entity_bedsize in ('_ENTITY_BED_SIZES_','_ENTITY_BED_SIZES_') group by entities_of_interest, entity_bedsize order by entity_bedsize;

    /* CPT Utilization: Client Entities (Hospitals) of Interest vs ALL other Health Systems with same Entity Urban Status */
    select distinct 
        entities_of_interest
        , entity_urban
        , count(distinct encounterid) as cases
        , sum(UnitsOfService) UOS
        , count(distinct enc_date_id) as patient_days
        , round(sum(UnitsOfService) / cast(count(distinct encounterid) as decimal(10,2)),1) as UOS_per_case
        , round(sum(UnitsOfService) / cast(count(distinct enc_date_id) as decimal(10,2)),1) as UOS_per_patientday
    from billing group by entities_of_interest, entity_urban order by entity_urban;

    /* Determine TOTAL case volume to compare client of interest as a system vs cohort */
    select distinct clientofinterest, clienttype, count(distinct encounterid) cases from enc where clienttype = '_CLIENTTYPE_' group by clientofinterest, clienttype;
    select distinct clientofinterest, client_region, count(distinct encounterid) cases from enc where client_region = '_CLIENT_CENSUS_REGION_' group by clientofinterest, client_region;
    select distinct clientofinterest, client_OpEx, count(distinct encounterid) cases from enc where client_OpEx = '_CLIENT_OPEX_' group by clientofinterest, client_OpEx;

    /* Determine TOTAL case volume to compare entities of interest vs cohort entities */
    select distinct entities_of_interest, entitytype, count(distinct encounterid) from enc where entitytype = '_ENTITY_TYPE_' group by entities_of_interest, entitytype;
    select distinct entities_of_interest, entity_OpEx, count(distinct encounterid) from enc where entity_OpEx in ('_ENTITY_OPEX_','_ENTITY_OPEX_') group by entities_of_interest, entity_OpEx order by entity_opex;
    select distinct entities_of_interest, entity_bedsize, count(distinct encounterid) from enc where entity_bedsize in ('_ENTITY_BEDSIZE_','_ENTITY_BEDSIZE_') group by entities_of_interest, entity_bedsize order by entity_bedsize;
    select distinct entities_of_interest, entity_urban, count(distinct encounterid) from enc group by entities_of_interest, entity_urban order by entity_urban;
    
    
    
    
    /* Determine top 5 Client of Interest (COI) MSDRG Codes by Selected CPT case volume to compare with cohort */
    select top 5 
        sphmsdrgcode as top5_COI
        , orgpin
        , count(distinct encounterid) cases 
        , sum(UnitsOfService) UOS
        , count(distinct enc_date_id) as patient_days
        , round(sum(UnitsOfService) / cast(count(distinct encounterid) as decimal(10,2)),1) as UOS_per_case
        , round(sum(UnitsOfService) / cast(count(distinct enc_date_id) as decimal(10,2)),1) as UOS_per_patientday
    from billing 
    where clientofinterest = 1 
    group by sphmsdrgcode, orgpin 
    order by cases desc;
        /* The Top 5 MSDRG codes from this output will be used in the next 3 queries to compare case volume for the same MSDRG codes. */

    select top 5 
        sphmsdrgcode as top5_COI_comp
        , count(distinct encounterid) cases 
        , sum(UnitsOfService) UOS
        , count(distinct enc_date_id) as patient_days
        , round(sum(UnitsOfService) / cast(count(distinct encounterid) as decimal(10,2)),1) as UOS_per_case
        , round(sum(UnitsOfService) / cast(count(distinct enc_date_id) as decimal(10,2)),1) as UOS_per_patientday
    from billing 
    where clientofinterest = 0 and sphmsdrgcode in ('_DRG_', '_DRG_', '_DRG_', '_DRG_', '_DRG_') -- Replace _DRG_ in the following queries with the top MSDRG codes from the query above. 
    group by sphmsdrgcode 
    order by cases desc;

    /* Determine top 5 Client of Interest (COI) MSDRG Codes by TOTAL case volume to compare with cohort */
    select top 5 
        sphmsdrgcode as top5_COI_comp
        , count(distinct encounterid) cases 
    from enc 
    where clientofinterest = 0 and sphmsdrgcode in ('_DRG_', '_DRG_', '_DRG_', '_DRG_', '_DRG_') -- Replace _DRG_ in the following queries with the top MSDRG codes from the query above. 
    group by sphmsdrgcode 
    order by cases desc;

    select top 5 
        sphmsdrgcode as top5_COI
        , orgpin
        , count(distinct encounterid) cases 
    from enc 
    where clientofinterest = 1 and sphmsdrgcode in ('_DRG_', '_DRG_', '_DRG_', '_DRG_', '_DRG_') -- Replace _DRG_ in the following queries with the top MSDRG codes from the query above. 
    group by sphmsdrgcode, orgpin 
    order by cases desc;



    /* Determine top 5 Comparison Cohort MSDRG Codes by Selected CPT case volume to compare with Client of Interest (COI) */
    select top 5
        sphmsdrgcode as top5_comp
        , count(distinct encounterid) cases 
        , sum(UnitsOfService) UOS
        , count(distinct enc_date_id) as patient_days
        , round(sum(UnitsOfService) / cast(count(distinct encounterid) as decimal(10,2)),1) as UOS_per_case
        , round(sum(UnitsOfService) / cast(count(distinct enc_date_id) as decimal(10,2)),1) as UOS_per_patientday
    from billing 
    where clientofinterest = 0 and sphmsdrgcode <> '000'
    group by sphmsdrgcode 
    order by cases desc;
        /* The Top 5 MSDRG codes from this output will be used in the next 3 queries to compare case volume for the same MSDRG codes. */

    select top 5 
        sphmsdrgcode as top5_comp_COI
        , orgpin, count(distinct encounterid) cases 
        , sum(UnitsOfService) UOS
        , count(distinct enc_date_id) as patient_days
        , round(sum(UnitsOfService) / cast(count(distinct encounterid) as decimal(10,2)),1) as UOS_per_case
        , round(sum(UnitsOfService) / cast(count(distinct enc_date_id) as decimal(10,2)),1) as UOS_per_patientday
    from home_glucose_billing 
    where clientofinterest = 1 and sphmsdrgcode in ('_DRG_', '_DRG_', '_DRG_', '_DRG_', '_DRG_') -- Replace _DRG_ in the following queries with the top MSDRG codes from the query above. 
    group by sphmsdrgcode, orgpin 
    order by cases desc;

    /* Determine top 5 Cohort MSDRG Codes by TOTAL case volume to compare with Client of Interest */
    select top 5 
        sphmsdrgcode as top5_comp
        , count(distinct encounterid) cases 
    from enc 
    where clientofinterest = 0 and sphmsdrgcode in ('_DRG_', '_DRG_', '_DRG_', '_DRG_', '_DRG_') -- Replace _DRG_ in the following queries with the top MSDRG codes from the query above. 
    group by sphmsdrgcode 
    order by cases desc;

    select top 5 
        sphmsdrgcode as top5_comp_COI
        , orgpin
        , count(distinct encounterid) cases 
    from enc 
    where clientofinterest = 1 and sphmsdrgcode in ('_DRG_', '_DRG_', '_DRG_', '_DRG_', '_DRG_') -- Replace _DRG_ in the following queries with the top MSDRG codes from the query above. 
    group by sphmsdrgcode, orgpin 
    order by cases desc;
    
