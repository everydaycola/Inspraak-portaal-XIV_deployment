#!/bin/bash

# Set variables
source config.sh

# Function to check if a given command exists
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Set the project and zone before checkign them
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE

# Check if gcloud cli is installed
if ! command_exists gcloud; then
	echo "Error: gcloud CLI is not installed. Please look at the prerequisites for this script."
i	exit 1
fi

# Check if user is authenticated
if ! gcloud auth list --format="value(account)" | grep -q "@"; then
    echo "Error: You are not authenticated. Run: gcloud auth login"
    exit 1
fi

# Check if project is set
if [ -z "$(gcloud config get-value project 2>/dev/null)" ]; then
    echo "Error: No GCP project is set. Run: gcloud config set project [PROJECT_ID]"
    exit 1
fi

# Check if compute zone is set
if [ -z "$(gcloud config get-value compute/zone 2>/dev/null)" ]; then
    echo "Error: No compute zone is set. Run: gcloud config set compute/zone [ZONE]"
    exit 1
fi

# Check if startup script exists
if [ ! -f "$STARTUP_SCRIPT" ]; then
    echo "Warning: $STARTUP_SCRIPT not found. The VM will not use a startup script."
    STARTUP_METADATA=""
else
    STARTUP_METADATA="--metadata=startup-script=$(cat $STARTUP_SCRIPT)"
fi

# Set the project
gcloud config set project $PROJECT_ID

# Create the VM
echo "Creating VM instance..."
gcloud compute instances create $INSTANCE_NAME \
    --zone=$ZONE \
    --machine-type=$MACHINE_TYPE \
    --image-family=$IMAGE_FAMILY \
    --image-project=$IMAGE_PROJECT \
    $STARTUP_METADATA \
    --tags=http-server \
    --scopes=cloud-platform

# Configure firewall to allow http traffic
gcloud compute firewall-rules create allow-http \
    --allow tcp:80 \
    --source-ranges 0.0.0.0/0 \
    --target-tags http-server \
    --description "Allow HTTP traffic" \
    --quiet

# Get the external IP
echo "Fetching external IP address..."
EXTERNAL_IP=$(gcloud compute instances describe $INSTANCE_NAME --zone=$ZONE --format='get(networkInterfaces[0].accesConfigs[0].natIP)')

echo "Deployment complete. Access your VM at http://$EXTERNAL_IP"

