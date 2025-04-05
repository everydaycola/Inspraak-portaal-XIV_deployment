#!/bin/bash

source colors.sh
source config.sh

setup_firewall_rules() {
    # Create a Firewall Rule to allow HTTP
    echo_in_green "Creating Firewall Rule to Allow HTTP..."
    gcloud compute firewall-rules create "$FIREWALL_RULE_NAME" \
        --allow tcp:80,tcp:5000 \
        --source-ranges 0.0.0.0/0 \
        --target-tags http-server \
        --description "Allow HTTP traffic"

    echo_in_green "Creating firewall rule 'allow-postgres'..."
    gcloud compute firewall-rules create "allow-postgres" \
        --allow tcp:5432 \
        --source-ranges 0.0.0.0/0 \
        --target-tags postgres-server \
        --description "Allow PostgreSQL traffic"
}
