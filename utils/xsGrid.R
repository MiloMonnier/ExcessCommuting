source("utils/matrices.R")

require(RPostgreSQL)
require(sf)
lapply(dbListConnections(PostgreSQL()), dbDisconnect) # Kill all connexions
conn = dbConnect(drv=dbDriver("PostgreSQL"), host="localhost", port=5432,
                 dbname="XS", user="postgres", password="postgres")
tbl = "aus_tz_2011"
city = "sydney"
radius = 10000
scale = 1000

xsGrid = function(conn,
                  tbl,
                  city,
                  radius,
                  scale)
{
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
  sim  = paste0(tbl,"_", city, "_", radius, "_", scale)
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
  
  # Get city coordinates used for centering the buffer
  q = paste0("
        SELECT ST_X(ST_Transform(geometry, ", epsg, ")) AS x,
               ST_Y(ST_Transform(geometry, ", epsg, ")) AS y
        FROM cities where name='", city,"';
      ")
  city_coords = dbGetQuery(conn, q)
  xcenter = city_coords$x
  ycenter = city_coords$y
  
  # Create a grid spanning over the buffer
  xmin = xcenter - radius         # Get radius bbox
  xmax = xcenter + radius
  ymin = ycenter - radius
  ymax = ycenter + radius
  xext = xmax - xmin                  # Get x and y extent
  yext = ymax - ymin
  width  = ceiling(xext/scale)         # Nb of necessary cells
  height = ceiling(yext/scale)
  newxext = width * scale             # Enlarge extent with superior nb of cells needed
  newyext = height * scale
  xmin = xmin - (newxext - xext) / 2  # Compute new min and max
  ymin = ymin - (newyext - yext) / 2
  
  # Create an empty raster and make it a grid
  q = paste0("
      DROP TABLE IF EXISTS ", grid,"; 
      CREATE TABLE ", grid," (id serial primary key,geom geometry(polygon,", epsg,"));
      CREATE INDEX ON ", grid," using gist (geom);
  
      INSERT INTO ", grid," (geom) 
      SELECT (ST_PixelAsPolygons(
                ST_AddBand(
                  ST_MakeEmptyRaster(", width,",", height,",", xmin,",", ymin,", ", scale,", ", scale,", 0, 0, ", epsg,"),
                  '8BSI'::text, 1, 0),
                1, false)
              ).geom;
      ")
  dbSendQuery(conn, q)
  dbSendQuery(conn, paste0("VACUUM ANALYZE ", grid, ";"))
  
  
  # Select GRID cells intersecting BUF to create DIV
  q = paste0("
      DROP TABLE IF EXISTS ", div, ";
      CREATE TABLE ", div, "(id serial primary key, geom geometry(Polygon,", epsg,"));
      CREATE INDEX ON ", div, " USING GIST(geom);
  
      INSERT INTO ", div, "(geom)
      SELECT ", grid,".geom FROM ", grid,", ", buf," 
      WHERE ST_Intersects(", buf,".geom, ", grid,".geom);
      ")
  dbSendQuery(conn, q)
  dbSendQuery(conn, paste0("VACUUM ANALYZE ", div, ";"))
  
  # For each cell of DIV, compute centroid coordinates and area
  q = paste0("
      ALTER TABLE ", div, " ADD x double precision;
      ALTER TABLE ", div, " ADD y double precision;
      ALTER TABLE ", div, " ADD area double precision;
      UPDATE ", div, " SET x = ST_X(ST_Centroid(geom));
      UPDATE ", div, " SET y = ST_Y(ST_Centroid(geom));
      UPDATE ", div, " SET area = ST_Area(geom);
      ")
  dbSendQuery(conn, q)
  
  # Extract origin-destination flows contained into DIV
  q = paste0("
      SELECT g_orig.id AS from, g_dest.id AS to, SUM(d.weight) AS w 
      FROM ", div," AS g_orig, ", div," AS g_dest, ", tbl," AS d 
      WHERE ST_Intersects(g_orig.geom, d.orig) 
      AND ST_Intersects(g_dest.geom, d.dest) 
      GROUP BY g_orig.id, g_dest.id;
      ")
  od = dbGetQuery(conn, q)
  
  # Add internal null flows and convert origin-destination table into a symetric matrix
  id = sort(unique(c(od$from, od$to)))
  x = cbind(id, id, 0)
  colnames(x) = colnames(od)
  od = rbind(od, x)
  matflows = as.matrix(xtabs(w ~ from+to, data=od))
  # matflows = round(matflows)            # Round matflows (for countries with a real format weight)
  # Statistical weight
  
  # Get DIV shapefile 
  shp = st_read(conn, div, quiet=TRUE)
  shp = shp[shp$id %in% id, ]  # Eliminate grid cells without workers or jobs
  
  # Compute optimal and random matrices
  matcost = fields::rdist(cbind(shp$x, shp$y))   # Euclidian distance matrix
  matmin  = optimalCommuting(matflows, matcost)  # Optimal
  matrand = randomCommuting(matflows)            # Random
  
  # Drop all temporary tables
  dbSendQuery(conn, paste0("DROP TABLE ", buf, ", ", grid,", ", div))
  
  # Output
  list(sim=sim,
       matflows=matflows, 
       matcost=matcost, 
       matmin=matmin, 
       matrand=matrand, 
       shp=shp)
}


# conn = dbConnect(drv=dbDriver("PostgreSQL"), host="localhost", port=5432,
#                  dbname="XS", user="postgres", password="postgres")
# test = xsGrid(conn, tbl="aus_tz_2011", city="sydney", radius=10000, scale=1000)
# dbDisconnect(conn)