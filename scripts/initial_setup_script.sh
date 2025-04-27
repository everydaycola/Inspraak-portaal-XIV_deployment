#!/bin/bash

source colors.sh

# This script should be run ONCE when a new organization wants to use the scripts

read -p "$(echo -e ${YELLOW}Enter the desired Google Cloud Project Name or ID: ${ENDCOLOR})" INPUT_PROJECT

# Function to check if a project exists
check_project_exists() {
    local PROJECT_TO_CHECK="$1"
    gcloud projects describe "$PROJECT_TO_CHECK" &>/dev/null
    return $? # Returns 0 if exists, non-zero otherwise
}

PROJECT_ID=""
PROJECT_EXISTS=false

if check_project_exists "$INPUT_PROJECT"; then
    echo_in_yellow "Project '$INPUT_PROJECT' already exists. Using this project."
    PROJECT_ID="$INPUT_PROJECT"
    PROJECT_EXISTS=true
else
    echo_in_yellow "Project '$INPUT_PROJECT' does not exist. Attempting to create a new one."
    PROJECT_NAME="$INPUT_PROJECT" # Use the input as the desired name

    SANITIZE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g' | cut -c -20) # Lowercase, alphanumeric, hyphen, max 20 chars
    RANDOM_STRING=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)
    PROJECT_ID="${SANITIZE_NAME}-${RANDOM_STRING}"
    PROJECT_ID=$(echo "$PROJECT_ID" | cut -c -30) # Ensure max 30 chars

    echo_in_yellow "Generated Project ID: ${PROJECT_ID} (based on name '$PROJECT_NAME')"
fi

echo "Using Project ID: ${PROJECT_ID}"

read -p "$(echo -e ${YELLOW}Enter the Billing Account ID to link - optional, leave blank to skip: ${ENDCOLOR})" BILLING_ACCOUNT_ID

# List of Google Cloud APIs to enable
APIS_TO_ENABLE=(
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
    networkservices.googleapis.com)

# Default Compute Region and Zone (optional, can be set later or in deploy script)
read -p "$(echo -e ${YELLOW}Enter the default Compute Region - optional - default=europe_west: ${ENDCOLOR})" DEFAULT_REGION
read -p "$(echo -e ${YELLOW}Enter the default Compute Zone - optional - default=europe_west: ${ENDCOLOR})" DEFAULT_ZONE

# --- Helper Functions ---

check_gcloud_installed() {
    if ! command -v gcloud &>/dev/null; then
        echo_in_red "Error: Google Cloud CLI (gcloud) is not installed or not in your PATH."
        echo "Please follow the installation instructions here: https://cloud.google.com/sdk/docs/install"
        exit 1
    fi
}

create_project() {
    echo_in_blue "Creating Google Cloud project: '$PROJECT_ID'..."
    if gcloud projects create "$PROJECT_ID" --name=$PROJECT_NAME --enable-cloud-apis 2>&1; then
        echo_in_green "Project '$PROJECT_ID' created successfully."
    else
        echo_in_red "Error creating project '$PROJECT_ID'."
        exit 1
    fi
}

link_billing_account() {
    if [[ -n "$BILLING_ACCOUNT_ID" ]] && [[ "$PROJECT_EXISTS" == "false" ]]; then
        echo_in_blue "Linking billing account '$BILLING_ACCOUNT_ID' to project '$PROJECT_ID'..."
        gcloud beta billing accounts projects link "$PROJECT_ID" "$BILLING_ACCOUNT_ID" 2>&1
        if [ $? -eq 0 ]; then
            echo_in_green "Billing account linked successfully."
        else
            echo_in_red "Error linking billing account."
        fi
    elif [[ -n "$BILLING_ACCOUNT_ID" ]] && [[ "$PROJECT_EXISTS" == "true" ]]; then
        echo_in_yellow "Project already exists. Skipping explicit billing account linking (it should already be linked)."
    else
        echo_in_yellow "Skipping billing account linking."
    fi
}

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

# --- IAM Setup ---

get_project_number() {
    local project_id="$1"
    gcloud projects describe "$project_id" --format="value(projectNumber)"
}

set_iam_permissions() {
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

# --- Secret Manager Setup ---

create_secret() {
    local SECRET_NAME="$1"
    echo_in_blue "Creating Secret Manager secret: '$SECRET_NAME' in project '$PROJECT_ID'..."
    gcloud secrets create "$SECRET_NAME" --project="$PROJECT_ID" 2>&1
    if [ $? -eq 0 ]; then
        echo_in_green "Secret '$SECRET_NAME' created."
    elif [[ $(gcloud secrets describe "$SECRET_NAME" --project="$PROJECT_ID" 2>&1) ]]; then
        echo_in_yellow "Secret '$SECRET_NAME' already exists."
    else
        echo_in_red "Error creating secret '$SECRET_NAME'."
    fi
}

add_secret_version() {
    local SECRET_NAME="$1"
    local SECRET_VALUE="$2"
    echo_in_blue "Adding version to secret: '$SECRET_NAME' in project '$PROJECT_ID'..."
    echo -n "$SECRET_VALUE" | gcloud secrets versions add "$SECRET_NAME" --data-file=- --project="$PROJECT_ID" 2>&1
    if [ $? -eq 0 ]; then
        echo_in_green "Version added to secret '$SECRET_NAME'."
    else
        echo_in_red "Error adding version to secret '$SECRET_NAME'."
    fi
}

generate_deploy_key() {
    echo_in_blue "Generating a new SSH deploy key pair..."
    KEY_PATH="$HOME/.ssh/gitlab_deploy_key"
    ssh-keygen -t ed25519 -f $KEY_PATH -N ""
    if [ $? -eq 0 ]; then
        echo_in_green "SSH deploy key pair generated successfully at '$KEY_PATH' and '$KEY_PATH.pub'."
        PRIVATE_KEY=$(cat "$KEY_PATH" | base64)
        PUBLIC_KEY=$(cat "$KEY_PATH.pub")
        create_secret "gitlab_deploy_key"
        add_secret_version "gitlab_deploy_key" "$PRIVATE_KEY"
        # gcloud secrets versions add "gitlab_deploy_key" --data-file=$KEY_PATH --project="$PROJECT_ID" --quiet
        if [ $? -eq 0 ]; then
            echo_in_green "Private key stored in Secret Manager as 'gitlab_deploy_key'."
            echo_in_yellow "\n--- Public Key for GitLab ---"
            echo_in_yellow "Please add the following public key to your GitLab project's"
            echo_in_yellow "'Repository' -> 'Deploy Keys' settings:"
            echo_in_yellow "$PUBLIC_KEY"
            echo_in_yellow "Ensure 'Write access allowed' is unchecked unless necessary."
            echo_in_yellow "---"
        else
            echo_in_red "Error storing private key in Secret Manager."
        fi
    else
        echo_in_red "Error generating SSH deploy key pair."
    fi
}

setup_secrets() {
    echo_in_blue "Setting up secrets in Secret Manager for project '$PROJECT_ID'..."

    # Prompt for Gitlab Deploy Key
    generate_deploy_key

    # Prompt for Cloud SQL Instance Connection Name
    read -p "$(echo -e ${YELLOW}Enter the Cloud SQL Instance Connection Name - e.g., project_ID:region:db_name: ${ENDCOLOR})" CLOUD_SQL_CONN
    if [[ -n "$CLOUD_SQL_CONN" ]]; then
        create_secret "cloud_sql_instance_connection_name"
        add_secret_version "cloud_sql_instance_connection_name" "$CLOUD_SQL_CONN"
    else
        echo_in_yellow "Cloud SQL Instance Connection Name not provided, skipping secret creation."
    fi

    # Prompt for Cloud SQL Password
    read -p "$(echo -e -s ${YELLOW}Enter the Cloud SQL Password for user 'postgres': ${ENDCOLOR})" CLOUD_SQL_PASS
    echo "\n" # Add a newline after the password input
    if [[ -n "$CLOUD_SQL_PASS" ]]; then
        create_secret "cloud_sql_password"
        add_secret_version "cloud_sql_password" "$CLOUD_SQL_PASS"
    else
        echo_in_yellow "Cloud SQL Password not provided, skipping secret creation."
    fi

    # Prompt for Mailjet Public API Key
    read -p "$(echo -e ${YELLOW}Enter the Mailjet Public API Key: ${ENDCOLOR})" MJ_PUBLIC
    if [[ -n "$MJ_PUBLIC" ]]; then
        create_secret "mj-api-key-public"
        add_secret_version "mj-api-key-public" "$MJ_PUBLIC"
    else
        echo_in_yellow "Mailjet Public API Key not provided, skipping secret creation."
    fi

    # Prompt for Mailjet Private API Key
    read -p "$(echo -e -s ${YELLOW}Enter the Mailjet Private API Key: ${ENDCOLOR})" MJ_PRIVATE
    echo # Add a newline after the password input
    if [[ -n "$MJ_PRIVATE" ]]; then
        create_secret "mj-api-key-secret"
        add_secret_version "mj-api-key-secret" "$MJ_PRIVATE"
    else
        echo_in_yellow "Mailjet Private API Key not provided, skipping secret creation."
    fi
}

# --- Main Script ---

check_gcloud_installed

# Determine Project ID and whether it exists
check_project_exists "$INPUT_PROJECT"
PROJECT_EXISTS=$?
if [ "$PROJECT_EXISTS" -eq 0 ]; then
    echo_in_yellow "Using existing project '$INPUT_PROJECT'."
    PROJECT_ID="$INPUT_PROJECT"
else
    echo_in_yellow "Project '$INPUT_PROJECT' does not exist. Creating a new one."
    PROJECT_NAME="$INPUT_PROJECT" # Use the input as the desired name

    SANITIZE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g' | cut -c -20) # Lowercase, alphanumeric, hyphen, max 20 chars
    RANDOM_STRING=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)
    PROJECT_ID="${SANITIZE_NAME}-${RANDOM_STRING}"
    PROJECT_ID=$(echo "$PROJECT_ID" | cut -c -30) # Ensure max 30 chars

    echo_in_yellow "Generated Project ID: ${PROJECT_ID} (based on name '$PROJECT_NAME')"
    create_project
fi

link_billing_account
enable_apis
set_default_region_zone

setup_secrets

set_iam_permissions

echo_in_green "Initial project setup for '$PROJECT_ID' complete."
echo_in_yellow "You can now run your main deployment script to provision resources."
echo_in_yellow "Remember the Project ID: ${PROJECT_ID}"
