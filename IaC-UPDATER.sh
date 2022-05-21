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

printf "\n${CYAN} PIPELINE DONE \n\n${NC}"
