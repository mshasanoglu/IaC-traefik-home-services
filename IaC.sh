#!/bin/bash

docker-compose up -d cloud-app
docker-compose exec cloud-app apt -y update
docker-compose exec cloud-app apt -y install libmagickcore-6.q16-6-extra
sleep 30
sed -i "/);/i \  'default_phone_region' => 'DE'," data/cloud-app/config/config.php
