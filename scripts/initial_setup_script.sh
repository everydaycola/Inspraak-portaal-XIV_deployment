#!/bin/bash

source modules/colors.sh
source modules/config.sh
source secrets/secrets.sh
source modules/create_ssl_cert.sh
source modules/add_lb_ip_to-cloudflare.sh
source modules/setup_gitlab_ci_variables.sh
source deploy_using_modules.sh

# This script should be run ONCE when a new organization wants to use the scripts

# Function to check if a project exists
check_project_exists() {
    local PROJECT_TO_CHECK="$1"
    gcloud projects describe "$PROJECT_TO_CHECK" &>/dev/null
    return $? # Returns 0 if exists, non-zero otherwise
}

PROJECT_EXISTS_FOR_BILLING=false

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
    networkservices.googleapis.com
    servicenetworking.googleapis.com)

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
    gcloud config set project $PROJECT_ID
}

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
    local CD_SA_NAME="gitlab-cd-fase"
    local CD_SA_FASE_EMAIL="${CD_SA_NAME}@${PROJECT_ID}.iam.gserviceaccount.com"
    local KEY_OUTPUT_PATH="gcloud-auth.json"
    local KEY_OUTPUT_BASE64_PATH="gcloud-auth-base64.txt"

    echo_in_blue "Granting necessary IAM permissions to Compute Engine default service account: '$SERVICE_ACCOUNT_EMAIL'..."

    ROLES_TO_GRANT=(
        "roles/certificatemanager.viewer"
        "roles/redis.viewer"
        "roles/cloudsql.client"
        "roles/secretmanager.secretAccessor"
        "roles/secretmanager.admin"
        "roles/storage.objectAdmin"
        "roles/storage.objectCreator"
        "roles/storage.objectViewer"
        "roles/monitoring.metricWriter"
        "roles/logging.logWriter"
    )

    for ROLE in "${ROLES_TO_GRANT[@]}"; do
        echo "  Granting role: '$ROLE'..."
        gcloud projects add-iam-policy-binding "$PROJECT_ID" \
            --member="serviceAccount:$SERVICE_ACCOUNT_EMAIL" \
            --role="$ROLE" 2>&1 >/dev/null
        if [ $? -eq 0 ]; then
            echo_in_green "    Granted '$ROLE'."
        else
            echo_in_red "    Error granting '$ROLE'."
        fi
    done

    gcloud iam service-accounts create "$CD_SA_NAME" \
        --project="$PROJECT_ID" \
        --display-name="GitLab CI/CD Service Account"

    gcloud projects add-iam-policy-binding "$PROJECT_ID" \
        --member="serviceAccount:$CD_SA_FASE_EMAIL" \
        --role="roles/compute.instanceGroupManagerServiceAgent"

    # Generate and download key
    gcloud iam service-accounts keys create "$KEY_OUTPUT_PATH" \
        --iam-account="$CD_SA_FASE_EMAIL" \
        --project="$PROJECT_ID"

    set_gitlab_file_as_variable "GCP_SA_KEY_JSON" $KEY_OUTPUT_PATH
    echo_in_green "IAM permissions granted to '$SERVICE_ACCOUNT_EMAIL' and '$CD_SA_FASE_EMAIL'."
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
    GITLAB_API="https://gitlab.com/api/v4"
    if [ $? -eq 0 ]; then
        echo_in_green "SSH deploy key pair generated successfully at '$KEY_PATH' and '$KEY_PATH.pub'."
        PRIVATE_KEY=$(cat "$KEY_PATH" | base64)
        PUBLIC_KEY=$(cat "$KEY_PATH.pub")

        create_secret "gitlab_deploy_key"
        add_secret_version "gitlab_deploy_key" "$PRIVATE_KEY"

        if [ $? -eq 0 ]; then
            echo_in_green "Private key stored in Secret Manager."

            echo_in_blue "Adding public key to GitLab deploy keys..."
            DATA="{\"title\": \"Auto-generated deploy key\", \"key\": \"$PUBLIC_KEY\", \"can_push\": false}"
            TMP_JSON=$(mktemp)

            # Use GitLab API to add deploy key
            HTTP_STATUS=$(curl --silent --show-error \
                --write-out "%{http_code}" \
                --output "$TMP_JSON" \
                --request POST \
                --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
                --header "Content-Type: application/json" \
                --data "$DATA" \
                "$GITLAB_API/projects/$GITLAB_PROJECT_ID/deploy_keys")
            if [ "$HTTP_STATUS" -eq 201 ]; then
                echo_in_green "Public deploy key successfully added to GitLab project."
            elif [ "$HTTP_STATUS" -eq 400 ]; then
                echo_in_yellow "Deploy key already exists or is invalid. Please check GitLab UI."
            else
                echo_in_red "Failed to add deploy key to GitLab. Status code: $HTTP_STATUS"
            fi
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
    create_secret "cloud_sql_instance_connection_name"
    add_secret_version "cloud_sql_instance_connection_name" "$CLOUD_SQL_CONN"

    # Cloud SQL Password
    if [[ -n "$CLOUD_SQL_PASSWORD" ]]; then
        create_secret "cloud_sql_password"
        add_secret_version "cloud_sql_password" "$CLOUD_SQL_PASSWORD"
    else
        echo_in_yellow "Cloud SQL Password not provided, skipping secret creation."
    fi

    # Cloud SQL User
    if [[ -n "$CLOUD_SQL_USER" ]]; then
        create_secret "cloud_sql_user"
        add_secret_version "cloud_sql_user" "$CLOUD_SQL_USER"
    else
        echo_in_yellow "Cloud SQL user not provided, skipping secret creation."
    fi

    if [[ -n "$SENDGRID_API_KEY" ]]; then
        create_secret "sndgrd-api-key-public"
        add_secret_version "sndgrd-api-key-public" "$SENDGRID_API_KEY"
    else
        echo_in_yellow "Sendgrid Public API Key not provided, skipping secret creation."
    fi

    # Adding cloudflare key using a file
    create_secret "cloudflare-origin-private-key"
    gcloud secrets versions add "cloudflare-origin-private-key" --data-file="secrets/cf-key.pem" --project=$PROJECT_ID

    # Adding cloudflare cert using a file
    create_secret "cloudflare-origin-certificate"
    gcloud secrets versions add cloudflare-origin-certificate --data-file="secrets/cf-cert.pem" --project=$PROJECT_ID

    # Create SSL cert
    gcloud beta compute ssl-certificates create $SSL_CERT \
        --project=$PROJECT_ID \
        --global \
        --private-key="secrets/cf-key.pem" \
        --certificate="secrets/cf-cert.pem"
    create_ssl_cert

    create_secret "pinc_api_key"
    add_secret_version "pinc_api_key" "$PINC_API_KEY"

    create_secret "my-app-bucket-name"
    add_secret_version "my-app-bucket-name" "$BUCKET_NAME"

    # Add variables to gitlab CI
    set_gitlab_variable "PROJECT_ID" "$PROJECT_ID"
    set_gitlab_variable "MIG_NAME" "$INSTANCE_GROUP_NAME"
    set_gitlab_variable "REGION" "$REGION"
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
    else
        echo_in_red "Error reserving global static IP address '$STATIC_IP_NAME'."
    fi
}

# --- Main Script ---

check_gcloud_installed

# Determine Project ID and whether it exists
check_project_exists "$PROJECT_ID"
PROJECT_EXISTS=$?
if [ "$PROJECT_EXISTS" -eq 0 ]; then
    echo_in_yellow "Using existing project '$PROJECT_ID'."
else
    echo_in_yellow "Project '$PROJECT_ID' does not exist. Creating a new one."
    create_project
fi

link_billing_account
enable_apis
set_default_region_zone

setup_secrets
setup_vpc_network_initial
reserve_static_ip
add_lb_ip_to_cloudflare
setup_iam_permissions

echo_in_green "Initial project setup for '$PROJECT_ID' complete."
echo_in_yellow "You can now run your main deployment script to provision resources."
echo_in_yellow "Remember the Project ID: ${PROJECT_ID}"

deploy_using_modules
