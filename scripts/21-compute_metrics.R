library(RPostgreSQL)
library(sf)
library(DescTools)
library(transport)
library(reshape2)
library(data.table)
options(scipen=10000) # Avoid scientific notation
options(stringsAsFactors=FALSE)

radius = seq(10000,70000,5000)

print("Refreshing results ...")

df = data.frame(
  idsim = character(),
  country = character(),
  country.name = character(),
  scale = character(),
  city = character(),
  city_name = character(),
  radius = numeric(),
  commuters = numeric(),
  mean_unit_size = numeric(),
  median_unit_size = numeric(),
  Cmax = numeric(),  # Benchmarks
  Cmax.c = numeric(),
  Crand = numeric(),
  Cobs = numeric(),
  Cmin = numeric(),
  Cmin.c = numeric(),
  Cex = numeric(),  # Indices
  Cex.c = numeric(),
  Cu = numeric(),
  Cu.c = numeric(),
  NCe = numeric(),
  NCe.c = numeric(),
  Ce = numeric()
)

sim_files = list.files("ou")
  
    country = names(lf[i])
    country.name = paste0(toupper(substr(country,1,1)), substr(country,2,nchar(country))) # Uppercase for 1st letter
    file = lf[[country]][[j]]
    idfile = paste(country, file, sep = "_")
    print(paste("load", idfile, "results"))
    
    # Load cities list
    cities = read.csv("Data/cities/cities.csv", stringsAsFactors=F)
    cities = cities[cities$country==country,]
    
    for (k in 1:nrow(cities)) {
      city = cities[k,"name"]
      city.name = cities[k,"name2"]
      
      for (l in 1:length(radius)) {
        r = radius[l]
        idsim = paste(idfile, city, r, sep="_")
        idsim.data = paste0("outputs/", idfile, "/", idsim, ".RData")
        
        # Load .RData if exists
        if (!file.exists(idsim.data)){
          print(paste(idsim, "doesn't exists"))
          
        } else {
          print(paste("load", idsim))
          load(idsim.data)
          
          attach(result, warn.conflicts = F)
          
          
          W = sum(matflows) # Total nb of workers/jobs
          
          if (W==0) {
            print("EMPTY")
            next
          }
          
          #  Average costs
          Cmax  = sum(matcost * matmax)   / W
          Crand = sum(matcost * matrand)  / W
          Cobs  = sum(matcost * matflows) / W
          Cmin  = sum(matcost * matmin)   / W
          # Indices
          Cex = (Cobs  - Cmin) /  Cobs  * 100             # Cex - Excess Commute
          Cu  = (Cobs  - Cmin) / (Cmax  - Cmin) * 100     # Cu  - Commuting Potential Utilized
          NCe = (Crand - Cobs) / (Crand - Cmin) * 100     # NCe - Normalized Commuting Economy
          Ce  = (Crand - Cobs) /  Crand * 100             # Ce  - Commuting Economy
          
          # With constrained matrices
          Cmax.c  = sum(matcost * matmax.c)   / W
          Cmin.c  = sum(matcost * matmin.c)   / W
          # Indices
          Cex.c = (Cobs  - Cmin.c) /  Cobs  * 100
          Cu.c  = (Cobs  - Cmin.c) / (Cmax.c  - Cmin.c) * 100
          NCe.c = (Crand - Cobs)   / (Crand - Cmin.c) * 100
          
          # Moran index ? Duncan index ?
          
          df.tmp = data.frame(
            idsim = idsim,
            country = country,
            country.name = country.name,
            scale = file,
            city = city,
            city.name = city.name,
            radius = r,
            commuters = W,
            mean_unit_size = mean(shp$area),
            median_unit_size = median(shp$area),
            Cmax = Cmax,
            Cmax.c = Cmax.c,
            Crand = Crand,
            Cobs = Cobs,
            Cmin = Cmin,
            Cmin.c = Cmin.c,
            Cex = Cex,
            Cex.c = Cex.c,
            Cu = Cu,
            Cu.c = Cu.c,
            NCe = NCe,
            NCe.c = NCe.c,
            Ce = Ce,
            stringsAsFactors = F
          )
          
          df = rbind(df, df.tmp) # Add to the main df
        }
      }
    }
  }
}


df$mean_unit_size = round(df$mean_unit_size/ 10^6, 1)
df$median_unit_size = round(df$median_unit_size/ 10^6, 1)

df = df[df$radius>10000,]
ben = c("Cmax", "Cmax.c", "Crand", "Cobs", "Cmin", "Cmin.c")
ind = c("Cex", "Cex.c", "Cu", "Cu.c", "NCe", "NCe.c", "Ce")
df[,ben] = round(df[,ben]/1000)
df[,ind] = round(df[,ind],1)

print(paste(nrow(df), "results exported"))
fwrite(df, "outputs/results.csv")
