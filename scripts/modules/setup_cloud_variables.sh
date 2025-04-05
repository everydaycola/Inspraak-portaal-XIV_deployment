#!/bin/bash

setup_cloud_variables() {
    # Set the project and zone before checkign them
    echo_in_green "Setting gcloud variables..."
    gcloud config set project $PROJECT_ID
    gcloud config set compute/zone $ZONE
}
