import pandas as pd
import numpy as np
import itertools
import re
import weightedcalcs as wc

lead_data = pd.read_csv("tractnc2015.csv")

primary_key = ["TRACT","PUMA10","COUNTY","COUSUB","YBL INDEX","BLD INDEX","HFL INDEX"]
occupancy_types = ["OWNER","RENTER"]
data_types = ["ELEP","GASP","FULP","HINCP",""]
income_strata = ["0-30%","30-50%","50-80%","80-100%","100%+"]

inputdata = [occupancy_types, data_types, income_strata]
data_columns = list(itertools.product(*inputdata))

data_columns = [re.sub(' +',' ',' '.join(x)) for x in data_columns]

lead_data["TRACT"] = lead_data["TRACT"].astype("int")
lead_data["COUSUB"] = lead_data["COUSUB"].astype("int")
lead_data["COUNTY"] = lead_data["COUNTY"].astype("int")
lead_data["PUMA10"] = lead_data["PUMA10"].astype("int")
lead_data["BLD INDEX"] = lead_data["BLD INDEX"].astype("int")
lead_data["YBL INDEX"] = lead_data["YBL INDEX"].astype("int")
lead_data["HFL INDEX"] = lead_data["HFL INDEX"].astype("int")

long_lead_data = lead_data.set_index(primary_key, inplace=False)[data_columns]

count_rename_dict = {' '.join(x):' '.join(y) for x,y in zip(list(itertools.product(*[occupancy_types, income_strata])), list(itertools.product(*[occupancy_types,["COUNT"], income_strata])))}

long_lead_data.rename(mapper=count_rename_dict, axis=1, inplace=True)
long_lead_data.columns = long_lead_data.columns.str.split(' ', expand=True)

long_lead_data.columns.rename(names=['OCCUPANCY TYPE','INCOME STRATA'], level=[0,2], inplace=True)

wide_lead_data = long_lead_data.stack(level=[0,2])
wide_lead_data["ENERGY BURDEN"] = 12 * (wide_lead_data["ELEP"] + wide_lead_data["GASP"] + wide_lead_data["FULP"]) / wide_lead_data["HINCP"]

features = ['TRACT','YBL INDEX','BLD INDEX','HFL INDEX','OCCUPANCY TYPE','INCOME STRATA']

calc = wc.Calculator("COUNT")
nicely_grouped = wide_lead_data.groupby(features)
print("trying to calc")
print(calc.mean(nicely_grouped, "ELEP").head())

#fully_aggregated = tract_aggregated.groupby("TRACT").apply(wtavg)

#tract_aggregated.to_csv("tractnc2015_cleaned.csv")

#fully_aggregated.to_csv("tractnc2015_aggregated.csv")