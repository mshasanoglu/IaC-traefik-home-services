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

printf "\n${CYAN} STARTING PIPELINE \n\n${NC}"

# load .env file
printf "\n${PURPLE} REMOVING COMMENTS FROM .env FILE \n\n${NC}"
sed -i "s/# e.g.*//  " .env
printf "\n${PURPLE} LOADING ENVIRONMENT VARIABLES \n\n${NC}"
export $(grep -v '^#' .env | xargs)

# generate traefik credentials to hash
printf "\n${PURPLE} CREATING HASH CREDENTIALS FOR BasicAUTH LOGINS \n\n${NC}"
export BASIC_AUTH_CREDS=$(htpasswd -nb $BASIC_AUTH_USERNAME $BASIC_AUTH_PASSWORD)

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
printf "\n${PURPLE} STARTING SERVICES \n\n${NC}"
docker-compose up -d
printf "\n${PURPLE} ALL SERVICES STARTED \n\n${NC}"

# update the cloud container to install missing package on nextcloud
printf "\n${PURPLE} UPDATING CONTAINER PACKEGES AND INSTALLING REQUIRED PACKAGES FOR NEXTCLOUD \n\n${NC}"
docker-compose exec cloud-app apt -y update
docker-compose exec cloud-app apt -y install libmagickcore-6.q16-6-extra
printf "\n${PURPLE} REQUIRED PACKAGES FOR NEXTCLOUD INSTALLED \n\n${NC}"

# give nextcloud container time to append extra configuration values
printf "\n${PURPLE} WAITING 20 SECONDS TO ADD EXTRA CONFIGURATION VALUES TO NEXTCLOUD \n\n${NC}"
sleep 20
printf "\n${PURPLE} ADDING EXTRA VALUES AND RESTARTING NEXTCLOUD CONTAINER\n\n${NC}"
sed -i "/overwrite.cli.url/d" $DATA_PATH/cloud-app/config/config.php
sed -i "/);/i \  'overwrite.cli.url' => '${NEXTCLOUD_PROTOCOL}://${NEXTCLOUD_ALIAS}.${DOMAIN}'," $DATA_PATH/cloud-app/config/config.php
sed -i "/);/i \  'default_phone_region' => '${PHONE_REGION}'," $DATA_PATH/cloud-app/config/config.php
docker-compose exec --user www-data cloud-app /var/www/html/occ config:app:set text workspace_available --value=0
docker-compose exec cloud-app sed -i "/opcache.interned_strings_buffer/c\opcache.interned_strings_buffer=32" /usr/local/etc/php/conf.d/opcache-recommended.ini
docker-compose restart cloud-app 

printf "\n${CYAN} PIPELINE DONE \n\n${NC}"