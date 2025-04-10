#!/bin/bash
set -x

# Variables
GIT_REPO="git@gitlab.com:kdg-ti/integratieproject-1/202425/14_team-14/development.git"
GIT_BRANCH="development"
APP_DIR="/root/myapp"
APP_OUT_DIR="$APP_DIR/out"
APP_LOG_FILE="/var/log/myapp/myapp.log"
NGINX_CONFIG="/etc/nginx/sites-available/myapp"
DOMAIN_NAME="www.ip14.be" #replace with your domain.

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
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

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

# Ensure necessary EF Core packages are installed
cd "$APP_DIR"

# Ensure we're in the /root directory
cd /root

# Download Cloud SQL Proxy
curl -o cloud-sql-proxy https://storage.googleapis.com/cloud-sql-connectors/cloud-sql-proxy/v2.11.0/cloud-sql-proxy.linux.amd64
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to download Cloud SQL Proxy."
  exit 1
fi

chmod +x /root/cloud-sql-proxy
sudo mv /root/cloud-sql-proxy /usr/local/bin/
chmod +x /usr/local/bin/cloud-sql-proxy

# Verify the executable exists
if [ ! -f /usr/local/bin/cloud-sql-proxy ]; then
  echo "ERROR: Cloud SQL Proxy executable not found in /usr/local/bin/."
  exit 1
fi

# Get Cloud SQL variables from Secret Manager
INSTANCE_CONNECTION_NAME=$(gcloud secrets versions access latest --secret=cloud_sql_instance_connection_name)
DB_PASSWORD=$(gcloud secrets versions access latest --secret=cloud_sql_password)
#DB_USER=$(gcloud secrets versions access latest --secret=cloud_sql_user)
DB_USER="postgres"

# Retrieve Redis Private IP
# TODO change this --region flag to be more dynamic
REDIS_PRIVATE_IP=$(gcloud redis instances describe my-redis-instance --region=europe-west1 --format="value(host)")

# Check if retrieval was successful
if [ -z "$REDIS_PRIVATE_IP" ]; then
  echo "ERROR: Failed to retrieve Redis private IP."
  exit 1
fi

# Retrieve MailJet Secrets
MJ_APIKEY_PUBLIC=$(gcloud secrets versions access latest --secret=mj-api-key-public)
MJ_APIKEY_PRIVATE=$(gcloud secrets versions access latest --secret=mj-api-key-secret)

# Set environment variable
export MJ_APIKEY_PUBLIC="$MJ_APIKEY_PUBLIC"
export MJ_APIKEY_PRIVATE="$MJ_APIKEY_PRIVATE"
export REDIS_PRIVATE_IP="$REDIS_PRIVATE_IP"
export PGPASSWORD="$DB_PASSWORD"

echo "INSTANCE_CONNECTION_NAME: $INSTANCE_CONNECTION_NAME"
echo "DB_USER: $DB_USER"
echo "DB_PASSWORD: $DB_PASSWORD"

# Check if secrets were retrieved
if [ -z "$INSTANCE_CONNECTION_NAME" ] || [ -z "$DB_PASSWORD" ] || [ -z "$DB_USER" ]; then
  echo "ERROR: Cloud SQL secrets not found in Secret Manager. Exiting."
  exit 1
fi

export ConnectionStrings__DefaultConnection="host=127.0.0.1;Username=$DB_USER;password=$DB_PASSWORD;database=mydatabase"
echo $ConnectionStrings__DefaultConnection

# Cloud SQL Proxy Systemd Service
cat <<EOF | sudo tee /etc/systemd/system/cloud-sql-proxy.service
[Unit]
Description=Cloud SQL Proxy
After=network.target

[Service]
User=root
ExecStart=/usr/local/bin/cloud-sql-proxy $INSTANCE_CONNECTION_NAME
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.tar get
EOF

sudo systemctl daemon-reload
sudo systemctl enable cloud-sql-proxy
sudo systemctl start cloud-sql-proxy

echo "Waiting for Cloud SQL Proxy to be ready..."
retries=0
max_retries=200           # Increase retries
service_check_interval=10 # Check service status every 10 retries

while ! psql -h 127.0.0.1 -U "$DB_USER" -d mydatabase -c "SELECT 1;" >/dev/null 2>&1; do
  if [ $retries -ge $max_retries ]; then
    echo "ERROR: Cloud SQL Proxy failed to connect after $max_retries retries."
    exit 1
  fi

  # Check Cloud SQL Proxy service every 10 retries
  if ((retries % service_check_interval == 0)); then
    systemctl is-active --quiet cloud-sql-proxy || echo "Warning: Cloud SQL Proxy service is not running."
  fi

  sleep 5
  retries=$((retries + 1))
done

echo "Cloud SQL Proxy is ready."

# Test PostgreSQL connection
psql -h 127.0.0.1 -U "$DB_USER" -d mydatabase -c "SELECT NOW();"

cd "$APP_DIR"

# Install .NET EF tools (if not already installed)
echo "Installing .NET EF tools..."
dotnet tool install --global dotnet-ef || echo "dotnet-ef already installed."

# Restore dependencies
echo "Restoring dependencies..."
dotnet restore

# Run migrations
echo "Checking for existing migrations..."
if [ ! -d "$APP_DIR/Migrations" ]; then
  echo "No migrations found. Adding initial migration..."
  dotnet ef migrations add InitialCreate
fi

# Apply migrations and update the database
echo "Updating database..."
dotnet ef database update

echo "Database migration and update completed successfully."

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
#Environment="ASPNETCORE_ENVIRONMENT=Development"
Environment="ConnectionStrings__DefaultConnection=host=127.0.0.1;Username=$DB_USER;password='$DB_PASSWORD';database=mydatabase"
Environment="Redis_Configuration=$REDIS_PRIVATE_IP:6379"
Environment="Redis_InstanceName=my-redis-instance"

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable myapp
sleep 2 #wait for cloud sql proxy to fully start.
sudo systemctl start myapp
