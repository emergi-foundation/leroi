``` r
knitr::opts_chunk$set(echo = TRUE)

library(tidyverse)
```

    ## ── Attaching packages ────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── tidyverse 1.3.0 ──

    ## ✓ ggplot2 3.2.1     ✓ purrr   0.3.3
    ## ✓ tibble  2.1.3     ✓ dplyr   0.8.3
    ## ✓ tidyr   1.0.2     ✓ stringr 1.4.0
    ## ✓ readr   1.3.1     ✓ forcats 0.4.0

    ## ── Conflicts ───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────── tidyverse_conflicts() ──
    ## x dplyr::filter() masks stats::filter()
    ## x dplyr::lag()    masks stats::lag()

``` r
library(readxl)
```

Introduction
============

``` r
acs_date <- 2016
```

This is an exploratory data analysis of the Low Income Energy
Affordability Data
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

``` r
base_url <- "https://openei.org/doe-opendata/dataset/9dcd443b-c0e5-4d4a-b764-5a8ff0c2c92b/resource/831ac481-1a60-4f87-a887-15b310ffff53/download/"


file_name <- "ami68tractshnc"
data_url <- paste0(base_url,file_name,".csv")
desired_name <- paste0(file_name,".csv")
desired_path <- file.path(desired_name)

download.file(data_url,desired_path)
```

A full data dictionary is available, and downloaded below.

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
temp <- tempfile()
download.file(url,temp,mode="wb")
path <- temp
path %>%
  excel_sheets() %>%
  set_names() %>% 
  map(read_then_csv, path = path)
```

    ## New names:
    ## * `` -> ...1
    ## * `` -> ...2
    ## * `` -> ...3
    ## * `` -> ...4
    ## * `` -> ...5
    ## * … and 3 more problems

    ## $`Data Dictionary`
    ## # A tibble: 53 x 8
    ##    ...1   ...2     ...3          ...4  ...5  ...6  ...7   ...8                  
    ##    <chr>  <chr>    <chr>         <chr> <chr> <chr> <chr>  <chr>                 
    ##  1 YBL I… <NA>     Year of buil… <NA>  <NA>  <NA>  UNITS  Number of occupied ho…
    ##  2 0      2010+    <NA>          <NA>  <NA>  <NA>  HINCP  Average annual househ…
    ##  3 1      2000-09  <NA>          <NA>  <NA>  <NA>  ELEP   Original American Com…
    ##  4 2      1980-99  <NA>          <NA>  <NA>  <NA>  ELEP … Calibrated American C…
    ##  5 3      1960-79  <NA>          <NA>  <NA>  <NA>  GASP   Original American Com…
    ##  6 4      1940-59  <NA>          <NA>  <NA>  <NA>  GASP … Calibrated American C…
    ##  7 5      BEFORE … <NA>          <NA>  <NA>  <NA>  GASP-… Calibrated American C…
    ##  8 <NA>   <NA>     <NA>          <NA>  <NA>  <NA>  FULP   Original American Com…
    ##  9 BLD I… <NA>     Number of un… <NA>  <NA>  <NA>  COUNT  Average number of ACS…
    ## 10 0      1 UNIT … <NA>          <NA>  <NA>  <NA>  <NA>   <NA>                  
    ## # … with 43 more rows

``` r
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
burden_dict <- rbind(burden_dict, names(hfl_dict), names(bld_dict), names(ybl_dict))
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

-   Remove rows where `UNITS<1`.
-   Seperate the `AMI68` column into `occupancy_type` and
    `income_bracket` columns
-   Create `min_age` from `YBL INDEX`.
-   Create `min_units` from `BLD INDEX`.
-   Create `detached` from `BLD INDEX`.

Remove Fractional Units
-----------------------

The estimation procedure used by the DOE results in an estimated number
of occupied housing units meeting the subset characteristics (`UNITS`)
and displays the number of American Community Survey responses that
contribute to the estimate of energy expenditures (`COUNT`). We first
remove any categories that have fewer than 1 unit represented, since
this is not physically possible.

``` r
#Remove rows where `UNITS<1`.

data <- data[data$UNITS>=1,]
```

This results in removing 0% of the available rows (gross: 0 rows of
296679). This is a total of 0 housing units, or 0% of the estimated
total 3.168291210^{6} units in the state.

Break Out Ownership & Income Bracket
------------------------------------

The data combines the unit’s ownership status (`OWNER` vs. `RENTER`) and
income bracket as a fraction of Area Median Income (`0-30%`, `30-60%`,
`60-80%`, `80-100%`, or `100%+`) into the same column (e.g. OWNER
100%+). This `AMI68` column needs to be seperated for meaningful
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

``` r
#Create `min_age` from `YBL INDEX`.
```

``` r
#Create `min_units` from `BLD INDEX`.
```

``` r
#Create `detached` from `BLD INDEX`.
```

Questions:

-   How many ACS survey responses inform each segment? (`COUNT` vs
    `UNITS`)
-   Are there any trends in the energy burden based on age,
    units/building, home ownership, home attachment, ?
-   Perform a principal component analysis
-   Does `YBL INDEX` or `min_age` better explain the energy burden
    variance?
-   Does `BLD INDEX` or `min_units` better explain the energy burden
    variance?
