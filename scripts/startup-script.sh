#!/bin/bash

# TODO fix SSH between gitlab and google cloud, currently the VMs are not able to clone the code
# Set up environment variables
APP_DIR="/home/ubuntu/myapp"
REPO_URL="git@gitlab.com:kdg-ti/integratieproject-1/202425/14_team-14/development.git"
PUBLISH_DIR="$APP_DIR/publish"
DOTNET_DLL="$PUBLISH_DIR/UI-MVC.dll"

# Update packages
sudo apt update -y
sudo apt install -y nginx

# Install .NET SDK
wget https://packages.microsoft.com/keys/microsoft.asc
sudo apt-key add microsoft.asc
sudo apt-add-repository https://packages.microsoft.com/ubuntu/$(lsb_release -r | awk "{print \$2}")/prod
sudo apt update
sudo apt install -y dotnet-sdk-8.0

# Dit werkt nog niet, weet niet hoe het te fixen
# --- Set up SSH Key from CI/CD Variable ---
mkdir -p /home/ubuntu/.ssh
echo "$DEPLOY_KEY" > /home/ubuntu/.ssh/id_rsa  # Use the CI/CD variable
chmod 600 /home/ubuntu/.ssh/id_rsa # Set correct permissions

# Clone the GitLab repository or pull the latest changes
APP_DIR="/home/ubuntu/myapp"
git clone https://gitlab.com/kdg-ti/integratieproject-1/202425/14_team-14/development.git $APP_DIR

# Publish the .NET app
dotnet publish -c Release -o $APP_DIR/publish

# Set up nginx as reverse proxy for .NET app
sudo systemctl stop nginx
sudo rm /etc/nginx/sites-enabled/default
echo "server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
}" | sudo tee /etc/nginx/sites-available/default

# Restart nginx to apply new configuration
sudo systemctl restart nginx