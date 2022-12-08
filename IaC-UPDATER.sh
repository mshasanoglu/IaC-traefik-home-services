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

# start building applications
printf "\n${PURPLE} UPDATING SERVICES\n\n${NC}"
docker-compose up -d
printf "\n${PURPLE} ALL SERVICES UPDATED \n\n${NC}"

# update the cloud container to install missing package on nextcloud
printf "\n${PURPLE} UPDATING CONTAINER PACKEGES AND INSTALLING REQUIRED PACKAGES FOR NEXTCLOUD IF NEEDED \n\n${NC}"
REQUIRED_PKG="libmagickcore-6.q16-6-extra"
PKG_OK=$(docker-compose exec cloud-app dpkg-query -W --showformat='${Status}\n' $REQUIRED_PKG|grep "install ok installed")

if [ "" = "$PKG_OK" ]; then
  echo "No $REQUIRED_PKG. Setting up $REQUIRED_PKG."
  docker-compose exec cloud-app apt -y update
  docker-compose exec cloud-app apt -y install $REQUIRED_PKG
  printf "\n${PURPLE} REQUIRED PACKAGES FOR NEXTCLOUD INSTALLED \n\n${NC}"
fi

# append extra configuration values
printf "\n${PURPLE} DB FIX, ADDING EXTRA VALUES AND RESTARTING NEXTCLOUD CONTAINER IF NEEDED \n\n${NC}"
docker-compose exec --user www-data cloud-app /var/www/html/occ db:add-missing-indices
docker-compose exec --user www-data cloud-app /var/www/html/occ db:convert-filecache-bigint
WORKSPACE_AVAILABLE=$(docker-compose exec --user www-data cloud-app /var/www/html/occ config:app:get text workspace_available | head -c1)
INTERNED_STRINGS_BUFFER=$(docker-compose exec cloud-app awk -F "=" '/opcache.interned_strings_buffer/ {print $2}' /usr/local/etc/php/conf.d/opcache-recommended.ini | head -c2)
VALUES_CHANGED=false

if [ $WORKSPACE_AVAILABLE != 0 ]; then
  docker-compose exec --user www-data cloud-app /var/www/html/occ config:app:set text workspace_available --value=0
  VALUES_CHANGED=true
fi
if [ $INTERNED_STRINGS_BUFFER != 32 ]; then
  docker-compose exec cloud-app sed -i "/opcache.interned_strings_buffer/c\opcache.interned_strings_buffer=32" /usr/local/etc/php/conf.d/opcache-recommended.ini
  VALUES_CHANGED=true
fi
if [ $VALUES_CHANGED = true ]; then
  docker-compose restart cloud-app 
  printf "\n${PURPLE} REQUIRED VALUES FOR NEXTCLOUD ADDED \n\n${NC}"
fi

printf "\n${CYAN} PIPELINE DONE \n\n${NC}"







