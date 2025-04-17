#!/bin/bash

# Configuration
DOMAIN="leazzy.in"
EC2_IP="13.60.86.228"
EC2_USER="ubuntu"
EC2_KEY_PATH="./my-mail-server.pem"  # Update this with your actual key path
MONGODB_URI="mongodb+srv://syrexDataBase:Rebook@123@cluster0.3teuel3.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0"
MONGODB_DB_NAME="syrexDataBase"
SMTP_USER="admin@leazzy.in"
SMTP_PASS="ashish@123"
APP_DIR="/opt/smtp-server"
SMTP_PORT="25"  # Changed back to 25 for production use

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
  echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if required tools are installed
check_requirements() {
  print_status "Checking requirements..."
  
  # Check for Node.js
  if ! command -v node &> /dev/null; then
    print_error "Node.js is not installed. Please install Node.js 18.x or higher."
    exit 1
  fi
  
  # Check for npm
  if ! command -v npm &> /dev/null; then
    print_error "npm is not installed. Please install npm."
    exit 1
  fi
  
  # Check for SSH
  if ! command -v ssh &> /dev/null; then
    print_error "SSH is not installed. Please install SSH."
    exit 1
  fi
  
  # Check for SCP
  if ! command -v scp &> /dev/null; then
    print_error "SCP is not installed. Please install SCP."
    exit 1
  fi
  
  # Check for zip
  if ! command -v zip &> /dev/null; then
    print_error "zip is not installed. Please install zip."
    exit 1
  fi
  
  print_status "All requirements satisfied."
}

# Create deployment package
create_deployment_package() {
  print_status "Creating deployment package..."
  
  # Create a temporary directory for the deployment package
  mkdir -p deploy_package
  
  # Copy necessary files to the deployment package
  cp -r src deploy_package/
  cp package.json deploy_package/
  cp package-lock.json deploy_package/ 2>/dev/null || true
  cp .env deploy_package/
  
  # Create a zip file of the deployment package
  zip -r deploy_package.zip deploy_package
  
  # Remove the temporary directory
  rm -rf deploy_package
  
  print_status "Deployment package created successfully."
}

# Deploy to EC2
deploy_to_ec2() {
  print_status "Deploying to EC2..."
  
  # Check if the EC2 key file exists
  if [ ! -f "$EC2_KEY_PATH" ]; then
    print_error "EC2 key file not found at $EC2_KEY_PATH. Please update the EC2_KEY_PATH variable."
    exit 1
  fi
  
  # Copy the deployment package to EC2
  scp -i "$EC2_KEY_PATH" deploy_package.zip "$EC2_USER@$EC2_IP:~/"
  if [ $? -ne 0 ]; then
    print_error "Failed to copy deployment package to EC2."
    exit 1
  fi
  
  # SSH into EC2 and run the setup script
  ssh -i "$EC2_KEY_PATH" "$EC2_USER@$EC2_IP" << 'EOF'
    # Exit on error
    set -e
    
    # Update system packages
    echo "Updating system packages..."
    sudo apt-get update
    sudo apt-get upgrade -y
    
    # Install required packages
    echo "Installing required packages..."
    sudo apt-get install -y unzip
    
    # Install Node.js and npm
    echo "Installing Node.js and npm..."
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
    
    # Verify Node.js installation
    if ! command -v node &> /dev/null; then
      echo "ERROR: Node.js installation failed."
      exit 1
    fi
    
    # Install PM2 globally
    echo "Installing PM2..."
    sudo npm install -g pm2
    
    # Verify PM2 installation
    if ! command -v pm2 &> /dev/null; then
      echo "ERROR: PM2 installation failed."
      exit 1
    fi
    
    # Install Certbot for SSL certificates
    echo "Installing Certbot..."
    sudo apt-get install -y certbot
    
    # Backup existing configuration if it exists
    if [ -d "/opt/smtp-server" ] && [ "$(ls -A /opt/smtp-server)" ]; then
      echo "Backing up existing configuration..."
      sudo tar -czf /opt/smtp-server-backup-$(date +%Y%m%d%H%M%S).tar.gz -C /opt smtp-server
    fi
    
    # Remove existing application directory if it exists
    if [ -d "/opt/smtp-server" ]; then
      echo "Removing existing application directory..."
      sudo rm -rf /opt/smtp-server
    fi
    
    # Create application directory with proper permissions
    echo "Creating application directory..."
    sudo mkdir -p /opt/smtp-server
    sudo chown -R ubuntu:ubuntu /opt/smtp-server
    sudo chmod -R 755 /opt/smtp-server
    
    # Unzip the deployment package
    echo "Extracting deployment package..."
    sudo unzip -o deploy_package.zip -d /opt/
    
    # Move files from deploy_package to smtp-server
    echo "Moving files to application directory..."
    sudo cp -r /opt/deploy_package/* /opt/smtp-server/
    sudo rm -rf /opt/deploy_package
    
    # Set proper permissions again after extraction
    sudo chown -R ubuntu:ubuntu /opt/smtp-server
    sudo chmod -R 755 /opt/smtp-server
    
    # Change to application directory
    cd /opt/smtp-server
    
    # Install dependencies
    echo "Installing dependencies..."
    npm install
    
    # Create necessary directories
    echo "Creating required directories..."
    mkdir -p logs
    mkdir -p src/views
    mkdir -p config/ssl
    
    # Create dummy SSL certificates for development
    echo "Creating dummy SSL certificates..."
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
      -keyout config/ssl/private.key -out config/ssl/certificate.crt \
      -subj "/C=US/ST=State/L=City/O=Organization/CN=mail.leazzy.in"
    
    # Create .env file if it doesn't exist
    if [ ! -f .env ]; then
      echo "Creating .env file..."
      echo "NODE_ENV=production" > .env
      echo "SMTP_PORT=25" >> .env
      echo "SMTP_USER=admin@leazzy.in" >> .env
      echo "SMTP_PASS=ashish@123" >> .env
      echo "DOMAIN=leazzy.in" >> .env
      echo "MONGODB_URI=mongodb+srv://syrexDataBase:Rebook@123@cluster0.3teuel3.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0" >> .env
      echo "MONGODB_DB_NAME=syrexDataBase" >> .env
      echo "TLS_KEY_PATH=/opt/smtp-server/config/ssl/private.key" >> .env
      echo "TLS_CERT_PATH=/opt/smtp-server/config/ssl/certificate.crt" >> .env
    else
      # Update .env file with production settings
      echo "Updating .env file..."
      sed -i "s|NODE_ENV=.*|NODE_ENV=production|g" .env
      sed -i "s|SMTP_PORT=.*|SMTP_PORT=25|g" .env
      sed -i "s|MONGODB_URI=.*|MONGODB_URI=mongodb+srv://syrexDataBase:Rebook@123@cluster0.3teuel3.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0|g" .env
      sed -i "s|MONGODB_DB_NAME=.*|MONGODB_DB_NAME=syrexDataBase|g" .env
      sed -i "s|SMTP_USER=.*|SMTP_USER=admin@leazzy.in|g" .env
      sed -i "s|SMTP_PASS=.*|SMTP_PASS=ashish@123|g" .env
      
      # Add TLS paths if they don't exist
      if ! grep -q "TLS_KEY_PATH" .env; then
        echo "TLS_KEY_PATH=/opt/smtp-server/config/ssl/private.key" >> .env
      fi
      if ! grep -q "TLS_CERT_PATH" .env; then
        echo "TLS_CERT_PATH=/opt/smtp-server/config/ssl/certificate.crt" >> .env
      fi
    fi
    
    # Generate SSL certificate (using DNS challenge instead of HTTP)
    echo "SSL certificate generation requires manual DNS configuration."
    echo "You need to manually add the DNS records for the ACME challenge."
    echo "Run this command on your local machine to get the DNS records:"
    echo "sudo certbot certonly --manual --preferred-challenges dns -d mail.leazzy.in"
    
    # Stop existing PM2 processes if any
    echo "Stopping existing PM2 processes..."
    pm2 delete all || true
    
    # Start the SMTP server with PM2 using sudo
    echo "Starting SMTP server with sudo..."
    sudo pm2 start /opt/smtp-server/src/server.js --name "smtp-server"
    
    # Verify SMTP server started
    if ! sudo pm2 list | grep -q "smtp-server.*online"; then
      echo "ERROR: SMTP server failed to start."
      sudo pm2 logs smtp-server
      exit 1
    fi
    
    # Start the web interface with PM2
    echo "Starting web interface..."
    pm2 start /opt/smtp-server/src/web-interface.js --name "web-interface"
    
    # Verify web interface started
    if ! pm2 list | grep -q "web-interface.*online"; then
      echo "ERROR: Web interface failed to start."
      pm2 logs web-interface
      exit 1
    fi
    
    # Save PM2 configuration
    echo "Saving PM2 configuration..."
    sudo pm2 save
    
    # Set up PM2 to start on boot
    echo "Setting up PM2 to start on boot..."
    sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu
    
    # Clean up
    cd ~
    rm -rf deploy_package.zip
    
    echo "Deployment completed successfully!"
    
    # Display status
    echo "Current PM2 status:"
    sudo pm2 list
    
    echo "SMTP server logs:"
    sudo pm2 logs smtp-server --lines 10
    
    echo "Web interface logs:"
    pm2 logs web-interface --lines 10
EOF
  
  if [ $? -ne 0 ]; then
    print_error "Failed to deploy to EC2."
    exit 1
  fi
  
  print_status "Deployed to EC2 successfully."
}

# Main function
main() {
  print_status "Starting deployment process..."
  
  # Check requirements
  check_requirements
  
  # Create deployment package
  create_deployment_package
  
  # Deploy to EC2
  deploy_to_ec2
  
  print_status "Deployment completed successfully!"
  print_status "SMTP server is running on port 25"
  print_status "Web interface is available at http://$EC2_IP:3000"
  print_status "Note: SSL certificate generation requires manual DNS configuration."
  print_status "Please follow the instructions provided during deployment to set up SSL."
}

# Run the main function
main 

cat > /opt/smtp-server/.env << EOF
NODE_ENV=production
SMTP_PORT=25
SMTP_USER=admin@leazzy.in
SMTP_PASS=ashish@123
DOMAIN=leazzy.in
MONGODB_URI=mongodb+srv://syrexDataBase:Rebook@123@cluster0.3teuel3.mongodb.net/?retryWrites=true&w=majority&appName=Cluster0
MONGODB_DB_NAME=syrexDataBase
EOF

sudo chown -R ubuntu:ubuntu /opt/smtp-server 

pm2 list
pm2 logs smtp-server
pm2 logs web-interface 