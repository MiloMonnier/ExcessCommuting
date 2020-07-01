library(RPostgreSQL)
library(sf)
library(DescTools)
library(transport)
library(reshape2)
library(data.table)
source("utils/XS_utils_admin.R")
options(stringsAsFactors=FALSE)
options(scipen=10000) # Avoid scientific notation

# PostgreSQL database identifiers
drv      = dbDriver("PostgreSQL")
host     = "localhost"
port     = 5432
dbname   = "XS"
user     = "milo"
password = "postgres"
lapply(dbListConnections(PostgreSQL()), dbDisconnect) # Kill all connexions

files = c(
  "aus_tz_2011",
  "can_cd_2016",
  "can_csd_2016",
  "dnk_kom_2017",
  "esp_mun_2011",
  "fra_com_2015",
  "fra_can_2015",
  "gbr_oa_2001",
  "gbr_msoa_2011",
  "ita_com_2011",
  "usa_cou_2015",
  "usa_mcd_2015"
)

# Separate file containing EPSG codes is used to control CRS of each country
epsg_countries = read.csv2("epsg_countries.csv", sep=",")

# For each country, generate outputs for the n greatest cities
cities = readRDS("data/world_cities/world_cities.rds")
n_cities = 50

radius = c(10000, 20000)

i=1
for (i in 1:length(files)) {
  
  file = files[i]
  country = substr(file, 1, 3)
  epsg = epsg_countries[epsg_countries$country==country, "epsg"]

  # Take the n greatest cities of this country
  cit = cities[cities$country==toupper(country), ]
  cit = cit[1:min(c(nrow(cit), n_cities)), ]
  
  for (j in 1:nrow(cit)) {
    for (k in 1:length(radius)) {
      
      city = cit[j, "name"]
      rad = radius[k]
      sim = paste(file, city, rad, sep="_")
      outfile = paste0("outputs/", sim, ".rds")

      # Don't compute output if already exists
      if (!file.exists(outfile)) {
        print(paste(sim, "already exists"))
        next
      }
      # Compute XS function and save result
      conn = dbConnect(drv, dbname=dbname, host=host, port=port, user=user, password=password)
      res = xsGrid(conn, file, city, rad)
      saveRDS(res, outfile)
    }
  }
}