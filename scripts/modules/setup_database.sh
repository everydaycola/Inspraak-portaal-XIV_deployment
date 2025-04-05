#!/bin/bash

source colors.sh
source config.sh

setup_database() {
    # Collecting Credentials from the secret manager
    DB_PASSWORD=$(gcloud secrets versions access latest --secret=cloud_sql_password)
    DB_USER=$(gcloud secrets versions access latest --secret=cloud_sql_user)

    # Cloud SQL Instance Creation
    if gcloud sql instances describe "$DB_INSTANCE_NAME" >/dev/null 2>&1; then
        echo_in_orange "Cloud SQL instance '$DB_INSTANCE_NAME' already exists."
    else
        echo_in_green "Creating Cloud SQL Instance..."
        gcloud sql instances create "$DB_INSTANCE_NAME" \
            --project="$PROJECT_ID" \
            --database-version="$SQL_VERSION" \
            --tier="$SQL_TIER" \
            --region="$DB_REGION" \
            --root-password="$DB_PASSWORD" \
            --network="$VPC_NETWORK_NAME"
    fi
    echo_in_purple "Cloud SQL Instance '$DB_INSTANCE_NAME'"

    # Cloud SQL Database Creation
    if gcloud sql databases describe "mydatabase" --instance="$DB_INSTANCE_NAME" >/dev/null 2>&1; then
        echo_in_orange "Database 'mydatabase' already exists."
    else
        echo_in_green "Creating Database instance..."
        gcloud sql databases create "mydatabase" --instance="$DB_INSTANCE_NAME"
    fi
}
