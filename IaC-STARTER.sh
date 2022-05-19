#!/bin/bash

# Output Colors
NC='\033[0m'
RED='\033[0;91m'
CYAN='\033[0;96m'
PURPLE='\033[0;95m'

# check if the script executed by root user
if [ "$EUID" != 0 ]
  then printf "\n${RED} PLEASE RUN AS ROOT \n\n${NC}"
  exit
fi
printf "\n${CYAN} PIPELINE START \n\n${NC}"

# load .env file
export $(grep -v '^#' .env | xargs)
printf "\n${PURPLE} ENVIRONMENT VARIABLES LOADED \n\n${NC}"

# generate traefik credentials to hash
export SCRIPT_GENERATED_CREDS=$(htpasswd -nb $TRAEFIK_WEB_USER $TRAEFIK_WEB_PASSWORD)
printf "\n${PURPLE} HASH CREDENTIALS FOR TRAEFIK DASHBOARD CREATED\n\n${NC}"

# modify mariadb init file
printf "\n${PURPLE} MODIFYING MARIADB INIT FILE \n\n${NC}"
mkdir -p $DATA_PATH/db/init
for file in ./config/mariadb/*
do
  FILENAME=$(basename $file)
  printf "\n${PURPLE} EDITING $FILENAME \n${NC}"
  sed  "s/USER_NAME/${MYSQL_USER}/g ; s/DB_NAME/${!FILENAME}/g ; $ a \ " $file >> $DATA_PATH/db/init/init.sql
done

# start building applications
printf "\n${PURPLE} STARTING DOCKER-COMPOSE \n\n${NC}"
docker-compose up -d
printf "\n${PURPLE} ALL SERVICES STARTED \n\n${NC}"

# update the cloud container to install missing package on nextcloud
printf "\n${PURPLE} NEXTCLOUD CONTAINER UPDATING PACKAGES AND INSTALLING MISSING PACKAGE \n\n${NC}"
docker-compose exec cloud-app apt -y update
docker-compose exec cloud-app apt -y install libmagickcore-6.q16-6-extra
printf "\n${PURPLE} MISSING PACKAGE FOR NEXTCLOUD INSTALLED \n\n${NC}"

# give nextcloud container time to append extra configuration values
printf "\n${PURPLE} WAITING 20 SECONDS TO APPEND EXTRA CONFIGURATION VALUES TO NEXTCLOUD \n\n${NC}"
sleep 20
printf "\n${PURPLE} ADDING EXTRA VALUES \n\n${NC}"
sed -i "/overwrite.cli.url/d" $DATA_PATH/cloud-app/config/config.php
sed -i "/);/i \  'overwrite.cli.url' => '${NEXTCLOUD_PROTOCOL}://${NEXTCLOUD_ALIAS}.${DOMAIN}'," $DATA_PATH/cloud-app/config/config.php
sed -i "/);/i \  'default_phone_region' => '${PHONE_REGION}'," $DATA_PATH/cloud-app/config/config.php

printf "\n${CYAN} PIPELINE DONE \n\n${NC}"
