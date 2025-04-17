#!/bin/bash

# Update system
sudo apt-get update
sudo apt-get upgrade -y

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install PM2
sudo npm install -g pm2

# Install Certbot for SSL certificates
sudo apt-get install -y certbot

# Create directories
mkdir -p ~/smtp-server/logs
mkdir -p ~/smtp-server/storage/emails
mkdir -p ~/smtp-server/config/dkim

# Clone repository (if using git)
# git clone <repository-url> ~/smtp-server

# Install dependencies
cd ~/smtp-server
npm install

# Generate SSL certificate
sudo certbot certonly --standalone -d mail.leazzy.in

# Set up PM2 to start the server
pm2 start src/server.js --name "smtp-server"
pm2 save

# Set up PM2 to start on boot
pm2 startup

echo "AWS EC2 setup completed!"
echo "Please update your .env file with the actual AWS EC2 IP address."
echo "Then run: node scripts/generate-dns-records.js to get your DNS records." 