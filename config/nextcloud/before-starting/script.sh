#!/bin/bash

# user config
/var/www/html/occ config:system:set overwrite.cli.url --value="$OVERWRITEPROTOCOL://$OVERWRITEHOST"
/var/www/html/occ config:system:set default_phone_region --value="$PHONE_REGION"
/var/www/html/occ config:app:set activity enabled --value="$NEXTCLOUD_CONFIG_ACTIVITY"
/var/www/html/occ config:app:set circles enabled --value="$NEXTCLOUD_CONFIG_CIRCLES"
/var/www/html/occ config:app:set recommendations enabled --value="$NEXTCLOUD_CONFIG_RECOMMENDATIONS"
/var/www/html/occ config:app:set text workspace_available --value="$NEXTCLOUD__CONFIG_WORKSPACE"
/var/www/html/occ config:app:set user_status enabled --value="$NEXTCLOUD_CONFIG_USERSTATUS"
/var/www/html/occ app:$([[ $NEXTCLOUD_APP_DASHBOARD == true ]] && echo enable || echo disable) dashboard

# check db for missing indices
/var/www/html/occ db:add-missing-indices
/var/www/html/occ db:convert-filecache-bigint