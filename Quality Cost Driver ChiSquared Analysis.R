# This file combines with the Quality Association Script to perform chi-squared analysis on the output and determine if a specific cost driver is significantly associated with the quality event of interest. This specific example looks at the quality event of 'Ventilator-Associated Pneumonia'. 

#pull in Client Data file from SQL output
library(readxl)
raw_data <- read_excel("ClientDataFile.xlsx")
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
install.packages("ggstatsplot")
library(ggstatsplot)

# Remove columns for client de-identification
drops <- c('Entity','Patient Population','AttendPhysicianName')
new_data <- raw_data[ , !(names(raw_data) %in% drops)]

# Convert Cost values to numeric and eliminate entries with $0 of cost.
new_data$VDC <- replace(new_data$VDC, new_data$VDC == 'NULL', 0)
new_data$VDC <- as.numeric(new_data$VDC)
new_data$EncounterID %>%  as.character(new_data$EncounterID)
new_data <- new_data[new_data$VDC > 0,]

# Chi Squared Test Plot demonstrating association between quality event occurrence and cost drivers. 
ggbarstats(
  data = new_data,
  x = QVI,
  y = CostDriver
) +
  labs(caption = NULL) # remove caption

# From this graph, the Cost Drivers that are significantly associated (p < 0.05) with the quality event are:
# Blood, Cardiovascular, Clinic, Dialysis, Emergency Room, Laboratory, Other Diagnostic Services, Pharmacy, Respiratory Services, Supplies, Therapeutic Services 
# We want to create contingency tables based on the above cost drivers now using Date of Service and quality event status. 

Blood_Data <- new_data[new_data$CostDriver == 'Blood',]
Card_Data <- new_data[new_data$CostDriver == 'Cardiovascular',]
Clinic_Data <- new_data[new_data$CostDriver == 'Clinic',]
Dialysis_Data <- new_data[new_data$CostDriver == 'Dialysis',]
ER_Data <- new_data[new_data$CostDriver == 'Emergency Room',]
Lab_Data <- new_data[new_data$CostDriver == 'Laboratory',]
OthDx_Data <- new_data[new_data$CostDriver == 'Other Diagnostic Services',]
Pharm_Data <- new_data[new_data$CostDriver == 'Pharmacy',]
Resp_Data <- new_data[new_data$CostDriver == 'Respiratory Services',]
Supply_Data <- new_data[new_data$CostDriver == 'Supplies',]
Therapy_Data <- new_data[new_data$CostDriver == 'Therapeutic Services',]

# Now generate Chi Squared Plots for each of these significant cost drivers with Data of Ventilator Placement as other breakdown. 
Blood_Graph <- ggbarstats(
  data = Blood_Data,
  x = QVI,
  y = DateOfService,
  title = 'Blood Interventions between Quality Event cases and Control cases by Date of Ventilator Placement'
  ) +
    labs(caption = NULL, subtitle = NULL)
Blood_Graph

Card_Graph <- ggbarstats(
  data = Card_Data,
  x = QVI,
  y = DateOfService,
  title = 'Cardiovascular Interventions between Quality Event cases and Control cases by Date of Ventilator Placement'
) +
  labs(caption = NULL, subtitle = NULL)
Card_Graph

Clinic_Graph <- ggbarstats(
  data = Clinic_Data,
  x = QVI,
  y = DateOfService,
  title = 'Clinic Interventions between Quality Event cases and Control cases by Date of Ventilator Placement'
) +
  labs(caption = NULL, subtitle = NULL)
Clinic_Graph

Dialysis_Graph <- ggbarstats(
  data = Dialysis_Data,
  x = QVI,
  y = DateOfService,
  title = 'Dialysis Interventions between Quality Event cases and Control cases by Date of Ventilator Placement'
) +
  labs(caption = NULL, subtitle = NULL)
Dialysis_Graph

ER_Graph <- ggbarstats(
  data = ER_Data,
  x = QVI,
  y = DateOfService,
  title = 'ER Interventions between Quality Event cases and Control cases by Date of Ventilator Placement'
) +
  labs(caption = NULL, subtitle = NULL)
ER_Graph

Lab_Graph <- ggbarstats(
  data = Lab_Data,
  x = QVI,
  y = DateOfService,
  title = 'Lab Interventions between Quality Event cases and Control cases by Date of Ventilator Placement'
) +
  labs(caption = NULL, subtitle = NULL)
Lab_Graph

OthDx_Graph <- ggbarstats(
  data = OthDx_Data,
  x = QVI,
  y = DateOfService,
  title = 'Other Diagnostic Interventions between Quality Event cases and Control cases by Date of Ventilator Placement'
) +
  labs(caption = NULL, subtitle = NULL)
OthDx_Graph

Pharm_Graph <- ggbarstats(
  data = Pharm_Data,
  x = QVI,
  y = DateOfService,
  title = 'Pharmacy Interventions between Quality Event cases and Control cases by Date of Ventilator Placement'
) +
  labs(caption = NULL, subtitle = NULL)
Pharm_Graph

Resp_Graph <- ggbarstats(
  data = Resp_Data,
  x = QVI,
  y = DateOfService,
  title = 'Respiratory Interventions between Quality Event cases and Control cases by Date of Ventilator Placement'
) +
  labs(caption = NULL, subtitle = NULL)
Resp_Graph

Supply_Graph <- ggbarstats(
  data = Supply_Data,
  x = QVI,
  y = DateOfService,
  title = 'Supply Interventions between Quality Event cases and Control cases by Date of Ventilator Placement'
) +
  labs(caption = NULL, subtitle = NULL)
Supply_Graph

Therapy_Graph <- ggbarstats(
  data = Therapy_Data,
  x = QVI,
  y = DateOfService,
  title = 'Therapy Interventions between Quality Event cases and Control cases by Date of Ventilator Placement'
) +
  labs(caption = NULL, subtitle = NULL)
Therapy_Graph
