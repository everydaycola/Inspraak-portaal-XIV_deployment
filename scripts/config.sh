#!/bin/bash

# Google Cloud Project
PROJECT_ID="ip14-complete-test7"
PROJECT_NAME="IP-1"
ZONE="europe-west1-d"
REGION="europe-west1"

# Instance Group settings
INSTANCE_TEMPLATE_NAME="web-instance-template"
INSTANCE_GROUP_NAME="web-instance-group"
MACHINE_TYPE="e2-medium"
MIN_INSTANCES=2
MAX_INSTANCES=5
TARGET_CPU_UTILIZATION=0.6 # Autoscale when CPU > 60%

# Image Info
IMAGE_FAMILY="ubuntu-2004-lts"
IMAGE_PROJECT="ubuntu-os-cloud"

# Load Balancer Settings
HEALTH_CHECK_NAME="web-health-check"
BACKEND_SERVICE_NAME="web-backend-service"
URL_MAP_NAME="web-url-map"
#HTTP_PROXY_NAME="web-http-proxy"
HTTPS_PROXY_NAME="web-https-proxy"
SSL_CERT="cloudflare-origin-cert"
DOMAIN="ip14.be"
CERT_NAME="my-cert"
DNS_AUTH_NAME="my-dns-auth"
CERT_MAP_NAME="my-map"
CERT_ENTRY_1="my-domain-entry"
CERT_ENTRY_2="my-domain-and-wildcard-entry"
#FORWARDING_RULE_HTTP_NAME="web-forwarding-rule"
FORWARDING_RULE_HTTPS_NAME="https-forwarding-rule"
STATIC_IP_NAME="loadbalancer-static-ip"

# VPC variables
VPC_NETWORK_NAME="my-network"
VPC_NETWORK_REGION="europe-west1"
VPC_SUBNET_NAME="subnet-for-my-network"
VPC_SUBNET_RANGE="10.10.0.0/24"
PSA_RANGE_NAME="google-managed-services-range" # needed for Redis instance
PSA_IP_RANGE_CIDR="10.20.0.0/24"

# Startup Script
STARTUP_SCRIPT="startup-script.sh"

# Postgres variables
DB_INSTANCE_NAME="postgres-db"
DB_REGION="europe-west1"
SQL_TIER="db-perf-optimized-N-2"
SQL_VERSION="POSTGRES_17"

# Bucket var
BUCKET_NAME="ip14"
