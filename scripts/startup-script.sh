#!/bin/bash
set -x

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

#  Test SSH-verbinding met GitLab
echo "Testing SSH connection..."
ssh -T git@gitlab.com || echo "SSH connection failed"
echo "SSH connection successful."

#  Installeer Nginx
apt-get update
apt-get install -y nginx

# Installeer Git
apt-get install -y git

echo "Checking Git installation..."
which git || {
  echo "Git is not installed"
  exit 1
}
echo "Git is installed."

echo "Listing /root directory:"
ls -la /root/

wget https://packages.microsoft.com/config/ubuntu/20.04/prod.list
mv prod.list /etc/apt/sources.list.d/microsoft-prod.list
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | apt-key add -
apt-get update
apt-get install -y dotnet-sdk-8.0 # Vervang door de juiste versie van .NET die je nodig hebt

# Clone de repository
echo "Cloning repository..."
git clone git@gitlab.com:kdg-ti/integratieproject-1/202425/14_team-14/development.git ./myapp || {
  echo "Git clone failed"
  exit 1
}
echo "Repository cloned successfully."

cd ./myapp

# Controleer of .NET is geïnstalleerd
dotnet --version || {
  echo ".NET installation failed"
  exit 1
}

echo "Setting HOME environment variable..."
export HOME=/root

# Optioneel: Bouw de .NET applicatie
echo "Building .NET application..."
dotnet publish -c Release -o ./myapp/out || {
  echo "Dotnet build failed. Please check the logs for errors."
  exit 1
}
echo ".NET application built successfully."

# Zet Nginx om als reverse proxy
cat <<EOF >/etc/nginx/sites-available/myapp
server {
    listen 80;
    server_name myapp.example.com;

    location / {
        proxy_pass http://localhost:5000;  # Zorg ervoor dat de .NET-app op deze poort draait
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
EOF

#  Maak een symlink naar sites-enabled
ln -s /etc/nginx/sites-available/myapp /etc/nginx/sites-enabled/

# Test Nginx configuratie
nginx -t || {
  echo "Nginx configuration failed"
  exit 1
}

# Start Nginx
systemctl restart nginx

#  (Optioneel) Start de .NET applicatie
cd ./myapp/out
nohup dotnet myapp.dll >/var/log/myapp.log 2>&1 &
