#!/bin/bash

source core_functions.sh
source ../secrets.sh
source ../colors.sh

# Function to create a Secret Manager secret
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

# Function to add a version to a Secret Manager secret
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

# Function to generate an SSH deploy key pair and store the private key in Secret Manager
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

# Main function to set up secrets
setup_secrets() {
    echo_in_blue "Setting up secrets in Secret Manager for project '$PROJECT_ID'..."

    # Prompt for Gitlab Deploy Key
    generate_deploy_key

    # Create cloud sql instance connection name secret
    CLOUD_SQL_CONN=$PROJECT_ID:$DB_REGION:$DB_INSTANCE_NAME
    echo "$CLOUD_SQL_CONN"
    create_secret "cloud_sql_instance_connection_name"
    add_secret_version "cloud_sql_instance_connection_name" "$CLOUD_SQL_CONN"

    # Cloud SQL Password
    if [[ -n "$CLOUD_SQL_PASSWORD" ]]; then
        create_secret "cloud_sql_password"
        add_secret_version "cloud_sql_password" "$CLOUD_SQL_PASSWORD"
    else
        echo_in_yellow "Cloud SQL Password not provided, skipping secret creation."
    fi

    if [[ -n "$MJ_PUBLIC" ]]; then
        create_secret "mj-api-key-public"
        add_secret_version "mj-api-key-public" "$MJ_PUBLIC"
    else
        echo_in_yellow "Mailjet Public API Key not provided, skipping secret creation."
    fi

    if [[ -n "$MJ_PRIVATE" ]]; then
        create_secret "mj-api-key-secret"
        add_secret_version "mj-api-key-secret" "$MJ_PRIVATE"
    else
        echo_in_yellow "Mailjet Private API Key not provided, skipping secret creation."
    fi

    create_secret "pinc_api_key"
    add_secret_version "pinc_api_key" "$API_PROCI_INV"

    create_secret "pinc_api_key"
    add_secret_version "pinc_api_key" "$PINC_API"

    create_secret "pinc_api_key"
    add_secret_version "my-app-bucket-name" "$APP_BUCKET_NAME"
}
