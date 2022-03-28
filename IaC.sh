#!/bin/bash

docker-compose up -d cloud-app
sleep 30
sed -i "/);/i \  'default_phone_region' => 'DE'," data/cloud-app/config/config.php
