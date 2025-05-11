#!/bin/bash

# Load configuration variables
source config.sh
source colors.sh

setup_bucket() {
    # Check if bucket exists
    if gsutil ls -b "gs://${BUCKET_NAME}" &>/dev/null; then
        echo "Bucket exists. Cleaning it..."
        gsutil -m rm -r "gs://${BUCKET_NAME}/**"
    else
        echo "Bucket doesn't exist. Creating it..."
        gsutil mb -l us-central1 "gs://${BUCKET_NAME}"
    fi
}
