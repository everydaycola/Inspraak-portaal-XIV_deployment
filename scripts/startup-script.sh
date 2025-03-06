#!/bin/bash
set -x

# Variables
GIT_REPO="git@gitlab.com:kdg-ti/integratieproject-1/202425/14_team-14/development.git"
GIT_BRANCH="test_deployment-branch"
APP_DIR="/root/myapp"
APP_OUT_DIR="$APP_DIR/out"
APP_LOG_FILE="/var/log/myapp/myapp.log"
NGINX_CONFIG="/etc/nginx/sites-available/myapp"
DOMAIN_NAME="myapp.example.com" #replace with your domain.

# Ensure .ssh directory exists
mkdir -p ~/.ssh
chmod 700 ~/.ssh

# Retrieve the private SSH key from Google Secret Manager
echo "Retrieving and decoding SSH key..."
gcloud secrets versions access latest --secret=gitlab_deploy_key | tr -d '\r\n' | base64 --decode >/root/.ssh/gitlab_key
echo "SSH key retrieved and decoded."
chmod 600 ~/.ssh/gitlab_key

# Configure SSH to use GitLab
cat <<EOF >~/.ssh/config
Host gitlab.com
    IdentityFile ~/.ssh/gitlab_key
    StrictHostKeyChecking no
EOF
chmod 600 ~/.ssh/config

# Test SSH connection
echo "Testing SSH connection..."
ssh -T git@gitlab.com || {
  echo "SSH connection failed"
  exit 1
}
echo "SSH connection successful."

# Install dependencies before cloning
apt-get update && apt-get install -y nginx git postgresql-client curl

# Install .NET
wget https://packages.microsoft.com/config/ubuntu/20.04/prod.list
mv prod.list /etc/apt/sources.list.d/microsoft-prod.list
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | apt-key add -
apt-get update
apt-get install -y dotnet-sdk-8.0

# Clone repository
echo "Cloning repository..."
git clone --branch "$GIT_BRANCH" "$GIT_REPO" "$APP_DIR" || {
  echo "Git clone failed"
  exit 1
}
echo "Repository cloned."

cd "$APP_DIR"

# Check .NET installation
dotnet --version || {
  echo ".NET installation failed"
  exit 1
}

echo "Setting HOME environment variable..."
export HOME=/root

# Install Cloud SQL Proxy
curl -o cloud_sql_proxy https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64
chmod +x cloud_sql_proxy
sudo mv cloud_sql_proxy /usr/local/bin/

# Get Cloud SQL variables from Secret Manager
INSTANCE_CONNECTION_NAME=$(gcloud secrets versions access latest --secret=cloud_sql_instance_connection_name)
DB_PASSWORD=$(gcloud secrets versions access latest --secret=cloud_sql_password)
DB_USER=$(gcloud secrets versions access latest --secret=cloud_sql_user)

# Check if secrets were retrieved
if [ -z "$INSTANCE_CONNECTION_NAME" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_USER" ]; then
  echo "ERROR: Cloud SQL secrets not found in Secret Manager. Exiting."
  exit 1
fi

export ConnectionStrings__DefaultConnection="host=127.0.0.1;user=$DB_USER;password=$DB_PASSWORD;database=mydatabase"

# Cloud SQL Proxy Systemd Service
cat <<EOF | sudo tee /etc/systemd/system/cloud-sql-proxy.service
[Unit]
Description=Cloud SQL Proxy
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/cloud_sql_proxy -instances=$INSTANCE_CONNECTION_NAME=tcp:5432
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable cloud-sql-proxy
sudo systemctl start cloud-sql-proxy

# Wait for proxy
sleep 5

# Test PostgreSQL connection
psql -h 127.0.0.1 -U "$DB_USER" -d mydatabase -c "SELECT NOW();"

# Build .NET application
echo "Building .NET application..."
dotnet publish -c Release -o "$APP_OUT_DIR" || {
  echo "Dotnet build failed"
  exit 1
}
echo "Application built."

# Nginx configuration
cat <<EOF >"$NGINX_CONFIG"
server {
    listen 80;
    server_name $DOMAIN_NAME;

    location / {
        proxy_pass http://localhost:5000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection upgrade;
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
}
EOF

ln -s "$NGINX_CONFIG" /etc/nginx/sites-enabled/myapp
sudo rm /etc/nginx/sites-enabled/default

nginx -t || {
  echo "Nginx configuration failed"
  exit 1
}
systemctl restart nginx

# .NET application Systemd Service
mkdir -p /var/log/myapp/
cat <<EOF | sudo tee /etc/systemd/system/myapp.service
[Unit]
Description=My .NET Application
After=network.target cloud-sql-proxy.service

[Service]
WorkingDirectory=$APP_OUT_DIR
ExecStart=/usr/bin/dotnet UI-MVC.dll
Restart=always
RestartSec=10
SyslogIdentifier=myapp
StandardOutput=file:$APP_LOG_FILE
StandardError=file:$APP_LOG_FILE
Environment="ASPNETCORE_URLS=http://localhost:5000"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable myapp
sleep 2 #wait for cloud sql proxy to fully start.
sudo systemctl start myapp
