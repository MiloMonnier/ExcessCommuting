## For each country, this script cleans the raw mobility table and the raw 
## boundary shapefile associated.
## Ouputs are:
## 1 - Mobility table (orig, dest, weight) --> country_scale_year_mob.rds
## 2 - Boundaries shapefile (id, geometry)  --> country_scale_year_shp.rds

library(data.table)
library(sf)

options(stringsAsFactors=FALSE)
formals(saveRDS)$compress = FALSE # Don't compress .rds files to fasten import and export

# A separate file controls CRS used for each country
epsg_countries = read.csv2("epsg_countries.csv", sep=",")

# At the end of each clean, mobility table and shapefile table are checked
checkMobShp = function(mob, shp) {
  print(paste(length(unique(mob$orig)), "different origins"))
  print(paste(length(unique(mob$dest)), "different destinations"))
  print(paste(length(mob$orig[is.na(mob$orig)]), "empty origins"))
  print(paste(length(mob$dest[is.na(mob$dest)]), "empty destinations"))
  if (length(unique(nchar(mob$orig)))>1) {
    warning("Heterogeneous mob$orig number of characters")
  } else {
    print("mob$orig ok")
  }
  if (length(unique(nchar(mob$dest)))>1) {
    warning("Heterogeneous mob$dest number of characters")
  } else {
    print("mob$dest ok")
  }
  if (length(shp$id[duplicated(shp$id)])) {
    warning(paste(length(shp$id[duplicated(shp$id)]), "duplicated shp ids"))
  } else {
    print("shp ids ok")
  }
  mobids = unique(c(mob$orig, mob$dest))   # Matching MOB - SHP
  if (length(mobids[!mobids %in% shp$id])) {
    warning(paste(length(mobids[!mobids %in% shp$id]), "mob ids does not match shp ids"))
  } else {
    print("shp ids ok")
  }
}


# AUSTRALIA ---------------------------------------------------------------

country = "aus"
year = 2011

##### Travel Zones (TZs)
scale = "tz" 
# Mobility table
mob = fread("data/aus/raw/2011JTW_Table11_V1.3.csv")
mob = mob[, c("O_TZ11", "D_TZ11", "EMPLOYED_PERSONS")]
colnames(mob) = c("orig", "dest", "weight")
mob = mob[!is.na(mob$orig),]
mob$orig = formatC(mob$orig, width=4, format="d", flag="0")  # Add leading zeros
mob$dest = formatC(mob$dest, width=4, format="d", flag="0")
mob$weight = round(as.numeric(mob$weight))
# Boundary shapefile
shp = st_read(dsn="data/aus/raw/TZ_NSW_2011.shp", quiet=TRUE)
epsg = epsg_countries[epsg_countries$country==country, "epsg"]
shp = st_transform(shp, epsg) # Reproject it
shp$id = formatC(shp$TZ_CODE11, width=4, format="d", flag="0")  # Add leading zeros
shp = shp[, c("id", "geometry")]
# Check and save
file = paste(country, scale, year, sep="_")
print(paste("Check", file))
checkMobShp(mob, shp)
fwrite(mob, paste0("data/", country, "/", file, "_mob.csv"))
saveRDS(shp, paste0("data/", country, "/", file, "_admin.rds"))



# CANADA ------------------------------------------------------------------

country = "can"
year = 2016

#### Census Divisions (CDs)
scale = "cd"
# Mobility table
mob = fread(file="data/can/raw/CDs/98-400-X2016391_English_CSV_data.csv")
mob = mob[, c(2,8,16)]
colnames(mob) = c("orig", "dest", "weight")
mob$orig = as.character(mob$orig)
mob$dest = as.character(mob$dest)
# Boundary shapefile
shp = st_read("data/can/raw/CDs/lcd_000b16a_e.shp", quiet=TRUE)
epsg = epsg_countries[epsg_countries$country==country, "epsg"]
shp = st_transform(shp, epsg) # Reproject it
shp$id = as.character(shp$CDUID)
shp = shp[, c("id", "geometry")]
# Check and save
file = paste(country, scale, year, sep="_")
print(paste("Check", file))
checkMobShp(mob, shp)
fwrite(mob, paste0("data/", country, "/", file, "_mob.csv"))
saveRDS(shp, paste0("data/", country, "/", file, "_admin.rds"))


#### Census Subdivisions (CSDs)
scale = "csd"
# Mobility table
mob = fread("data/can/raw/CSDs/98-400-X2016325_English_CSV_data.csv")
mob = mob[, c(2,9,16)]
colnames(mob) = c("orig", "dest", "weight")
mob$orig = as.character(mob$orig)
mob$dest = as.character(mob$dest)
# Boundary shapefile
shp = st_read(dsn="data/can/raw/CSDs/lcsd000b16a_e.shp", quiet=TRUE)
epsg = epsg_countries[epsg_countries$country==country, "epsg"]
shp = st_transform(shp, epsg) # Reproject it
shp$id = as.character(shp$CSDUID)
shp = shp[, c("id", "geometry")]
# Check and save
file = paste(country, scale, year, sep="_")
print(paste("Check", file))
checkMobShp(mob, shp)
fwrite(mob, paste0("data/", country, "/", file, "_mob.csv"))
saveRDS(shp, paste0("data/", country, "/", file, "_admin.rds"))



# DENMARK -----------------------------------------------------------------

country = "dnk"
year = 2017

#### Kommuner
scale = "kom"
# Mobility table
mob = fread("data/dnk/raw/mob_Denmark_2017_matrix.csv", header=FALSE, colClasses=c("character", "character", "numeric"))
colnames(mob) = c("orig", "dest", "weight")
mob = mob[as.numeric(mob$orig)>100, ] # Keep only flow Kom>Kom
mob = mob[as.numeric(mob$dest)>100, ]
# Boundary shapefile
shp = st_read("data/dnk/raw/kommuner_2015.shp", quiet=TRUE)
epsg = epsg_countries[epsg_countries$country==country, "epsg"]
shp = st_transform(shp, epsg) # Reproject it
shp$id = as.character(shp$KOMKODE)
shp$id = substr(shp$id, 2, 4)
shp = shp[, c("id", "geometry")]
shp = st_zm(shp) # Remove Z dimension
shp = aggregate(shp, by=list(shp$id), FUN=length, do_union=TRUE)
# Check and save
file = paste(country, scale, year, sep="_")
print(paste("Check", file))
checkMobShp(mob, shp)
fwrite(mob, paste0("data/", country, "/", file, "_mob.csv"))
saveRDS(shp, paste0("data/", country, "/", file, "_admin.rds"))



# SPAIN -------------------------------------------------------------------

country = "esp"
year = 2011

#### Municipios
scale = "mun"
# Mobility table
mob = fread("data/esp/raw/Network2011.csv", colClasses=c("character", "character", "integer"))
colnames(mob) = c("orig", "dest", "weight")
mob = mob[which(mob$dest != "-1"), ] # Delete flows going to foreign countries
# Boundary shapefile
shp = st_read("data/esp/raw/recintos_etrs89.shp", quiet=TRUE)
epsg = epsg_countries[epsg_countries$country==country, "epsg"]
shp = st_transform(shp, epsg) # Reproject it
shp$id = shp$CODIGOINE
shp = shp[, c("id", "geometry")]
shp = shp[which(shp$id != "03014"), ] # Remove Alicante (duplicate)
# Check and save
file = paste(country, scale, year, sep="_")
print(paste("Check", file))
checkMobShp(mob, shp)
fwrite(mob, paste0("data/", country, "/", file, "_mob.csv"))
saveRDS(shp, paste0("data/", country, "/", file, "_admin.rds"))




# FRANCE ------------------------------------------------------------------

country = "fra"
year = 2015

#### Communes
scale = "com"
# Mobility table
mob = fread("data/fra/raw/FD_MOBPRO_2015.txt")
mob = mob[, c("COMMUNE","ARM","DCLT")] # Ignore statistical weight of individual (IPONDI)
mob$orig = ifelse(mob$ARM=="ZZZZZ", mob$COMMUNE, mob$ARM)
mob$dest = mob$DCLT
mob = mob[, c("orig", "dest")]
mob = suppressWarnings(mob[!is.na(as.numeric(mob$orig)), ])   # Remove Corsica in origin
mob = suppressWarnings(mob[!is.na(as.numeric(mob$dest)), ])   # and destination
mob = setDT(mob)[, list(weight=.N), keyby='orig,dest']  # Fast aggregation
# Boundary shapefile
shp = st_read("data/fra/raw/COMMUNE.shp", quiet=TRUE)
epsg = epsg_countries[epsg_countries$country==country, "epsg"]
shp = st_transform(shp, epsg) # Reproject it
shp$id = shp$INSEE_COM
shp = shp[, c("id", "geometry")]
# Check and save
file = paste(country, scale, year, sep="_")
print(paste("Check", file))
checkMobShp(mob, shp)
fwrite(mob, paste0("data/", country, "/", file, "_mob.csv"))
saveRDS(shp, paste0("data/", country, "/", file, "_admin.rds"))


# Backups for next steps
mob0 = mob
shp0 = shp
# Build a correspondance table between communes, cantons and EPCI
com = fread("data/fra/raw/corres_com2.csv") # Communes
arr = fread("data/fra/raw/corres_arr2.csv") # Paris + Marseille arrondissements
df = rbind(com[, c("CODGEO", "EPCI", "CV")],
           arr[, c("CODGEO", "EPCI", "CV")])
colnames(df) = c("com", "epci", "canton")

#### EPCI
scale = "epci"
## Replace commune id by EPCI ids
mob$orig = df$epci[match(mob0$orig, df$com)] # Saint Lucien, in Seine Maritime
mob$dest = df$epci[match(mob0$dest, df$com)]
mob = mob[!is.na(mob$orig), ]  # Some communes dont have an EPCI (here St-Lucien)
mob = mob[!is.na(mob$dest), ]  # Foreign countries (code 99999)
mob = setDT(mob)[, list(weight=.N), keyby='orig,dest']  # Aggregate it
# Boundary shapefile
shp$id = df$epci[match(shp0$id, df$com)]
shp = aggregate(shp, by=list(shp$id), FUN=length, do_union=TRUE)
# Check and save
file = paste(country, scale, year, sep="_")
print(paste("Check", file))
checkMobShp(mob, shp)
fwrite(mob, paste0("data/", country, "/", file, "_mob.csv"))
saveRDS(shp, paste0("data/", country, "/", file, "_admin.rds"))

# Cantons have been given up (too similar to EPCI)



# GBR  --------------------------------------------------------------------
# (ENGLAND-WALES)$

country = "gbr"
year = 2011

#### Output Areas
scale = "oa"
# Mobility table
mob = fread("data/gbr/raw/WF01AEW_OA_WPZ_V1_2011.csv", header=FALSE)
colnames(mob) = c("orig", "dest_WZ", "weight") # Origi are OA, but dest are Worplaces Zones (WZs)
df = fread("data/gbr/raw/OutputAreas2WorkplacesZones2011.csv")  # Load correspondance table OA-WZs
mob$dest = df$OA11CD[match(mob$dest_WZ, df$WZ11CD)] # Merge OA codes by WZ
mob = mob[,c("orig", "dest", "weight")]
# Boundary shapefile
shp = st_read("data/gbr/raw/OA_2011_shp/Output_Area_December_2011_Full_Extent_Boundaries_in_England_and_Wales.shp", quiet=TRUE)
epsg = epsg_countries[epsg_countries$country==country, "epsg"]
shp = st_transform(shp, epsg) # Reproject it (long, heavy file)
shp$id = as.character(shp$oa11cd)
shp = shp[, c("id", "geometry")]
# Check and save
file = paste(country, scale, year, sep="_")
print(paste("Check", file))
checkMobShp(mob, shp)
fwrite(mob, paste0("data/", country, "/", file, "_mob.csv"))
saveRDS(shp, paste0("data/", country, "/", file, "_admin.rds"))


#### Middle Small Output Areas 
scale = "msoa"
# Mobility table
mob = fread("data/gbr/raw/WU01EW_V2_MSOA_2011.csv")
mob = mob[, 1:3]
colnames(mob) = c("orig", "dest", "weight")
# Boundary shapefile
shp = st_read("data/gbr/raw/MSOA_2011_shp/Middle_Layer_Super_Output_Areas_December_2011_Full_Clipped_Boundaries_in_England_and_Wales.shp", quiet=TRUE)
epsg = epsg_countries[epsg_countries$country==country, "epsg"]
shp = st_transform(shp, epsg) # Reproject it
shp$id = as.character(shp$msoa11cd)
shp = shp[, c("id", "geometry")]
# Check and save
file = paste(country, scale, year, sep="_")
print(paste("Check", file))
checkMobShp(mob, shp)
fwrite(mob, paste0("data/", country, "/", file, "_mob.csv"))
saveRDS(shp, paste0("data/", country, "/", file, "_admin.rds"))



# ITALY -------------------------------------------------------------------

country = "ita"
year = 2011

#### Comuni
scale = "com"
# Mobility table
mob = fread("data/ita/raw/matrix_pendo2011_10112014.txt", colClasses=rep("character", 15))
mob = mob[, c(3,4,6,8,9,14,15)]
colnames(mob) = c("COD_PRO_O", "COD_COM_O", "motivation", "COD_PRO_D", "COD_COM_D", "EstimCommuters", "ObsCommuters")
mob$orig = paste0(mob$COD_PRO_O, mob$COD_COM_O)
mob$dest = paste0(mob$COD_PRO_D, mob$COD_COM_D)
mob = mob[!is.na(mob$motivation=="2"), ]  # Workers only, not students
mob$weight = as.numeric(mob$ObsCommuters) # Observed commuters, not estimated
mob = mob[!is.na(mob$comm), ]   # Delete NA ("ND")
mob = mob[, c("orig", "dest", "weight")]
# Boundary shapefile
shp = st_read("data/ita/raw/Com2011_WGS84_g.shp", quiet=TRUE)
epsg = epsg_countries[epsg_countries$country==country, "epsg"]
shp = st_transform(shp, epsg) # Reproject it
shp$id = formatC(shp$PRO_COM, width=max(nchar(shp$PRO_COM)), format="d", flag="0")  # Add leading zeros
shp = shp[, c("id", "geometry")]
# Check and save
file = paste(country, scale, year, sep="_")
print(paste("Check", file))
checkMobShp(mob, shp)
fwrite(mob, paste0("data/", country, "/", file, "_mob.csv"))
saveRDS(shp, paste0("data/", country, "/", file, "_admin.rds"))




# USA ---------------------------------------------------------------------

country = "usa"
year = 2015
# We work on only 12 north-east states only. Their codes should be 3 characters length
states = c(9, 23, 25, 26, 27, 33, 34, 36, 42, 44, 50, 55)
states = formatC(states, width=3, format="d", flag="0") # Add leading zeros  

#### Counties
scale = "cou"
# Mobility table
mob = fread("data/usa/raw/mob_counties_2015.csv")
colnames(mob) = c("State_O", "County_O", "State_D", "County_D", "weight")
mob$State_O  = formatC(mob$State_O, width=3, format="d", flag="0")  # Add leading zeros
mob$State_D  = formatC(mob$State_D, width=3, format="d", flag="0")  
mob$County_O = formatC(mob$County_O, width=3, format="d", flag="0")  
mob$County_D = formatC(mob$County_D, width=3, format="d", flag="0")
mob = mob[mob$State_O %in% states, ]    # Filter states
mob = mob[mob$State_D %in% states, ]
mob$orig = paste0(mob$State_O, mob$County_O)
mob$dest = paste0(mob$State_D, mob$County_D)
mob = mob[, c("orig", "dest", "weight")]
# Boundary shapefile
shp = st_read("data/usa/raw/cb_2017_us_county_20m.shp", quiet=TRUE)
epsg = epsg_countries[epsg_countries$country==country, "epsg"]
shp = st_transform(shp, epsg) # Reproject it
shp$STATEFP = formatC(as.numeric(shp$STATEFP), width=3, format="d", flag="0")
shp = shp[shp$STATEFP %in% states, ]
shp$id = paste0(shp$STATEFP, shp$COUNTYFP)
shp = shp[, c("id", "geometry")]
# Check and save
file = paste(country, scale, year, sep="_")
print(paste("Check", file))
checkMobShp(mob, shp)
fwrite(mob, paste0("data/", country, "/", file, "_mob.csv"))
saveRDS(shp, paste0("data/", country, "/", file, "_admin.rds"))


#### Minor Civil Divisions
scale = "mcd"
# Mobility table
mob = fread("data/usa/raw/mob_mcd_2015.csv")
colnames(mob) = c("StateCode_O", "StateName_O", "MCD_O", "StateCode_D", "StateName_D", "MCD_D", "weight")
mob = mob[!is.na(mob$MCD_O), ] # Many states don't have MCD referenced
mob = mob[!is.na(mob$MCD_D), ]
mob$State_O = formatC(mob$StateCode_O, width=3, format="d", flag="0")
mob$State_D = formatC(mob$StateCode_D, width=3, format="d", flag="0")
mob$MCD_O = formatC(mob$MCD_O, width=5, format="d", flag="0")
mob$MCD_D = formatC(mob$MCD_D, width=5, format="d", flag="0")
mob$orig = paste0(mob$State_O, mob$MCD_O)  # Paste State and MCD codes
mob$dest = paste0(mob$State_D, mob$MCD_D)
mob = mob[, c("orig", "dest", "weight")]
# Boundary shapefile
shp = st_read("data/usa/raw/MCDs/MCDs_merged.shp", quiet=TRUE)
epsg = epsg_countries[epsg_countries$country==country, "epsg"]
shp = st_transform(shp, epsg) # Reproject it
shp$STATEFP = formatC(shp$STATEFP, width=3, format="d", flag="0")
shp$id = paste0(shp$STATEFP, shp$COUSUBFP) # Paste State and MCDs codes
shp = aggregate(shp, by=list(shp$id), FUN=length, do_union=TRUE)
shp = shp[, c("id", "geometry")]
# Check and save
file = paste(country, scale, year, sep="_")
print(paste("Check", file))
checkMobShp(mob, shp)
fwrite(mob, paste0("data/", country, "/", file, "_mob.csv"))
saveRDS(shp, paste0("data/", country, "/", file, "_admin.rds"))

