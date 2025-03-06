#!/bin/bash

# Google Cloud Project
PROJECT_ID="cs2-eycken-tibo"
ZONE="europe-west1-d"
REGION="europe-west1"

# Instance Group settings
INSTANCE_TEMPLATE_NAME="web-instance-template"
INSTANCE_GROUP_NAME="web-instance-group"
MACHINE_TYPE="e2-medium"
MIN_INSTANCES=2
MAX_INSTANCES=5
TARGET_CPU_UTILIZATION=0.6 # Autoscale when CPU > 60%

# Image Info
IMAGE_FAMILY="ubuntu-2004-lts"
IMAGE_PROJECT="ubuntu-os-cloud"

# Load Balancer Settings
HEALTH_CHECK_NAME="web-health-check"
BACKEND_SERVICE_NAME="web-backend-service"
URL_MAP_NAME="web-url-map"
HTTP_PROXY_NAME="web-http-proxy"
FORWARDING_RULE_NAME="web-forwarding-rule"

# Firewall Rule
FIREWALL_RULE_NAME="allow-http"

# Startup Script
STARTUP_SCRIPT="startup-script.sh"
