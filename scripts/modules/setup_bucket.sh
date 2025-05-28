#!/bin/bash

# Load configuration variables
source modules/config.sh
source modules/colors.sh

setup_bucket() {
    local BUCKET_NAME=$BUCKET_NAME
    if gsutil ls -b "gs://${BUCKET_NAME}" &>/dev/null; then
        read -p "Bucket 'gs://${BUCKET_NAME}' already exists. Do you want to [k]eep it or [r]emove and create a new one? (k/r): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Rr]$ ]]; then
            echo_in_orange "Removing existing bucket and creating a new one..."
            gcloud storage rm -r gs://$BUCKET_NAME
            gcloud storage buckets create gs://$BUCKET_NAME \
                --location=$REGION \
                --default-storage-class=STANDARD \
                --uniform-bucket-level-access \
                --no-public-access-prevention
        else
            echo "Keeping existing bucket."
        fi
    else
        echo "Bucket 'gs://${BUCKET_NAME}' doesn't exist. Creating it..."
        gcloud storage buckets create gs://$BUCKET_NAME \
            --location=$REGION \
            --default-storage-class=STANDARD \
            --uniform-bucket-level-access \
            --no-public-access-prevention
    fi
}

setup_bucket
