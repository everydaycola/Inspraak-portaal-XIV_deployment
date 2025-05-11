#!/bin/bash

source core_functions.sh
source ../config.sh # Assuming config.sh will hold default values if needed
source ../colors.sh

# Function to create a new Google Cloud project
create_project() {
    echo_in_blue "Creating Google Cloud project: '$PROJECT_ID'..."
    if gcloud projects create "$PROJECT_ID" --name=$PROJECT_NAME --enable-cloud-apis 2>&1; then
        echo_in_green "Project '$PROJECT_ID' created successfully."
    else
        echo_in_red "Error creating project '$PROJECT_ID'."
        exit 1
    fi
}

# Function to link a billing account to a project
link_billing_account() {
    if [[ -n "$BILLING_ACCOUNT_ID" ]] && [[ "$PROJECT_EXISTS_FOR_BILLING" == "false" ]]; then
        echo_in_blue "Linking billing account '$BILLING_ACCOUNT_ID' to project '$PROJECT_ID'..."
        gcloud beta billing projects link "$PROJECT_ID" --billing-account="$BILLING_ACCOUNT_ID" 2>&1
        if [ $? -eq 0 ]; then
            echo_in_green "Billing account linked successfully."
        else
            echo_in_red "Error linking billing account."
        fi
    elif [[ -n "$BILLING_ACCOUNT_ID" ]] && [[ "$PROJECT_EXISTS_FOR_BILLING" == "true" ]]; then
        echo_in_yellow "Project already exists. Skipping explicit billing account linking (it should already be linked)."
    else
        echo_in_yellow "Skipping billing account linking."
    fi
}

# Function to enable a list of Google Cloud APIs
enable_apis() {
    echo_in_blue "Enabling necessary Google Cloud APIs..."
    for API in "${APIS_TO_ENABLE[@]}"; do
        echo "  Enabling API: $API"
        gcloud services enable "$API" --project="$PROJECT_ID" 2>&1
        if [ $? -ne 0 ]; then
            echo_in_red "Error enabling API '$API'."
            echo "Please check the output above for details."
            exit 1
        fi
    done
    echo_in_green "All necessary APIs enabled successfully."
}

# Function to set default compute region and zone
set_default_region_zone() {
    if [[ -n "$DEFAULT_REGION" ]]; then
        echo_in_blue "Setting default Compute Region to '$DEFAULT_REGION'..."
        gcloud config set compute/region "$DEFAULT_REGION" --project="$PROJECT_ID"
        if [ $? -eq 0 ]; then
            echo_in_green "Default Compute Region set."
        else
            echo_in_yellow "Failed to set default Compute Region."
        fi
    fi

    if [[ -n "$DEFAULT_ZONE" ]]; then
        echo_in_blue "Setting default Compute Zone to '$DEFAULT_ZONE'..."
        gcloud config set compute/zone "$DEFAULT_ZONE" --project="$PROJECT_ID"
        if [ $? -eq 0 ]; then
            echo_in_green "Default Compute Zone set."
        else
            echo_in_yellow "Failed to set default Compute Zone."
        fi
    fi
}
