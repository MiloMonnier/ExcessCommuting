library(RPostgreSQL)
library(sf)
library(parallel)
library(sp)

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

i=1
# for (i in 1:length(files)) {
  
  file = files[i]
  print(file)
  country = substr(file, 1, 3)
  
  # Open a PostgreSQL connexion
  conn = dbConnect(drv, dbname=dbname, host=host, port=port, user=user, password=password)
  
  # Load built-up data generated in 0.CleanData
  bup = st_read(conn, paste0(file, "_merged"))
  rownames(bup) = bup$id
  
  # Load MOB file cleaned in previous script
  mob = fread(paste0("data/", country, "/", file, "_mob_cleaned.csv"))
  
  # Check ids
  idbup = sort(as.character(bup$id))
  idmob = sort(unique(c(mob$orig, mob$dest)))
  print(c(length(idbup), length(idmob), sum(idbup==idmob)))
  
  # Expand lines from sum to 1 per indiv
  mob = mob[rep(seq(nrow(mob)), mob$pers), 1:2]
  mob$weight = 1
  
  # Compute marginals
  mar_orig = aggregate(mob$orig, list(mob$orig), length)
  mar_dest = aggregate(mob$dest, list(mob$dest), length)
  print(c(sum(mar_orig[,2]), sum(mar_dest[,2])))   # Check if nb workers == nb jobs
  
  # Add marginals to bup
  bup$workers = mar_orig[match(bup$id, mar_orig[,1]), 2]
  bup$jobs    = mar_dest[match(bup$id, mar_dest[,1]), 2]
  bup$workers[is.na(bup$workers)] = 0
  bup$jobs[is.na(bup$jobs)] = 0      
  
  # Convert sf into sp object, and split it to compute function in parallel
  bup_sp = as(bup, "Spatial")
  splitbup = sp::split(bup_sp, f=row.names(bup_sp))
  
  # Spatial sampling is faster with sp than sf
  myFun = function(x, mar) {
    if (mar==1) {
      n = x@data$workers
    } else if (mar==2) {
      n = x@data$jobs
    }
    if (n>0) {
      sp = suppressWarnings(spsample(x, n, type="random", iter=64))
      coords = coordinates(sp)
      res = data.frame(id=x@data$id, x=coords[,1], y=coords[,2])
    } else {
      res = data.frame(id=NA, x=NA, y=NA)
    }
    return(res)
  }
  # lapply(splitbup[1:100], myFun, 1)
  
  # Sample workers and jobs locations into built-up polygons
  cores = detectCores()-2 # Cores used for parallel computing
  system.time({
    print("Sample workers locations into polygons  ...")
    sample_orig = mclapply(splitbup, FUN=myFun, mar=1, mc.cores=cores)
  })
  sample_orig = do.call(rbind, sample_orig)
  sample_orig = sample_orig[!is.na(sample_orig[,1]), ]
  
  system.time({
    print("Sample jobs locations into polygons ...")
    sample_dest = mclapply(splitbup, FUN=myFun, mar=2, mc.cores=cores)
  })
  sample_dest = do.call(rbind, sample_dest)
  sample_dest = sample_dest[!is.na(sample_dest[,1]), ]
  doParallel::stopImplicitCluster() # Stop all used cores
  
  # Merge final table
  final = data.frame(
    id = 1:nrow(mob),
    orig = mob$orig,
    dest = mob$dest,
    x_orig = 0,
    y_orig = 0,
    x_dest = 0,
    y_dest = 0,
    weight = mob$weight
  )
  
  # Push sample_ori & sample_des XY into the final df 
  final = final[order(final$orig), ]
  sample_orig = sample_orig[order(sample_orig$id), ]
  print(c(length(final$orig), length(sample_orig$id), sum(final$orig==sample_orig$id))) # Check
  final$x_orig = sample_orig$x
  final$y_orig = sample_orig$y
  final = final[order(final$dest), ]
  sample_dest = sample_dest[order(sample_dest$id), ]
  print(c(length(final$dest), length(sample_dest$id), sum(final$dest==sample_dest$id))) # Check
  final$x_dest = sample_dest$x
  final$y_dest = sample_dest$y
  
  # Save mob orig and dest location
  final = final[order(final$orig, final$dest), ]
  fwrite(final, paste0("data/", country, "/", file, "_sampled_od.csv"))

  # Check
  # unid = final[final$id==sample(final$id, 1), ] # Get a random commune id
  # idcom = as.character(final[unid,"orig"])
  # par(mfrow=c(1,2))
  # plot(st_geometry(bup[bup$id==idcom,]), col="grey", main="Workers")
  # points(final[final$origin==idcom,"x_ori"], final[final$origin==idcom,"y_ori"], pch=16, col="red", cex=.2)
  # mtext(paste("n =", nrow(final[final$origin==idcom,])))
  # plot(st_geometry(bup[bup$id==idcom,]), col="grey", main="Jobs")
  # points(final[final$destination==idcom,"x_des"], final[final$destination==idcom,"y_des"], pch=16, col="blue", cex=.2)
  # mtext(paste("n =", nrow(final[final$destination==idcom,])))
  # Sys.sleep(60)
  # dev.off()
# }