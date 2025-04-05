#!/bin/bash

source colors.sh
source config.sh

setup_health_checks() {
    echo_in_green "Creating Health Check..."
    # Create a Health Check
    gcloud compute health-checks create http "$HEALTH_CHECK_NAME" \
        --check-interval=30s \
        --timeout=5s \
        --unhealthy-threshold=3 \
        --healthy-threshold=2 \
        --port=80
}
