#!/bin/bash
set -e # Exit on error

echo "Restarting deployment..."

echo "Destroying existing resources..."
./destroy.sh

echo "Deploying new resources..."
./deploy.sh

echo "Restart complete."
