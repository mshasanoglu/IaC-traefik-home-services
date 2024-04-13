#!/bin/bash


# user config
for var in $(compgen -e); do
	if [[ "$var" == NEXTCLOUD_CONFIG_* ]]; then
		app=$(echo ${var/NEXTCLOUD_CONFIG_/} | tr '[:upper:]' '[:lower:]')
		case $app in
			"default_language" | "default_locale" | "default_phone_region" | "skeletondirectory")
				config="config:system:set"
				appcmd="$app"
			;;
			"maintenance_window_start")
				config="config:system:set"
				appcmd="$app --type=integer"
			;;
			"workspace_available")
				config="config:app:set"
				appcmd="text $app"
			;;
			*)
				config="config:app:set"
				appcmd="$app enabled"
			;;
		esac
		/var/www/html/occ $config $appcmd --value="${!var}"
	fi
done

# check db for missing indices
/var/www/html/occ db:add-missing-indices
/var/www/html/occ db:convert-filecache-bigint

# clean log file
rm /var/www/html/data/nextcloud.log