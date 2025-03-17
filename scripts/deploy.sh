#!/bin/bash

# Load Configuration Variables
source config.sh
source colors.sh

# Function to check if a given command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Set the project and zone before checkign them
echo_in_green "Setting gcloud variables..."
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE

echo_in_green "Doing some checks..."
# Check if gcloud cli is installed
if ! command_exists gcloud; then
    echo_in_red "Error: gcloud CLI is not installed. Please look at the prerequisites for this script."
    i exit 1
fi

if ! gcloud auth list --format="value(account)" | grep -q "@"; then
    echo_in_red "Error: You are not authenticated. Run: gcloud auth login"
    exit 1
fi

# Check if "project" has a value
if [ -z "$(gcloud config get-value project 2>/dev/null)" ]; then
    echo_in_red "Error: No GCP project is set. Run gcloud config set project [PROJECT_ID]"
    exit 1
fi

# Check if "compute/zone" has a value
if [ -z "$(gcloud config get-value compute/zone 2>/dev/null)" ]; then
    echo_in_red "Error: No compute zone is set. Run: gcloud config set compute/zone [ZONE]"
    exit 1
fi

# Check if startup script exists
if [ ! -f "$STARTUP_SCRIPT" ]; then
    echo_in_red "Warning: $STARTUP_SCRIPT not found. The VM will not use a startup script."
    STARTUP_METADATA=""
else
    STARTUP_METADATA="--metadata=startup-script=$(cat $STARTUP_SCRIPT)"
fi

# Create private IP address range
if ! gcloud compute addresses describe google-managed-services-range --global >/dev/null 2>&1; then
    echo_in_green "Creating private IP address range..."
    gcloud compute addresses create google-managed-services-range \
        --global \
        --prefix-length=24 \
        --purpose=VPC_PEERING \
        --network=default
fi

# Create VPC peering connection
echo_in_green "Creating VPC peering connection..."
if ! gcloud services vpc-peerings list --network=default | grep servicenetworking.googleapis.com >/dev/null 2>&1; then
    echo_in_green "Creating VPC peering connection..."
    gcloud services vpc-peerings connect \
        --service=servicenetworking.googleapis.com \
        --network=default \
        --ranges=google-managed-services-range
fi

echo_in_green "Creating instance template..."
# Create an Instance Template
gcloud compute instance-templates create "$INSTANCE_TEMPLATE_NAME" \
    --machine-type="$MACHINE_TYPE" \
    --region="$REGION" \
    --image-family="$IMAGE_FAMILY" \
    --image-project="$IMAGE_PROJECT" \
    --metadata=startup-script="$(cat $STARTUP_SCRIPT)" \
    --tags=http-server,https-server \
    --scopes=cloud-platform

echo_in_green "Creating MIG..."
# Create a Managed Instance Group (MIG)
gcloud compute instance-groups managed create "$INSTANCE_GROUP_NAME" \
    --base-instance-name=web-instance \
    --size=$MIN_INSTANCES \
    --template="$INSTANCE_TEMPLATE_NAME" \
    --zone="$ZONE"
echo_in_green "MIG Created."

echo_in_green "Setting up autoscaler..."
# Set up Autoscaler
gcloud compute instance-groups managed set-autoscaling "$INSTANCE_GROUP_NAME" \
    --zone="$ZONE" \
    --min-num-replicas="$MIN_INSTANCES" \
    --max-num-replicas="$MAX_INSTANCES" \
    --target-cpu-utilization="$TARGET_CPU_UTILIZATION" \
    --cool-down-period=60

echo_in_green "Creating Health Check..."
# Create a Health Check
gcloud compute health-checks create http "$HEALTH_CHECK_NAME" \
    --check-interval=30s \
    --timeout=5s \
    --unhealthy-threshold=3 \
    --healthy-threshold=2 \
    --port=80

echo_in_green "Creating Load Balancer..."
# Create a Backend Service
gcloud compute backend-services create "$BACKEND_SERVICE_NAME" \
    --protocol=HTTP \
    --health-checks="$HEALTH_CHECK_NAME" \
    --global

# Add the Instance Group to Backend Service
echo_in_green "Adding instance group to backend service..."
gcloud compute backend-services add-backend "$BACKEND_SERVICE_NAME" \
    --instance-group="$INSTANCE_GROUP_NAME" \
    --instance-group-zone="$ZONE" \
    --global

# Create a URL Map
echo_in_green "Creating URL Map..."
gcloud compute url-maps create "$URL_MAP_NAME" --default-service="$BACKEND_SERVICE_NAME"

# Create an HTTP Proxy
echo_in_green "Creating HTTP Proxy..."
gcloud compute target-http-proxies create "$HTTP_PROXY_NAME" --url-map="$URL_MAP_NAME"

# Create a Global Forwarding Rule
echo_in_green "Creating Global Forwarding Rule..."
gcloud compute forwarding-rules create "$FORWARDING_RULE_NAME" \
    --global \
    --target-http-proxy="$HTTP_PROXY_NAME" \
    --ports=80

# Collecting Credentials from the secret manager
DB_PASSWORD=$(gcloud secrets versions access latest --secret=cloud_sql_password)
DB_USER=$(gcloud secrets versions access latest --secret=cloud_sql_user)

# Cloud SQL Instance Creation
if gcloud sql instances describe "$DB_INSTANCE_NAME" >/dev/null 2>&1; then
    echo_in_orange "Cloud SQL instance '$DB_INSTANCE_NAME' already exists."
else
    echo_in_green "Creating Cloud SQL Instance..."
    gcloud sql instances create "$DB_INSTANCE_NAME" \
        --project="$PROJECT_ID" \
        --database-version="$SQL_VERSION" \
        --tier="$SQL_TIER" \
        --region="$DB_REGION" \
        --root-password="$DB_PASSWORD" \
        --network="default"
fi
echo_in_purple "Cloud SQL Instance '$DB_INSTANCE_NAME'"

# Cloud SQL Database Creation
if gcloud sql databases describe "mydatabase" --instance="$DB_INSTANCE_NAME" >/dev/null 2>&1; then
    echo_in_orange "Database 'mydatabase' already exists."
else
    echo_in_green "Creating Database instance..."
    gcloud sql databases create "mydatabase" --instance="$DB_INSTANCE_NAME"
fi

# Create a Firewall Rule to allow HTTP
echo_in_green "Creating Firewall Rule to Allow HTTP..."
gcloud compute firewall-rules create "$FIREWALL_RULE_NAME" \
    --allow tcp:80,tcp:5000 \
    --source-ranges 0.0.0.0/0 \
    --target-tags http-server \
    --description "Allow HTTP traffic"

echo_in_green "Creating firewall rule 'allow-postgres'..."
gcloud compute firewall-rules create "allow-postgres" \
    --allow tcp:5432 \
    --source-ranges 0.0.0.0/0 \
    --target-tags postgres-server \
    --description "Allow PostgreSQL traffic"

echo_in_green "Deployment complete. Access your app via the load balancer. http://$(gcloud compute forwarding-rules list --global --format='value(IPAddress)')"
echo -e "${YELLOW}Accessing the Load balancer may take up to 5 minutes.${ENDCOLOR}"
echo -e "${YELLOW}You can also go to a specific instance via: http://$(gcloud compute instances list --filter='status=RUNNING' --limit=1 --format='value(networkInterfaces[0].accessConfigs[0].natIP)')${ENDCOLOR}"
