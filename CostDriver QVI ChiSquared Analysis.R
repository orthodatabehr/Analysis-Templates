#pull in Client Data file from SQL output
library(readxl)
raw_data <- read_excel("Library/CloudStorage/OneDrive-StrataDecisionTechnology/StrataJazz Info/Example Client File.xlsx")
View(Example_Client_File)

# Install relevant packages for data cleaning and transformations
install.packages("dplyr")
library(dplyr)
install.packages("tibble")
library(tibble)
install.packages("stringr")
library(stringr)
install.packages("tidyverse")
library(tidyverse)

# Remove columns
drops <- c('Entity','Patient Population','AttendPhysicianName')
new_data <- raw_data[ , !(names(raw_data) %in% drops)]

# Convert Cost values to numeric and eliminate entries with $0 of cost.
new_data$VDC <- replace(new_data$VDC, new_data$VDC == 'NULL', 0)
new_data$VDC <- as.numeric(new_data$VDC)
new_data$EncounterID %>%  as.character(new_data$EncounterID)
new_data <- new_data[new_data$VDC > 0,]

# Create separate tibbles for Ventilator-Associated Pneumonia Patients and Patients without this complication.
PNA_data <- new_data[new_data$QVI != 'Control',]
Control_data <- new_data[new_data$QVI == 'Control',]

PNASummary <-
  PNA_data %>% 
  group_by(CostDriver, DateOfService) %>% 
  summarize(pna_cases = n_distinct(EncounterID))
head(PNASummary)

ControlSummary <-
  Control_data %>% 
  group_by(CostDriver, DateOfService) %>% 
  summarize(control_cases = n_distinct(EncounterID))
head(ControlSummary)

# Combine above 2 tibbles into single dataframe for Chi-Squared Test of Independence 
CombinedSummary <- 
  PNASummary %>% 
  inner_join(ControlSummary, by = c('CostDriver', 'DateOfService'))
CombinedSummary$CostDriver_DOS <- str_c(CombinedSummary$CostDriver, ' ', CombinedSummary$DateOfService)
CombinedSummary <- CombinedSummary %>% relocate(CostDriver_DOS) %>% 
CombinedSummary <- CombinedSummary[, c("CostDriver_DOS","pna_cases","control_cases")]

CombinedSummary <- data.frame(CombinedSummary,row.names = 1)
head(CombinedSummary)


# Perform individual Chi-Squared Test of Independence on each Cost Driver broken out by Date of Service 
install.packages("corrplot")
library(corrplot)

anes_rows <- c('Anesthesia and Recovery After Vent','Anesthesia and Recovery Before Vent','Anesthesia and Recovery Day of Vent')
anesthesia <- CombinedSummary[rownames(CombinedSummary) %in% anes_rows,]
anes_chisq <- chisq.test(anesthesia)
anes_chisq$p.value
# p-value = 0.325
corrplot(anes_chisq$residual, is.corr = FALSE)

blood_rows <- c('Blood After Vent','Blood Before Vent','Blood Day of Vent')
blood <- CombinedSummary[rownames(CombinedSummary) %in% blood_rows,]
blood_chisq <- chisq.test(blood)
blood_chisq$p.value
# p-value = 0.643
corrplot(blood_chisq$residual, is.corr = FALSE)

card_rows <- c('Cardiovascular After Vent','Cardiovascular Before Vent','Cardiovascular Day of Vent')
card <- CombinedSummary[rownames(CombinedSummary) %in% card_rows,]
card_chisq <- chisq.test(card)
card_chisq$p.value
# p-value = 0.010
corrplot(card_chisq$residual, is.corr = FALSE)

clinic_rows <- c('Clinic After Vent','Clinic Before Vent','Clinic Day of Vent')
clinic <- CombinedSummary[rownames(CombinedSummary) %in% clinic_rows,]
clinic_chisq <- chisq.test(clinic)
clinic_chisq$p.value
# p-value = 0.300
corrplot(clinic_chisq$residual, is.corr = FALSE)

dial_rows <- c('Dialysis After Vent','Dialysis Before Vent','Dialysis Day of Vent')
dialysis <- CombinedSummary[rownames(CombinedSummary) %in% dial_rows,]
dial_chisq <- chisq.test(dialysis)
dial_chisq$p.value
# p-value = 0.598
corrplot(dial_chisq$residual, is.corr = FALSE)

ER_rows <- c('Emergency Room After Vent','Emergency Room Before Vent','Emergency Room Day of Vent')
ER <- CombinedSummary[rownames(CombinedSummary) %in% ER_rows,]
ER_chisq <- chisq.test(ER)
ER_chisq$p.value
# p-value = 1.111143e-08
corrplot(ER_chisq$residual, is.corr = FALSE)

endo_rows <- c('Endoscopy After Vent','Endoscopy Before Vent','Endoscopy Day of Vent')
endo <- CombinedSummary[rownames(CombinedSummary) %in% endo_rows,]
endo_chisq <- chisq.test(endo)
endo_chisq$p.value
# p-value = 0.841
corrplot(endo_chisq$residual, is.corr = FALSE)

img_rows <- c('Imaging After Vent','Imaging Before Vent','Imaging Day of Vent')
img <- CombinedSummary[rownames(CombinedSummary) %in% img_rows,]
img_chisq <- chisq.test(img)
img_chisq$p.value
# p-value = 0.009
corrplot(img_chisq$residual, is.corr = FALSE)

LOS_rows <- c('LOS After Vent','LOS Before Vent','LOS Day of Vent')
LOS <- CombinedSummary[rownames(CombinedSummary) %in% LOS_rows,]
LOS_chisq <- chisq.test(LOS)
LOS_chisq$p.value
# p-value = 0.005
corrplot(LOS_chisq$residual, is.corr = FALSE)

lab_rows <- c('Laboratory After Vent','Laboratory Before Vent','Laboratory Day of Vent')
lab <- CombinedSummary[rownames(CombinedSummary) %in% lab_rows,]
lab_chisq <- chisq.test(lab)
lab_chisq$p.value
# p-value = 0.006
corrplot(lab_chisq$residual, is.corr = FALSE)

OR_rows <- c('OR Time After Vent','OR Time Before Vent','OR Time Day of Vent')
OR <- CombinedSummary[rownames(CombinedSummary) %in% OR_rows,]
OR_chisq <- chisq.test(OR)
OR_chisq$p.value
# p-value = 0.611
corrplot(OR_chisq$residual, is.corr = FALSE)

othDX_rows <- c('Other Diagnostic Services After Vent','Other Diagnostic Services Before Vent','Other Diagnostic Services Day of Vent')
othDX <- CombinedSummary[rownames(CombinedSummary) %in% othDX_rows,]
othDX_chisq <- chisq.test(othDX)
othDX_chisq$p.value
# p-value = 0.287
corrplot(othDX_chisq$residual, is.corr = FALSE)

pharm_rows <- c('Pharmacy After Vent','Pharmacy Before Vent','Pharmacy Day of Vent')
pharm <- CombinedSummary[rownames(CombinedSummary) %in% pharm_rows,]
pharm_chisq <- chisq.test(pharm)
pharm_chisq$p.value
# p-value = 0.007
corrplot(pharm_chisq$residual, is.corr = FALSE)

resp_rows <- c('Respiratory Services After Vent','Respiratory Services Before Vent','Respiratory Services Day of Vent')
resp <- CombinedSummary[rownames(CombinedSummary) %in% resp_rows,]
resp_chisq <- chisq.test(resp)
resp_chisq$p.value
# p-value = 0.010
corrplot(resp_chisq$residual, is.corr = FALSE)

supplies_rows <- c('Supplies After Vent','Supplies Before Vent','Supplies Day of Vent')
supplies <- CombinedSummary[rownames(CombinedSummary) %in% supplies_rows,]
supplies_chisq <- chisq.test(supplies)
supplies_chisq$p.value
# p-value = 0.024
corrplot(supplies_chisq$residual, is.corr = FALSE)

therapy_rows <- c('Therapeutic Services After Vent','Therapeutic Services Before Vent','Therapeutic Services Day of Vent')
therapy <- CombinedSummary[rownames(CombinedSummary) %in% therapy_rows,]
therapy_chisq <- chisq.test(therapy)
therapy_chisq$p.value
# p-value = 0.244
corrplot(therapy_chisq$residual, is.corr = FALSE)