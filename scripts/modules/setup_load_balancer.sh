#!/binbash

source colors.sh
source config.sh

setup_load_balancer() {
    echo_in_green "Creating Load Balancer..."
    # Create a Backend Service
    gcloud compute backend-services create "$BACKEND_SERVICE_NAME" \
        --protocol=HTTP \
        --health-checks="$HEALTH_CHECK_NAME" \
        --network="$VPC_NETWORK_NAME" \
        --global

    # Add the Instance Group to Backend Service
    echo_in_green "Adding instance group to backend service..."
    gcloud compute backend-services add-backend "$BACKEND_SERVICE_NAME" \
        --instance-group="$INSTANCE_GROUP_NAME" \
        --instance-group-zone="$ZONE" \
        --global

    # Create a URL Map
    echo_in_green "Creating URL Map..."
    gcloud compute url-maps create "$URL_MAP_NAME" --default-service="$BACKEND_SERVICE_NAME"

    # Create an HTTP Proxy
    echo_in_green "Creating HTTP Proxy..."
    gcloud compute target-http-proxies create "$HTTP_PROXY_NAME" --url-map="$URL_MAP_NAME"

    # Create a Global Forwarding Rule
    echo_in_green "Creating Global Forwarding Rule..."
    gcloud compute forwarding-rules create "$FORWARDING_RULE_NAME" \
        --global \
        --target-http-proxy="$HTTP_PROXY_NAME" \
        --ports=80
}
