#!/bin/bash

source config.sh
source colors.sh

source modules/core_functions.sh
source modules/project_setup.sh
source modules/iam_setup.sh
source modules/secret_manager_setup.sh
source modules/network_setup.sh

main() {
    check_gcloud_installed
    determine_project "$PROJECT_ID"

    link_billing_account "$PROJECT_ID" "$BILLING_ACCOUNT_ID" "$PROJECT_EXISTS"
    enable_default_apis "$PROJECT_ID"

    # --- Initial Secrets Setup ---
    setup_initial_secrets "$PROJECT_ID"

    # --- Network Setup ---
    setup_initial_network "$PROJECT_ID"

    # --- IAM Permissions ---
    grant_initial_iam_permissions "$PROJECT_ID"

    echo_in_green "Initial project setup for '$PROJECT_ID' complete."
    echo_in_yellow "You can now run your main deployment script to provision resources."
    echo_in_yellow "Remember the Project ID: ${PROJECT_ID}"
}

# --- Helper Functions for the Main Script ---

determine_project() {
    local INPUT_PROJECT="$1"
    check_project_exists "$INPUT_PROJECT"
    PROJECT_EXISTS=$?
    PROJECT_ID=""
    if [ "$PROJECT_EXISTS" -eq 0 ]; then
        echo_in_yellow "Using existing project '$PROJECT_ID'."
    else
        echo_in_yellow "Project '$PROJECT_ID' does not exist. Creating a new one."
        create_project
    fi
}

enable_default_apis() {
    local PROJECT_ID="$1"
    local APIS_TO_ENABLE=(
        compute.googleapis.com
        sqladmin.googleapis.com
        redis.googleapis.com
        iam.googleapis.com
        serviceusage.googleapis.com
        cloudresourcemanager.googleapis.com
        monitoring.googleapis.com
        logging.googleapis.com
        storage-api.googleapis.com
        storage-component.googleapis.com
        dns.googleapis.com
        secretmanager.googleapis.com
        networkconnectivity.googleapis.com
        networkservices.googleapis.com
    )
    enable_apis "$PROJECT_ID" "${APIS_TO_ENABLE[@]}"
}

setup_initial_secrets() {
    local PROJECT_ID="$1"
    # We might not have all the specific details yet, so we'll just trigger the setup.
    # The prompts for individual secrets are within the setup_secrets function.
    setup_secrets "$PROJECT_ID" "" "" "" # Pass empty strings as placeholders for now
}

setup_initial_network() {
    local PROJECT_ID="$1"
    # Assuming VPC network details are in config.sh
    setup_vpc_network_initial "$PROJECT_ID"

    # Conditionally reserve static IP if the name is defined
    if [[ -n "$STATIC_IP_NAME" ]]; then
        reserve_static_ip "$PROJECT_ID" "$STATIC_IP_NAME"
    fi
}

grant_initial_iam_permissions() {
    local PROJECT_ID="$1"
    setup_iam_permissions "$PROJECT_ID"
}

main
