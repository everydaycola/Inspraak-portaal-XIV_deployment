#!/bin/bash

# Load configuration variables
source config.sh
source colors.sh

echo_in_orange() {
        echo -e "${ORANGE}$1${ENDCOLOR}"
}

echo_in_orange "Deleting forwarding rule..."
gcloud compute forwarding-rules delete "$FORWARDING_RULE_NAME" --global --quiet

echo_in_orange "Deleting HTTP proxy..."
gcloud compute target-http-proxies delete "$HTTP_PROXY_NAME" --quiet

echo_in_orange "Deleting URL map..."
gcloud compute url-maps delete "$URL_MAP_NAME" --quiet

echo_in_orange "Deleting backend service..."
gcloud compute backend-services delete "$BACKEND_SERVICE_NAME" --global --quiet

echo_in_orange "Deleting health check..."
gcloud compute health-checks delete "$HEALTH_CHECK_NAME" --quiet

echo_in_orange "Deleting instance group..."
gcloud compute instance-groups managed delete "$INSTANCE_GROUP_NAME" --zone="$ZONE" --quiet

echo_in_orange "Deleting instance template..."
gcloud compute instance-templates delete "$INSTANCE_TEMPLATE_NAME" --quiet

echo_in_orange "Deleting firewall rule..."
gcloud compute firewall-rules delete "$FIREWALL_RULE_NAME" --quiet

echo_in_orange "Cleanup complete. All resources have been deleted."

