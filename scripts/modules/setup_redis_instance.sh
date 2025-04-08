#!/bin/bash

# this module will be used to setup a Redis instance
# Which will be used to cache the session state (cookies) so we can use it over the VMs
source config.sh

setup_redis_instance() {
    echo_in_green "Setting up Redis instance..."

    # Check if Redis instance exists
    if ! gcloud redis instances describe my-redis-instance --region="$REGION" >/dev/null 2>&1; then
        echo_in_green "Creating Redis instance..."
        gcloud redis instances create my-redis-instance \
            --region="$REGION" \
            --size=1 \
            --redis-version=redis_7_2 \
            --network="$VPC_NETWORK_NAME" \
            --zone="$ZONE"
    else
        echo_in_yellow "Redis instance 'my-redis-instance' already exists. Skipping creation."
    fi
}
