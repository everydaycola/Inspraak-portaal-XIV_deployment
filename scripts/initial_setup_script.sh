#!/bin/bash

source colors.sh
source config.sh

# This script should be run ONCE when a new organization wants to use the scripts

read -p "$(echo -e ${YELLOW}Enter the desired Google Cloud Project Name or ID: ${ENDCOLOR})" INPUT_PROJECT

# Function to check if a project exists
check_project_exists() {
    local PROJECT_TO_CHECK="$1"
    gcloud projects describe "$PROJECT_TO_CHECK" &>/dev/null
    return $? # Returns 0 if exists, non-zero otherwise
}

PROJECT_ID=""
PROJECT_EXISTS_FOR_BILLING=false

# if check_project_exists "$INPUT_PROJECT"; then
#     echo_in_yellow "Project '$INPUT_PROJECT' already exists. Using this project."
#     PROJECT_ID="$INPUT_PROJECT"
#     PROJECT_EXISTS=true
# else
#     echo_in_yellow "Project '$INPUT_PROJECT' does not exist. Attempting to create a new one."
#     PROJECT_NAME="$INPUT_PROJECT" # Use the input as the desired name

#     SANITIZE_NAME=$(echo "$PROJECT_NAME" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9-]//g' | cut -c -20) # Lowercase, alphanumeric, hyphen, max 20 chars
#     RANDOM_STRING=$(head /dev/urandom | tr -dc a-z0-9 | head -c 8)
#     PROJECT_ID="${SANITIZE_NAME}-${RANDOM_STRING}"
#     PROJECT_ID=$(echo "$PROJECT_ID" | cut -c -30) # Ensure max 30 chars

#     echo_in_yellow "Generated Project ID: ${PROJECT_ID} (based on name '$PROJECT_NAME')"
# fi

# echo "Using Project ID: ${PROJECT_ID}"

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
    echo_in_blue "billing account method running $BILLING_ACCOUNT_ID, $PROJECT_EXISTS_FOR_BILLING"
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

    # Create cloud sql instance connection name secret
    CLOUD_SQL_CONN=$PROJECT_ID:$DB_REGION:$DB_INSTANCE_NAME
    echo "$CLOUD_SQL_CONN"
    create_secret "cloud_sql_instance_connection_name"
    add_secret_version "cloud_sql_instance_connection_name" "$CLOUD_SQL_CONN"

    # Prompt for Cloud SQL Password
    read -s -p "$(echo -e ${YELLOW}Enter the Cloud SQL Password for user 'postgres': ${ENDCOLOR})" CLOUD_SQL_PASS
    echo "\n" # Add a newline after the password input
    if [[ -n "$CLOUD_SQL_PASS" ]]; then
        create_secret "cloud_sql_password"
        add_secret_version "cloud_sql_password" "$CLOUD_SQL_PASS"
    else
        echo_in_yellow "Cloud SQL Password not provided, skipping secret creation."
    fi

    # Prompt for Mailjet Public API Key
    read -s -p "$(echo -e ${YELLOW}Enter the Mailjet Public API Key: ${ENDCOLOR})" MJ_PUBLIC
    if [[ -n "$MJ_PUBLIC" ]]; then
        create_secret "mj-api-key-public"
        add_secret_version "mj-api-key-public" "$MJ_PUBLIC"
    else
        echo_in_yellow "Mailjet Public API Key not provided, skipping secret creation."
    fi

    # Prompt for Mailjet Private API Key
    read -s -p "$(echo -e ${YELLOW}Enter the Mailjet Private API Key: ${ENDCOLOR})" MJ_PRIVATE
    echo # Add a newline after the password input
    if [[ -n "$MJ_PRIVATE" ]]; then
        create_secret "mj-api-key-secret"
        add_secret_version "mj-api-key-secret" "$MJ_PRIVATE"
    else
        echo_in_yellow "Mailjet Private API Key not provided, skipping secret creation."
    fi

    # --- API "procinvies-in-cijfers" Key ---
    read -p "$(echo -e ${YELLOW}Enter the API Key for 'pinc_api_key': ${ENDCOLOR})" API_PROCI_INV
    create_secret "pinc_api_key"
    add_secret_version "pinc_api_key" "$API_PROCI_INV"

    # --- PINC API Key ---
    read -p "$(echo -e ${YELLOW}Enter the PINC API Key: ${ENDCOLOR})" PINC_API
    create_secret "pinc_api_key"
    add_secret_version "pinc_api_key" "$PINC_API"

    # --- My App Bucket Name ---
    read -p "$(echo -e ${YELLOW}Enter the Name of your application\'s main storage bucket: ${ENDCOLOR})" APP_BUCKET_NAME
    create_secret "pinc_api_key"
    add_secret_version "my-app-bucket-name" "$APP_BUCKET_NAME"
}

setup_vpc_network_initial() {
    echo_in_blue "Setting up VPC network..."

    # Check if the necessary variables are defined in config.sh
    if [[ -z "$VPC_NETWORK_NAME" ]]; then
        echo_in_red "Error: VPC_NETWORK_NAME is not defined in config.sh. Please configure it."
        return 1
    fi
    if [[ -z "$VPC_NETWORK_REGION" ]]; then
        echo_in_red "Error: VPC_NETWORK_REGION is not defined in config.sh. Please configure it."
        return 1
    fi
    if [[ -z "$VPC_SUBNET_NAME" ]]; then
        echo_in_red "Error: VPC_SUBNET_NAME is not defined in config.sh. Please configure it."
        return 1
    fi
    if [[ -z "$VPC_SUBNET_RANGE" ]]; then
        echo_in_red "Error: VPC_SUBNET_RANGE is not defined in config.sh. Please configure it."
        return 1
    fi

    echo_in_yellow "Using VPC network name: '$VPC_NETWORK_NAME' (configured in config.sh)."
    echo_in_yellow "Using VPC network region: '$VPC_NETWORK_REGION' (configured in config.sh)."
    echo_in_yellow "Using subnet name: '$VPC_SUBNET_NAME' (configured in config.sh)."
    echo_in_yellow "Using subnet IP range: '$VPC_SUBNET_RANGE' (configured in config.sh)."

    # Create VPC Network (if it doesn't exist)
    if gcloud compute networks list --filter="name=$VPC_NETWORK_NAME" --format="value(name)" --project="$PROJECT_ID" 2>/dev/null | grep -q "$VPC_NETWORK_NAME"; then
        echo_in_yellow "VPC network $VPC_NETWORK_NAME already exists."
    else
        echo_in_green "Creating VPC network: $VPC_NETWORK_NAME"
        gcloud compute networks create "$VPC_NETWORK_NAME" --subnet-mode=custom --project="$PROJECT_ID"
        if [ $? -ne 0 ]; then
            echo_in_red "Failed to create VPC network."
            return 1
        fi
    fi

    # Create Subnet (if it doesn't exist)
    if ! gcloud compute networks subnets describe "$VPC_SUBNET_NAME" --region="$VPC_NETWORK_REGION" --network="$VPC_NETWORK_NAME" --project="$PROJECT_ID" >/dev/null 2>&1; then
        echo_in_green "Creating Subnet: $VPC_SUBNET_NAME"
        gcloud compute networks subnets create "$VPC_SUBNET_NAME" --network="$VPC_NETWORK_NAME" --range="$VPC_SUBNET_RANGE" --region="$VPC_NETWORK_REGION" --project="$PROJECT_ID"
        if [ $? -ne 0 ]; then
            echo_in_red "Failed to create Subnet."
            return 1
        fi
    else
        echo_in_yellow "Subnet $VPC_SUBNET_NAME already exists."
    fi
}

reserve_static_ip() {
    gcloud compute addresses create "$STATIC_IP_NAME" --global --project="$PROJECT_ID" 2>&1
    if [ $? -eq 0 ]; then
        STATIC_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --global --project="$PROJECT_ID" --format="value(address)")
        echo_in_green "Global static IP address '$STATIC_IP' reserved with name '$STATIC_IP_NAME'."
        echo_in_yellow "You can use this IP for your load balancer or other global resources."

        echo_in_yellow "\n--- Domain Name Configuration ---"
        echo_in_yellow "To make your application accessible via your domain name (e.g., www.yourdomain.com),"
        echo_in_yellow "you will need to configure the DNS records at your domain registrar."
        echo_in_yellow "Once your deployment script has finished running successfully,"
        echo_in_yellow "it will output the public IP address of your load balancer."
        echo_in_yellow "You will need to create an 'A' record (and potentially a 'CNAME' record for 'www') at your registrar"
        echo_in_yellow "that points to this IP address."
        echo_in_yellow "Please refer to your domain registrar's documentation for instructions on how to manage DNS records."
        echo_in_yellow "---"
    else
        echo_in_red "Error reserving global static IP address '$STATIC_IP_NAME'."
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
setup_vpc_network_initial
reserve_static_ip
setup_iam_permissions

echo_in_green "Initial project setup for '$PROJECT_ID' complete."
echo_in_yellow "You can now run your main deployment script to provision resources."
echo_in_yellow "Remember the Project ID: ${PROJECT_ID}"
