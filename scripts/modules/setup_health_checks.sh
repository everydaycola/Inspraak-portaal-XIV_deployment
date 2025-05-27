#!/bin/bash

source modules/colors.sh
source modules/config.sh

setup_health_checks() {
    echo_in_green "Setting up Health Check..."

    # Check if LB Health Check exists
    if ! gcloud compute health-checks describe "$HEALTH_CHECK_NAME_LB" >/dev/null 2>&1; then
        echo_in_green "Creating Health Check..."
        # Create a Health Check
        gcloud compute health-checks create http "$HEALTH_CHECK_NAME_LB" \
            --check-interval=30s \
            --timeout=5s \
            --unhealthy-threshold=3 \
            --healthy-threshold=2 \
            --port=80
    else
        echo_in_yellow "Health Check '$HEALTH_CHECK_NAME_LB' already exists. Skipping creation."
    fi

    # Check if MIG Health Check exists
    if ! gcloud compute health-checks describe "$HEALTH_CHECK_NAME_MIG" >/dev/null 2>&1; then
        echo_in_green "Creating MIG Health Check..."
        # Create a Health Check for MIG
        gcloud compute health-checks create http "$HEALTH_CHECK_NAME_MIG" \
            --check-interval=5s \
            --timeout=3s \
            --unhealthy-threshold=2 \
            --healthy-threshold=1 \
            --port=80
    else
        echo_in_yellow "MIG Health Check '$HEALTH_CHECK_NAME_MIG' already exists. Skipping creation."
    fi
}
