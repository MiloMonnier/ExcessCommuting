source("utils/matrices.R")

require(RPostgreSQL)
require(sf)
lapply(dbListConnections(PostgreSQL()), dbDisconnect) # Kill all connexions
conn = dbConnect(drv=dbDriver("PostgreSQL"), host="localhost", port=5432,
                 dbname="XS", user="postgres", password="postgres")
tbl = "aus_tz_2011"
city = "sydney"
radius = 10000
verbose = FALSE

# xsAdmin = function(conn,
#                    tbl,
#                    city,
#                    radius,
verbose=FALSE)
# {
  
# Check connexion and if tables exist
if (!is(conn, "PostgreSQLConnection"))
  stop("'conn' must be connection object: <PostgreSQLConnection>")
if (!tbl %in% dbListTables(conn))
  stop(paste(tbl, "table does not exists in", dbGetInfo(conn)$dbname), "database")
if (!"cities" %in% dbListTables(conn))
  stop(paste("table 'cities' does not exists in", dbGetInfo(conn)$dbname), "database")
# Check if the city is contained in the table cities
country = toupper(substr(tbl, 1, 3))
country_cit = dbGetQuery(conn, paste0("SELECT name FROM cities WHERE country='", country, "';"))
country_cit = country_cit[, 1]
if (!city %in% country_cit)
  stop(paste("City '", city, "' is not contained into 'cities' table"))

# Set objects names
sim  = paste0(tbl,"_", city, "_", radius)
buf  = paste0("buf_", sim)
grid = paste0("grid_", sim)
div  = paste0("div_", sim)

# Get the epsg of the flows table, which will be applied to others
epsg = dbGetQuery(conn, paste0("SELECT ST_SRID(orig) FROM ", tbl, " LIMIT 1;"))

# Create an buffer centered on a city point, with a given radius
q = paste0("
      DROP TABLE IF EXISTS ", buf, ";
      CREATE TABLE ", buf, "(id SERIAL PRIMARY KEY , geom geometry(Polygon,", epsg,"));
      CREATE INDEX ON ", buf, " USING GIST(geom);

      INSERT INTO ", buf, "
      VALUES (1, (
        SELECT ST_Buffer(ST_Transform(geometry,", epsg,"),", radius, ") FROM cities 
        WHERE name='", city, "'
          AND country='", country, "'
        ));
      ")
dbSendQuery(conn, q)
dbSendQuery(conn, paste0("VACUUM ANALYZE ", buf, ";"))

# Convert both geometries into MultiPolygon. Move it in 0.CleanData ?
q = paste0("
      ALTER TABLE ", buf, " ALTER COLUMN geom TYPE geometry(MultiPolygon, ", epsg, ") using ST_Multi(geom);
      ALTER TABLE ", tbl, "_admin ALTER COLUMN geometry TYPE geometry(MultiPolygon, ", epsg, ") using ST_Multi(geometry);
      ")
dbSendQuery(conn, q)

# Select administrative entities which centroid intersects buffer
q = paste0("
      DROP TABLE IF EXISTS ", div, ";
      CREATE TABLE ", div, "(id serial primary key, geom geometry(MultiPolygon,", epsg,") , x double precision, y double precision, area double precision);
      CREATE INDEX ON ", div, " USING GIST(geom);

      INSERT INTO ", div, " (geom)
      SELECT ", tbl, "_admin.geometry AS geom FROM ", tbl, "_admin, ", buf,"
      WHERE ST_Intersects(", buf,".geom, ST_Centroid(", tbl, "_admin.geometry));
      ")
dbSendQuery(conn, q)
dbSendQuery(conn, paste0("VACUUM ANALYZE ", div, ";"))

# X, Y and area has already been computed in 10-clean-data
# q = paste0("
#       ALTER TABLE ", div, " ADD x double precision;
#       ALTER TABLE ", div, " ADD y double precision;
#       ALTER TABLE ", div, " ADD area double precision;
#       UPDATE ", div, " SET x = ST_X(ST_Centroid(geom));
#       UPDATE ", div, " SET y = ST_Y(ST_Centroid(geom));
#       UPDATE ", div, " SET area = ST_Area(geom);
#       ")
# dbSendQuery(conn, q)

# Take the flows from country table which both origin and destination points intersects DIV
# /!\ : Sums of WEIGHT of individuals
print("Build origin-destination matrix ...")
t0 = proc.time()
q = paste0("
      SELECT g_orig.id AS from, g_dest.id AS to, SUM(d.weight) AS w 
      FROM ", div," AS g_orig, ", div," AS g_dest, ", tbl," AS d 
      WHERE ST_INTERSECTS(g_orig.geom, d.orig)
      AND ST_INTERSECTS(g_dest.geom, d.dest) 
      GROUP BY g_orig.id, g_dest.id;
      ")
od = dbGetQuery(conn, q)
time_od = proc.time()-t0

# If empty, return empty result
if (!length(od)) {
  warning("Empty origin-destination matrix. Returned NULL result = 0")
  return(NULL)
}

# Add internal null flows and convert origin-destination table into a symetric matrix
id = sort(unique(c(od$from, od$to)))
x = cbind(id, id, 0)
colnames(x) = colnames(od)
od = rbind(od, x)
matflows = as.matrix(xtabs(w ~ from+to, data=od))

# Get DIV shapefile 
shp = st_read(conn, div, quiet=TRUE)
shp = shp[shp$id %in% id, ]  # Eliminate grid cells without workers or jobs

# Compute euclidian distance matrix
matcost = fields::rdist(cbind(shp$x, shp$y))   
# Internal admin entities distance = radius of a circle with the same area
diag(matcost) = sqrt(shp$area/pi)

# Possible to add constrain to the transportation problem: admin entites with 
# no observed spatial interactions (no commuters in matflows) can't interact
# Set a hug cost to avoid commuters between
# if (constrained)
#   matcost[matflows==0] = 999999999 

# Compute optimal matrix with transportation problem
if (verbose) print("Compute matmin ...")
t0 = proc.time()
matmin = optimalCommuting(matflows, matcost)
time_matmin = proc.time()-t0

if (verbose) print("Compute matrand ...")
t0 = proc.time()
matrand = randomCommuting(matflows)
time_matrand = proc.time()-t0

# Reverse matcost to compute the sub-optimal solution of tranportation problem
if (verbose) print("Compute matmax ...")
t0 = proc.time()
matcost_inv = matcost * -1
matmax = optimalCommuting(matflows, matcost_inv)
time_matmax = proc.time()-t0

# Drop all temporary tables
dbSendQuery(conn, paste0("DROP TABLE ", buf, ",", div))

# Return also the computation times
time = list(time_od, time_matmin, time_matrand, time_matmax)
names(time) = c("OD", "matmin", "matrand", "matmax")
if (verbose) print(sapply(time, "[", 3))

# Output
list(sim=sim,
     matflows=matflows,
     matcost=matcost, 
     matmin=matmin, 
     matrand=matrand,
     shp=shp,
     time=time)
}