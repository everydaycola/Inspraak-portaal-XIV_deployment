#!/bin/bash

# Load configuration variables
source config.sh
source colors.sh

# Create DNS Authorization
gcloud certificate-manager dns-authorizations create $DNS_AUTH_NAME \
    --domain=$DOMAIN

#Create Certificate
gcloud certificate-manager certificates create $CERT_NAME \
    --domains="$DOMAIN,*.$DOMAIN" \
    --dns-authorizations=$DNS_AUTH_NAME

#Create Cert Map
gcloud certificate-manager maps create $CERT_MAP_NAME

#Create Cert Map Entries
gcloud certificate-manager maps entries create $CERT_ENTRY_1 \
    --map=$CERT_MAP_NAME \
    --certificates=$CERT_NAME \
    --hostname=$DOMAIN

gcloud certificate-manager maps entries create $CERT_ENTRY_2 \
    --map=$CERT_MAP_NAME \
    --certificates=$CERT_NAME \
    --hostname="*.$DOMAIN"

#Update HTTPS Proxy
gcloud compute "$HTTPS_PROXY_NAME" update $HTTPS_PROXY_NAME \
    --certificate-map=$CERT_MAP_NAME
