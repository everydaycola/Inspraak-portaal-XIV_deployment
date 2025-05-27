#!/bin/bash

source modules/config.sh
source modules/colors.sh

# Make sure PROJECT_ID is set
if [ -z "$PROJECT_ID" ]; then
    echo_in_red "Error: PROJECT_ID is not set."
    exit 1
fi

# Check if the project exists
if gcloud projects describe "$PROJECT_ID" >/dev/null 2>&1; then
    echo -n "Are you sure you want to delete project '$PROJECT_ID'? [y/N]: "
    read -r CONFIRM
    if [[ "$CONFIRM" =~ ^[Yy]$ ]]; then
        echo_in_green "Deleting project '$PROJECT_ID'..."
        if ! gcloud projects delete "$PROJECT_ID" --quiet 2>/dev/null; then
            echo_in_red "Project '$PROJECT_ID' is already pending deletion or could not be deleted."
        fi
    else
        echo_in_red "Deletion cancelled."
    fi
else
    echo_in_red "Project '$PROJECT_ID' does not exist or you don't have permission to view it."
fi
