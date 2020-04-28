``` r
knitr::opts_chunk$set(echo = TRUE)

library(scales)
library(tidyverse)
```

    ## ── Attaching packages ────────────────────────────────────────────────────────────────────────────────────────────────────────────── tidyverse 1.3.0 ──

    ## ✓ ggplot2 3.2.1     ✓ purrr   0.3.3
    ## ✓ tibble  3.0.0     ✓ dplyr   0.8.5
    ## ✓ tidyr   1.0.2     ✓ stringr 1.4.0
    ## ✓ readr   1.3.1     ✓ forcats 0.5.0

    ## ── Conflicts ───────────────────────────────────────────────────────────────────────────────────────────────────────────────── tidyverse_conflicts() ──
    ## x readr::col_factor() masks scales::col_factor()
    ## x purrr::discard()    masks scales::discard()
    ## x dplyr::filter()     masks stats::filter()
    ## x dplyr::lag()        masks stats::lag()

``` r
library(readxl)
```

Introduction
============

``` r
energy_poverty_line <- 0.10
acs_date <- 2016
youngest_building <- acs_date - 1
oldest_building <- 1900 # this assumption is not used in the ultimate analysis
max_units <- 500 # 1 NYC block is 5 acres, assume 100 units/acre # this assumption is not used in the ultimate analysis
```

This is a data munging report for the Low Income Energy Affordability
Data
[LEAD](https://catalog.data.gov/dataset/low-income-energy-affordability-data-lead-tool)
from the Department of Energy (DOE). This dataset represents an estimate
of the monthly energy bills and average incomes of households in the
united states, segmented by the following characteristics:

-   Year of building first construction
-   Number of units in the building
-   Primary heating fuel type
-   Whether the residents own or rent the unit
-   Household income relative to Area Median Income or Federal Poverty
    Level
-   State
-   County, City, or Census Tract

For this project, I will use the data which displays the results by
census tract in terms of Area Median Income for the state of North
Carolina.

Acquiring Data
==============

``` r
base_url <- "https://openei.org/doe-opendata/dataset/9dcd443b-c0e5-4d4a-b764-5a8ff0c2c92b/resource/831ac481-1a60-4f87-a887-15b310ffff53/download/"


file_name <- "ami68tractshnc"
data_url <- paste0(base_url,file_name,".csv")
desired_name <- paste0(file_name,".csv")
desired_path <- file.path(desired_name)

if (!file.exists(desired_path)){
  download.file(data_url,desired_path)
}
```

A full data dictionary is available. It is downloaded and loaded into
constituent dataframes below.

``` r
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
  download.file(url,temp,mode="wb")
  path <- temp
  path %>%
    excel_sheets() %>%
    set_names() %>% 
    map(read_then_csv, path = path)
}

data_dict <- read_csv("Data Dictionary.csv")
```

    ## Parsed with column specification:
    ## cols(
    ##   ...1 = col_character(),
    ##   ...2 = col_character(),
    ##   ...3 = col_character(),
    ##   ...4 = col_logical(),
    ##   ...5 = col_logical(),
    ##   ...6 = col_logical(),
    ##   ...7 = col_character(),
    ##   ...8 = col_character()
    ## )

``` r
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
burden_dict
```

    ## # A tibble: 12 x 2
    ##    Variable   Description                                                       
    ##    <chr>      <chr>                                                             
    ##  1 UNITS      Number of occupied housing units (or households)                  
    ##  2 HINCP      Average annual household income ($/year)                          
    ##  3 ELEP       Original American Community Survey average household monthly elec…
    ##  4 ELEP CAL   Calibrated American Community Survey average household monthly el…
    ##  5 GASP       Original American Community Survey average household monthly gas …
    ##  6 GASP CAL   Calibrated American Community Survey average household monthly ga…
    ##  7 GASP-U CAL Calibrated American Community Survey average household monthly ga…
    ##  8 FULP       Original American Community Survey average housing unit monthly o…
    ##  9 COUNT      Average number of ACS survey responses contributing to the estima…
    ## 10 HFL INDEX  Primary heating fuel type                                         
    ## 11 BLD INDEX  Number of units in the building                                   
    ## 12 YBL INDEX  Year of building first construction

``` r
data <- read_csv(desired_path)
```

    ## Parsed with column specification:
    ## cols(
    ##   `GEO ID` = col_double(),
    ##   PUMA10 = col_double(),
    ##   FMR = col_double(),
    ##   `YBL INDEX` = col_double(),
    ##   `BLD INDEX` = col_double(),
    ##   `HFL INDEX` = col_double(),
    ##   AMI68 = col_character(),
    ##   UNITS = col_double(),
    ##   HINCP = col_double(),
    ##   ELEP = col_double(),
    ##   `ELEP CAL` = col_double(),
    ##   GASP = col_double(),
    ##   `GASP CAL` = col_double(),
    ##   `GASP-U CAL` = col_double(),
    ##   FULP = col_double(),
    ##   COUNT = col_double()
    ## )

``` r
summary(data)
```

    ##      GEO ID              PUMA10          FMR          YBL INDEX    
    ##  Min.   :3.700e+10   Min.   : 100   Min.   :37001   Min.   :0.000  
    ##  1st Qu.:3.705e+10   1st Qu.:1702   1st Qu.:37051   1st Qu.:1.000  
    ##  Median :3.708e+10   Median :2700   Median :37083   Median :2.000  
    ##  Mean   :3.709e+10   Mean   :2713   Mean   :37088   Mean   :2.485  
    ##  3rd Qu.:3.713e+10   3rd Qu.:3700   3rd Qu.:37125   3rd Qu.:4.000  
    ##  Max.   :3.718e+10   Max.   :5400   Max.   :37179   Max.   :5.000  
    ##    BLD INDEX       HFL INDEX        AMI68               UNITS          
    ##  Min.   :0.000   Min.   :0.000   Length:1048575     Min.   :   0.0000  
    ##  1st Qu.:0.000   1st Qu.:1.000   Class :character   1st Qu.:   0.0008  
    ##  Median :1.000   Median :2.000   Mode  :character   Median :   0.0715  
    ##  Mean   :2.501   Mean   :2.404                      Mean   :   3.1103  
    ##  3rd Qu.:4.000   3rd Qu.:3.000                      3rd Qu.:   1.3725  
    ##  Max.   :8.000   Max.   :8.000                      Max.   :1242.1053  
    ##      HINCP             ELEP           ELEP CAL           GASP        
    ##  Min.   : -7603   Min.   :  0.00   Min.   :  0.00   Min.   :  0.000  
    ##  1st Qu.:     0   1st Qu.:  0.00   1st Qu.:  0.00   1st Qu.:  0.000  
    ##  Median :     0   Median :  0.00   Median :  0.00   Median :  0.000  
    ##  Mean   : 19286   Mean   : 66.03   Mean   : 52.23   Mean   : 19.956  
    ##  3rd Qu.: 31330   3rd Qu.:130.75   3rd Qu.:103.40   3rd Qu.:  8.837  
    ##  Max.   :893731   Max.   :567.08   Max.   :783.47   Max.   :527.177  
    ##     GASP CAL         GASP-U CAL           FULP            COUNT        
    ##  Min.   :  0.000   Min.   :  0.000   Min.   :  0.00   Min.   :  0.000  
    ##  1st Qu.:  0.000   1st Qu.:  0.000   1st Qu.:  0.00   1st Qu.:  0.000  
    ##  Median :  0.000   Median :  0.000   Median :  0.00   Median :  0.000  
    ##  Mean   : 12.770   Mean   :  6.924   Mean   :  5.35   Mean   :  3.904  
    ##  3rd Qu.:  5.377   3rd Qu.:  0.000   3rd Qu.:  0.00   3rd Qu.:  2.177  
    ##  Max.   :704.908   Max.   :513.426   Max.   :329.11   Max.   :644.760

Data Munging
============

Munging Steps:

-   Seperate the `AMI68` column into `occupancy_type` and
    `income_bracket` columns.
-   Create `min_age` from `YBL INDEX`.
-   Create `min_units` from `BLD INDEX`.
-   Create `detached` from `BLD INDEX`.
-   Create the Energy Expenditures Indicator `mean_energy_cost`.
-   Create the Energy Burden Indicator `mean_energy_burden`.
-   Remove rows where `UNITS<1`, `mean_energy_cost<0`, or `HINCP<0`.

Break Out Ownership & Income Bracket
------------------------------------

The data combines the unit’s ownership status (`OWNER` vs. `RENTER`) and
income bracket as a fraction of Area Median Income (`0-30%`, `30-60%`,
`60-80%`, `80-100%`, or `100%+`) into the same column (e.g. OWNER
0-30%). This `AMI68` column needs to be seperated for meaningful
analysis. These categorical variables are saved as factors.

``` r
#Seperate the `AMI68` column into `occupancy_type` and `income_bracket` columns

data <- data %>% 
  separate(col="AMI68",
           into=c("occupancy_type", "income_bracket"), 
           sep = " ", 
           remove = FALSE, 
           convert = FALSE,
           extra = "warn", 
           fill = "warn")

data$occupancy_type <- as.factor(data$occupancy_type)
data$income_bracket <- as.factor(data$income_bracket)
```

Create Meaningful Indicators from Indices
-----------------------------------------

The `YBL INDEX` and `BLD INDEX` columns need some further treatment.
`YBL INDEX` represents the year the building was first constructed, but
is an index seperated into 10-20 year increments dating back to 1940.

``` r
ybl_dict
```

    ## # A tibble: 6 x 2
    ##   `YBL INDEX` `Year of building first construction`
    ##   <chr>       <chr>                                
    ## 1 0           2010+                                
    ## 2 1           2000-09                              
    ## 3 2           1980-99                              
    ## 4 3           1960-79                              
    ## 5 4           1940-59                              
    ## 6 5           BEFORE 1940

Since these indeces represent different possible ages and the increments
are not uniform, I will add a numerical indicator (`min_age`) to
represent the youngest age the building could possibly be based on its
category. Thus, a building in the `2010+` range must be at least 0 years
old (this data was collected in 2016), in the `1980-99` range at least
36 years old, in the `BEFORE 1940` range at least 76, etc. I choose
youngest rather than oldest age because it avoids the requirement to
make an assumption about the oldest age of buildings built before 1940.

For simplicity, I assume that the youngest building is 1 year old.

``` r
#Create `min_age` from `YBL INDEX`.

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
```

Similar to building age, the variable `BLD INDEX` represents a
non-uniformly distributed set of buckets for the range of
`number of units in the building`, as well as whether single unit
households are attached or detached from neighboring households. I will
extract the minimum number of units from the range, and whether the
building is detached.

Those households labeled `OTHER UNIT` will be given values of `NA` for
this characteristic.

``` r
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
```

Assign Primary Heating Fuel Type
--------------------------------

``` r
hfl_dict <- rename(hfl_dict,
               primary_heating_fuel=`Primary heating fuel type`)

hfl_dict$primary_heating_fuel <- as.factor(hfl_dict$primary_heating_fuel)

data <- merge(data, hfl_dict[c("HFL INDEX","primary_heating_fuel")], 
              by = "HFL INDEX", 
              all.x = TRUE)
```

Create the Energy Burden Indicators
-----------------------------------

Creating the final metric of average energy burden for each cohort is as
simple as adding up the montly expenditures on electricity (`ELEP CAL`),
natural gas (`GASP CAL`), and other fuels (`FULP`), and dividing this by
the cohort’s average monthly income (`HINCP / 12.0`).

``` r
# Create the Energy Expenditures Indicator `mean_energy_cost`.

data$mean_energy_cost <- data$`ELEP CAL` + data$`GASP CAL` + data$FULP

# Create the Energy Burden Indicator `mean_energy_burden`.

data$mean_energy_burden <- data$mean_energy_cost / (data$HINCP/12.0)

# Create the Energy Return on Investment Indicator `eroi`

data$mean_eroi <- data$HINCP / (12*data$mean_energy_cost)
```

Clean-up
--------

-   rename variables for convenience
-   keep only what we need

Select the columns I want:

``` r
data <- select(data,
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
               `mean_energy_cost`,
               `mean_energy_burden`,
               `mean_eroi`)
```

Rename columns to remove spaces:

``` r
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
```

Decompose the geo\_id into state, county, and tract codes for
interpretibility.

``` r
data <- separate(data,
                 col=geo_id,
                 into=c("state_id","county_id","tract_id"),
                 sep=c(2,5), 
                 remove=FALSE, 
                 convert=FALSE)
```

Adding an Energy Poverty Response Variable
------------------------------------------

For further analysis, I will add a designation of whether a cohort is,
on average, in energy poverty depending on whether the mean energy
burden is above 10%.

``` r
data$energy_poverty <- as.logical(data$mean_energy_burden > energy_poverty_line)
```

Remove Fractional Units
-----------------------

The estimation procedure used by the DOE results in an estimated number
of occupied housing units meeting the subset characteristics (`UNITS`,
renamed as `households`) and displays the number of American Community
Survey responses that contribute to the estimate of energy expenditures
(`COUNT`, renamed as `acs_responses`). We first remove any categories
that have fewer than 1 unit represented, since this is not physically
possible.

This results in removing 71.7064588% of the available rows (gross:
751896 rows of 1048575). This is a total of 9.304307510^{4} housing
units, or 2.8529144% of the estimated total 3.261334310^{6} units in the
state.

``` r
weird_rows <- data$annual_income<1 | data$mean_energy_cost<1
# | data$households<1 "or those which represent les than a single housing unit "
# | data$mean_energy_burden>1 "or energy costs greater than income"
weird_data <- data[weird_rows,]
data <- data[!weird_rows,]

weird_rate <- nrow(weird_data)/(nrow(data)+nrow(weird_data))
weird_unit_rate <- sum(weird_data$households)/(sum(data$households)+sum(weird_data$households))
```

I have seperated any cohorts with incomes or energy costs less than $1
into another dataset for analysis. This represents approximately 3% of
the housing units and 53% of the examined cohorts, so it will be
important to make sure that this subset does not contain systematic
bias.

``` r
write_csv(weird_data, "weird_lead.csv")
write_csv(data,"clean_lead.csv")

summary(data)
```

    ##     geo_id            state_id          county_id           tract_id        
    ##  Length:491368      Length:491368      Length:491368      Length:491368     
    ##  Class :character   Class :character   Class :character   Class :character  
    ##  Mode  :character   Mode  :character   Mode  :character   Mode  :character  
    ##                                                                             
    ##                                                                             
    ##                                                                             
    ##                                                                             
    ##  puma10_code          fmr_code         occupancy_type  income_bracket  
    ##  Length:491368      Length:491368      OWNER :256803   0-30%  : 91432  
    ##  Class :character   Class :character   RENTER:234565   100%+  :108978  
    ##  Mode  :character   Mode  :character                   30-60% : 98471  
    ##                                                        60-80% : 96230  
    ##                                                        80-100%: 96257  
    ##                                                                        
    ##                                                                        
    ##   primary_heating_fuel        number_of_units      year_constructed 
    ##  ELECTRICITY:210816    1 UNIT DETACHED:276507   1940-59    : 74304  
    ##  UTILITY GAS:115165    OTHER UNIT     : 72714   1960-79    :122722  
    ##  BOTTLED GAS: 73054    1 UNIT ATTACHED: 48004   1980-99    :139815  
    ##  FUEL OIL   : 48496    5-9 UNIT       : 21535   2000-09    : 82137  
    ##  WOOD       : 33840    3-4 UNIT       : 20631   2010+      : 20337  
    ##  NONE       :  7610    2 UNIT         : 20064   BEFORE 1940: 52053  
    ##  (Other)    :  2387    (Other)        : 31913                       
    ##    households        annual_income    electricity_spend   gas_spend      
    ##  Min.   :   0.0000   Min.   :     1   Min.   :  0.00    Min.   :  0.000  
    ##  1st Qu.:   0.3167   1st Qu.: 19167   1st Qu.: 78.01    1st Qu.:  0.000  
    ##  Median :   1.4079   Median : 32997   Median :106.98    Median :  7.181  
    ##  Mean   :   6.4595   Mean   : 41054   Mean   :111.00    Mean   : 27.091  
    ##  3rd Qu.:   5.0883   3rd Qu.: 49320   3rd Qu.:138.26    3rd Qu.: 41.142  
    ##  Max.   :1242.1053   Max.   :893731   Max.   :783.47    Max.   :704.908  
    ##                                                                          
    ##   other_spend      acs_responses         min_age        min_units    
    ##  Min.   :  0.000   Min.   :  0.0017   Min.   : 1.00   Min.   : 1.00  
    ##  1st Qu.:  0.000   1st Qu.:  1.0000   1st Qu.:17.00   1st Qu.: 1.00  
    ##  Median :  0.000   Median :  2.4950   Median :37.00   Median : 1.00  
    ##  Mean   : 11.362   Mean   :  8.3046   Mean   :31.96   Mean   : 2.82  
    ##  3rd Qu.:  5.282   3rd Qu.:  7.0200   3rd Qu.:57.00   3rd Qu.: 1.00  
    ##  Max.   :329.107   Max.   :644.7600   Max.   :76.00   Max.   :50.00  
    ##                                                       NA's   :72714  
    ##  detached      mean_energy_cost  mean_energy_burden    mean_eroi       
    ##  0   :142147   Min.   :  1.117   Min.   :   0.0004   Min.   :   0.001  
    ##  1   :276507   1st Qu.:100.873   1st Qu.:   0.0288   1st Qu.:  11.118  
    ##  NA's: 72714   Median :141.645   Median :   0.0501   Median :  19.962  
    ##                Mean   :149.450   Mean   :   0.1134   Mean   :  27.787  
    ##                3rd Qu.:182.144   3rd Qu.:   0.0899   3rd Qu.:  34.717  
    ##                Max.   :935.561   Max.   :1034.1000   Max.   :2308.418  
    ##                                                                        
    ##  energy_poverty 
    ##  Mode :logical  
    ##  FALSE:384372   
    ##  TRUE :106996   
    ##                 
    ##                 
    ##                 
    ## 

``` r
str(data)
```

    ## 'data.frame':    491368 obs. of  24 variables:
    ##  $ geo_id              : chr  "37001020100" "37001020100" "37081012504" "37119006303" ...
    ##  $ state_id            : chr  "37" "37" "37" "37" ...
    ##  $ county_id           : chr  "001" "001" "081" "119" ...
    ##  $ tract_id            : chr  "020100" "020100" "012504" "006303" ...
    ##  $ puma10_code         : chr  "1600" "1600" "1701" "3106" ...
    ##  $ fmr_code            : chr  "37001" "37001" "37081" "37119" ...
    ##  $ occupancy_type      : Factor w/ 2 levels "OWNER","RENTER": 1 1 2 1 2 1 1 1 2 2 ...
    ##  $ income_bracket      : Factor w/ 5 levels "0-30%","100%+",..: 5 2 3 3 2 5 5 2 5 5 ...
    ##  $ primary_heating_fuel: Factor w/ 9 levels "BOTTLED GAS",..: 8 8 8 8 8 8 8 8 8 8 ...
    ##  $ number_of_units     : Factor w/ 9 levels "1 UNIT ATTACHED",..: 2 2 2 2 2 2 2 2 6 2 ...
    ##  $ year_constructed    : Factor w/ 6 levels "1940-59","1960-79",..: 5 5 1 6 1 1 6 4 2 1 ...
    ##  $ households          : num  0.1181 2.618 0.0989 1.0301 0.2776 ...
    ##  $ annual_income       : num  49484 110956 23027 20005 73417 ...
    ##  $ electricity_spend   : num  120.9 100.2 89.6 98.5 97.6 ...
    ##  $ gas_spend           : num  26.1 33.3 69.1 103.8 68.9 ...
    ##  $ other_spend         : num  8.52e-11 8.45e-11 3.67e-01 8.48e-11 2.26 ...
    ##  $ acs_responses       : num  0.75 21.25 8.32 2.31 20.82 ...
    ##  $ min_age             : num  1 1 57 76 57 57 76 7 37 57 ...
    ##  $ min_units           : num  1 1 1 1 1 1 1 1 3 1 ...
    ##  $ detached            : Factor w/ 2 levels "0","1": 2 2 2 2 2 2 2 2 1 2 ...
    ##  $ mean_energy_cost    : num  147 133 159 202 169 ...
    ##  $ mean_energy_burden  : num  0.0356 0.0144 0.0829 0.1213 0.0276 ...
    ##  $ mean_eroi           : num  28.05 69.27 12.06 8.24 36.24 ...
    ##  $ energy_poverty      : logi  FALSE FALSE FALSE TRUE FALSE FALSE ...

``` r
data_reloaded <- read_csv(file.path(getwd(),"clean_lead.csv"),
                          col_types=cols(
                            geo_id = readr::col_character(),
                            state_id = readr::col_character(),
                            county_id = readr::col_character(),
                            tract_id = readr::col_character(),
                            puma10_code = readr::col_character(),
                            fmr_code = readr::col_character(),
                            occupancy_type = readr::col_factor(),
                            income_bracket = readr::col_factor(),
                            primary_heating_fuel = readr::col_factor(),
                            number_of_units = readr::col_factor(),
                            year_constructed = readr::col_factor(),
                            households = col_double(),
                            annual_income = col_double(),
                            electricity_spend = col_double(),
                            gas_spend = col_double(),
                            other_spend = col_double(),
                            acs_responses = col_double(),
                            min_age = col_double(),
                            min_units = col_double(),
                            detached = readr::col_factor(),
                            mean_energy_cost = col_double(),
                            mean_energy_burden = col_double(),
                            energy_poverty = col_logical()
                            ))

all(data_reloaded == data, na.rm=TRUE)
```

    ## [1] TRUE

``` r
summary(data_reloaded)
```

    ##     geo_id            state_id          county_id           tract_id        
    ##  Length:491368      Length:491368      Length:491368      Length:491368     
    ##  Class :character   Class :character   Class :character   Class :character  
    ##  Mode  :character   Mode  :character   Mode  :character   Mode  :character  
    ##                                                                             
    ##                                                                             
    ##                                                                             
    ##                                                                             
    ##  puma10_code          fmr_code         occupancy_type  income_bracket  
    ##  Length:491368      Length:491368      OWNER :256803   80-100%: 96257  
    ##  Class :character   Class :character   RENTER:234565   100%+  :108978  
    ##  Mode  :character   Mode  :character                   30-60% : 98471  
    ##                                                        0-30%  : 91432  
    ##                                                        60-80% : 96230  
    ##                                                                        
    ##                                                                        
    ##   primary_heating_fuel        number_of_units      year_constructed 
    ##  ELECTRICITY:210816    1 UNIT DETACHED:276507   2010+      : 20337  
    ##  UTILITY GAS:115165    OTHER UNIT     : 72714   1940-59    : 74304  
    ##  BOTTLED GAS: 73054    1 UNIT ATTACHED: 48004   BEFORE 1940: 52053  
    ##  FUEL OIL   : 48496    5-9 UNIT       : 21535   2000-09    : 82137  
    ##  WOOD       : 33840    3-4 UNIT       : 20631   1960-79    :122722  
    ##  NONE       :  7610    2 UNIT         : 20064   1980-99    :139815  
    ##  (Other)    :  2387    (Other)        : 31913                       
    ##    households        annual_income    electricity_spend   gas_spend      
    ##  Min.   :   0.0000   Min.   :     1   Min.   :  0.00    Min.   :  0.000  
    ##  1st Qu.:   0.3167   1st Qu.: 19167   1st Qu.: 78.01    1st Qu.:  0.000  
    ##  Median :   1.4079   Median : 32997   Median :106.98    Median :  7.181  
    ##  Mean   :   6.4595   Mean   : 41054   Mean   :111.00    Mean   : 27.091  
    ##  3rd Qu.:   5.0883   3rd Qu.: 49320   3rd Qu.:138.26    3rd Qu.: 41.142  
    ##  Max.   :1242.1053   Max.   :893731   Max.   :783.47    Max.   :704.908  
    ##                                                                          
    ##   other_spend      acs_responses         min_age        min_units    
    ##  Min.   :  0.000   Min.   :  0.0017   Min.   : 1.00   Min.   : 1.00  
    ##  1st Qu.:  0.000   1st Qu.:  1.0000   1st Qu.:17.00   1st Qu.: 1.00  
    ##  Median :  0.000   Median :  2.4950   Median :37.00   Median : 1.00  
    ##  Mean   : 11.362   Mean   :  8.3046   Mean   :31.96   Mean   : 2.82  
    ##  3rd Qu.:  5.282   3rd Qu.:  7.0200   3rd Qu.:57.00   3rd Qu.: 1.00  
    ##  Max.   :329.107   Max.   :644.7600   Max.   :76.00   Max.   :50.00  
    ##                                                       NA's   :72714  
    ##  detached      mean_energy_cost  mean_energy_burden    mean_eroi       
    ##  1   :276507   Min.   :  1.117   Min.   :   0.0004   Min.   :   0.001  
    ##  0   :142147   1st Qu.:100.873   1st Qu.:   0.0288   1st Qu.:  11.118  
    ##  NA's: 72714   Median :141.645   Median :   0.0501   Median :  19.962  
    ##                Mean   :149.450   Mean   :   0.1134   Mean   :  27.787  
    ##                3rd Qu.:182.144   3rd Qu.:   0.0899   3rd Qu.:  34.717  
    ##                Max.   :935.561   Max.   :1034.1000   Max.   :2308.418  
    ##                                                                        
    ##  energy_poverty 
    ##  Mode :logical  
    ##  FALSE:384372   
    ##  TRUE :106996   
    ##                 
    ##                 
    ##                 
    ## 

Adding additional data
======================

Additional features to merge from the American Community Survey:

B01003\_001E Estimate!!Total TOTAL POPULATION

-   Gender: Percent Non Male ++ B01001\_002E: Estimate!!Total!!Male SEX
    BY AGE
-   Age: Median Age ++ B01002\_001E: MEDIAN AGE BY SEX
-   Wealth: Median Income ++ B06011\_001E Estimate!!Median income in the
    past 12 months!!Total MEDIAN INCOME IN THE PAST 12 MONTHS (IN 2016
    INFLATION-ADJUSTED DOLLARS)
-   Education: Percent with less than high school education ++
    B06009\_002E Estimate!!Total!!Less than high school graduate PLACE
    OF BIRTH BY EDUCATIONAL ATTAINMENT IN THE UNITED STATES
-   Race/ethnicity: Percent Non White ++ B02001\_002E
    Estimate!!Total!!White alone RACE

Not examined in this analysis + Employment + Socioeconomic status +
Geography + Climate + Energy Efficiency

``` r
library(tidycensus)

acs_variables <- list(
  total_males = sym("B01001_002"),
  total_population = sym("B01003_001"),
  median_age = sym("B01002_001"),
  no_high_school = sym("B06009_001"),
  total_white = sym("B02001_002"),
  median_income = sym("B06011_001"),
  acs_total_households = sym("B25001_001")
)

acs_features <- get_acs(state = "NC", 
                    geography = "tract",
                    variables = as.character(unlist(acs_variables)),
                    year = 2016,
                    output = "tidy",
                    geometry = FALSE)
```

    ## Getting data from the 2012-2016 5-year ACS

``` r
acs_features <- pivot_wider(acs_features, id_cols=c("GEOID"),
                            names_from=c("variable"),
                            values_from=c("estimate"))
acs_features <- rename(acs_features, !!!acs_variables)
head(acs_features)
```

    ## # A tibble: 6 x 8
    ##   GEOID total_males median_age total_population total_white no_high_school
    ##   <chr>       <dbl>      <dbl>            <dbl>       <dbl>          <dbl>
    ## 1 3700…        2070       38.3             4224        2461           2905
    ## 2 3700…        1689       35.3             4021        1860           2582
    ## 3 3700…        3381       35.1             7823        3904           4883
    ## 4 3700…        2918       33.2             6861        1363           4193
    ## 5 3700…        1585       42.4             3515        2345           2312
    ## 6 3700…        1896       32.6             3816        1691           2311
    ## # … with 2 more variables: median_income <dbl>, acs_total_households <dbl>

``` r
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

data <- left_join(data, select(acs_features, final_acs_variables) %>% mutate(geo_id=as.character(geo_id)), by="geo_id")
```

    ## Note: Using an external vector in selections is ambiguous.
    ## ℹ Use `all_of(final_acs_variables)` instead of `final_acs_variables` to silence this message.
    ## ℹ See <https://tidyselect.r-lib.org/reference/faq-external-vector.html>.
    ## This message is displayed once per session.

``` r
write_csv(data,"clean_lead.csv")
```

``` r
data_reloaded <- read_csv(file.path(getwd(),"clean_lead.csv"),
                          col_types=cols(
                            geo_id = readr::col_character(),
                            state_id = readr::col_character(),
                            county_id = readr::col_character(),
                            tract_id = readr::col_character(),
                            puma10_code = readr::col_character(),
                            fmr_code = readr::col_character(),
                            occupancy_type = readr::col_factor(),
                            income_bracket = readr::col_factor(),
                            primary_heating_fuel = readr::col_factor(),
                            number_of_units = readr::col_factor(),
                            year_constructed = readr::col_factor(),
                            households = col_double(),
                            annual_income = col_double(),
                            electricity_spend = col_double(),
                            gas_spend = col_double(),
                            other_spend = col_double(),
                            acs_responses = col_double(),
                            min_age = col_double(),
                            min_units = col_double(),
                            detached = readr::col_factor(),
                            mean_energy_cost = col_double(),
                            mean_energy_burden = col_double(),
                            energy_poverty = col_logical(),
                            pct_non_male = col_double(), 
                            median_age = col_double(),
                            pct_no_high_school = col_double(),
                            pct_non_white = col_double(),
                            median_income = col_double(),
                            acs_total_households = col_double()
                            ))

all(data_reloaded == data, na.rm=TRUE)
```

    ## [1] TRUE

``` r
summary(data_reloaded)
```

    ##     geo_id            state_id          county_id           tract_id        
    ##  Length:491368      Length:491368      Length:491368      Length:491368     
    ##  Class :character   Class :character   Class :character   Class :character  
    ##  Mode  :character   Mode  :character   Mode  :character   Mode  :character  
    ##                                                                             
    ##                                                                             
    ##                                                                             
    ##                                                                             
    ##  puma10_code          fmr_code         occupancy_type  income_bracket  
    ##  Length:491368      Length:491368      OWNER :256803   80-100%: 96257  
    ##  Class :character   Class :character   RENTER:234565   100%+  :108978  
    ##  Mode  :character   Mode  :character                   30-60% : 98471  
    ##                                                        0-30%  : 91432  
    ##                                                        60-80% : 96230  
    ##                                                                        
    ##                                                                        
    ##   primary_heating_fuel        number_of_units      year_constructed 
    ##  ELECTRICITY:210816    1 UNIT DETACHED:276507   2010+      : 20337  
    ##  UTILITY GAS:115165    OTHER UNIT     : 72714   1940-59    : 74304  
    ##  BOTTLED GAS: 73054    1 UNIT ATTACHED: 48004   BEFORE 1940: 52053  
    ##  FUEL OIL   : 48496    5-9 UNIT       : 21535   2000-09    : 82137  
    ##  WOOD       : 33840    3-4 UNIT       : 20631   1960-79    :122722  
    ##  NONE       :  7610    2 UNIT         : 20064   1980-99    :139815  
    ##  (Other)    :  2387    (Other)        : 31913                       
    ##    households        annual_income    electricity_spend   gas_spend      
    ##  Min.   :   0.0000   Min.   :     1   Min.   :  0.00    Min.   :  0.000  
    ##  1st Qu.:   0.3167   1st Qu.: 19167   1st Qu.: 78.01    1st Qu.:  0.000  
    ##  Median :   1.4079   Median : 32997   Median :106.98    Median :  7.181  
    ##  Mean   :   6.4595   Mean   : 41054   Mean   :111.00    Mean   : 27.091  
    ##  3rd Qu.:   5.0883   3rd Qu.: 49320   3rd Qu.:138.26    3rd Qu.: 41.142  
    ##  Max.   :1242.1053   Max.   :893731   Max.   :783.47    Max.   :704.908  
    ##                                                                          
    ##   other_spend      acs_responses         min_age        min_units    
    ##  Min.   :  0.000   Min.   :  0.0017   Min.   : 1.00   Min.   : 1.00  
    ##  1st Qu.:  0.000   1st Qu.:  1.0000   1st Qu.:17.00   1st Qu.: 1.00  
    ##  Median :  0.000   Median :  2.4950   Median :37.00   Median : 1.00  
    ##  Mean   : 11.362   Mean   :  8.3046   Mean   :31.96   Mean   : 2.82  
    ##  3rd Qu.:  5.282   3rd Qu.:  7.0200   3rd Qu.:57.00   3rd Qu.: 1.00  
    ##  Max.   :329.107   Max.   :644.7600   Max.   :76.00   Max.   :50.00  
    ##                                                       NA's   :72714  
    ##  detached      mean_energy_cost  mean_energy_burden    mean_eroi       
    ##  1   :276507   Min.   :  1.117   Min.   :   0.0004   Min.   :   0.001  
    ##  0   :142147   1st Qu.:100.873   1st Qu.:   0.0288   1st Qu.:  11.118  
    ##  NA's: 72714   Median :141.645   Median :   0.0501   Median :  19.962  
    ##                Mean   :149.450   Mean   :   0.1134   Mean   :  27.787  
    ##                3rd Qu.:182.144   3rd Qu.:   0.0899   3rd Qu.:  34.717  
    ##                Max.   :935.561   Max.   :1034.1000   Max.   :2308.418  
    ##                                                                        
    ##  energy_poverty   pct_non_male       median_age    pct_no_high_school
    ##  Mode :logical   Min.   :0.03872   Min.   :18.70   Min.   :0.02061   
    ##  FALSE:384372    1st Qu.:0.49504   1st Qu.:35.30   1st Qu.:0.64930   
    ##  TRUE :106996    Median :0.51667   Median :40.50   Median :0.69324   
    ##                  Mean   :0.51543   Mean   :40.07   Mean   :0.68497   
    ##                  3rd Qu.:0.53682   3rd Qu.:44.40   3rd Qu.:0.72900   
    ##                  Max.   :0.64745   Max.   :66.90   Max.   :0.99296   
    ##                                                                      
    ##  pct_non_white    median_income   acs_total_households
    ##  Min.   :0.0000   Min.   : 2499   Min.   :   3        
    ##  1st Qu.:0.1095   1st Qu.:20143   1st Qu.:1518        
    ##  Median :0.2412   Median :23608   Median :1997        
    ##  Mean   :0.3049   Mean   :25324   Mean   :2100        
    ##  3rd Qu.:0.4582   3rd Qu.:29054   3rd Qu.:2587        
    ##  Max.   :0.9970   Max.   :94750   Max.   :7194        
    ## 

Bring in Electric Service Provider Data
---------------------------------------

``` r
erst <- read_csv(file.path(getwd(),"clean_erst.csv"),
                          col_types=cols(
                            tract_id = readr::col_character(),
                            utility_id = readr::col_character(),
                            percent_tract_served = readr::col_double(),
                            tract_households_served = readr::col_double(),
                            utility_name = readr::col_character(),
                            ownership_type = readr::col_factor(NULL),
                            balancing_authority = readr::col_factor(NULL),
                            retail_revenue_thousands = readr::col_double(),
                            retail_sales_MWh = readr::col_double(),
                            retail_customers = readr::col_double(),
                            implied_price_kWh = readr::col_double(),
                            revenue_per_customer = readr::col_double()))

data <- left_join(data, erst, by="tract_id")


# Calculate implied electricity usage
data$implied_electricity_use <- data$electricity_spend/data$implied_price_kWh

write_csv(data, "clean_lead.csv")
```

``` r
data_reloaded <- read_csv(file.path(getwd(),"clean_lead.csv"),
                          col_types=cols(
                            geo_id = readr::col_character(),
                            state_id = readr::col_character(),
                            county_id = readr::col_character(),
                            tract_id = readr::col_character(),
                            puma10_code = readr::col_character(),
                            fmr_code = readr::col_character(),
                            occupancy_type = readr::col_factor(),
                            income_bracket = readr::col_factor(),
                            primary_heating_fuel = readr::col_factor(),
                            number_of_units = readr::col_factor(),
                            year_constructed = readr::col_factor(),
                            households = col_double(),
                            annual_income = col_double(),
                            electricity_spend = col_double(),
                            gas_spend = col_double(),
                            other_spend = col_double(),
                            acs_responses = col_double(),
                            min_age = col_double(),
                            min_units = col_double(),
                            detached = readr::col_factor(NULL),
                            mean_energy_cost = col_double(),
                            mean_energy_burden = col_double(),
                            energy_poverty = col_logical(),
                            pct_non_male = col_double(), 
                            median_age = col_double(),
                            pct_no_high_school = col_double(),
                            pct_non_white = col_double(),
                            median_income = col_double(),
                            acstotal_households = col_double(),
                            utility_id = readr::col_factor(),
                            percent_tract_served = readr::col_double(),
                            tract_households_served = readr::col_double(),
                            utility_name = readr::col_character(),
                            ownership_type = readr::col_factor(NULL),
                            balancing_authority = readr::col_factor(NULL),
                            retail_revenue_thousands = readr::col_double(),
                            retail_sales_MWh = readr::col_double(),
                            retail_customers = readr::col_double(),
                            implied_price_kWh = readr::col_double(),
                            revenue_per_customer = readr::col_double(),
                            implied_electricity_use = readr::col_double()))
```

    ## Warning: The following named parsers don't match the column names:
    ## acstotal_households

``` r
all(data_reloaded == data, na.rm=TRUE)
```

    ## [1] TRUE

``` r
summary(data_reloaded)
```

    ##     geo_id            state_id          county_id           tract_id        
    ##  Length:1365556     Length:1365556     Length:1365556     Length:1365556    
    ##  Class :character   Class :character   Class :character   Class :character  
    ##  Mode  :character   Mode  :character   Mode  :character   Mode  :character  
    ##                                                                             
    ##                                                                             
    ##                                                                             
    ##                                                                             
    ##  puma10_code          fmr_code         occupancy_type  income_bracket  
    ##  Length:1365556     Length:1365556     OWNER :700949   80-100%:266662  
    ##  Class :character   Class :character   RENTER:664607   100%+  :302307  
    ##  Mode  :character   Mode  :character                   30-60% :271988  
    ##                                                        0-30%  :259493  
    ##                                                        60-80% :265106  
    ##                                                                        
    ##                                                                        
    ##   primary_heating_fuel        number_of_units      year_constructed 
    ##  ELECTRICITY:569360    1 UNIT DETACHED:770295   2010+      : 50835  
    ##  UTILITY GAS:292705    OTHER UNIT     :222582   1940-59    :216102  
    ##  BOTTLED GAS:219684    1 UNIT ATTACHED:116561   BEFORE 1940:160233  
    ##  FUEL OIL   :149508    2 UNIT         : 62636   2000-09    :214927  
    ##  WOOD       :105016    3-4 UNIT       : 60241   1960-79    :345927  
    ##  NONE       : 21431    5-9 UNIT       : 54948   1980-99    :377532  
    ##  (Other)    :  7852    (Other)        : 78293                       
    ##    households        annual_income    electricity_spend   gas_spend      
    ##  Min.   :   0.0000   Min.   :     1   Min.   :  0.00    Min.   :  0.000  
    ##  1st Qu.:   0.3122   1st Qu.: 18363   1st Qu.: 77.81    1st Qu.:  0.000  
    ##  Median :   1.3920   Median : 31636   Median :107.31    Median :  6.614  
    ##  Mean   :   6.0122   Mean   : 39411   Mean   :111.66    Mean   : 27.825  
    ##  3rd Qu.:   4.9863   3rd Qu.: 47147   3rd Qu.:139.66    3rd Qu.: 41.554  
    ##  Max.   :1242.1053   Max.   :893731   Max.   :783.47    Max.   :704.908  
    ##                                                                          
    ##   other_spend      acs_responses         min_age        min_units     
    ##  Min.   :  0.000   Min.   :  0.0017   Min.   : 1.00   Min.   : 1.00   
    ##  1st Qu.:  0.000   1st Qu.:  1.0000   1st Qu.:17.00   1st Qu.: 1.00   
    ##  Median :  0.000   Median :  2.4393   Median :37.00   Median : 1.00   
    ##  Mean   : 12.463   Mean   :  7.8419   Mean   :33.15   Mean   : 2.68   
    ##  3rd Qu.:  7.431   3rd Qu.:  6.8040   3rd Qu.:57.00   3rd Qu.: 1.00   
    ##  Max.   :329.107   Max.   :644.7600   Max.   :76.00   Max.   :50.00   
    ##                                                       NA's   :222582  
    ##  detached      mean_energy_cost  mean_energy_burden    mean_eroi       
    ##  1   :770295   Min.   :  1.117   Min.   :   0.0004   Min.   :   0.001  
    ##  0   :372679   1st Qu.:101.826   1st Qu.:   0.0302   1st Qu.:  10.511  
    ##  NA's:222582   Median :143.359   Median :   0.0531   Median :  18.830  
    ##                Mean   :151.946   Mean   :   0.1227   Mean   :  26.501  
    ##                3rd Qu.:186.354   3rd Qu.:   0.0951   3rd Qu.:  33.116  
    ##                Max.   :935.561   Max.   :1034.1000   Max.   :2308.418  
    ##                                                                        
    ##  energy_poverty   pct_non_male       median_age    pct_no_high_school
    ##  Mode :logical   Min.   :0.03872   Min.   :18.70   Min.   :0.02061   
    ##  FALSE:1045150   1st Qu.:0.49328   1st Qu.:36.00   1st Qu.:0.65664   
    ##  TRUE :320406    Median :0.51518   Median :41.10   Median :0.69957   
    ##                  Mean   :0.51346   Mean   :40.47   Mean   :0.68911   
    ##                  3rd Qu.:0.53682   3rd Qu.:45.30   3rd Qu.:0.73259   
    ##                  Max.   :0.64745   Max.   :66.90   Max.   :0.99296   
    ##                                                                      
    ##  pct_non_white    median_income   acs_total_households   utility_id    
    ##  Min.   :0.0000   Min.   : 2499   Min.   :   3         31     :525914  
    ##  1st Qu.:0.1096   1st Qu.:19126   1st Qu.:1534         34     :239779  
    ##  Median :0.2703   Median :22243   Median :2061         22     : 99228  
    ##  Mean   :0.3171   Mean   :23552   Mean   :2154         27     : 63552  
    ##  3rd Qu.:0.4692   3rd Qu.:26190   3rd Qu.:2721         12     : 50394  
    ##  Max.   :0.9970   Max.   :94750   Max.   :7194         (Other):380235  
    ##                                                        NA's   :  6454  
    ##  tract_households_served percent_tract_served utility_name      
    ##  Min.   :  35            Min.   :0.1316       Length:1365556    
    ##  1st Qu.:2420            1st Qu.:0.2655       Class :character  
    ##  Median :3296            Median :0.4227       Mode  :character  
    ##  Mean   :3528            Mean   :0.4871                         
    ##  3rd Qu.:4279            3rd Qu.:0.6355                         
    ##  Max.   :9756            Max.   :1.0000                         
    ##                                                                 
    ##         ownership_type   balancing_authority retail_revenue_thousands
    ##  Cooperative   :526578   DUK :470107         Min.   :   1563         
    ##  Investor Owned:806052   CPLE:728764         1st Qu.:  51736         
    ##  Municipal     : 25920   PJM :152473         Median :1700964         
    ##  NA's          :  7006   TVA :  7206         Mean   :1087812         
    ##                          NA's:  7006         3rd Qu.:1700964         
    ##                                              Max.   :2251968         
    ##                                              NA's   :7006            
    ##  retail_sales_MWh   retail_customers  implied_price_kWh revenue_per_customer
    ##  Min.   :   12288   Min.   :   1295   Min.   :0.102     Min.   :0.001       
    ##  1st Qu.:  410152   1st Qu.:  33551   1st Qu.:0.108     1st Qu.:0.001       
    ##  Median :15785056   Median :1162473   Median :0.108     Median :0.001       
    ##  Mean   :10201971   Mean   : 764948   Mean   :0.113     Mean   :0.002       
    ##  3rd Qu.:15785056   3rd Qu.:1162473   3rd Qu.:0.124     3rd Qu.:0.002       
    ##  Max.   :21615228   Max.   :1669923   Max.   :0.146     Max.   :0.002       
    ##  NA's   :7006       NA's   :7006      NA's   :7006      NA's   :7006        
    ##  implied_electricity_use
    ##  Min.   :   0.0         
    ##  1st Qu.: 685.6         
    ##  Median : 945.8         
    ##  Mean   : 989.9         
    ##  3rd Qu.:1232.8         
    ##  Max.   :7270.6         
    ##  NA's   :7006
