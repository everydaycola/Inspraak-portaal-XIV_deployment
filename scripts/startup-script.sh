#!/bin/bash

# Update package lists
sudo apt update -y

# Install nginx
sudo apt install -y nginx

# Create a test webpage
echo "<h1>Hello from $(hostname)</h1>" | sudo tee /var/www/html/index.html

# Start Nginx
sudo systemctl start nginx
sudo systemctl enable nginx
