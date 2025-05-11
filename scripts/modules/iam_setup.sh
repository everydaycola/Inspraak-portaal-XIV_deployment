#!/bin/bash

source ../colors.sh
source core_functions.sh

# Function to set up IAM permissions for the Compute Engine default service account
setup_iam_permissions() {
    local PROJECT_NUMBER=$(get_project_number "$PROJECT_ID")
    local SERVICE_ACCOUNT_EMAIL="${PROJECT_NUMBER}-compute@developer.gserviceaccount.com"

    echo_in_blue "Granting necessary IAM permissions to Compute Engine default service account: '$SERVICE_ACCOUNT_EMAIL'..."

    ROLES_TO_GRANT=(
        "roles/certificatemanager.viewer"
        "roles/redis.viewer"
        "roles/cloudsql.client"
        "roles/secretmanager.secretAccessor"
        "roles/storage.objectAdmin"
        "roles/storage.objectCreator"
        "roles/storage.objectViewer"
    )

    for ROLE in "${ROLES_TO_GRANT[@]}"; do
        echo "  Granting role: '$ROLE'..."
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
            --role="$ROLE" 2>&1
        if [ $? -eq 0 ]; then
            echo_in_green "    Granted '$ROLE'."
        else
            echo_in_red "    Error granting '$ROLE'."
        fi
    done

    echo_in_green "IAM permissions granted to '$SERVICE_ACCOUNT_EMAIL'."
}
