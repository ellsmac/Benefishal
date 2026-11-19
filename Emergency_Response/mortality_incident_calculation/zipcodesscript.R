library(dplyr)
library(readr)
library(tidycensus)

#census_api_key("306693a48417e27503f9a274fd0420ef059dd53e", install = TRUE)

#Reading in Intersection of Blocks and Zipcodes
riverside <- read_csv("Emergency_Response/mortality_incident_calculation/riversideBlocksZipcodes.csv")%>%
  mutate(county = "Riverside")
sd <- read_csv("Emergency_Response/mortality_incident_calculation/sdBlocksZipcodes.csv")%>%
  rename(ZIPCODE = ZIP)%>%
  mutate(county = "San Diego")

#Taking Highest Area Zipcode per Blocks
blocks_zipcodes <- bind_rows(riverside, sd) %>%
  group_by(block, tract) %>%
  slice_max(`Area in Square Miles`, n = 1, with_ties = FALSE) %>%
  ungroup() %>%
  select(geoid, block, blck_gr, tract, popultn, ZIPCODE, county, `Area in Square Miles`)

#Getting Population of Zipcodes
zip_pop <- get_acs(
  geography = "zcta",
  variables = c(population = "B01003_001"),
  year = 2024,
  survey = "acs5",
  output = "wide"
) %>%
  select(GEOID, populationE, populationM) %>%
  rename(
    ZIPCODE = GEOID,
    zipcode_population = populationE,
    zip_pop_error = populationM
  )

#Reading in EDvisits per zipcode
edvisits <- read_csv("Emergency_Response/mortality_incident_calculation/EDvists_zipcodes_2024_2025.csv") %>% 
  mutate(ZIPCODE = as.character(ZIPCODE))

#Putting together each block with the pop and edvisits of zipcode, 
#then calculating expected no. of ed visits within block
df <- blocks_zipcodes %>%
  mutate(ZIPCODE = as.character(ZIPCODE)) %>%
  left_join(zip_pop, by = "ZIPCODE")%>%
  left_join(edvisits, by = "ZIPCODE")%>% 
  mutate(ED_visits_2024=ZIP_ED_visits_2024*popultn/zipcode_population,
         ED_visits_2025=ZIP_ED_visits_2025*popultn/zipcode_population)

#Inferring Frequency of Cardiac Arrest from EDvisits

diagnosis_no <- read_csv("Emergency_Response/mortality_incident_calculation/DiagnosisCodeFreq2025.csv") %>% 
  rename(Desc=DiagnosisDesc,Total=TotalDiag)

external_no <- read_csv("Emergency_Response/mortality_incident_calculation/ExternalCauseCOde2025.csv") %>% 
  rename(Desc=ExtCauseDesc,Total=TotalEcm)

encounters <- read_csv("Emergency_Response/mortality_incident_calculation/Encounters by Facility 2012-2025.csv")

statewide_ed_visits <- encounters %>%
  filter(type == "ED_Visit") %>%
  group_by(year) %>%
  summarise(total_count = sum(count, na.rm = TRUE), .groups = "drop")

#Entry 14 is 2025
ICMcodes <-  bind_rows(external_no, diagnosis_no) %>% 
  mutate(freq = Total/statewide_ed_visits$total_count[14])

Cardiac_codes <- ICMcodes %>% 
  filter(grepl("Cardiac arrest", Desc, ignore.case = TRUE)) %>% 
  filter(!grepl("surgery", Desc, ignore.case = TRUE)) %>% 
  slice(-7)
cardiac_freq<-sum(Cardiac_codes$freq)


df <- mutate(df,cardiac_admits_2025 = ED_visits_2025*cardiac_freq,
             cardiac_admits_2024 = ED_visits_2024*cardiac_freq) %>% 
  select(geoid,block,blck_gr,tract,popultn,cardiac_admits_2024,cardiac_admits_2025)

write_csv(df, "Emergency_Response/mortality_incident_calculation/estimated_cardiac_admits.csv")
