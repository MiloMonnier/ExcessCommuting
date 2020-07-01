library(RPostgreSQL)
library(sf)
library(raster)
library(spex)
library(data.table)
# library(stringr)

options(stringsAsFactors=FALSE)
formals(saveRDS)$compress = FALSE # Don't compress .rds files to fasten import and export

# PostgreSQL database identifiers
drv      = dbDriver("PostgreSQL")
host     = "localhost"
port     = 5432
dbname   = "XS"
user     = "milo"
password = "postgres"
lapply(dbListConnections(PostgreSQL()), dbDisconnect) # Kill all connexions
# Help to format complex SQL requests: https://sqlformat.org/ 

files = c(
  "aus_tz_2011",
  "can_cd_2016",
  "can_csd_2016",
  "dnk_kom_2017",
  "esp_mun_2011",
  "fra_com_2015",
  "fra_epci_2015",
  "gbr_oa_2001",
  "gbr_msoa_2011",
  "ita_com_2011",
  "usa_cou_2015",
  "usa_mcd_2015"
)

# Separate file containing EPSG codes is used to control CRS of each country
epsg_countries = read.csv2("epsg_countries.csv", sep=",")

i=1
# for (i in 1:length(files)) {
  
  file = files[i]
  print(paste("Clean", file))
  country = substr(file, 1, 3)
  epsg = epsg_countries[epsg_countries$country==country, "epsg"]
  
  # Open a PostgreSQL connexion
  conn = dbConnect(drv, dbname=dbname, host=host, port=port, user=user, password=password)
  
  # Don't create cleaned merged table output if already exists 
  merged_tbl = paste0(file, "_merged")
  if (merged_tbl %in% dbListTables(conn)) {
    print(paste(merged_tbl, "already exists. Skip"))
    next
  }
  
  # Load files
  mob = fread(paste0("data/", country, "/", file, "_mob.csv"))
  shp = readRDS(paste0("data/", country, "/", file, "_admin.rds"))
  ghsl = raster("data/ghsl_raster/GHS_BUILT_LDS2014_GLOBE_R2016A_54009_1k_v1_0.tif")
  
  # Crop ghsl with the extent of boundary file (SHP)
  print("Convert GHSL raster into a grid ...")
  shp_ext = st_bbox(shp) %>%
    st_as_sfc() %>%
    st_transform(st_crs(ghsl)) %>%
    as("Spatial")
  ghsl = crop(ghsl, shp_ext)
  matghsl = as.matrix(ghsl)
  matghsl[matghsl>0] = 1
  matghsl[matghsl<=0] = NA
  ghsl = setValues(ghsl, matghsl)
  ghsl = projectRaster(ghsl, crs=crs(shp))
  ghsl = spex::polygonize(ghsl)      # Convert the raster into a grid
  ghsl$id = seq(nrow(ghsl))
  ghsl = ghsl[, c("id", "geometry")]
  rownames(ghsl) = ghsl$id
  if (st_crs(ghsl) != st_crs(shp)) # Sometimes, crs does not match because GHSL is proj4string and  for postgis to match it
    st_crs(ghsl) = st_crs(shp)
  
  # Write into the PostGIS database and create spatial index
  st_write(shp, conn, paste0(file, "_admin"), delete_layer=TRUE)
  st_write(ghsl, conn, paste0(file, "_ghsl"), delete_layer=TRUE)
  dbSendQuery(conn, paste0("CREATE INDEX ON ", file, "_admin using gist (geometry);"))
  dbSendQuery(conn, paste0("CREATE INDEX ON ", file, "_ghsl using gist (geometry);"))
  
  # Remove SHP entities which don't intersect built-up areas
  print("Clean SHP, MOB and GHSL")
  q = paste0("
      SELECT ", file, "_admin.id, ", file, "_ghsl.id 
      FROM ", file, "_admin, ", file, "_ghsl 
      WHERE ST_Intersects(", file, "_admin.geometry, ", file, "_ghsl.geometry)
    ")
  int = dbGetQuery(conn, q)
  intshp = int[, 1]
  intshp = intshp[!duplicated(intshp)]
  shp = shp[!is.na(match(shp$id, intshp)), ] 
  
  # Remove SHP entities not in MOB, and MOB lines non matching SHP entities
  idshp = sort(as.character(shp$id))
  idmob = c(mob$orig, mob$dest)
  idmob = sort(idmob[!duplicated(idmob)])
  intshpmob = intersect(idshp, idmob)
  shp = shp[!is.na(match(shp$id, intshpmob)), ]
  mob = mob[!is.na(match(mob$orig, intshpmob)), ]  
  mob = mob[!is.na(match(mob$dest, intshpmob)), ]
  idshp = sort(as.character(shp$id))
  idmob = c(mob$orig, mob$dest)
  idmob = sort(idmob[!duplicated(idmob)])
  intshpmob = intersect(idshp, idmob)
  shp = shp[!is.na(match(shp$id, intshpmob)), ]
  idshp = sort(as.character(shp$id))
  print(c(length(idshp), length(idmob), sum(idshp==idmob))) # Check
  
  # Save MOB in a rds file
  fwrite(mob, paste0("data/", country, "/", file, "_mob_cleaned.csv"))
  # And save SHP into the database (overwrite previous)
  st_write(shp, conn, paste0(file, "_admin"), delete_layer=TRUE)
  dbSendQuery(conn, paste0("CREATE INDEX ON ", file, "_admin using gist (geometry);"))
  
  # Remove GHSL polygons which don't intersect SHP entites
  q = paste0("
      SELECT ", file, "_admin.id, ", file, "_ghsl.id 
      FROM ", file, "_admin, ", file, "_ghsl 
      WHERE ST_Intersects(", file, "_admin.geometry, ", file, "_ghsl.geometry)
    ")
  int = dbGetQuery(conn, q)
  intghsl = int[, 2]
  intghsl = intghsl[!duplicated(intghsl)]
  ghsl = ghsl[!is.na(match(ghsl$id, intghsl)), ]
  ghsl$id = 1:length(ghsl$id) # Reset ids of GHSL polygons
  # Overwrite GHSL
  st_write(ghsl, conn, paste0(file, "_ghsl"), delete_layer=TRUE)
  dbSendQuery(conn, paste0("CREATE INDEX ON ", file, "_ghsl using gist (geometry);"))
  
  # Correct geometry errors of admin shapfile if any
  print("Intersect correct SHP geometry errors ...")
  q = paste0("SELECT COUNT(*) FROM ", file, "_admin WHERE ST_IsValid(geometry) = FALSE;")
  nb_errors = dbGetQuery(conn, q)
  print(paste(nb_errors, "geometry errors in the admin shapefile"))
  if (nb_errors > 0) {
    q = paste0("UPDATE ", file, "_admin SET geometry = ST_MakeValid(geometry) WHERE ST_IsValid(geometry) = FALSE;")
    dbSendQuery(conn, q)
  }
  
  # Intersection SHP and GHSL (longest process)
  # If GHSL geometry is totally included (ST_CoveredBy) in 1 admin geometry entity, take it full
  # Else, take only the geometry included in the admin entity (ST_Intersection), and convert it to a multigeometryetry (ST_Multi)
  # Join to these intersected polygons the commune id (comid) in which they are included (INNER JOIN)
  print("Intersect SHP and GHSL ...")
  q = paste0("
      DROP TABLE IF EXISTS ", file, " CASCADE;
      CREATE TABLE ", file ,"(gid serial primary key, adminid character(" , unique(nchar(shp$id)),"), geometry geometry(MULTIPOLYGON,", epsg,"));
      CREATE INDEX ON ", file, " using gist (geometry);
      
      INSERT INTO ", file, "(adminid, geometry)
      SELECT n.id AS adminid,
             CASE
                 WHEN ST_CoveredBy(p.geometry, n.geometry) THEN ST_Multi(p.geometry) --St_Multi added 04/04
                 ELSE ST_Multi(ST_Intersection(p.geometry, n.geometry))
             END AS geometry
      FROM ", file, "_ghsl AS p
      INNER JOIN ", file, "_admin AS n ON (ST_Intersects(p.geometry, n.geometry)
                                     AND NOT ST_Touches(p.geometry, n.geometry));
      ")
  dbSendQuery(conn, q)
  
  # Union (ST_Union) of GHLS previously intersectd polygons geom by adminid (GROUP BY) and conversion to multigeometry (ST_Multi)
  print("Unioning polygons ...")
  q = paste0("
      DROP TABLE IF EXISTS ", file, "_merged CASCADE;
      CREATE TABLE ", file, "_merged(gid serial primary key, adminid character(", unique(nchar(shp$id)),"), geometry geometry(MULTIPOLYGON,", epsg,"));
      CREATE INDEX ON ", file, "_merged using gist (geometry);
          INSERT INTO ", file, "_merged(adminid, geometry)
      SELECT ", file, ".adminid adminid,
             ST_Multi(ST_Union(", file, ".geometry))
      FROM ", file, "
      GROUP BY ", file, ".adminid;
    ")
  dbSendQuery(conn, q)
  
  # Add X, Y and Area
  q = paste0("
      ALTER TABLE ", file, "_merged RENAME adminid TO id;
      ALTER TABLE ", file, "_merged ADD x double precision;
      ALTER TABLE ", file, "_merged ADD y double precision;
      ALTER TABLE ", file, "_merged ADD Area double precision;
      UPDATE ", file, "_merged SET x = ST_X(ST_Centroid(geometry));
      UPDATE ", file, "_merged SET y = ST_Y(ST_Centroid(geometry));
      UPDATE ", file, "_merged SET area = ST_Area(geometry);
      
      ALTER TABLE ", file, "_admin ADD x double precision;
      ALTER TABLE ", file, "_admin ADD y double precision;
      ALTER TABLE ", file, "_admin ADD Area double precision;
      UPDATE ", file, "_admin SET x = ST_X(ST_Centroid(geometry));
      UPDATE ", file, "_admin SET y = ST_Y(ST_Centroid(geometry));
      UPDATE ", file, "_admin SET area = ST_Area(geometry);
    ")
  dbSendQuery(conn, q)
  dbSendQuery(conn, paste0("VACUUM ANALYZE ", file, "_merged;"))
  dbSendQuery(conn, paste0("VACUUM ANALYZE ", file, "_admin;"))
  
  dbSendQuery(conn, paste0("DROP TABLE IF EXISTS ", file, "_ghsl CASCADE;"))
  
  # Final check
  shp = st_read(conn, paste0(file,"_merged"), quiet=TRUE)
  idshp = sort(as.character(shp$id))
  idmob = c(mob$orig, mob$dest)
  idmob = sort(idmob[!duplicated(idmob)])
  print(c(length(idshp), length(idmob), sum(idshp==idmob))) # Check
  
  dbDisconnect(conn)
# }

#### PostGIS tables:
# file_merged wille be used in next script, and then removed
# file_admin is conserved for intersecting with the new XS function
# file_ghsl is removed now
