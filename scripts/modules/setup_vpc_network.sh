#!/bin/bash

source colors.sh
source config.sh

setup_vpc_network() {
    # Create private IP address range
    if ! gcloud compute addresses describe google-managed-services-range --global >/dev/null 2>&1; then
        echo_in_green "Creating private IP address range..."
        gcloud compute addresses create google-managed-services-range \
            --global \
            --prefix-length=24 \
            --purpose=VPC_PEERING \
            --network=default
    fi

    # Create VPC peering connection
    echo_in_green "Creating VPC peering connection..."
    if ! gcloud services vpc-peerings list --network=default | grep servicenetworking.googleapis.com >/dev/null 2>&1; then
        echo_in_green "Creating VPC peering connection..."
        gcloud services vpc-peerings connect \
            --service=servicenetworking.googleapis.com \
            --network=default \
            --ranges=google-managed-services-range
    fi
}
