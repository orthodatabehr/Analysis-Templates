'''
This is a data cleaning template for UNOS data specific to primary liver transplantation.
'''

import pandas as pd
import numpy as np

'''
Import UNOS CSV data of choice. 
Please review stratifications for continuous variables and determine optimal ranges with the surgeon you are working with.
'''

df = pd.read_csv('******')

# Total Rows and Columns of Data
print(df.shape)
# Preview Data
print(df.head())

'''
This function will determine how well populated a specific column is.
Based on Dr R suggestions, 90% is threshold.
'''


def column_populated(col_name):
    null_entries = df[col_name].isna().sum() + df[col_name].isna().sum()
    total_entries = df.shape[0]
    print(f"Percent populated in {col_name} column: {(total_entries - null_entries) / total_entries * 100}%")


'''Data cleaning
Please modify this area as you see fit. 
This current set up is created to focus on adult primary liver transplant cases.
'''
df = df.loc[
    # Including only Adult Patients
    (df['age'] >= 18)
    # Including only transplants from 2002 onwards
    & (df['tx_year'] >= 2002)
    # Excluding patients who received a heart transplant
    & (df['tx_hrt'] == '')
    # Excluding patients who received a kidney transplant
    & (df['tx_kid'] == '')
    # Excluding patients who received a lung transplant
    & (df['tx_lng'] == '')
    # Excluding patients who received an intestinal transplant
    & (df['tx_int'] == '')
    # Excluding patients who received a pancreas transplant
    & (df['tx_pan'] == '')
    # Excluding patients who had to be re-transplanted
    & (df['tx_retxdate'] == '')
    # Excluding patients with previous transplantations
    & (df['prev_tx'] != 'Y')
    # Excluding entries without transplant dates
    & (df['tx_date'] != '')
    # Exclude donors less than 10 years of age
    & (df['age_don'] >= 10)
]

# Create Donor Age stratification to convert age into discrete variables.
# Classifications defined based on physician direction.
column_populated('age_don')
donor_age = []
for row in df['age_don']:
    if row > 15:
        donor_age.append('dAgeSub15')
    elif row < 20:
        donor_age.append('dAge15_19')
    elif row < 25:
        donor_age.append('dAge20_24')
    elif row < 31:
        donor_age.append('dAge25_30')
    elif row < 45:
        donor_age.append('dAge30_44ref')
    elif row < 55:
        donor_age.append('dAge45_54')
    elif row < 60:
        donor_age.append('dAge55_59')
    elif row < 65:
        donor_age.append('dAge60_64')
    elif row < 70:
        donor_age.append('dAge65_69')
    elif row < 76:
        donor_age.append('dAge70_75')
    elif row > 75:
        donor_age.append('dAge75plus')

df['donor_age_categories'] = donor_age

df['dAgeSub15'] = np.where(df['donor_age_categories'].str.contains('sub15'), 1, 0)
df['dAge15_19'] = np.where(df['donor_age_categories'].str.contains('19'), 1, 0)
df['dAge20_24'] = np.where(df['donor_age_categories'].str.contains('24'), 1, 0)
df['dAge25_30'] = np.where(df['donor_age_categories'].str.contains('30'), 1, 0)
df['dAge30_44ref'] = np.where(df['donor_age_categories'].str.contains('44'), 1, 0)
df['dAge45_54'] = np.where(df['donor_age_categories'].str.contains('54'), 1, 0)
df['dAge55_59'] = np.where(df['donor_age_categories'].str.contains('59'), 1, 0)
df['dAge60_64'] = np.where(df['donor_age_categories'].str.contains('64'), 1, 0)
df['dAge65_69'] = np.where(df['donor_age_categories'].str.contains('69'), 1, 0)
df['dAge70_75'] = np.where(df['donor_age_categories'].str.contains('70_75'), 1, 0)
df['dAge75plus'] = np.where(df['donor_age_categories'].str.contains('75plus'), 1, 0)


# Create Donor BMI stratification to convert BMI into discrete variables.
# Classifications defined based on physician direction.
column_populated('bmi_don')
bmi_donor = []
for row in df['bmi_don']:
    if row <= 20:
        bmi_donor.append('dBMIsub20')
    elif row < 30:
        bmi_donor.append('dBMI20_29ref')
    elif row < 35:
        bmi_donor.append('dBMI30_34')
    elif row > 35:
        bmi_donor.append('dBMI35plus')

df['donor_bmi_categories'] = bmi_donor

df['dBMIsub20'] = np.where(df['donor_bmi_categories'].str.contains('sub20'), 1, 0)
df['dBMI20_29ref'] = np.where(df['donor_bmi_categories'].str.contains('29'), 1, 0)
df['dBMI30_34'] = np.where(df['donor_bmi_categories'].str.contains('34'), 1, 0)
df['dBMI35plus'] = np.where(df['donor_bmi_categories'].str.contains('35'), 1, 0)

# Create HIV status.
column_populated('cdc_risk_hiv_don')
df['dHIV'] = np.where(df['cdc_risk_hiv_don'] == 'Y', 1, 0)

# Create Cause of Death stratification.
column_populated('cod_cad_don')
df['dCOD_CVA'] = np.where(df['cod_cad_don'] == 2, 1, 0)
df['dCOD_trauma'] = np.where(df['cod_cad_don'] == 3, 1, 0)
df['dCOD_anoxia'] = np.where(df['cod_cad_don'] == 1, 1, 0)

# Create Donor Creatinine stratification to convert Creatinine into discrete variables.
# Classifications defined based on physician direction.
column_populated('creat_don')
creatinine_donor = []
for row in df['creat_don']:
    if row < 1.5:
        creatinine_donor.append('dCreatSub15')
    elif row < 2:
        creatinine_donor.append('dCreat15_19')
    elif row < 5:
        creatinine_donor.append('dCreat20_49')
    elif row >= 5:
        creatinine_donor.append('dCreat50plus')

df['donor_creatinine_categories'] = creatinine_donor

df['dCreatSub15'] = np.where(df['donor_creatinine_categories'].str.contains('Sub15'), 1, 0)
df['dCreat15_19'] = np.where(df['donor_creatinine_categories'].str.contains('19'), 1, 0)
df['dCreat20_49'] = np.where(df['donor_creatinine_categories'].str.contains('49'), 1, 0)
df['dCreat50plus'] = np.where(df['donor_creatinine_categories'].str.contains('50'), 1, 0)

# Create African American status.
column_populated('ethcat_don')
df['African_American_don'] = np.where(df['ethcat_don'] == 2, 1, 0)

# Create gender status.
column_populated('gender_don')
df['Female_Donor'] = np.where(df['gender_don'] == 'F', 1, 0)

# Create HBV Core Ab status.
column_populated('hbv_core_don')
df['Donor_HBV_Core_Antibody'] = np.where(df['hbv_core_don'] == 'P', 1, 0)

# Create HCV Ab status.
column_populated('hep_c_anti_don')
df['Donor_HCV_Antibody'] = np.where(df['hep_c_anti_don'] == 'P', 1, 0)

# Create Donor height stratification to convert height into discrete variables.
# Classifications defined based on physician direction.
column_populated('hgt_cm_don_calc')
height_donor = []
for row in df['hgt_cm_don_calc']:
    if row < 160:
        height_donor.append('dHeightSub160cm')
    elif row < 183:
        height_donor.append('dHeight160_182cmRef')
    elif row > 182:
        height_donor.append('dHeight182cmPlus')

df['donor_height_categories'] = height_donor

df['dHeightSub160cm'] = np.where(df['donor_height_categories'].str.contains('Sub160'), 1, 0)
df['dHeight160_182cmRef'] = np.where(df['donor_height_categories'].str.contains('160_182'), 1, 0)
df['dHeight182cmPlus'] = np.where(df['donor_height_categories'].str.contains('182cmPlus'), 1, 0)

# Create donor comorbidity status.
column_populated('hist_diabetes_don')
column_populated('hist_hypertens_don')
df['hx_DM2'] = np.where(df['hist_diabetes_don'] != 1, 1, 0)
df['hx_HTN'] = np.where(df['hist_hypertens_don'] == 'Y', 1, 0)

# Create Donor AST & ALT stratification to convert AST/ALT into discrete variables.
# Classifications defined based on physician direction.
column_populated('sgot_don')
column_populated('sgpt_don')
AST_donor = []
ALT_donor = []
for row in df['sgot_don']:
    if row < 50:
        AST_donor.append('dASTSub50Ref')
    elif row < 100:
        AST_donor.append('dAST50_99')
    elif row < 200:
        AST_donor.append('dAST100_199')
    elif row < 500:
        AST_donor.append('dAST200_499')
    elif row >= 500:
        AST_donor.append('dAST500Plus')

df['donor_AST_categories'] = AST_donor

for row in df['sgpt_don']:
    if row < 50:
        ALT_donor.append('dALTSub50Ref')
    elif row < 100:
        ALT_donor.append('dALT50_99')
    elif row < 200:
        ALT_donor.append('dALT100_199')
    elif row < 500:
        ALT_donor.append('dALT200_499')
    elif row >= 500:
        ALT_donor.append('dALT500Plus')

df['donor_ALT_categories'] = ALT_donor

df['dASTSub50Ref'] = np.where(df['donor_AST_categories'].str.contains('50Ref'), 1, 0)
df['dAST50_99'] = np.where(df['donor_AST_categories'].str.contains('99'), 1, 0)
df['dAST100_199'] = np.where(df['donor_AST_categories'].str.contains('199'), 1, 0)
df['dAST200_499'] = np.where(df['donor_AST_categories'].str.contains('499'), 1, 0)
df['dAST500Plus'] = np.where(df['donor_AST_categories'].str.contains('500'), 1, 0)

df['dALTSub50Ref'] = np.where(df['donor_ALT_categories'].str.contains('50Ref'), 1, 0)
df['dALT50_99'] = np.where(df['donor_ALT_categories'].str.contains('99'), 1, 0)
df['dALT100_199'] = np.where(df['donor_ALT_categories'].str.contains('199'), 1, 0)
df['dALT200_499'] = np.where(df['donor_ALT_categories'].str.contains('499'), 1, 0)
df['dALT500Plus'] = np.where(df['donor_ALT_categories'].str.contains('500'), 1, 0)


# Create Donor Bilirubin stratification to convert serum bilirubin into discrete variables.
# Classifications defined based on physician direction.
column_populated('tbili_don')
donor_bilirubin = []
for row in df['tbili_don']:
    if row < 1:
        donor_bilirubin.append('dBiliSub10Ref')
    elif row < 2:
        donor_bilirubin.append('dBili10_19')
    elif row < 3:
        donor_bilirubin.append('dBili20_29')
    elif row < 4:
        donor_bilirubin.append('dBili30_39')
    elif row < 5:
        donor_bilirubin.append('dBili40_49')
    elif row < 10:
        donor_bilirubin.append('dBili50_99')
    elif row >= 10:
        donor_bilirubin.append('dBili100Plus')

df['donor_bilirubin_categories'] = donor_bilirubin

df['dBiliSub10Ref'] = np.where(df['donor_bilirubin_categories'].str.contains('10Ref'), 1, 0)
df['dBili10_19'] = np.where(df['donor_bilirubin_categories'].str.contains('19'), 1, 0)
df['dBili20_29'] = np.where(df['donor_bilirubin_categories'].str.contains('29'), 1, 0)
df['dBili30_39'] = np.where(df['donor_bilirubin_categories'].str.contains('39'), 1, 0)
df['dBili40_49'] = np.where(df['donor_bilirubin_categories'].str.contains('49'), 1, 0)
df['dBili50_99'] = np.where(df['donor_bilirubin_categories'].str.contains('99'), 1, 0)
df['dBili100Plus'] = np.where(df['donor_bilirubin_categories'].str.contains('100'), 1, 0)

# Create donor Controlled Cardiac Death status.
column_populated('controlled_don')
df['don_CCD'] = np.where(df['controlled_don'] == 'Y', 1, 0)

# Create donor Liver Type (Partial/Split) status.
column_populated('lityp')
df['Split_Liver_Transplant'] = np.where(df['lityp'] < 20, 1, 0)

# Donor allograft share type (national, foreign, regional)
column_populated('share_ty')
df['Regional_Share'] = np.where(df['share_ty'] == 4, 1, 0)
df['National_Share'] = np.where(df['share_ty'] == 5, 1, 0)
df['Foreign_Share'] = np.where(df['share_ty'] == 6, 1, 0)

'''
Output cleaned dataframe with only columns of interest & outcome variable column
Reference Group columns are omitted.
Output table should only include columns that we created with 0/1 as statuses.
Output table will export as CSV to import into STATA for logistical regression.
'''

output = df[[
    'dAgeSub15',
    'dAge15_19',
    'dAge20_24',
    'dAge25_30',
    'dAge45_54',
    'dAge55_59',
    'dAge60_64',
    'dAge65_69',
    'dAge70_75',
    'dAge75plus',
    'dBMIsub20',
    'dBMI30_34',
    'dBMI35plus',
    'HIV',
    'dCOD_CVA',
    'dCOD_anoxia',
    'dCOD_trauma',
    'don_CCD',
    'dCreat15_19',
    'dCreat20_49',
    'dCreat50plus',
    'African_American_don',
    'Female_Donor',
    'Donor_HBV_Core_Antibody',
    'Donor_HCV_Antibody',
    'dHeightSub160cm',
    'dHeight182cmPlus',
    'hx_DM2',
    'hx_HTN',
    'dAST50_99',
    'dAST100_199',
    'dAST200_499',
    'dAST500Plus',
    'dALT50_99',
    'dALT100_199',
    'dALT200_499',
    'dALT500Plus',
    'dBili10_19',
    'dBili20_29',
    'dBili30_39',
    'dBili40_49',
    'dBili50_99',
    'dBili100Plus',
    'Split_Liver_Transplant',
    'Regional_Share',
    'National_Share',
    'Foreign_Share',
    # Graft Status is the dependent variable that we are examining.
    'gstatus'
]]

output.to_csv(index=False)





