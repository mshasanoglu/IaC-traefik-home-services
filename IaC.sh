#!/bin/bash


# output colors
NC='\e[0m'
RED='\e[1;31m'
DARK_RED='\e[0;31m'
GREEN='\e[1;32m'
YELLOW='\e[1;33m'
DARK_YELLOW='\e[0;33m'
BLUE='\e[1;34m'
PURPLE='\e[1;35m'
CYAN='\e[1;36m'
WHITE='\e[1;37m'

# logger
logger() {
  case $1 in
    "SECTION")
      key=${PURPLE}
      value="\n $2\n\n${NC}"
      ;;
    "PIPELINE")
      key=${GREEN}
      value=" $2\n${NC}"
      ;;
    "INFO")
      key="${WHITE}$1:${NC}"
      value="   $2\n${NC}"
      ;;
    "ACTION")
      key="${YELLOW}$1:${DARK_YELLOW}"
      value=" $2\n${NC}"
      ;;
    "WARNING")
      key="${YELLOW}$1:${DARK_YELLOW}"
      value="$2\n${NC}"
      ;;
    "ERROR")
      key="${RED}$1:${DARK_RED}"
      value="  $2\n${NC}"
      ;;
    *)
      key="${GREEN}* "
      value="${YELLOW}$1${CYAN}$2\n${NC}"
      ;;
  esac

  printf "$key $value"
}

# check if the script executed by root user
[[ "$EUID" != 0 ]] && logger "ERROR" "PLEASE RUN AS ROOT" && exit 1

# define the usage function to display help
usage() {
  printf "\n${WHITE}Usage:   $0 -e <env> -a <action>"
  printf "\n${DARK_YELLOW}Options:"
  printf "\n${YELLOW}         -e <env>     Specify the env ${DARK_YELLOW}  (required, values: prod or staging)"
  printf "\n${YELLOW}         -a <action>  Specify the action ${DARK_YELLOW}  (required, values: start, update, stop)"
  printf "\n${DARK_YELLOW}         -h <help>    Display this help message \n\n${NC}"
  exit 1
}

# initialize variables with default values
env=""
action=""

# use getopts to process command line options
while getopts ":e:a:h" opt; do
  case $opt in
    e)
      env="$OPTARG"
      ;;
    a)
      action="$OPTARG"
      ;;
    h)
      usage
      ;;
    \?)
      logger "ERROR" "Invalid option: -$OPTARG!"
      usage
      ;;
    :)
      logger "ERROR" "Option -$OPTARG requires an argument!"
      usage
      ;;
  esac
done

# check if required options are provided
if [[ -z "$env" ]] || [[ -z "$action" ]]; then
  logger "ERROR" "Missing required options!"
  usage
fi

# validate env values
if [[ "$env" != "prod" ]] && [[ "$env" != "staging" ]]; then
  logger "ERROR" "Invalid env! Please use 'prod' or 'staging'"
  usage
fi

# validate action values
if [[ "$action" != "start" ]] && [[ "$action" != "update" ]] && [[ "$action" != "stop" ]]; then
  logger "ERROR" "Invalid action! Please use 'start', 'update' or 'stop'"
  usage
fi

# check required packages
! dpkg -s apache2-utils >/dev/null 2>&1 && logger "ERROR" "Missing required package! Install 'apache2-utils' for htpasswd (BasicAUTH Credentials)" && exit 1
! dpkg -s docker-compose-plugin >/dev/null 2>&1 && logger "ERROR" "Missing required package! Install 'docker-ce && docker-compose-plugin' from official docker instructions page" && exit 1

# comments of env file in same line
env_file=$(< .env)
new_content=""
while IFS= read -r line; do
  [[ "$line" == "#"* || ! "$line" =~ [^[:space:]] ]] && continue
  entry=$(sed "s/[ ][ ].*#.*<=.*//g" <<< "$line")
  min_line_length=$([[ ${#entry} -gt $min_line_length ]] && echo ${#entry} || echo $min_line_length)
done <<< $env_file

while IFS= read -r line; do
  comment=$(grep -Po "#.*<=.*" <<< "$line")
  entry=$(sed "s/[ ][ ].*#.*<=.*//g" <<< "$line")
  space_diff=$(($min_line_length - ${#entry}))
  line_length=$(($space_diff + 5))
  spaces=""
  for ((i=1; i<=$line_length; i++)); do
    spaces+=" "
  done
  entry=$(sed "s/ *$//" <<< "$entry")
  new_content+="${entry}${spaces}${comment}\n"
done <<< $env_file
echo -e "$new_content" > .env

# load .env file
logger "SECTION" "LOADING ENVIRONMENT VARIABLES"
[[ ! -f ".env" ]] && logger "ERROR" "file '.env' does not exist!" && exit 1
set -a
source .env
set +a
export NEXTCLOUD_STARTUP_CMD=$([[ $NEXTCLOUD_STARTUP_CMD ]] && echo "$NEXTCLOUD_STARTUP_CMD && /entrypoint.sh apache2-foreground" || echo "/entrypoint.sh apache2-foreground")
logger "INFO" "Environments loaded"

# check if the data path exists and returns the number of items in it
check_data_path() {
  logger "SECTION" "CHECKING DATA PATH AND CONTENTS OF DATA PATH"
  if [[ ! -d "$DATA_PATH" ]]; then
    logger "ERROR" "Data path does not exist!"
    exit 1
  else
    logger "INFO" "Data path exists"
    return $(find $DATA_PATH -mindepth 1 | wc -l)
  fi
}

# start pipeline 
start_pipeline() {
  # start pipeline with provided args
  printf "\n"
  logger "PIPELINE" "STARTING PIPELINE WITH FOLLOWING ARGS"
  logger ""
  logger "     env: " "$env"
  logger "  action: " "$action"
  logger ""
  export ENV=$env

  # filter profiles for deployment
  profiles=""
  for var in $(compgen -e); do
    if [[ "$var" == *_DEPLOY* && "${!var}" == "true" ]]; then
      modified_variable="${var/_DEPLOY/_PROFILE_NAME}"
      profiles+=",${!modified_variable}"
    fi
  done

  profiles=${profiles#,}
  if [[ -n $profiles ]]; then
    logger "PIPELINE" "GETTING DEPLOYMENT PROFILES"
    logger ""
    logger "profiles: " "$profiles"
    logger ""
    export COMPOSE_PROFILES=$profiles
  else
    logger "ERROR" "There is no Deployment activated! Please update your .env file"
    exit 1
  fi

}

# generate traefik credentials to hash
generate_traefik_credentials_to_hash(){
  logger "PIPELINE" "GENERATING HASH CREDENTIALS"
  export BASIC_AUTH_CREDS="$(htpasswd -nb $BASIC_AUTH_USERNAME $BASIC_AUTH_PASSWORD)"
  logger ""
  logger "    user: " "$BASIC_AUTH_USERNAME"
  logger ""
}

# prepare db
prepare_db() {
  logger "PIPELINE" "PREPARING DB"
  logger ""
  if [[ $MYSQL_DEPLOY == "false" ]]; then
    logger "ERROR" "Activation of NEXTCLOUD or WORDPRESS require activation of MYSQL!"
    exit 1
  elif [[ $action == "update" && -f "$DATA_PATH/db/init/init.sql" ]]; then
    logger "      db: " "init.sql found in data path"
  else
    mkdir -p $DATA_PATH/db/init
    for file in ./config/mariadb/*
    do
      FILENAME=$(basename $file)
      sed  "s/USER_NAME/${MYSQL_USER}/g ; s/DB_NAME/${!FILENAME}/g ; $ a \ " $file >> $DATA_PATH/db/init/init.sql
      logger "      db: " "$FILENAME added"
    done
    logger "      db: " "init.sql created"
  fi
  logger ""
}

# service handler
service_handler() {
  logger "PIPELINE" "$1 SERVICES"
  logger ""
  docker compose $2
}

# check cloud-app
check_cloud_app() {
  [[ $PLEX_DEPLOY == "true" || $API_DEPLOY == "true" ]] && docker compose exec --user www-data cloud-app /var/www/html/occ files:scan --all -q
  [[ $NEXTCLOUD_DEPLOY == "true" ]] && chown -R www-data: $DATA_PATH/cloud-app/*
}

# action handler
case $action in
  "start")
    if check_data_path; then
      logger "INFO" "Data path has no content. Ready to deploy"
    else
      logger "INFO" "Data path has content"
      logger "ACTION" "This operation will clear the data path. Are you sure you want to continue?"
      printf "${YELLOW}(y/n):   ${NC}"
      read -n 1 confirmation
      printf "\n"

      # check if the user wants to continue
      if [[ "$confirmation" != "y" ]]; then
        logger "WARNING" "Operation canceled. You can run the script again with '-a update' to handle existing data"
        exit 1
      else
        logger "ACTION" "Do you want to keep the ssl certificates to prevent the maximum number of Let's Encrypt requests?"
        printf "${YELLOW}(y/n):   ${NC}"
        read -n 1 confirmation
        printf "\n"

        # check if the user wants to continue
        if [[ "$confirmation" != "y" ]]; then
          rm -rf $DATA_PATH/*
          logger "INFO" "Data path cleared"
        else
          find $DATA_PATH -mindepth 1 -maxdepth 1 ! -name ssl-certs -exec rm -rf {} +
          logger "INFO" "Data path cleared without deleting the ssl certificates"
        fi
      fi
    fi

    start_pipeline
    generate_traefik_credentials_to_hash
    [[ $NEXTCLOUD_DEPLOY == "true" || $WORDPRESS_DEPLOY == "true" ]] && prepare_db
    service_handler "STARTING" "up -d --wait"
    check_cloud_app
    ;;
  "update")
    if check_data_path; then
      logger "ERROR" "Data path has no content! You can run the script again with '-a start'"
      exit 1
    else
      logger "INFO" "Data path has content"
    fi

    start_pipeline
    generate_traefik_credentials_to_hash
    [[ $NEXTCLOUD_DEPLOY == true || $WORDPRESS_DEPLOY == true ]] && prepare_db
    service_handler "UPDATING" "up -d --wait"
    check_cloud_app
    ;;
  "stop")
    start_pipeline
    service_handler "STOPPING" "down"
esac
logger "PIPELINE" "PIPELINE DONE"