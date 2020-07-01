library(RPostgreSQL)
library(sf)
library(stringr)

# Load function to simplify polygons
system("psql XS -f scripts/simplifyLayerPreserveTopology.sql")

# PostgreSQL database identifiers
drv      = dbDriver("PostgreSQL")
host     = "localhost"
port     = 5432
dbname   = "XS"
user     = "milo"
password = "postgres"
lapply(dbListConnections(PostgreSQL()), dbDisconnect) # Kill all connexions

files = c(
  "AUS_tz_2011",
  "CAN_cd_2016",
  "CAN_csd_2016",
  "DEN_kom_2017",
  "ESP_mun_2011",
  "FRA_com_2015",
  "FRA_can_2015",
  "GBR_oa_2001",
  "GBR_msoa_2011",
  "ITA_com_2011",
  "USA_cou_2015",
  "USA_mcd_2015"
)

i=1
# for (i in 1:length(files)) {
  
  file = files[i]
  country = str_split(file, "_")[[1]]
  scale   = str_split(file, "_")[[2]]
  year    = str_split(file, "_")[[3]]
  
  # Set coordinate reference system (EPSG) according to the country
  epsg_corresp = read.csv2("epsg_corresp.csv", sep=",", stringsAsFactors=F, colClass=c("character", "character"))
  epsg = epsg_corresp[epsg_corresp$country==country, "epsg"] 
  
  
  conn = dbConnect(drv, dbname=dbname, host=host, port=port, user=user, password=password)
  
  # Load SHP(id, geom), standardized for each country
  print(paste("Begin", gile))
  # load(paste0("SHP_", idfile,".RData")) # Future
  shp = st_read(con, paste0(idfile, "_admin")) #TMP
  print(paste("SHP before :", nrow(shp), "rows,", format(object.size(shp), units="Mb")))
  st_write(shp, paste0(idfile, "_before.shp"), delete_layer=T) # Check
  
  # Write into DB
  st_write(shp, con, paste0(idfile, "_admin_tmp"), overwrite=T)
  
  # Correct geometry errors of admin shapfile if any
  errors = dbGetQuery(con, paste0("SELECT COUNT(*) FROM ", idfile, "_admin_tmp WHERE ST_IsValid(geometry) = FALSE;"))
  print(paste(errors, "geometry errors in the _admin_tmp shapefile"))
  
  if (errors > 0) {
    dbSendQuery(con, paste0("UPDATE ", idfile, "_admin_tmp SET geometry = ST_MakeValid(geometry) WHERE ST_IsValid(geometry) = FALSE;"))
  }
  
  # Check number of multigeometries
  q = paste0("SELECT COUNT(CASE WHEN ST_NumGeometries(geometry) > 1 THEN 1 END) AS multi, COUNT(geometry) AS total FROM ", idfile, "_admin_tmp;")
  df = dbGetQuery(con, q)
  print(df)
  
  # Convert geometry(Polygon) ----> geom(Multipolygon) in a new column
  q = paste0("
      ALTER TABLE ", idfile, "_admin_tmp ADD COLUMN IF NOT EXISTS geom geometry('MULTIPOLYGON', ", epsg, ");
      UPDATE ", idfile, "_admin_tmp SET geom = ST_Multi(geometry);
      ")
  dbSendQuery(con, q)
  
  # Simplify the geometry with the function and import it
  q = paste0("SELECT * FROM simplifyLayerPreserveTopology('', '", idfile, "_admin_tmp', 'id', 'geom', 1000) AS (id text, geom geometry);")
  shp.simpl = st_read(con, query=q)
  
  # Check
  print(paste("SHP simplified :", nrow(shp.simpl), "rows,", format(object.size(shp.simpl), units="Mb")))
  # plot(st_geometry(shp.simpl))
  st_write(shp.simpl, paste0(idfile,"_after.shp"),  delete_layer=T)
  
  # Overwite the original shp
  # st_write(shp.simpl, con, paste0(idfile, "_admin"), overwrite=T)
  
  # Drop tmp table    
  dbSendQuery(con, paste0("DROP TABLE IF EXISTS ", idfile, "_admin_tmp CASCADE;"))
  
  
  dbDisconnect(con)
  # }
  # }
  