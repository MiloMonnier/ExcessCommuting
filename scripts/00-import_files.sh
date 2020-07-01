#!/bin/bash

#########	GHSL	##########

# https://ghsl.jrc.ec.europa.eu/ghs_bu.php

#########	AUSTRALIA (2011)   ##########

#### Travel Zones (TZ)
# Mobility file (table 11)
# https://opendata.transport.nsw.gov.au/dataset/journey-work-jtw-2011
unzip BTS_JTW_Table11_2011_V1_3.zip
awk -F "," '{print $1 "," $16 "," $31}'  2011JTW_Table11_V1.3.csv > MOB_Australia_2011_TZs.csv
# Admin shapefile
# https://opendata.transport.nsw.gov.au/dataset/travel-zones-2011



#########	CANADA	(2016) ##########

# All mobility tables
# https://www12.statcan.gc.ca/census-recensement/2016/dp-pd/dt-td/Lp-eng.cfm?LANG=E&APATH=3&DETAIL=0&DIM=0&FL=A&FREE=0&GC=0&GID=0&GK=0&GRP=1&PID=0&PRID=10&PTYPE=109445&S=0&SHOWALL=0&SUB=0&Temporal=2017&THEME=125&VID=0&VNAMEE=&VNAMEF=
# All shapefiles
# https://www12.statcan.gc.ca/census-recensement/2011/geo/bound-limit/bound-limit-2016-eng.cfm


#########	COLOMBIA	##########

# Mobility file
# https://www.datos.gov.co/api/views/mvbb-bn7j/rows.csv?accessType=DOWNLOAD

# https://drive.google.com/drive/folders/0Bzyr0SveNi4AeDJ6MzJtYnJ6MlU



#########	FRANCE (2015)	##########

# Mobility file
# https://www.insee.fr/fr/statistiques/3566008?sommaire=3558417#consulter
wget -nc  https://www.insee.fr/fr/statistiques/fichier/3566008/rp2015_mobpro_txt.zip
unzip -o rp2015_mobpro_txt.zip
# Documentation
wget -nc https://www.insee.fr/fr/statistiques/fichier/3566008/contenu_rp2015_mobpro.pdf

#### Correspondance communes-interco 2015
wget -nc https://www.insee.fr/fr/statistiques/fichier/2028028/table-appartenance-geo-communes-15.zip
unzip table-appartenance-geo-communes-15.zip
rm table-appartenance-geo-communes-15.zip
# xls2csv (manual...)
tail -n +6 corres_com.csv > corres_com2.csv # Remove 5 first rows
tail -n +6 corres_arr.csv > corres_arr2.csv # Remove 5 first rows


#########	Cities & zoning
# https://www.data.gouv.fr/fr/datasets/referentiel-geographique-francais-communes-unites-urbaines-aires-urbaines-departements-academies-regions/
wget -nc https://www.data.gouv.fr/fr/datasets/r/b05d1fed-c33e-4dea-a983-f9918b7aafb7
mv b05d1fed-c33e-4dea-a983-f9918b7aafb7 ref_com_fr.csv
# 6=COM_CODE; 13=UU_CODE; 32=AU_CODE
awk -F";" '{print $6 "," $13 "," $32}' ref_com_fr.csv > ref_com_fr_clean.csv


#########	ENGLAND+WALES	##########

# Magic!
# http://wicid.ukdataservice.ac.uk/cider/wicid/downloads.php
# http://wicid.ukdataservice.ac.uk/cider/wicid/downloads.php?wicid_Session=6f4db70e2687978997890d6c886adba6

# RF03EW 2011:
# Between the 326 Local Authorities (LA)
# https://www.statistics.digitalresources.jisc.ac.uk/dataset/rf03ew-2011-srs-merged-lala-location-usual-residence-and-place-work/resource/a75b42d3-ee10
wget -nc https://s3-eu-west-1.amazonaws.com/statistics.digitalresources.jisc.ac.uk/dkan/files/FLOW/rf03ew_v1/rf03ew_v1.zip
# Can work for London
# Download documentation
wget -nc https://www.nomisweb.co.uk/datasets/1211_1/about.pdf

sed '1,9d;11d' mob_ew.csv > mob_ew_clean.csv # Remove 9 first and 11th rows

# 2011 wards 
# http://geoportal.statistics.gov.uk/datasets/e1ed938a33cf472fa802d99b1900164b_0
wget -nc https://opendata.arcgis.com/datasets/e1ed938a33cf472fa802d99b1900164b_0.zip?outSR=%7B%22wkid%22%3A27700%2C%22latestWkid%22%3A27700%7D
n=`echo $_ | awk -F"/" '{print $NF}'`
unzip -o ${n}
rm ${n}

# OA 2011
wget -nc https://opendata.arcgis.com/datasets/5a8a6ac972cc4ce4bc02f64f52f8ffd7_0.csv

# For the future if mob file found: output areas
# http://geoportal.statistics.gov.uk/datasets/09b8a48426e3482ebbc0b0c49985c0fb_1


# Correspondance table between WZs and OA (for 2011)
http://geoportal.statistics.gov.uk/datasets/5a8a6ac972cc4ce4bc02f64f52f8ffd7_0

# WZ shp
# https://data.gov.uk/dataset/328939e5-5f72-4706-af3d-49827d6c0610/workplace-zones-december-2011-full-extent-boundaries-in-england-and-wales
wget -nc geoportal1-ons.opendata.arcgis.com/datasets/a399c2a5922a4beaa080de63c0a218a3_1.zip




#########	ITALY	##########

# Download mob data
# https://www.istat.it/it/archivio/139381
wget -nc www.istat.it/storage/cartografia/matrici_pendolarismo/matrici_pendolarismo_2011.zip
unzip -o matrici_pendolarismo_2011.zip
mv MATRICE\ PENDOLARISMO\ 2011/* .

# Delete useless files
rm -r MATRICE\ PENDOLARISMO\ 2011/
rm matrici_pendolarismo_2011.zip
rm Thumbs.db

# Clean columns and replace " " by ";" as separator
# Filter: If journey motivation is work only ($6==2)
# Concatenate cols 3-4 & 8-9 (COD_PRO-COD_COM from origin & destination)
awk -F" " '{if ($6==2) print $3 $4 "," $8 $9 "," $15}' matrix_pendo2011_10112014.txt > MOB_ITA_2011.csv
# $14: Estimated commuters; $15: Observed commuters

# Header
sed -i '1iorigin, destination, commuters' MOB_ITA_2011.csv

sed -i 's/ND//g' MOB_ITA_2011.csv


# Download communes
# https://www.istat.it/it/archivio/124086
wget -nc www.istat.it/storage/cartografia/confini_amministrativi/archivio-confini/generalizzati/2011/Limiti_2011_WGS84_g.zip
unzip Limiti_2011_WGS84_g.zip
mv Limiti_2011_WGS84_g/Com2011_WGS84_g/Com2011_WGS84_g.* .
# rm -r Limiti_2011_WGS84_g



#########	USA	##########

# US Census bureau Data
# 2015 MOB (county and MCDs scale)
# https://www.census.gov/data/tables/time-series/demo/commuting/commuting-flows.html
wget -nc https://www2.census.gov/programs-surveys/demo/tables/metro-micro/2015/commuting-flows-2015/table3.xlsx 
wget -nc http://www2.census.gov/programs-surveys/acs/tech_docs/accuracy/MultiyearACSAccuracyofData2015.pdf # Documentation


xlsx2csv table3.xlsx > tmp1.csv # Convert xlsx to csv
tail -n +7 tmp1.csv > tmp2.csv # Remove 6 first rows
head -n -4 tmp2.csv > tmp3.csv # Remove 4 last rows

# Table structure ontaine :
    # Residence :
    #    - State FIPS Code
    #    - County FIPS Code
    #    - Minor Civil Division FIPS Code
    #    - State Name
    #    - State County
    #    - Minor Civil Division FIPS Name
    # Place of Work :
    #   - State FIPS Code
    #   - County FIPS Code
    #   - Minor Civil Division FIPS Code
    #   - State Name
    #   - State County
    #   - Minor Civil Division FIPS Name
    # Commuting :
    #   - Workers in commuting flow
    #   - Margin of Error


####  Counties (COU)
# paste StateCode + CountyCode to obtain a new code, for O & D
awk -F "," '{print $1 "," $2 "," $7 "," $8 "," $13}' tmp3.csv > mob_counties_2015.csv
# Boundaries shapefile 
wget -nc www2.census.gov/geo/tiger/GENZ2017/shp/cb_2017_us_county_20m.zip
# We use FIPS (Federal Information Processing Standard Publication)
# Chose COUNTYFP as ids, not COUNTYNS





#### Minor Civil Divisions (MCDs)

# Extract MOB: select StateCode + MCDCode by paste it later in R
awk -F "," '{print $1 "," $4 "," $3 "," $7 "," $10 "," $9 "," $13}' tmp3.csv > mob_mcd_2015.csv

# Boudary shapefile

# Only 12 US States are concerned by MCD in MOB file: Connecticut, Maine, Massachusetts, Michigan, Minnesota, New Hampshire, New Jersey, New York, Pennsylvania, Rhode Island, Vermont, Wisconsin
states_codes='09 23 25 26 27 33 34 36 42 44 50 55'

# Each state MCDs shapefile must be downloaded and unziped separatly
for code in $states_codes;
do
    wget -nc https://www2.census.gov/geo/tiger/TIGER2015/COUSUB/tl_2015_${code}_cousub.zip
    unzip -o tl_2015_${code}_cousub.zip
done

# Then, merge the 12 shapefiles into one
rm -f MCDs_merged.*
file="MCDs_merged.shp"
for i in $(ls tl_2015_*.shp)
do
    if [ -f $file ]
    then
        echo "Append  `du -h $i`"
        ogr2ogr -f 'ESRI Shapefile' -update -append $file $i -nln MCDs_merged
    else
        echo "Create $file"
        ogr2ogr -f 'ESRI Shapefile' $file $i
    fi
done
echo "Result: `du -h $file`"




#### Traffic Analysis Zones (TAZs) 

# Mobility file is not open ... 

# Boundary shapefilefile
# For TAZs, all states are concerned
states_codes=`seq -w 1 50`    # Other method: `echo {01..50}` 
for code in $states_codes;
do
	wget -nc https://www2.census.gov/geo/tiger/TIGER2010/TAZ/2010/tl_2011_${code}_taz10.zip
    unzip -o tl_2011_${code}_taz10.zip
done
