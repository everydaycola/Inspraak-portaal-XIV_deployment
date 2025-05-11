#!/bin/bash

source colors.sh
source config.sh

setup_managed_instance_group() {
    echo_in_green "Setting up Managed Instance Group..."

    # Check if Instance Template exists
    if ! gcloud compute instance-templates describe "$INSTANCE_TEMPLATE_NAME" --region="$REGION" >/dev/null 2>&1; then
        echo_in_green "Creating instance template..."
        # Create an Instance Template
        gcloud compute instance-templates create "$INSTANCE_TEMPLATE_NAME" \
            --machine-type="$MACHINE_TYPE" \
            --region="$REGION" \
            --image-family="$IMAGE_FAMILY" \
            --image-project="$IMAGE_PROJECT" \
            --metadata=startup-script="$(cat $STARTUP_SCRIPT)" \
            --tags=http-server,https-server \
            --network="$VPC_NETWORK_NAME" \
            --subnet="$VPC_SUBNET_NAME" \
            --scopes=cloud-platform
    else
        echo_in_yellow "Instance Template '$INSTANCE_TEMPLATE_NAME' already exists. Skipping creation."
    fi

    # Check if Managed Instance Group exists
    if ! gcloud compute instance-groups managed describe "$INSTANCE_GROUP_NAME" --zone="$ZONE" >/dev/null 2>&1; then
        echo_in_green "Creating MIG..."
        # Create a Managed Instance Group (MIG)
        gcloud compute instance-groups managed create "$INSTANCE_GROUP_NAME" \
            --base-instance-name=web-instance \
            --size=$MIN_INSTANCES \
            --template="$INSTANCE_TEMPLATE_NAME" \
            --initial-delay=240 \
            --zone="$ZONE"
        echo_in_green "MIG Created."

        echo_in_green "Setting named ports..."
        gcloud compute instance-groups set-named-ports "$INSTANCE_GROUP_NAME" \
            --named-ports=http:80 \
            --zone="$ZONE"

        echo_in_green "Setting up autoscaler..."
        # Set up Autoscaler
        gcloud compute instance-groups managed set-autoscaling "$INSTANCE_GROUP_NAME" \
            --zone="$ZONE" \
            --min-num-replicas="$MIN_INSTANCES" \
            --max-num-replicas="$MAX_INSTANCES" \
            --target-cpu-utilization="$TARGET_CPU_UTILIZATION" \
            --cool-down-period=240
    else
        echo_in_yellow "Managed Instance Group '$INSTANCE_GROUP_NAME' already exists. Skipping creation and autoscaler setup."
    fi
}
