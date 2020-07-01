library(RPostgreSQL)
library(sf)
# library(dplyr)

# PostgreSQL database identifiers
drv      = dbDriver("PostgreSQL")
host     = "localhost"
port     = 5432
dbname   = "XS"
user     = "milo"
password = "postgres"
lapply(dbListConnections(PostgreSQL()), dbDisconnect) # Kill all connexions

# download.file("https://www.naturalearthdata.com/http//www.naturalearthdata.com/download/10m/cultural/ne_10m_populated_places_simple.zip",
#               "data/world_cities/ne_10m_populated_places_simple.zip")
# system("cd data/world_cities && unzip -o ne_10m_populated_places_simple.zip")

cit = st_read("data/world_cities/ne_10m_populated_places_simple.shp", quiet=TRUE)
cit = cit[, c("name", "adm0_a3", "pop_max", "geometry")]
colnames(cit) = c("name", "country", "pop", "geometry")
countries = c("AUS", "CAN", "DNK", "ESP", "FRA", "GBR", "ITA", "USA")
cit = cit[cit$country %in% countries, ]
cit = cit[cit$pop>100000, ]
rownames(cit) = 1:nrow(cit)
crs = st_crs(cit) #4326

# Format cities names
myFun = function(x) {
  x = tolower(x)
  x = iconv(x, to="ASCII//TRANSLIT//IGNORE") # Remove accents
  x = gsub("[ -]", "_", x)  # Remove spaces and special characters
  x = gsub("[?'`^~.,]", "", x)
}
cit$name = myFun(cit$name)

# For some countries, only a part of the regions is concerned
#   USA: North-East states
#   GBR: England and Wales
#   AUS: New South-Wales 
# Delete cities of these countries not included in perimeter
# USA
shp = readRDS("data/usa/usa_mcd_2015_admin.rds")
cit = st_transform(cit, st_crs(shp))
cit = rbind(cit[cit$country != "USA", ],
            cit[unlist(st_intersects(shp, cit)), ])
# GBR
shp = readRDS("data/gbr/gbr_msoa_2011_admin.rds")
cit = st_transform(cit, st_crs(shp))
cit = rbind(cit[cit$country != "GBR", ],
            cit[unlist(st_intersects(shp, cit)), ])
# AUS
shp = readRDS("data/aus/aus_tz_2011_admin.rds")
cit = st_transform(cit, st_crs(shp))
cit = rbind(cit[cit$country != "GBR", ],
            cit[unlist(st_intersects(shp, cit)), ])

# Other option: merge all the shp, and make a big intersection

# Restore WGS84 CRS
cit = st_transform(cit, 4326)
# Some cities located on the border has been duplicated
cit = cit[!duplicated(paste0(cit$name, cit$country)), ]
cit = cit[order(cit$country, cit$pop, decreasing=TRUE),]

# Import cities into PostGIS, and save a separate rds
conn = dbConnect(drv, dbname=dbname, host=host, port=port, user=user, password=password)
st_write(cit, conn, "cities", delete_layer=TRUE)
dbSendQuery(conn, "CREATE INDEX ON cities using gist (geometry);")
dbDisconnect(conn)

# saveRDS(cit, "data/world_cities/world_cities.rds")

# cities = st_drop_geometry(cit)
# write.csv(cities, "cities.csv")