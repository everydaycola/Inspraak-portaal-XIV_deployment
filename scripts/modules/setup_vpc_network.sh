#!/bin/bash

source colors.sh
source config.sh

setup_vpc_network() {
    # Create VPC Network (if it doesn't exist)
    if gcloud compute networks list --filter="name=$VPC_NETWORK_NAME" --format="value(name)" 2>/dev/null | grep -q "$VPC_NETWORK_NAME"; then
        echo_in_yellow "VPC network $VPC_NETWORK_NAME already exists."
    else
        echo_in_green "Creating VPC network: $VPC_NETWORK_NAME"
        gcloud compute networks create "$VPC_NETWORK_NAME" --subnet-mode=custom
        if [ $? -ne 0 ]; then
            echo_in_red "Failed to create VPC network."
            return 1
        fi
    fi

    # Create Subnet (if it doesn't exist)
    if ! gcloud compute networks subnets describe "$VPC_SUBNET_NAME" --region="$VPC_NETWORK_REGION" --network="$VPC_NETWORK_NAME" >/dev/null 2>&1; then
        echo_in_green "Creating Subnet: $VPC_SUBNET_NAME"
        gcloud compute networks subnets create "$VPC_SUBNET_NAME" --network="$VPC_NETWORK_NAME" --range="$VPC_SUBNET_RANGE" --region="$VPC_NETWORK_REGION"
        if [ $? -ne 0 ]; then
            echo_in_red "Failed to create Subnet."
            return 1
        fi
    else
        echo_in_yellow "Subnet $VPC_SUBNET_NAME already exists."
    fi
}

setup_vpc_peering() {
    local network_name="$VPC_NETWORK_NAME"
    local global_range_name="google-managed-services-range"
    local region="$VPC_NETWORK_REGION"

    echo_in_green "Setting up VPC peering for Cloud SQL in network: $network_name"

    # Check if network exists
    if ! gcloud compute networks list --filter="name=$network_name" --format="value(name)" >/dev/null 2>&1; then
        echo_in_red "Error: Network '$network_name' does not exist."
        return 1
    fi

    # Check if address range exists, if not create it.
    if ! gcloud compute addresses describe "$global_range_name" --global >/dev/null 2>&1; then
        echo_in_green "Creating global address range: $global_range_name"
        gcloud compute addresses create "$global_range_name" \
            --global \
            --prefix-length=24 \
            --purpose=VPC_PEERING \
            --network="$network_name"

        if [ $? -ne 0 ]; then
            echo_in_red "Failed to create address range."
            return 1
        fi
    else
        echo_in_yellow "Global address range '$global_range_name' already exists."
    fi

    # Check if peering exists, if not create it.
    if ! gcloud services vpc-peerings list --network="$network_name" | grep servicenetworking.googleapis.com >/dev/null 2>&1; then
        echo_in_green "Creating VPC peering connection for network: $network_name"
        gcloud services vpc-peerings connect \
            --service=servicenetworking.googleapis.com \
            --network="$network_name" \
            --ranges="$global_range_name"

        if [ $? -ne 0 ]; then
            echo_in_red "Failed to create VPC peering connection."
            return 1
        fi
    else
        echo_in_yellow "VPC peering connection for network '$network_name' already exists."
    fi

    echo_in_green "VPC peering setup complete for Cloud SQL."
    return 0
}

setup_firewall_rules() {
    # Create a Firewall Rule to allow HTTP/HTTPS (if it doesn't exist)
    if ! gcloud compute firewall-rules describe allow-http-https --network="$VPC_NETWORK_NAME" >/dev/null 2>&1; then
        echo_in_green "Creating Firewall Rule to Allow HTTP/HTTPS..."
        gcloud compute firewall-rules create allow-http-https \
            --network="$VPC_NETWORK_NAME" \
            --allow=tcp:80,tcp:443,tcp:5000 \
            --source-ranges=0.0.0.0/0 \
            --target-tags=http-server \
            --description="Allow HTTP, HTTPS, and application traffic from the internet"
    else
        echo_in_yellow "Firewall rule allow-http-https already exists."
    fi

    # Create firewall rule to allow postgres traffic (if it doesn't exist)
    if ! gcloud compute firewall-rules describe allow-internal-postgres --network="$VPC_NETWORK_NAME" >/dev/null 2>&1; then
        echo_in_green "Creating firewall rule 'allow-internal-postgres'..."
        gcloud compute firewall-rules create allow-internal-postgres \
            --network="$VPC_NETWORK_NAME" \
            --allow=tcp:5432 \
            --source-ranges="$VPC_SUBNET_RANGE" \
            --target-tags=postgres-server \
            --description="Allow internal PostgreSQL traffic from application instances"
    else
        echo_in_yellow "Firewall rule allow-internal-postgres already exists."
    fi

    # Create firewall rule to allow redis traffic (if it doesn't exist)
    if ! gcloud compute firewall-rules describe allow-redis --network="$VPC_NETWORK_NAME" >/dev/null 2>&1; then
        echo_in_green "Creating firewall rule 'allow-redis'..."
        gcloud compute firewall-rules create allow-redis \
            --network="$VPC_NETWORK_NAME" \
            --allow=tcp:6379 \
            --source-ranges="$VPC_SUBNET_RANGE" \
            --target-tags=redis-server \
            --description="Allow internal Redis traffic from application instances"
    else
        echo_in_yellow "Firewall rule allow-redis already exists."
    fi
}
