#!/bin/bash

source modules/colors.sh
source modules/config.sh

# Function to check if a given command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

pre_deploy_checks() {
    echo_in_yellow "Doing some checks..."
    # Check if gcloud cli is installed
    if ! command_exists gcloud; then
        echo_in_red "Error: gcloud CLI is not installed. Please look at the prerequisites for this script."
        exit 1
    fi

    if ! gcloud auth list --format="value(account)" | grep -q "@"; then
        echo_in_red "Error: You are not authenticated. Run: gcloud auth login"
        exit 1
    fi

    # Check if "project" has a value
    if [ -z "$(gcloud config get-value project 2>/dev/null)" ]; then
        echo_in_red "Error: No GCP project is set. Run gcloud config set project [PROJECT_ID]"
        exit 1
    fi

    # Check if "compute/zone" has a value
    if [ -z "$(gcloud config get-value compute/zone 2>/dev/null)" ]; then
        echo_in_red "Error: No compute zone is set. Run: gcloud config set compute/zone [ZONE]"
        exit 1
    fi

    # Check if startup script exists
    if [ ! -f "$STARTUP_SCRIPT" ]; then
        echo_in_red "Warning: $STARTUP_SCRIPT not found. The VM will not use a startup script."
        STARTUP_METADATA=""
    else
        STARTUP_METADATA="--metadata=startup-script=$(cat $STARTUP_SCRIPT)"
    fi
    echo_in_yellow "Checks finished..."
}
