#!/bin/bash

# this module will be used to setup a Redis instance
# Which will be used to cache the session state (cookies) so we can use it over the VMs
source config.sh

setup_redis() {
    gcloud redis instances create my-redis-instance \
        --region="$REGION" \
        --size=1 \
        --redis-version=redis_6_2 \
        --network="$VPC_NETWORK_NAME" \
        --zone="$ZONE"
}
