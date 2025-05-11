#!/bin/bash

source core_functions.sh
source ../config.sh # To access VPC related variables
source ../colors.sh

# Function to set up the initial VPC network and subnet
setup_vpc_network_initial() {
    echo_in_blue "Setting up VPC network..."

    # Check if the necessary variables are defined in config.sh
    if [[ -z "$VPC_NETWORK_NAME" ]]; then
        echo_in_red "Error: VPC_NETWORK_NAME is not defined in config.sh. Please configure it."
        return 1
    fi
    if [[ -z "$VPC_NETWORK_REGION" ]]; then
        echo_in_red "Error: VPC_NETWORK_REGION is not defined in config.sh. Please configure it."
        return 1
    fi
    if [[ -z "$VPC_SUBNET_NAME" ]]; then
        echo_in_red "Error: VPC_SUBNET_NAME is not defined in config.sh. Please configure it."
        return 1
    fi
    if [[ -z "$VPC_SUBNET_RANGE" ]]; then
        echo_in_red "Error: VPC_SUBNET_RANGE is not defined in config.sh. Please configure it."
        return 1
    fi

    echo_in_yellow "Using VPC network name: '$VPC_NETWORK_NAME' (configured in config.sh)."
    echo_in_yellow "Using VPC network region: '$VPC_NETWORK_REGION' (configured in config.sh)."
    echo_in_yellow "Using subnet name: '$VPC_SUBNET_NAME' (configured in config.sh)."
    echo_in_yellow "Using subnet IP range: '$VPC_SUBNET_RANGE' (configured in config.sh)."

    # Create VPC Network (if it doesn't exist)
    if gcloud compute networks list --filter="name=$VPC_NETWORK_NAME" --format="value(name)" --project="$PROJECT_ID" 2>/dev/null | grep -q "$VPC_NETWORK_NAME"; then
        echo_in_yellow "VPC network $VPC_NETWORK_NAME already exists."
    else
        echo_in_green "Creating VPC network: $VPC_NETWORK_NAME"
        gcloud compute networks create "$VPC_NETWORK_NAME" --subnet-mode=custom --project="$PROJECT_ID"
        if [ $? -ne 0 ]; then
            echo_in_red "Failed to create VPC network."
            return 1
        fi
    fi

    # Create Subnet (if it doesn't exist)
    if ! gcloud compute networks subnets describe "$VPC_SUBNET_NAME" --region="$VPC_NETWORK_REGION" --network="$VPC_NETWORK_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
        echo_in_green "Creating Subnet: $VPC_SUBNET_NAME"
        gcloud compute networks subnets create "$VPC_SUBNET_NAME" --network="$VPC_NETWORK_NAME" --range="$VPC_SUBNET_RANGE" --region="$VPC_NETWORK_REGION" --project="$PROJECT_ID"
        if [ $? -ne 0 ]; then
            echo_in_red "Failed to create Subnet."
            return 1
        fi
    else
        echo_in_yellow "Subnet $VPC_SUBNET_NAME already exists."
    fi
}

reserve_static_ip() {
    gcloud compute addresses create "$STATIC_IP_NAME" --global --project="$PROJECT_ID" 2>&1
    if [ $? -eq 0 ]; then
        STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --global --project="$PROJECT_ID" --format="value(address)")
        echo_in_green "Global static IP address '$STATIC_IP' reserved with name '$STATIC_IP_NAME'."
        echo_in_yellow "You can use this IP for your load balancer or other global resources."

        echo_in_yellow "\n--- Domain Name Configuration ---"
        echo_in_yellow "To make your application accessible via your domain name (e.g., www.yourdomain.com),"
        echo_in_yellow "you will need to configure the DNS records at your domain registrar."
        echo_in_yellow "Once your deployment script has finished running successfully,"
        echo_in_yellow "it will output the public IP address of your load balancer."
        echo_in_yellow "You will need to create an 'A' record (and potentially a 'CNAME' record for 'www') at your registrar"
        echo_in_yellow "that points to this IP address."
        echo_in_yellow "Please refer to your domain registrar's documentation for instructions on how to manage DNS records."
        echo_in_yellow "---"
    else
        echo_in_red "Error reserving global static IP address '$STATIC_IP_NAME'."
    fi
}
