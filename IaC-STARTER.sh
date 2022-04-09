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

# modify mariadb init file
printf "\n${PURPLE} MODIFYING MARIADB INIT FILE \n\n${NC}"
sed -i "s/USER/${MYSQL_USER}/g" config/mariadb/init.sql
sed -i "s/WORDPRESS_DB/${WORDPRESS_DB}/g" config/mariadb/init.sql
sed -i "s/NEXTCLOUD_DB/${NEXTCLOUD_DB}/g" config/mariadb/init.sql


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
sed -i "/overwrite.cli.url/d" data/cloud-app/config/config.php
sed -i "/);/i \  'overwrite.cli.url' => '${NEXTCLOUD_PROTOCOL}://${NEXTCLOUD_ALIAS}.${DOMAIN}'," data/cloud-app/config/config.php
sed -i "/);/i \  'default_phone_region' => '${PHONE_REGION}'," data/cloud-app/config/config.php

printf "\n${CYAN} PIPELINE DONE \n\n${NC}"
