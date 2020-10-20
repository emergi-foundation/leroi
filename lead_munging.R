library(scales)
library(readxl)
library(tidycensus)
library(ckanr)
library(RCurl)
library(pacman)
library(data.table)
library(tidyverse)
library(arrow)
library(feather)

source("replica_munging.R")

#resource_id <- "93688609-f649-4f12-98a2-501d2950cadb"

#https://openei.org/doe-opendata/api/3/action/package_show?id=great-salt-lake-composition-and-rare-earth-speciation-analysis

# AMI68_STATE-CITY-COUNTY_SH_NC
# FPL15_STATE-CITY-COUNTY_SH_NC

# state <- "nc"
# income_metric <- "fpl15" #"ami68"
# geographic_scope <- "tract" #statecitycounty #need to adjust for census query below

list_all_states <- function(all_resources=NULL, refresh=FALSE){
  if(is.null(all_resources)){
    all_resources <- download_lead_resource_ids(replace=refresh)
  }
  all_files <- vapply(strsplit(all_resources$name, split = "_", fixed = T), tail, n=1L, FUN.VALUE=character(1))
  states=unique(all_files[nchar(all_files) <=2])
  
  ## remove IL for now
  ignore_states <- c() #c("IL")
  states <- states[!(states %in% ignore_states)]
  
  return(states)
}

download_lead_resource_ids <- function(replace=TRUE){
  if(!file.exists("LEAD_resource_ids.csv")){
    package_id="9dcd443b-c0e5-4d4a-b764-5a8ff0c2c92b"
    full_package <- package_show(id=package_id,
                                 url = "https://openei.org/doe-opendata/",
                                 as="list")
    all_resources <- full_package$resources %>% map(flatten) %>% bind_rows()
    write_csv(all_resources, "LEAD_resource_ids.csv")
  }else{
    all_resources <- read_csv("LEAD_resource_ids.csv")
  }
  return(all_resources)
}

get_lead_resource_url <- function(file_name,
                                 all_resources=NULL,
                                 replace=TRUE){
  
  if(is.null(all_resources)){
    all_resources <- download_lead_resource_ids(replace=replace)
  }
  
  resource_url <- all_resources$url[which(all_resources$name==file_name)]
  
  return(resource_url)
}

get_lead_dataset <- function(state,
                             income_metric="fpl15",
                             resource_id=NULL,
                             geographic_scope="tract",
                             all_resources=NULL,
                             refresh=FALSE,
                             load=TRUE,
                             format="lead",
                             save_format="fst"){ #csv
  
  print(state)
  acs_date <- 2016
  youngest_building <- acs_date - 1
  oldest_building <- 1900 # this assumption is not used in the ultimate analysis
  max_units <- 500 # 1 NYC block is 5 acres, assume 100 units/acre # this assumption is not used in the ultimate analysis
  
  
  save_file_name <- toupper(paste(income_metric,
                                  geographic_scope,
                                  "sh",
                                  state, sep = "_"))#"AMI68_TRACT_SH_NC"
  load_file_name <- paste0("clean_lead_",save_file_name,".",save_format)
  if (format=="replica"){
    load_file_name <- paste0("replica_lead_",save_file_name,".",save_format)
  }
  
  if(!file.exists(load_file_name) | refresh==TRUE){
    resource_url <- get_lead_resource_url(file_name=save_file_name, 
                                          all_resources=all_resources)
    
    
    # save_file_name <- paste0(income_metric,
    #                          geographic_scope,
    #                          state)
    
    desired_name <- paste0(save_file_name,".",save_format)
    desired_path <- file.path(desired_name)
    
    if (!file.exists(desired_path)){
      download.file(resource_url,desired_path, method="libcurl")
    }
    if (format=="raw"){
      if (load) {
        if (save_format=="csv"){
          lead_raw <- read_csv(desired_path)
        }
        if (save_format=="feather"){
          lead_raw <- read_feather(desired_path)
        }
        return(lead_raw)
      }
      return(TRUE)
    }
    
    # https://readxl.tidyverse.org/articles/articles/readxl-workflows.html
    
    read_then_csv <- function(sheet, path) {
      pathbase <- path %>%
        basename() %>%
        tools::file_path_sans_ext()
      path %>%
        read_excel(sheet = sheet, col_names = FALSE, col_types = "text") %>% 
        write_csv(paste0(sheet, ".csv"))
    }
    
    url <- "https://openei.org/doe-opendata/dataset/9dcd443b-c0e5-4d4a-b764-5a8ff0c2c92b/resource/51a2cd49-fd61-4842-82e2-2f90ffec7e42/download/datadictionary.xlsx"
    
    if(!file.exists("Data Dictionary.csv")){
      temp <- tempfile()
      download.file(url,temp,mode="wb", method="libcurl")
      mode = 'wb'
      path <- temp
      path %>%
        excel_sheets() %>%
        set_names() %>% 
        map(read_then_csv, path = path)
    }
    
    data_dict <- read_csv("Data Dictionary.csv")
    
    ybl_dict <- data_dict[1:7,1:2]
    ybl_dict[1,2] <- data_dict[1,3]
    names(ybl_dict) <- as.matrix(ybl_dict[1, ])
    ybl_dict <- ybl_dict[-1, ]
    
    bld_dict <- data_dict[9:18,1:2]
    bld_dict[1,2] <- data_dict[9,3]
    names(bld_dict) <- as.matrix(bld_dict[1, ])
    bld_dict <- bld_dict[-1, ]
    
    hfl_dict <- data_dict[20:29,1:2]
    hfl_dict[1,2] <- data_dict[20,3]
    names(hfl_dict) <- as.matrix(hfl_dict[1, ])
    hfl_dict <- hfl_dict[-1, ]
    
    burden_dict <- data_dict[1:9,7:8]
    names(burden_dict) <- c("Variable", "Description")
    burden_dict <- rbind(burden_dict, 
                         names(hfl_dict), 
                         names(bld_dict), 
                         names(ybl_dict))
    #burden_dict
    if(save_format=="csv"){
      data <- read_csv(desired_path)
    }
    if(save_format=="fst"){
      print(desired_path)
      # data <- read_feather(desired_path)
      data <- read_fst(desired_path)
    }
    #, 
                     # col_types=cols(
                     #   geo_id = readr::col_character()))#,
                     #   state_id = readr::col_character(),
                     #   county_id = readr::col_character(),
                     #   tract_id = readr::col_character(),
                     #   puma10_code = readr::col_character(),
                     #   fmr_code = readr::col_character(),
                     #   occupancy_type = readr::col_factor(),
                     #   income_bracket = readr::col_factor(),
                     #   primary_heating_fuel = readr::col_factor(),
                     #   number_of_units = readr::col_factor(),
                     #   year_constructed = readr::col_factor(),
                     #   households = col_double(),
                     #   annual_income = col_double(),
                     #   electricity_spend = col_double(),
                     #   gas_spend = col_double(),
                     #   other_spend = col_double(),
                     #   acs_responses = col_double(),
                     #   min_age = col_double(),
                     #   min_units = col_double(),
                     #   detached = readr::col_factor(),
                     #   mean_energy_cost = col_double()
                     # ))
    
    #summary(data)
    
    #Seperate the `AMI68` column into `occupancy_type` and `income_bracket` columns
    # print(object.size(data, units="Gb"))
    
    data <- data %>% 
      separate(col=toupper(income_metric),
               into=c("occupancy_type", "income_bracket"), 
               sep = " ", 
               remove = FALSE, 
               convert = FALSE,
               extra = "warn", 
               fill = "warn")
    
    data$occupancy_type <- as.factor(data$occupancy_type)
    data$income_bracket <- as.factor(data$income_bracket)
    
    ybl_dict
    
    ybl_ranges <- str_extract_all(ybl_dict$`Year of building first construction`, "[0-9]+", simplify=TRUE)
    ybl_ranges <- apply(ybl_ranges, c(1,2), as.numeric)
    ybl_ranges[1,2] <- youngest_building
    ybl_ranges[6,2] <- ybl_ranges[6,1]
    ybl_ranges[6,1] <- oldest_building
    ybl_ranges[2:5,2] <- floor(ybl_ranges[2:5,1]/100)*100 + ybl_ranges[2:5,2]
    
    ybl_ranges <- data.frame(ybl_ranges)
    names(ybl_ranges) <- c("min_year", "max_year")
    ybl_ranges$min_age <- acs_date - ybl_ranges$max_year
    ybl_ranges$max_age <- acs_date - ybl_ranges$min_year
    ybl_dict <- cbind(ybl_dict, ybl_ranges)
    ybl_dict$`YBL INDEX` <- as.factor(ybl_dict$`YBL INDEX`)
    
    
    ybl_dict <- rename(ybl_dict,
                       year_constructed=`Year of building first construction`)
    
    ybl_dict$year_constructed <- as.factor(ybl_dict$year_constructed)
    
    data$`YBL INDEX` <- as.factor(data$`YBL INDEX`)
    data <- merge(data, ybl_dict[c("YBL INDEX",
                                   "min_age",
                                   "year_constructed")], 
                  by = "YBL INDEX", 
                  all.x = TRUE)
    
    #Create `min_units` from `BLD INDEX` (and `max_units`).
    #Create `detached` from `BLD INDEX`.
    
    bld_ranges <- str_extract_all(bld_dict$`Number of units in the building`, "[0-9]+", simplify=TRUE)
    
    bld_ranges <- apply(bld_ranges, c(1,2), as.numeric)
    bld_ranges[1:3,2] <- bld_ranges[1:3,1]
    bld_ranges[8,2] <- max_units
    
    bld_ranges <- data.frame(bld_ranges)
    names(bld_ranges) <- c("min_units", "max_units")
    
    bld_ranges$detached <- as.factor(c(1,rep(0,nrow(bld_ranges)-2),NA))
    
    bld_dict <- cbind(bld_dict, bld_ranges)
    bld_dict$`BLD INDEX` <- as.factor(bld_dict$`BLD INDEX`)
    
    bld_dict <- rename(bld_dict,
                       number_of_units=`Number of units in the building`)
    
    bld_dict$number_of_units <- as.factor(bld_dict$number_of_units)
    
    data$`BLD INDEX` <- as.factor(data$`BLD INDEX`)
    data <- merge(data, bld_dict[c("BLD INDEX",
                                   "min_units",
                                   "detached",
                                   "number_of_units")], 
                  by = "BLD INDEX", 
                  all.x = TRUE)
    
    hfl_dict <- rename(hfl_dict,
                       primary_heating_fuel=`Primary heating fuel type`)
    
    hfl_dict$primary_heating_fuel <- as.factor(hfl_dict$primary_heating_fuel)
    
    data <- merge(data, hfl_dict[c("HFL INDEX","primary_heating_fuel")], 
                  by = "HFL INDEX", 
                  all.x = TRUE)
    
    # Create the Energy Expenditures Indicator `mean_energy_cost`.
    
    data$mean_energy_cost <- data$`ELEP CAL` + data$`GASP CAL` + data$FULP
    
    data <- dplyr::select(data,
                   `GEO ID`,
                   `PUMA10`,
                   `FMR`,
                   `occupancy_type`,
                   `income_bracket`,
                   `primary_heating_fuel`,
                   `number_of_units`,
                   `year_constructed`,
                   `UNITS`, 
                   `HINCP`, 
                   `ELEP CAL`, 
                   `GASP CAL`, 
                   `FULP`, 
                   `COUNT`, 
                   `min_age`, 
                   `min_units`, 
                   `detached`,
                   `mean_energy_cost`)
    
    data <- rename(data,
                   geo_id=`GEO ID`,
                   puma10_code=`PUMA10`,
                   fmr_code=`FMR`,
                   households=`UNITS`, 
                   acs_responses=`COUNT`,
                   annual_income=`HINCP`,
                   electricity_spend=`ELEP CAL`, 
                   gas_spend=`GASP CAL`, 
                   other_spend=`FULP`) %>% 
      mutate(puma10_code=as.character(puma10_code),
             geo_id=as.character(geo_id),
             fmr_code=as.character(fmr_code))
    
    data <- separate(data,
                     col=geo_id,
                     into=c("state_id","county_id","tract_id"),
                     sep=c(2,5), 
                     remove=FALSE, 
                     convert=FALSE)
    
    fp <- read_excel(path="all-geocodes-v2016.xlsx", skip=5,
                     col_names=c("summary_level","state_code_fips","county_code_fips",
                                 "county_sub_code","place_code","city_code",
                                 "area_name"))
    
    state_names <- read_delim(file = "state_fips.txt", delim = "|",
                              col_names=c("state_code_fips","state_code_usps","state_name","state_code_gnisid"))
    
    
    data$state_id <- str_pad(as.character(data$state_id), width=2, side="left", pad="0")
    data$county_id <- str_pad(as.character(data$county_id), width=3, side="left", pad="0")
    
    data <- left_join(x=data, y=state_names, 
                      by=c("state_id"="state_code_fips"))
    
    data <- left_join(x=data, y=fp, 
                      by=c("state_id"="state_code_fips","county_id"="county_code_fips"))
    
    # print(object.size(data, units="Gb"))
    #data <- add_acs_data(data, save_file_name)
    
    #summary(data)
    #str(data)
    print(paste0("converting ",state," to format: ",format))
    if (format=="replica"){
      data <- lead_to_replica(data)
    }
    if(save_format=="csv"){
      write_csv(data, load_file_name)
    }
    if(save_format=="fst"){
      # write_feather(data, load_file_name)
      write_fst(data, load_file_name, uniform_encoding=FALSE)
    }
  }else{
    if(load){
      if(save_format=="csv"){
        data <- read_csv(load_file_name)
      }
      if(save_format=="fst"){
        # data <- read_feather(load_file_name)
        data <- read_fst(load_file_name)
      }
    }
  }
  # print(object.size(data , units="Gb"))
  return(if(load){data}else{load_file_name})
}

clean_lead_data <- function(data, save_file_name){
  weird_rows <- rep(FALSE, nrow(data)) #data$annual_income<=0 | data$mean_energy_cost<=0 | data$annual_income < (12 * data$mean_energy_cost)
  # | data$households<1 "or those which represent less than a single housing unit "
  # | data$mean_energy_burden>1 "or energy costs greater than income"
  weird_data <- data[weird_rows,]
  data <- data[!weird_rows,]
  
  weird_rate <- nrow(weird_data)/(nrow(data)+nrow(weird_data))
  weird_unit_rate <- sum(weird_data$households)/(sum(data$households)+sum(weird_data$households))
  
  write_csv(weird_data, paste0("weird_lead_",save_file_name,".csv"))
  
  clean_file_name <- paste0("clean_lead_",save_file_name,".csv")
  write_csv(data,clean_file_name)
}

add_acs_data <- function(data, save_file_name){
  
  acs_variables <- list(
    total_males = sym("B01001_002"),
    total_population = sym("B01003_001"),
    median_age = sym("B01002_001"),
    no_high_school = sym("B06009_001"),
    total_white = sym("B02001_002"),
    median_income = sym("B06011_001"),
    acs_total_households = sym("B25001_001")
  )
  
  states <- unique(data$state_id)
  
  acs_features <- get_acs(state = states, 
                          geography = geographic_scope,
                          variables = as.character(unlist(acs_variables)),
                          year = 2016,
                          output = "tidy",
                          geometry = FALSE)
  
  acs_features <- pivot_wider(acs_features, id_cols=c("GEOID"),
                              names_from=c("variable"),
                              values_from=c("estimate"))
  acs_features <- rename(acs_features, !!!acs_variables)
  head(acs_features)
  
  acs_features$pct_non_male <- 1.0 - acs_features$total_males / acs_features$total_population
  acs_features$pct_no_high_school <- acs_features$no_high_school / acs_features$total_population
  acs_features$pct_non_white <- 1.0 - acs_features$total_white / acs_features$total_population
  
  acs_features$geo_id <- as.numeric(acs_features$GEOID)
  
  final_acs_variables <- c("geo_id",
                           "pct_non_male",
                           "median_age",
                           "pct_no_high_school",
                           "pct_non_white",
                           "median_income",
                           "acs_total_households")
  
  data <- left_join(data, dplyr::select(acs_features, all_of(final_acs_variables)) %>% mutate(geo_id=as.character(geo_id)), by="geo_id")
  
  #write_csv(data, paste0("clean_lead_acs_",save_file_name,".csv"))
  return(data)
}

get_multiple_states <- function(states="all",
                                income_metric="ami68",
                                geographic_scope="tract",
                                refresh=FALSE,
                                col_types=NULL,
                                format="lead",
                                save_format="fst",#csv
                                parallel=TRUE){
  
  save_file_name <- toupper(paste(income_metric,
                                  geographic_scope,
                                  "sh",
                                  paste(sort(states),  collapse = "_"), 
                                  sep = "_"))#"AMI68_TRACT_SH_NC"
  
  all_resources <- download_lead_resource_ids(replace=refresh)
  
  if(tolower(states=="all")){
    states <- list_all_states((all_resources=all_resources))
  }
  
  states <- c(states)
  print(states)
  
  load_file_name <- paste0("clean_lead_",save_file_name,".",save_format)
  if (format=="replica"){
      load_file_name <- paste0("replica_lead_",save_file_name,".",save_format)
    }
  if(format=="raw"){
    load_file_name <- paste0(save_file_name,".",save_format)
  }
  
  if(!file.exists(load_file_name) | refresh==TRUE){
  
    for (state in states){
      get_lead_dataset(state, 
                       income_metric=income_metric, 
                       resource_id=NULL, 
                       geographic_scope=geographic_scope, 
                       all_resources=all_resources,
                       refresh=refresh,
                       load=FALSE,
                       format=format,
                       save_format=save_format)
      gc()
    }
    
    #data <- bind_rows(all_states)
    p_load(doParallel,data.table,dplyr,stringr,fst)
    
    # get the file name
    #dir() %>% str_subset("\\.csv$") -> fn
    filenames <- sapply(states, function(x){
      save_file_name <- toupper(paste(income_metric,
                                      geographic_scope,
                                      "sh",
                                      x,
                                      sep = "_"))
      load_file_name <- paste0("clean_lead_",save_file_name,".",save_format)
      if(format=="replica"){
        load_file_name <- paste0("replica_lead_",save_file_name,".",save_format)
      }
      if(format=="raw"){
        load_file_name <- paste0(save_file_name,".",save_format)
      }
      full_load_file_name <- file.path(getwd(), load_file_name)
      return(full_load_file_name)})
    
    # all_states <- lapply(states, function(x){
    #   return(get_lead_dataset(state,
    #                                income_metric=income_metric,
    #                                resource_id=NULL,
    #                                geographic_scope=geographic_scope,
    #                                all_resources=all_resources,
    #                                refresh=FALSE))
    # })
    
    if(parallel){
      # use parallel setting
      (cl = min(length(states), detectCores()) %>%
          makeCluster(outfile="")) %>%
        registerDoParallel()

      registerDoSEQ()

      # read and bind
      system.time({
        data = foreach(i = filenames,
                         .packages = "data.table") %dopar% {
                           fread(i,colClasses = "character")
                         } %>%
          rbindlist(use.names=TRUE, fill = T)
      })

      # end of parallel work
      # stopImplicitCluster(cl)
      stopCluster(cl)
    } else {
      data <- fread(filenames[1], colClasses="character")
      num_files <- length(filenames)
      if (num_files > 1){
        for (filename in filenames[2:num_files]){
          data <- rbindlist(list(data, fread(filename, colClasses="character")), fill=TRUE)
        }
      }
    }
    if(save_format=="csv"){
      write_feather(data, load_file_name)
    }
    if(save_format=="feather"){
      write_csv(data, load_file_name)
    }
  }else{
    if(save_format=="csv"){
      data <- read_csv(load_file_name)
    }
    if(save_format=="feather"){
      data <- read_feather(load_file_name)
    }
    #, 
                     # col_types=cols(
                     #   geo_id = readr::col_character(),
                     #   state_id = readr::col_character(),
                     #   county_id = readr::col_character(),
                     #   tract_id = readr::col_character(),
                     #   puma10_code = readr::col_character(),
                     #   fmr_code = readr::col_character(),
                     #   occupancy_type = readr::col_factor(),
                     #   income_bracket = readr::col_factor(),
                     #   primary_heating_fuel = readr::col_factor(),
                     #   number_of_units = readr::col_factor(),
                     #   year_constructed = readr::col_factor(),
                     #   households = col_double(),
                     #   annual_income = col_double(),
                     #   electricity_spend = col_double(),
                     #   gas_spend = col_double(),
                     #   other_spend = col_double(),
                     #   acs_responses = col_double(),
                     #   min_age = col_double(),
                     #   min_units = col_double(),
                     #   detached = readr::col_factor(),
                     #   mean_energy_cost = col_double()
                     # ))
  }
  
  return(type_convert(data %>% mutate_all(as.character), col_types=col_types))
}

# data_reloaded <- read_csv(file.path(getwd(),clean_file_name),
#                           col_types=cols(
#                             geo_id = readr::col_character(),
#                             state_id = readr::col_character(),
#                             county_id = readr::col_character(),
#                             tract_id = readr::col_character(),
#                             puma10_code = readr::col_character(),
#                             fmr_code = readr::col_character(),
#                             occupancy_type = readr::col_factor(),
#                             income_bracket = readr::col_factor(),
#                             primary_heating_fuel = readr::col_factor(),
#                             number_of_units = readr::col_factor(),
#                             year_constructed = readr::col_factor(),
#                             households = col_double(),
#                             annual_income = col_double(),
#                             electricity_spend = col_double(),
#                             gas_spend = col_double(),
#                             other_spend = col_double(),
#                             acs_responses = col_double(),
#                             min_age = col_double(),
#                             min_units = col_double(),
#                             detached = readr::col_factor(),
#                             mean_energy_cost = col_double(),
#                             pct_non_male = col_double(), 
#                             median_age = col_double(),
#                             pct_no_high_school = col_double(),
#                             pct_non_white = col_double(),
#                             median_income = col_double(),
#                             acs_total_households = col_double()
#                           ))
# 
# all(data_reloaded == data, na.rm=TRUE)
# summary(data_reloaded)


