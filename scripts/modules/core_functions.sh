#!/bin/bash

source ../colors.sh

# --- Helper Functions ---
check_gcloud_installed() {
    if ! command -v gcloud &>/dev/null; then
        echo_in_red "Error: Google Cloud CLI (gcloud) is not installed or not in your PATH."
        echo "Please follow the installation instructions here: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
}

check_project_exists() {
    local PROJECT_TO_CHECK="$1"
    gcloud projects describe "$PROJECT_TO_CHECK" &>/dev/null
    return $? # Returns 0 if exists, non-zero otherwise
}

get_project_number() {
    local project_id="$1"
    gcloud projects describe "$project_id" --format="value(projectNumber)"
}
