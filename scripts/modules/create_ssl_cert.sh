#!/bin/bash

# Load configuration variables
source config.sh
source colors.sh

create_ssl_cert() {
    # Create DNS Authorization
    gcloud certificate-manager dns-authorizations create $DNS_AUTH_NAME \
        --domain=$DOMAIN \
        --location=global

    #Create Certificate
    gcloud certificate-manager certificates create $CERT_NAME \
        --domains="$DOMAIN,*.$DOMAIN" \
        --dns-authorizations=$DNS_AUTH_NAME \
        --location=global

    #Create Cert Map
    gcloud certificate-manager maps create $CERT_MAP_NAME \
        --location=global

    #Create Cert Map Entries
    gcloud certificate-manager maps entries create $CERT_ENTRY_1 \
        --map=$CERT_MAP_NAME \
        --certificates=$CERT_NAME \
        --hostname=$DOMAIN \
        --location=global

    gcloud certificate-manager maps entries create $CERT_ENTRY_2 \
        --map=$CERT_MAP_NAME \
        --certificates=$CERT_NAME \
        --hostname="*.$DOMAIN" \
        --location=global

    #     #Update HTTPS Proxy
    #     gcloud compute "$HTTPS_PROXY_NAME" update $HTTPS_PROXY_NAME \
    #         --certificate-map=$CERT_MAP_NAME \
    #         --location=global
}
