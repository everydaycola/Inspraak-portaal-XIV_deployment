#!/bin/bash

# Load config variables
source config.sh

echo "WARNING: This will delete the VM instance '$INSTANCE_NAME'!"
read -p "Are you sure you want to proceed? (yes/no): " CONFIRM

if [[ "$CONFIRM" != "yes" ]]; then 
	echo "Aborted"
	exit 0
fi

# Check if the instance exists
INSTANCE_STATUS=$(gcloud compute instances list --filter="name=$INSTANCE_NAME" --format="value(name)")

if [[ -z "$INSTANCE_STATUS" ]]; then 
	echo "Instance '$INSTANCE_NAME' not found. Skipping deletion."
else 
	echo "Deleting VM instance '$INSTANCE_NAME'..."
	gcloud compute instances delete $INSTANCE_NAME --zone=$ZONE --quiet
	echo "VM instance deleted"
fi

# Check if the firewall rule exists before deleting
FIREWALL_RULE="allow_http"
FIREWALL_EXISTS=$(gcloud compute firewall-rules list --format="value(name)" | grep -w "$FIREWALL_RULE")

if [[ -n "$FIREWALL_EXISTS" ]]; then
	echo "Deleting firewall rule '$FIREWALL_RULE'..."
	gcloud compute firewall-rules delete $FIREWALL_RULE --quiet
	echo "Firewall rule deleted."
else
	echo "Firewall rule '$FIREWALL_RULE' not found. Skipping deletion."
fi

echo "Cleanup finnished"
