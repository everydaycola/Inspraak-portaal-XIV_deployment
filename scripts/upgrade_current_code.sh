#!/bin/bash

source modules//config.sh

# Ensure required variables are set
if [ -z "$INSTANCE_GROUP_NAME" ] || [ -z "$REGION" ]; then
    echo "Error: INSTANCE_GROUP_NAME or REGION is not set in config.sh."
    exit 1
fi

# Check if the MIG exists
if ! gcloud compute instance-groups managed describe "$INSTANCE_GROUP_NAME" --region="$REGION" >/dev/null 2>&1; then
    echo "Error: Managed Instance Group '$INSTANCE_GROUP_NAME' does not exist in region '$REGION' or you lack permissions."
    exit 1
fi

# Ask user for confirmation
echo -n "Are you sure you want to perform a rolling replace on '$INSTANCE_GROUP_NAME'? [y/N]: "
read -r CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
    echo "Operation cancelled."
    exit 0
fi

# Perform the rolling replace
echo "Starting rolling replace on '$INSTANCE_GROUP_NAME'..."
gcloud compute instance-groups managed rolling-action replace "$INSTANCE_GROUP_NAME" \
    --max-surge=2 \
    --max-unavailable=1 \
    --replacement-method=substitute \
    --region="$REGION"
