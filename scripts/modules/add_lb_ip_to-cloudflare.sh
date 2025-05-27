#!/bin/bash

source modules/config.sh
source secrets/secrets.sh

# --- Configuration ---
DNS_TTL=300
DNS_PROXIED=true

add_lb_ip_to_cloudflare() {
    LOAD_BALANCER_IP=$(gcloud compute addresses describe "$STATIC_IP_NAME" --global --project="$PROJECT_ID" --format="value(address)")
    if [ -z "$LOAD_BALANCER_IP" ]; then
        echo "Error: Could not retrieve load balancer IP address."
        exit 1
    fi

    echo "Load Balancer IP: $LOAD_BALANCER_IP"

    # --- Function to check if DNS record exists and get its ID (without jq) ---
    get_dns_record_id() {
        local RECORD_NAME="$1"
        local API_ENDPOINT="https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records?name=${RECORD_NAME}&type=A"
        local RESPONSE=$(curl -s -X GET -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" -H "Content-Type: application/json" "$API_ENDPOINT")
        local RECORD_ID=$(echo "$RESPONSE" | grep -o '"id":"[^"]*"' | cut -d':' -f2 | tr -d '"')
        echo "$RECORD_ID"
    }

    # --- Function to update or create DNS record ---
    update_dns_record() {
        local RECORD_NAME="$1"
        local API_ENDPOINT="$2"
        local HTTP_METHOD="$3"
        local DATA='{
    "type": "A",
    "name": "'"${RECORD_NAME}"'",
    "content": "'"${LOAD_BALANCER_IP}"'",
    "ttl": '"${DNS_TTL}"',
    "proxied": '"${DNS_PROXIED}"'
  }'

        curl -s -X "$HTTP_METHOD" \
            -H "Authorization: Bearer ${CLOUDFLARE_API_TOKEN}" \
            -H "Content-Type: application/json" \
            -d "$DATA" \
            "$API_ENDPOINT"
        return $?
    }

    # --- Main Script Logic ---

    declare -a records_to_update=("${DOMAIN}" "www.${DOMAIN}" "*.${DOMAIN}")

    for record_name in "${records_to_update[@]}"; do
        echo "Processing DNS record: $record_name"
        DNS_RECORD_ID=$(get_dns_record_id "$record_name")
        API_ENDPOINT_BASE="https://api.cloudflare.com/client/v4/zones/${CLOUDFLARE_ZONE_ID}/dns_records"

        if [ -n "$DNS_RECORD_ID" ]; then
            echo "DNS record found with ID: $DNS_RECORD_ID. Proceeding to update."
            API_ENDPOINT="$API_ENDPOINT_BASE/$DNS_RECORD_ID"
            HTTP_METHOD="PUT"
        else
            echo "DNS record not found. Proceeding to create."
            API_ENDPOINT="$API_ENDPOINT_BASE"
            HTTP_METHOD="POST"
        fi

        update_dns_record "$record_name" "$API_ENDPOINT" "$HTTP_METHOD"

        if [ $? -eq 0 ]; then
            echo "Cloudflare DNS record for $record_name updated successfully."
        else
            echo "Error updating Cloudflare DNS record for $record_name."
        fi
        echo "---"
    done

    echo "Finished processing DNS records."
}
