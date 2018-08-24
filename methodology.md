I believe to aggregate this data we will have to turn Income Level and Occupation type into their own columns, or find a way to do our math so that the columns with the same data types match.

So we need the primary key to be:

TRACT: Census Tract
PUMA10: Public Use Microdata Areas
COUNTY: County
COUSUB: County Subdivision
YBL INDEX: Year of building first construction (index, 0-5)
BLD INDEX: Number of units in each building (index, 0-8)
HFL INDEX: Primary heating fuel type (index, 0-8)
*OCCUPANCY*: Renter or Owner Occupied
*INCOME_STRATA*: Income level relative to poverty line

So all of the stratified columns such as OWNER ELEP 30-50% would instead just become ELEP, with OWNER represented in the OCCUPANCY column and 30-50% represented in the INCOME_STRATA column. We will have the following columns of data:

COUNT: Housing Unit Counts
HINC: Household Income ($/year)
ELEP: Electricity Expenditures ($/month)
GASP: Gas Expenditures ($/month)
FULP: Other Fuel Expenditures ($/month)

Then we can create energy burden for each row quite easily: ENERGY_BURDEN = 12 * (ELEP + GASP + FULP) /  HINC

And from this dataset we can calculate the weighted average housing burden in any area (TRACT, PUMA10, COUNTY, COUSUB) using the Housing Unit Counts (COUNT) as the weighting factor.

For aggregating by YBL, BLD, and HFL we can use the Housing Unit Counts (COUNT) to create a weighting factor just as we would when aggregating beyond OCCUPANCY and INCOME_STRATA.

nc census tract data: https://openei.org/doe-opendata/dataset/9dcd443b-c0e5-4d4a-b764-5a8ff0c2c92b/resource/4e994236-813f-436f-8e8c-fb38543ba432/download/tractnc2015.csv