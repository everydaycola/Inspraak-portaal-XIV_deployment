#!/bin/bash

# Load configuration variables
source config.sh
source colors.sh

# Cloud SQL Instance Deletion
if gcloud sql instances describe "$DB_INSTANCE_NAME" >/dev/null 2>&1; then
        echo_in_orange "Deleting Cloud SQL instance '$DB_INSTANCE_NAME'..."
        gcloud sql instances delete "$DB_INSTANCE_NAME" --quiet
else
        echo_in_red "Cloud SQL instance '$DB_INSTANCE_NAME' does not exist."
fi

if gcloud compute firewall-rules describe "allow-postgres" >/dev/null 2>&1; then
        echo_in_orange "Deleting firewall rule 'allow-postgres'..."
        gcloud compute firewall-rules delete "allow-postgres" --quiet
else
        echo_in_red "Firewall rule 'allow-postgres' does not exist."
fi

# Private IP Address range deletion.
if gcloud compute addresses describe google-managed-services-range --global >/dev/null 2>&1; then
        echo_in_orange "Deleting private IP address range 'google-managed-services-range'..."
        gcloud compute addresses delete google-managed-services-range --global --quiet
else
        echo_in_red "private IP address range 'google-managed-services-range' does not exist."
fi

#Private Service Access peering deletion.
if gcloud services vpc-peerings list --network=default | grep servicenetworking.googleapis.com >/dev/null 2>&1; then
        echo_in_orange "Deleting VPC peering connection..."
        gcloud services vpc-peerings delete --service=servicenetworking.googleapis.com --network=default --quiet
else
        echo_in_red "VPC peering connection does not exist."
fi

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

echo_in_orange "Unsetting gcloud variables"
gcloud config unset project
gcloud config unset compute/zone

echo_in_orange "Cleanup complete. All resources have been deleted."
