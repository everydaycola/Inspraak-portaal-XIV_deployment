#!/bin/bash

# Google Cloud Project
PROJECT_ID="cs2-eycken-tibo"   # LET OP: Dit hoort uniek te zijn dus voeg indien nodig een aantal cijfers toe (voorbeeld ons-eerste-project-1a)
PROJECT_NAME="IP-1"            # Pas aan naar een naam naar keuze
ZONE="europe-west1-d"          # laat zo of kies een andere, deze zones zijn te vinden met commando `gcloud compite zones list`
REGION="europe-west1"          # Laat zo of kies een andere, regios te vinden met `gcloud compute regions list`
DB_INSTANCE_NAME="postgres-db" # Naam voor de databank

# Instance Group settings
INSTANCE_TEMPLATE_NAME="web-instance-template" # Name of the VMs template
INSTANCE_GROUP_NAME="web-instance-group"       # Name of the MIG
MACHINE_TYPE="e2-medium"                       # The VMs machine type
MIN_INSTANCES=2                                # Min amount of instances in the MIG
MAX_INSTANCES=5                                # Max amount of instances in the MIG
TARGET_CPU_UTILIZATION=0.6                     # At which CPU-usage percentage we will scale-up

# Image Info
IMAGE_FAMILY="ubuntu-2004-lts"  # The chosen ubuntu images family
IMAGE_PROJECT="ubuntu-os-cloud" # Where the ubuntu image can be found in the cloud

# Load Balancer Settings
HEALTH_CHECK_NAME_LB="web-health-check"    # Name for the health checks of the LB
HEALTH_CHECK_NAME_MIG="mig-health-check"   # Name for the health checks of the MIG
BACKEND_SERVICE_NAME="web-backend-service" # Name for the load-balancers backend
URL_MAP_NAME="web-url-map"                 # Name for the url-map
HTTPS_PROXY_NAME="web-https-proxy"
SSL_CERT="cloudflare-origin-cert"                  # Name for the ssl cert
DOMAIN="ip14.be"                                   # The domain name
CERT_NAME="my-cert"                                # Name of the google-managed cert
DNS_AUTH_NAME="my-dns-auth"                        # Name for dns-authentication
CERT_MAP_NAME="my-map"                             # Name for the certificate mapping
CERT_ENTRY_1="my-domain-entry"                     # Name certificate entry for domain
CERT_ENTRY_2="my-domain-and-wildcard-entry"        # Name certificate entry for the wildcard
FORWARDING_RULE_HTTPS_NAME="https-forwarding-rule" # Name forwarding rule
STATIC_IP_NAME="loadbalancer-static-ip"            # Naam statisch IP loadbalancer

# VPC variables
VPC_NETWORK_NAME="my-network"                  # Naam VPC netwerk
VPC_NETWORK_REGION="europe-west1"              # regio voor de VMs
VPC_SUBNET_NAME="subnet-for-my-network"        # subent naam
VPC_SUBNET_RANGE="10.10.0.0/24"                # subnet range voor de virtuale machines
PSA_RANGE_NAME="google-managed-services-range" # needed for Redis instance
PSA_IP_RANGE_CIDR="10.20.0.0/24"

# Startup Script
STARTUP_SCRIPT="vmScripts/startup-script.sh" # pad naar startup-script

# Postgres variables
DB_REGION="europe-west1"         # Regio waar de databank draait
SQL_TIER="db-perf-optimized-N-2" # Tier van de postgres server
SQL_VERSION="POSTGRES_17"        # Versie van postgres
BACKUP_START_TIME="23:00"        # Wanneer backups gebeuren
RETAINED_BACKUPS="2"             # Aantal backups dat je wilt bewaren
