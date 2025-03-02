#!/bin/bash

# Needed Variables
PROJECT_ID="cs2-eycken-tibo" # Replace with your actual GCE project id
ZONE="europe-west1-d"
INSTANCE_NAME="my-vm-instance"
MACHINE_TYPE="e2-medium"
IMAGE_FAMILY="ubuntu-2004-lts"
IMAGE_PROJECT="ubuntu-os-cloud"
STARTUP_SCRIPT="startup-script.sh"

# Postgres variables
DB_INSTANCE_NAME="postgres-db"
DB_USER="postgres"
DB_PASSWORD="your_secure_password"
DB_REGION="europe-west1"
SQL_TIER="db-perf-optimized-N-2"
SQL_VERSION="POSTGRES_17"
