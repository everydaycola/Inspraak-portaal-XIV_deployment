#!/bin/bash

# this script can be used when something was changed in the configuration of the startup-script
# Will automatically update all running instances

source config.sh

# This will override the old instance template with the changed STARTUP SCRIPT
gcloud compute instance-templates create "$INSTANCE_TEMPLATE_NAME" \
    --update-instance-template \
    --metadata=startup-script="$(cat $STARTUP_SCRIPT)"

# This will replace the current instances with new instances which will use the overridden template
gcloud compute instance-groups managed rolling-action replace "$INSTANCE_GROUP_NAME" \
    --zone="$ZONE" \
    --max-surge=100% \
    --max-unavailable=0%
