import numpy as np
# import xarray as xr
import metpy.calc
from metpy.calc import cape_cin, dewpoint_from_relative_humidity, parcel_profile, showalter_index,equivalent_potential_temperature,get_layer,moist_lapse
from metpy.units import units
# # from wrf import interpz3d,getvar
# from numpy import sqrt,mod,arctan2
# # import os
# # import pandas as pd
# # import shutil
# # import xlrd
# # import xlwt
# # import matplotlib 
import proplot as pplt
# import matplotlib.pyplot as plt
# import matplotlib.dates as mdate
# from netCDF4 import Dataset
# from datetime import datetime