#!/bin/bash

source colors.sh
source config.sh

setup_load_balancer() {
    echo_in_green "Setting up Load Balancer..."

    # Check if Backend Service exists
    if ! gcloud compute backend-services describe "$BACKEND_SERVICE_NAME" --global >/dev/null 2>&1; then
        echo_in_green "Creating Backend Service..."
        gcloud compute backend-services create "$BACKEND_SERVICE_NAME" \
            --protocol=HTTPS \
            --health-checks="$HEALTH_CHECK_NAME" \
            --network="$VPC_NETWORK_NAME" \
            --global

        # Add the Instance Group to Backend Service
        echo_in_green "Adding instance group to backend service..."
        gcloud compute backend-services add-backend "$BACKEND_SERVICE_NAME" \
            --instance-group="$INSTANCE_GROUP_NAME" \
            --instance-group-zone="$ZONE" \
            --global
    else
        echo_in_yellow "Backend Service '$BACKEND_SERVICE_NAME' already exists. Skipping creation."
    fi

    # Check if URL Map exists
    if ! gcloud compute url-maps describe "$URL_MAP_NAME" --global >/dev/null 2>&1; then
        echo_in_green "Creating URL Map..."
        gcloud compute url-maps create "$URL_MAP_NAME" --default-service="$BACKEND_SERVICE_NAME"
    else
        echo_in_yellow "URL Map '$URL_MAP_NAME' already exists. Skipping creation."
    fi

    # Check if HTTP Proxy exists
    if ! gcloud compute target-http-proxies describe "$HTTP_PROXY_NAME" --global >/dev/null 2>&1; then
        echo_in_green "Creating HTTP Proxy..."
        gcloud compute target-http-proxies create "$HTTP_PROXY_NAME" --url-map="$URL_MAP_NAME"
    else
        echo_in_yellow "HTTP Proxy '$HTTP_PROXY_NAME' already exists. Skipping creation."
    fi

    # Create HTTPS Proxy
    if ! gcloud compute target-https-proxies describe "$HTTPS_PROXY_NAME" --global >/dev/null 2>&1; then
        echo_in_green "Creating HTTPS Proxy..."
        gcloud compute target-https-proxies create $HTTPS_PROXY_NAME \
            --url-map="$URL_MAP_NAME" \
            --ssl-certificates="$CERT_NAME" --global
    else
        echo_in_yellow "HTTPS Proxy '$HTTP_PROXY_NAME' already exists. Skipping creation."
    fi
    # Check if Forwarding Rule exists
    if ! gcloud compute forwarding-rules describe "$FORWARDING_RULE_HTTP_NAME" --global >/dev/null 2>&1; then
        echo_in_green "Creating Global Forwarding HTTP Rule..."
        gcloud compute forwarding-rules create "$FORWARDING_RULE_HTTP_NAME" \
            --global \
            --target-http-proxy="$HTTP_PROXY_NAME" \
            --ports=80 \
            --address="$STATIC_IP_NAME"
    else
        echo_in_yellow "Forwarding Rule '$FORWARDING_RULE_HTTP_NAME' already exists. Skipping creation."
    fi

    if ! gcloud compute forwarding-rules describe "$FORWARDING_RULE_HTTPS_NAME" --global >/dev/null 2>&1; then
        echo_in_green "Creating Global Forwarding HTTPS Rule..."
        gcloud compute forwarding-rules create "$FORWARDING_RULE_HTTPS_NAME" \
            --global \
            --target-https-proxy="$HTTPS_PROXY_NAME" \
            --ports=443 \
            --address="$STATIC_IP_NAME"
    else
        echo_in_yellow "Forwarding Rule '$FORWARDING_RULE_HTTPS_NAME' already exists. Skipping creation."
    fi
}
