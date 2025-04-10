#!/bin/bash

# this script can be used when something was changed in the configuration of the startup-script
# Will automatically update all running instances

source config.sh

# 1. Instance-group bijwerken met de nieuwe template
echo "Instance-group bijwerken met de nieuwe template..."
gcloud compute instance-groups managed update $INSTANCE_GROUP_NAME \
    --template=$INSTANCE_TEMPLATE_NAME \
    --zone=$ZONE

# 2. Rolling update initiëren om de VM's te vervangen
echo "Rolling update starten om de VM's te vervangen..."
gcloud compute instance-groups managed rolling-action restart $INSTANCE_GROUP_NAME \
    --zone=$ZONE \
    --max-surge=100% \
    --max-unavailable=0%
