## Analysis-Templates

OPPORTUNITY SCREENING TEMPLATE (SQL) = This script helps identify the use of a specific charge code within a client database to calculate margin-improvement opportunity. This script can be scaled based on the number of opportunities that the user is interested in examining. 

CPT CODE OPPORTUNITY ANALYSIS (SQL) = This script is an in-depth exploration of potential redundant usage of a particular CPT code within a client database. This is commonly performed for imaging and laboratory tests to determine if too many tests are performed within a same day or during a single patient stay. 

ENTITY CHARGE CODE COMPARISON SCRIPT (SQL) = This script is a large scale comparison of charge code utilization between entities within a client database. This analysis will identify cross-entity utilization variation savings opportunities. 

LIVER TRANSPLANT DATA CLEANING FILE (PYTHON) = This file allows for standardized cleaning of UNOS data specific for liver transplantation analyses. 

QUALITY ASSOCIATION SCRIPT (SQL) = This script pulls charge code utilization for patients with a specific quality event during their stay as well as a comparable control group for Chi-Squared analysis in R. 

QUALITY COST DRIVER CHI SQUARED ANALYSIS (SQL) = This file performs a Chi Squared Test of Independence between patient intervention categories, quality event status, and time of intervention. The file currently is using data related to Ventilator-   Associated Pneumonia as the quality event of interest. 

SNOWFLAKE CPT CROSS CLIENT COMPARISON SCRIPT (SNOWFLAKE SQL) = This Snowflake script pulls utilization across different client databases for a specific CPT code interest. This analysis will benchmark utilization rates of specific CPT codes. 

SNOWFLAKE ICD 10 PROCEDURAL CODE TO MSDRG GROUP MAPPING (SNOWFLAKE SQL) = This Snowflake script compares MSDRG Grouping (defined by the AAPC) with ICD10 Procedural Code Body Systems to determine the distribution of unrelated ICD10 Procedural Codes across client databases.




