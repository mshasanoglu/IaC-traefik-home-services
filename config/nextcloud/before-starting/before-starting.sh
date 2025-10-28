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

# set redis config
/var/www/html/occ config:system:set redis host --value='in-memory-db'
/var/www/html/occ config:system:set redis port --value=$REDIS_PORT
/var/www/html/occ config:system:set redis password --value=''
/var/www/html/occ config:system:set redis dbindex --value=$REDIS_DBINDEX
/var/www/html/occ config:system:set redis timeout --value=$REDIS_TIMEOUT

# memcached config
/var/www/html/occ config:system:set memcache.local --value='\OC\Memcache\APCu'
/var/www/html/occ config:system:set memcache.distributed --value='\OC\Memcache\Redis'
/var/www/html/occ config:system:set memcache.locking --value='\OC\Memcache\Redis'

# check db for missing indices
/var/www/html/occ db:add-missing-indices
/var/www/html/occ db:convert-filecache-bigint
/var/www/html/occ maintenance:repair --include-expensive

# clean log file
rm /var/www/html/data/nextcloud.log