#!/bin/bash

source modules/config.sh
source modules/colors.sh

GITLAB_API="https://gitlab.com/api/v4"

function set_gitlab_variable() {
    local KEY=$1
    local VALUE=$2

    echo_in_green "Setting Gitlab variable $KEY..."
    # Check if variable exists
    EXISTING_VAR=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "$GITLAB_API/projects/$GITLAB_PROJECT_ID/variables/$KEY")

    if echo "$EXISTING_VAR" | grep -q "key"; then
        echo "Variable $KEY exists, updating..."
        curl -s --request PUT "$GITLAB_API/projects/$GITLAB_PROJECT_ID/variables/$KEY" \
            --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            --form "value=$VALUE" \
            --form "variable_type=env_var" \
            --form "protected=false"
    else
        echo "Variable $KEY not found, creating..."
        curl -s --request POST "$GITLAB_API/projects/$GITLAB_PROJECT_ID/variables" \
            --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            --form "key=$KEY" \
            --form "value=$VALUE" \
            --form "variable_type=env_var" \
            --form "protected=false"
    fi
}

function set_gitlab_file_as_variable() {
    local VARIABLE_KEY="$1"
    local FILE_PATH="$2"

    if [ ! -f "$FILE_PATH" ]; then
        echo_in_red "Error: File not found at $FILE_PATH"
        return 1
    fi

    echo_in_green "Setting Gitlab variable $VARIABLE_KEY with content of $FILE_PATH..."

    # Read the content of the file
    FILE_CONTENT=$(cat "$FILE_PATH")

    # Check if variable exists
    EXISTING_VAR=$(curl -s --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
        "$GITLAB_API/projects/$GITLAB_PROJECT_ID/variables/$VARIABLE_KEY")

    if echo "$EXISTING_VAR" | grep -q "key"; then
        curl -s --request PUT "$GITLAB_API/projects/$GITLAB_PROJECT_ID/variables/$VARIABLE_KEY" \
            --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            --form "value=$FILE_CONTENT" \
            --form "variable_type=env_var" \
            --form "protected=false"
    else
        curl -s --request POST "$GITLAB_API/projects/$GITLAB_PROJECT_ID/variables" \
            --header "PRIVATE-TOKEN: $GITLAB_TOKEN" \
            --form "key=$VARIABLE_KEY" \
            --form "value=$FILE_CONTENT" \
            --form "variable_type=env_var" \
            --form "protected=false"
    fi

    if [ $? -eq 0 ]; then
        echo_in_green "Gitlab variable $VARIABLE_KEY set successfully."
    else
        echo_in_red "Error setting Gitlab variable $VARIABLE_KEY."
    fi
    rm $FILE_PATH
}
