#!/bin/bash

# Zorg ervoor dat de SSH-map bestaat
mkdir -p $HOME/.ssh
chmod 700 $HOME/.ssh

#  Haal de private SSH-sleutel op uit Google Secret Manager
gcloud secrets versions access latest --secret=gitlab-ssh-key >$HOME/.ssh/gitlab_key
chmod 600 $HOME/gitlab_key/gitlab_key

# Configureer SSH om GitLab te gebruiken
cat <<EOF >$HOME/gitlab_key/config
Host gitlab.com
  IdentityFile $HOME/gitlab_key/gitlab_key
  StrictHostKeyChecking no
EOF
chmod 600 $HOME/gitlab_key/config

#  Test SSH-verbinding met GitLab
ssh -T git@gitlab.com || echo "SSH connection failed"

#  Installeer Nginx
apt-get update
apt-get install -y nginx

# Installeer Git
apt-get install -y git

wget https://packages.microsoft.com/config/ubuntu/20.04/prod.list
mv prod.list /etc/apt/sources.list.d/microsoft-prod.list
wget -q https://packages.microsoft.com/keys/microsoft.asc -O- | apt-key add -
apt-get update
apt-get install -y dotnet-sdk-8.0 # Vervang door de juiste versie van .NET die je nodig hebt

# Clone de repository
export GIT_SSH_COMMAND="ssh -i $HOME/gitlab_key -o StrictHostKeyChecking=no"
chmod 600 $HOME/gitlab_key
git clone git@gitlab.com:kdg-ti/integratieproject-1/202425/14_team-14/development.git /var/www/myapp || echo "Git clone failed"
cd /var/www/myapp

# Controleer of .NET is geïnstalleerd
dotnet --version || {
  echo ".NET installation failed"
  exit 1
}

# Optioneel: Bouw de .NET applicatie
if ! dotnet publish -c Release -o /var/www/myapp/out; then
  echo "Dotnet build failed. Please check the logs for errors."
  exit 1
fi

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
cd /var/www/myapp/out
nohup dotnet myapp.dll &
