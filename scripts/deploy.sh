#!/bin/bash

# Load Configuration Variables
source config.sh

# Load colors
source colors.sh

# Function to echo in green just for more clarity

echo_in_green() {
	echo -e "${GREEN}$1${ENDCOLOR}"
}

echo_in_green "Setting gcloud properties..."
# Set some gcloud properties
gcloud config set project $PROJECT_ID
gcloud config set compute/zone $ZONE
echo_in_green "Properties set."

echo_in_green "Starting some checks..."
# Function to check if a given command exists - used to check mostly if gcloud exists
command_exists() {
	command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
if ! command_exists gcloud; then
	echo "Error: gcloud CLI is not installed"
	exit 1
fi

if ! gcloud auth list --format="value(account)" | grep -q "@"; then
	echo "Error: You are not authenticated. Run: gcloud auth login"
	exit 1
fi

# Check if "project" has a value
if [ -z "$(gcloud config get-value project 2>/dev/null)" ]; then
	echo "Error: No GCP project is set. Run gcloud config set project [PROJECT_ID]"
	exit 1
fi

# Check if "compute/zone" has a value
if [ -z "$(gcloud config get-value compute/zone 2>/dev/null)" ]; then
	echo "Error: No compute zone is set. Run: gcloud config set compute/zone [ZONE]"
	exit 1
fi

echo_in_green "Checks finnished with no problems."

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
echo_in_green "Template created."

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
echo_in_green "Autoscaler set up."

echo_in_green "Creating Health Check..."
# Create a Health Check
gcloud compute health-checks create http "$HEALTH_CHECK_NAME" \
	--check-interval=30s \
	--timeout=5s \
	--unhealthy-threshold=3 \
	--healthy-threshold=2 \
	--port=80
echo_in_green "Health check created."

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

# Create a Firewall Rule to allow HTTP
echo_in_green "Creating Firewall Rule to Allow HTTP..."
gcloud compute firewall-rules create "$FIREWALL_RULE_NAME" \
	--allow tcp:80 \
	--source-ranges 0.0.0.0/0 \
	--target-tags http-server \
	--description "Allow HTTP traffic"
echo_in_green "Load Balancer created."

# Verkrijg de naam van de eerste instantie in de Instance Group
INSTANCE_NAME=$(gcloud compute instance-groups managed list-instances "$INSTANCE_GROUP_NAME" --zone="$ZONE" --format="value(name)" | head -n 1)

# Kopieer de bestanden naar de VM
# gcloud compute scp --recurse ./publish/* "$INSTANCE_NAME:$APP_DIR" --zone $ZONE

# SSH naar de VM en start de applicatie
# gcloud compute ssh "$INSTANCE_NAME" --zone="$ZONE" --command "bash $APP_DIR/startup-script.sh"

echo_in_green "Deployment complete. Access your app via the load balancer. IP: $(gcloud compute forwarding-rules list --global --format='value(IPAddress)')"
