#!/bin/bash

source colors.sh
source config.sh

setup_managed_instance_group() {
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
}
