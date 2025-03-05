#!/bin/bash

# Set variables
source config.sh

# Check gcloud CLI and authentication
if ! command -v gcloud &>/dev/null; then
    echo "Error: gcloud CLI is not installed."
    exit 1
fi

if ! gcloud auth list --format="value(account)" | grep -q "@"; then
    echo "Error: You are not authenticated. Run: gcloud auth login"
    exit 1
fi

# Set the project and zone before checking them
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE

# Check project and zone settings
if [ -z "$(gcloud config get-value project 2>/dev/null)" ]; then
    echo "Error: No GCP project is set. Run: gcloud config set project [PROJECT_ID]"
    exit 1
fi

if [ -z "$(gcloud config get-value compute/zone 2>/dev/null)" ]; then
    echo "Error: No compute zone is set. Run: gcloud config set compute/zone [ZONE]"
    exit 1
fi

# Create private IP address range
if ! gcloud compute addresses describe google-managed-services-range --global >/dev/null 2>&1; then
    echo "Creating private IP address range..."
    gcloud compute addresses create google-managed-services-range \
        --global \
        --prefix-length=24 \
        --purpose=VPC_PEERING \
        --network=default
fi

# Create VPC peering connection
if ! gcloud services vpc-peerings list --network=default | grep servicenetworking.googleapis.com >/dev/null 2>&1; then
    echo "Creating VPC peering connection..."
    gcloud services vpc-peerings connect \
        --service=servicenetworking.googleapis.com \
        --network=default \
        --ranges=google-managed-services-range
fi

# VM Creation
if gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" >/dev/null 2>&1; then
    echo "VM instance '$INSTANCE_NAME' already exists."
else
    echo "Creating VM instance..."
    gcloud compute instances create "$INSTANCE_NAME" \
        --zone="$ZONE" \
        --machine-type="$MACHINE_TYPE" \
        --image-family="$IMAGE_FAMILY" \
        --image-project="$IMAGE_PROJECT" \
        --metadata=startup-script="$(cat "$STARTUP_SCRIPT")",instance-connection-name="$PROJECT_ID:$DB_REGION:$DB_INSTANCE_NAME",db-password="$DB_PASSWORD",db-user="$DB_USER" \
        --tags=http-server,postgres-server \
        --scopes=cloud-platform
fi

# Get the external IP of the VM
# Note: This assumes that the VM has a network interface and that the network interface has an IP assigned.
INTERNAL_IP=$(gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" --format='value(networkInterfaces[0].networkIP)')

# Cloud SQL Instance Creation
if gcloud sql instances describe "$DB_INSTANCE_NAME" >/dev/null 2>&1; then
    echo "Cloud SQL instance '$DB_INSTANCE_NAME' already exists."
else
    echo "Creating Cloud SQL instance..."
    gcloud sql instances create "$DB_INSTANCE_NAME" \
        --project="$PROJECT_ID" \
        --database-version="$SQL_VERSION" \
        --tier="$SQL_TIER" \
        --region="$DB_REGION" \
        --root-password="$DB_PASSWORD" \
        --network="default"
fi

# Cloud SQL Database Creation
if gcloud sql databases describe "mydatabase" --instance="$DB_INSTANCE_NAME" >/dev/null 2>&1; then
    echo "Database 'mydatabase' already exists."
else
    echo "Creating Database instance..."
    gcloud sql databases create "mydatabase" --instance="$DB_INSTANCE_NAME"
fi

# Firewall Rules
if gcloud compute firewall-rules describe "allow-http" >/dev/null 2>&1; then
    echo "Firewall rule 'allow-http' already exists."
else
    echo "Creating firewall rule 'allow-http'..."
    gcloud compute firewall-rules create "allow-http" \
        --allow tcp:80 \
        --source-ranges 0.0.0.0/0 \
        --target-tags http-server \
        --description "Allow HTTP traffic"
fi

if gcloud compute firewall-rules describe "allow-postgres" >/dev/null 2>&1; then
    echo "Firewall rule 'allow-postgres' already exists."
else
    echo "Creating firewall rule 'allow-postgres'..."
    gcloud compute firewall-rules create "allow-postgres" \
        --allow tcp:5432 \
        --source-ranges 0.0.0.0/0 \
        --target-tags postgres-server \
        --description "Allow PostgreSQL traffic"
fi

echo "Deployment complete. Access your VM at http://$INTERNAL_IP"
