#!/bin/bash

# Google Cloud Project
PROJECT_ID="cs2-eycken-tibo"
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
HTTP_PROXY_NAME="web-http-proxy"
FORWARDING_RULE_NAME="web-forwarding-rule"

# VPC variables
VPC_NETWORK_NAME="my-custom-network"
VPC_NETWORK_REGION="europe-west1"
VPC_SUBNET_NAME="subnet-for-custom-network"
VPC_SUBNET_RANGE="10.10.0.0/24"

# Startup Script
STARTUP_SCRIPT="startup-script.sh"

# Postgres variables
DB_INSTANCE_NAME="postgres-db"
DB_REGION="europe-west1"
SQL_TIER="db-perf-optimized-N-2"
SQL_VERSION="POSTGRES_17"
