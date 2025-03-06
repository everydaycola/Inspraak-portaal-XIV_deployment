#!/bin/bash

<<<<<<< HEAD
# Load configuration variables
=======
# Set variables
>>>>>>> deploy_and_destroy_scripts-branch
source config.sh
source colors.sh

<<<<<<< HEAD
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

echo_in_orange "Unsetting gcloud variables"
gcloud config unset project
gcloud config unset compute/zone

echo_in_orange "Cleanup complete. All resources have been deleted."

=======
# Cloud SQL Database Deletion
if gcloud sql databases describe "mydatabase" --instance="$DB_INSTANCE_NAME" >/dev/null 2>&1; then
	echo "Deleting database 'mydatabase'..."
	gcloud sql databases delete "mydatabase" --instance="$DB_INSTANCE_NAME" --quiet
else
	echo "Database 'mydatabase' does not exist."
fi

# Cloud SQL Instance Deletion
if gcloud sql instances describe "$DB_INSTANCE_NAME" >/dev/null 2>&1; then
	echo "Deleting Cloud SQL instance '$DB_INSTANCE_NAME'..."
	gcloud sql instances delete "$DB_INSTANCE_NAME" --quiet
else
	echo "Cloud SQL instance '$DB_INSTANCE_NAME' does not exist."
fi

# VM Instance Deletion
if gcloud compute instances describe "$INSTANCE_NAME" --zone="$ZONE" >/dev/null 2>&1; then
	echo "Deleting VM instance '$INSTANCE_NAME'..."
	gcloud compute instances delete "$INSTANCE_NAME" --zone="$ZONE" --quiet
else
	echo "VM instance '$INSTANCE_NAME' does not exist."
fi

# Firewall Rule Deletion
if gcloud compute firewall-rules describe "allow-http" >/dev/null 2>&1; then
	echo "Deleting firewall rule 'allow-http'..."
	gcloud compute firewall-rules delete "allow-http" --quiet
else
	echo "Firewall rule 'allow-http' does not exist."
fi

if gcloud compute firewall-rules describe "allow-postgres" >/dev/null 2>&1; then
	echo "Deleting firewall rule 'allow-postgres'..."
	gcloud compute firewall-rules delete "allow-postgres" --quiet
else
	echo "Firewall rule 'allow-postgres' does not exist."
fi

# Private IP Address range deletion.
if gcloud compute addresses describe google-managed-services-range --global >/dev/null 2>&1; then
	echo "Deleting private IP address range 'google-managed-services-range'..."
	gcloud compute addresses delete google-managed-services-range --global --quiet
else
	echo "private IP address range 'google-managed-services-range' does not exist."
fi

#Private Service Access peering deletion.
if gcloud services vpc-peerings list --network=default | grep servicenetworking.googleapis.com >/dev/null 2>&1; then
	echo "Deleting VPC peering connection..."
	gcloud services vpc-peerings delete --service=servicenetworking.googleapis.com --network=default --quiet
else
	echo "VPC peering connection does not exist."
fi

echo "Destruction complete."
>>>>>>> deploy_and_destroy_scripts-branch
