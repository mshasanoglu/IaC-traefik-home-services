# Home Services - Infrastructure as Code (IaC) Deployment

This repository contains Infrastructure as Code (IaC) for deploying various home services using Docker Compose. Follow the instructions below to set up and deploy the services on your server.

## Prerequisites

Before proceeding, ensure you have the following prerequisites installed on your server:

- Docker
- Docker Compose
- sudo privileges

## Services Overview

All services are behind the Traefik reverse proxy, and their configurations are defined in the `docker-compose.yml` file.

Here is an overview of the included services:

- **WireGuard VPN**
- **Traefik Reverse Proxy**
- **Whoami**
- **VS Code**
- **Pi-hole**
- **Matter (Server)**
- **Smarthome (Home Assistant)**
- **MySQL Database (MariaDB)**
- **Homepage (WordPress)**
- **Cloud (Nextcloud)**
- **Plex Media Server**
- **API (FastAPI)**

## Requirements

### 1. Dynamic DNS (DDNS) for Server
If your home server's public IP address is dynamic (changes periodically), consider using a Dynamic DNS (DDNS) service. This ensures that your domain always points to the correct IP address, even if it changes. Set up a DDNS service and configure your router to update the DDNS provider with the current IP address.

### 2. Domain with CNAME Entries
You need a registered domain (e.g., `mydomain.de`) with CNAME (Canonical Name) entries for each service you deploy.

Example:

- `traefik.mydomain.de` CNAME to the Traefik service
- `pihole.mydomain.de` CNAME to the Pihole service
- `cloud.mydomain.de` CNAME to the Cloud service
- ... and so on for each service

Ensure that both the domain and DDNS settings are configured correctly before deploying the services.
The aliases in `.env` file should match the CNAME entries you set up for your domain.

Example:

```bash
# Traefik
TRAEFIK_ALIAS=traefik

# Pihole
PIHOLE_ALIAS=pihole

# Cloud
NEXTCLOUD_ALIAS=cloud

# ... and so on for each service
```

### 3. Port Forwarding

Ensure the following ports are forwarded on your home router to access the deployed services:

- **Traefik (HTTP/HTTPS):**
  - Port: 80 (HTTP)
  - Port: 443 (HTTPS)
  - Protocol: TCP

- **WireGuard VPN:**
  - Port: Specify the value set in the `WIREGUARD_SERVERPORT` variable in your `.env` file (default: 51820)
  - Protocol: UDP (WireGuard requires UDP port forwarding)

- **Plex Media Server:**
  - Port: Specify the value set in the `PLEX_PORT` variable in your `.env` file (default: 32400)
  - Protocol: TCP

Adjust the port forwarding settings on your home router to forward external requests on these ports to the internal IP address of the server running the deployed services. Consult your router's manual or support documentation for guidance on setting up port forwarding.

## Configuration

### 1. Environment Variables

Copy the provided `.env_template` file to `.env` and fill in the required values.

```bash
cp .env_template .env
```

Edit the `.env` file and provide values for the configuration parameters such as `DATA_PATH`, `HOST_IP`, `DOMAIN`, `TZ`, etc.

All services will use the provided `DATA_PATH` value specified in the `.env` file. This path is crucial for organizing and persisting data generated by the deployed services, such as VPN configuration files. The deployment will use this directory as the base path. Other paths specified in the `.env` file are subpaths of the `DATA_PATH`.

Example:
```bash
DATA_PATH=/home/user1/homeservices
PLEX_DATA=cloud-app/data/cloud-user1/files/plex-media
```
This configuration will mount the path for Plex as:
- `$DATA_PATH/$PLEX_DATA`  
- In this case: `/home/user1/homeservices/cloud-app/data/cloud-user1/files/plex-media`

Ensure that the `DATA_PATH` is accessible.

### 2. Activate Services

Activate the services you want to deploy by setting the corresponding environment variables in the `.env` file. For each service, set the corresponding `<SERVICE_NAME>_DEPLOY` variable to `true` to enable deployment.

Example (Activate Pi-hole and Nextcloud):

```bash
PIHOLE_DEPLOY=true
NEXTCLOUD_DEPLOY=true
```

### 3. Dynamic Load Balancing

Customize load balancing by using the `/dynamic-conf` folder under the `/config` folder. You can place manual load balancing configurations in this folder. For example, a template (`gw-router.yml-template`) is provided for load balancing the home router. Rename it to `gw-router.yml` and adjust the configuration `rule:` and `url:` as needed:

```yml
http:
  routers:
    gw-router:
      service: gw-router
      tls:
        certResolver: "prod"
      rule: "Host(`router.mydomain.de`)"
  services:
    gw-router:
      loadBalancer:
        servers:
          - url: "http://192.168.2.1"
```

## Additional Configuration Folders

#### `/fastapi`

This folder contains the required files to build a FastAPI app. Keep it as it is.

After deployment, place your own FastAPI-written app with Python in the volume-mounted folder specified by the `API_DATA` value in the `.env` file. The container will look for a `main.py` file with FastAPI implementation inside the provided path.

Example main.py:
```python
from fastapi import FastAPI

app = FastAPI()

@app.get("/")
def read_root():
    return {"message": "User App is running"}
```
Check the logs if the API is not running as expected and try to restart the fastapi container.
```bash
docker logs -f fastapi
```

#### `/mariadb`

The `/mariadb` folder includes DB table initialization files. Adding empty files with the same naming pattern of the included files (`NEXTCLOUD_DB` and `WORDPRESS_DB`) will initialize the tables during deployment with the name of the files without "_DB".

#### `/nextcloud`

The `/nextcloud` folder includes three subfolders: `/pre-installation`, `/post-installation`, and `/before-starting`. Customize the shell scripts in these folders to run specific tasks during different stages of the Nextcloud container's lifecycle:

- `/pre-installation`: Run on the first start of the container.
- `/post-installation`: Run on the first start of the container.
- `/before-starting`: Run every time the container stops and starts or restarts.

Feel free to edit or add shell scripts to these folders to tailor the Nextcloud container's behavior to your requirements.

## Deployment Script

Use the provided deployment script `IaC.sh` to manage the deployment pipeline. The script requires root (sudo) privileges.

```bash
sudo ./IaC.sh -e <env> -a <action>
```

- `-e <env>`: Specify the environment (required, values: prod or staging).
- `-a <action>`: Specify the action (required, values: start, update, stop).
- `-h`: Display help message.

Example:

```bash
sudo ./IaC.sh -e prod -a start
```

## Notes

- Make sure to configure your router for port forwarding if necessary, especially for services like WireGuard and Plex.
- Keep your `.env` file secure, as it contains sensitive information.

- Some services are dependent on others for proper functionality. For example, Nextcloud and WordPress may rely on the DB service for database operations. Ensure that dependent services are successfully deployed and healthy before deploying services that rely on them.

- The deployment process may take some time as services are initialized, configurations are applied, and containers are created. Be patient and allow the process to complete. Monitor the progress by observing the output of the deployment script and checking the health status of containers.
To check the live status of containers, open another terminal and use the following command:
    ```bash
    watch -n 1 docker ps
    ```

Feel free to customize this setup according to your preferences and needs.

---
### **Now you can buy me a coffee**
<a href="https://www.buymeacoffee.com/mshasanoglu"><img src="https://img.buymeacoffee.com/button-api/?text=Buy me a coffee&emoji=☕&slug=mshasanoglu&button_colour=1a3b70&font_colour=ffffff&font_family=Cookie&outline_colour=ffffff" /></a>