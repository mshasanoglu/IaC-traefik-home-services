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
export $(grep -v '^#' .env | xargs)
printf "\n${PURPLE} LOADING ENVIRONMENT VARIABLES \n\n${NC}"

# generate traefik credentials to hash
export BASIC_AUTH_CREDS=$(htpasswd -nb $BASIC_AUTH_USERNAME $BASIC_AUTH_PASSWORD)
printf "\n${PURPLE} CREATING HASH CREDENTIALS FOR BasicAUTH LOGINS \n\n${NC}"

# start building applications
printf "\n${PURPLE} UPDATING SERVICES\n\n${NC}"
docker-compose up -d
printf "\n${PURPLE} ALL SERVICES UPDATED \n\n${NC}"

# update the cloud container to install missing package on nextcloud
printf "\n${PURPLE} UPDATING CONTAINER PACKEGES AND INSTALLING REQUIRED PACKAGES FOR NEXTCLOUD \n\n${NC}"
docker-compose exec cloud-app apt -y update
docker-compose exec cloud-app apt -y install libmagickcore-6.q16-6-extra
printf "\n${PURPLE} REQUIRED PACKAGES FOR NEXTCLOUD INSTALLED \n\n${NC}"

# append extra configuration values
printf "\n${PURPLE} ADDING EXTRA VALUES AND RESTARTING NEXTCLOUD CONTAINER\n\n${NC}"
docker-compose exec --user www-data cloud-app /var/www/html/occ config:app:set text workspace_available --value=0
docker-compose exec cloud-app sed -i "/opcache.interned_strings_buffer/c\opcache.interned_strings_buffer=32" /usr/local/etc/php/conf.d/opcache-recommended.ini
docker-compose restart cloud-app 

printf "\n${CYAN} PIPELINE DONE \n\n${NC}"
