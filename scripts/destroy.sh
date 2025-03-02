#!/bin/bash

# Load config variables
source config.sh

# Delete the VM instance if it exists
INSTANCE_STATUS=$(gcloud compute instances list --filter="name=$INSTANCE_NAME" --format="value(name)")

if [[ -n "$INSTANCE_STATUS" ]]; then
	echo "Deleting VM instance '$INSTANCE_NAME'..."
	gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --quiet
	echo "VM instance deleted."
else
	echo "Instance '$INSTANCE_NAME' not found. Skipping VM deletion."
fi

# Delete the Cloud SQL instance if it exists
SQL_INSTANCE_STATUS=$(gcloud sql instances list --filter="name=$DB_INSTANCE_NAME" --format="value(name)")

if [[ -n "$SQL_INSTANCE_STATUS" ]]; then
	echo "Deleting Cloud SQL instance '$DB_INSTANCE_NAME'..."
	gcloud sql instances delete $DB_INSTANCE_NAME --quiet
	echo "Cloud SQL instance deleted."
else
	echo "Cloud SQL instance '$DB_INSTANCE_NAME' not found. Skipping deletion."
fi

# Delete firewall rules if they exist
FIREWALL_RULES=("allow-http" "allow-postgres")

for RULE in "${FIREWALL_RULES[@]}"; do
	FIREWALL_EXISTS=$(gcloud compute firewall-rules list --format="value(name)" | grep -w "$RULE")
	if [[ -n "$FIREWALL_EXISTS" ]]; then
		echo "Deleting firewall rule '$RULE'..."
		gcloud compute firewall-rules delete $RULE --quiet
		echo "Firewall rule '$RULE' deleted."
	else
		echo "Firewall rule '$RULE' not found. Skipping deletion."
	fi
done

echo "Cleanup finished. All resources deleted."
