# Infrastructure as Code (IaC)
This project provides recommended Home-Services that are pre-configured before deployment.
All Services are deployed behind the proxy and using SSL.

## STEP's before deployment
* rename the file `.env_template` to `.env`
* edit your environment variables inside the previously renamed `.env` file

## REQUIRED ❗️
* `docker-compose` installation
* Own DOMAIN with CNAME entries for the SUBDOMAINS (Alias values inside the `.env` file)
* Port Forwarding `80` and `443` on your Router configurations

## Deployment
Start the deployment script with the command `sudo ./IaC-STARTER.sh` and lean back 😎

## Modify/Update
Use the Updater script with the command `sudo ./IaC-UPDATER.sh` for config updates, version updates or additional Service integrations
