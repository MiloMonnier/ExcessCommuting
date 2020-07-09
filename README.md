<<<<<<< HEAD
Generation of Origin-Destination matrices based on individual data
===================================================================================

## Description

According to a specific aggregation design this algorithm aims at generating a set of Origin-Destination matrices (OD) based on individual mobility flow information. First, it spatially aggregates the individual mobility flow according to a specific study area divided into several spatial units. Then, it computes an optimized version of the OD, minimizing the travel distance while preserving the total number of people getting in and out each spatial unit (i.e. the marginals). It also returns a random OD where the flows are randomly assigned while preserving the marginals as well.

## Input

The input table contains individual mobility flow information from an origin to a destination (journey to work for example). Every origin and destination is represented by a point. The input table is a 6 columns csv file with column names, **the value separator is a semicolon ","**. Each row of the file represents an individual. 

1. **ID:** Identifier of the individual
2. **X_Ori:** X coordinate of the Origin (projected in meters)
3. **Y_Ori:** Y coordinate of the Origin (projected in meters)
4. **X_Des:** X coordinate of the Destination (projected in meters)
5. **Y_Des:** Y coordinate of the Destination (projected in meters)
6. **Weight:** Statistical weight of the individual

An example is provided in the csv file ***country*** containing mobility information on 10,000 fake individuals. In this case the coordinated are projected in epsg ***3035***. It is important to work with coordinates in meters and to be aware of the epsg code of the projection. 

## Import the table in PostGIS

The script **ImportTable.R** imports the input table in a PostGIS database. The imported table contains 4 columns: one **id**, a **weight** and two geometries **orig** and **dest**. Note that a PostGIS database should be created before in order to get the following information needed to run the script:

- **host:** Server host
- **port:** Port of the server host
- **db:** Database
- **user:** User name
- **mdp:** Password

## Set the aggregation design to extract the ODs

Once the table is imported into a PostGIS database, an aggregation design can be set up in the script **Main.R** with the following information:

- **city:** Name of the study area
- **xcenter:** X center of the study area
- **ycenter:** Y center of the study area
- **shape:** Shape of the study area (square & circle) 
- **radius:** Half side length of the shape  (need to be a multiple of scale)
- **scale:** Side length of the grid cell

## Outputs

The script **Main.R** runs the function **XS.R** which returns a list containing 5 elements based on the aggregation design.

- **idsim:** Simulation ID
- **matflows:** OD matrix
- **matcost:** Cost associated with the OD matrix
- **matmin:** Optimized OD matrix
- **matrand:** Randomized OD matrix
- **shp:** Associated spatial object (grid cells)

## Contributors

- [Hadrien Commenges](https://github.com/hcommenges)
- [Maxime Lenormand](https://gitlab.com/users/maximelenormand/projects)
- [Nicolas Moyroud](https://nmoyroud.teledetection.fr/index.php/telechargements)
- [Milo Monnier](https://github.com/MiloMonnier)
- [Paul Chapron](https://github.com/chapinux)

If you need help, find a bug, want to give me advice or feedback, please contact me!
You can reach me at maxime.lenormand[at]inrae.fr



=======
# Excess Commuting
>>>>>>> e9f4492001f91ceaadbf1f53e70351f7d6e0ee87
