#!/bin/bash

source colors.sh
source config.sh

setup_health_checks() {
    echo_in_green "Setting up Health Check..."

    # Check if Health Check exists
    if ! gcloud compute health-checks describe "$HEALTH_CHECK_NAME" >/dev/null 2>&1; then
        echo_in_green "Creating Health Check..."
        # Create a Health Check
        gcloud compute health-checks create http "$HEALTH_CHECK_NAME" \
            --check-interval=30s \
            --timeout=5s \
            --unhealthy-threshold=3 \
            --healthy-threshold=2 \
            --port=80
    else
        echo_in_yellow "Health Check '$HEALTH_CHECK_NAME' already exists. Skipping creation."
    fi
}
