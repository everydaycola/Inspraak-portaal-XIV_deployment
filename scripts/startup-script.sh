#!/bin/bash
set -e

# Update and install required packages
sudo apt update
sudo apt install -y postgresql-client curl

# Install Cloud SQL Proxy
curl -o cloud_sql_proxy https://dl.google.com/cloudsql/cloud_sql_proxy.linux.amd64
chmod +x cloud_sql_proxy
sudo mv cloud_sql_proxy /usr/local/bin/

# Get metadata
INSTANCE_CONNECTION_NAME=$(gcloud compute instances describe $(hostname) --zone=$(gcloud config get-value compute/zone) --format='value(metadata.items[?key="instance-connection-name"].value)')
DB_PASSWORD=$(gcloud compute instances describe $(hostname) --zone=$(gcloud config get-value compute/zone) --format='value(metadata.items[?key="db-password"].value)')
DB_USER=$(gcloud compute instances describe $(hostname) --zone=$(gcloud config get-value compute/zone) --format='value(metadata.items[?key="db-user"].value)')

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
PGPASSWORD="$DB_PASSWORD" psql -h 127.0.0.1 -U "$DB_USER" -d mydatabase -c "SELECT NOW();"

echo "Startup script completed."
