library(RPostgreSQL)
# Re-import table in postgislibrary(RPostgreSQL)

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
  "den_kom_2017",
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

i=1
# for (i in 1:length(files)) {

file = files[i]
country = substr(file, 1, 3)
dir = paste0("data/", country, "/")
f = paste0(dir, file,"_sampled_od.csv")
if (!file.exists(f)) {
  print(paste(f, "does not exists"))
  next
}
print(paste("Import", file, "into PostGIS ..."))

epsg = epsg_countries[epsg_countries$country==country, "epsg"]

# Create country.vrt
# Generate geometry fields (wkbPoint) based on X & Y coordinates of the .csv
res="<OGRVRTDataSource>"
res=c(res, paste0("    <OGRVRTLayer name='", file,"'>"))
res=c(res, paste0("        <SrcDataSource> ", file,".csv</SrcDataSource>")) 
res=c(res, paste0("        <LayerSRS>EPSG:", epsg,"</LayerSRS>"))
res=c(res, paste0("        <FID>id</FID>"))
res=c(res, paste0("        <Field name='id' src='id' type='Integer'></Field>"))
res=c(res, paste0("        <Field name='weight' src='weight' type='Real'></Field>"))
res=c(res, paste0("        <GeometryField name='orig' encoding='PointFromColumns' x='x_orig' y='y_orig'>"))
res=c(res, paste0("            <GeometryType>wkbPoint</GeometryType>"))
res=c(res, paste0("            <SRS>EPSG:", epsg,"</SRS>"))
res=c(res, paste0("        </GeometryField>"))
res=c(res, paste0("        <GeometryField name='dest' encoding='PointFromColumns' x='x_dest' y='y_dest'>"))
res=c(res, paste0("            <GeometryType>wkbPoint</GeometryType>"))
res=c(res, paste0("            <SRS>EPSG:", epsg,"</SRS>"))
res=c(res, paste0("        </GeometryField>"))
res=c(res, paste0("    </OGRVRTLayer>"))
res=c(res, paste0("</OGRVRTDataSource>"))

# Create a virtual raster tile (.vrt)
write.table(res, paste0("data/", country, "/", file, ".vrt"), col.names=FALSE, row.names=FALSE, quote=FALSE)

# Then use the vrt to import ODs .csv into PostGIS
pgids = paste0("'dbname=", dbname, " user=", user, " password=", password, "'")
system(paste0("cd ", dir, " && ogr2ogr -overwrite -f PostgreSQL PG:", pgids, " -nln '", file,"' '", file, ".vrt' -lco 'SPATIAL_INDEX=NO' --config PG_USE_COPY YES"))

# Create spatial index
conn = dbConnect(drv, dbname=dbname, host=host, port=port, user=user, password=password)
dbSendQuery(conn, paste0("CREATE INDEX ", file, "_orig_gist_idx ON ", file, " USING GIST (orig);"))
dbSendQuery(conn, paste0("CREATE INDEX ", file, "_dest_gist_idx ON ", file, " USING GIST (dest);"))
dbSendQuery(conn, paste0("VACUUM ANALYZE ", file, ";"))
dbDisconnect(conn)

  }