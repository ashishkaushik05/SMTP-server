# Custom SMTP Server

A secure, standards-compliant SMTP server built with Node.js, featuring TLS encryption, SPF, DKIM, and DMARC support.

## Features

- SMTP server implementation using Node.js
- TLS encryption support
- SPF, DKIM, and DMARC validation
- Email storage and logging
- Authentication support
- AWS EC2 deployment ready

## Prerequisites

- Node.js 18.x or higher
- npm (Node Package Manager)
- AWS EC2 instance (for production deployment)
- Domain name with DNS management access

## Installation

1. Clone the repository:
```bash
git clone <repository-url>
cd smtp-server
```

2. Install dependencies:
```bash
npm install
```

3. Create environment configuration:
```bash
cp .env.example .env
```
Edit the `.env` file with your configuration.

## Development

Start the server in development mode:
```bash
NODE_ENV=development node src/server.js
```

## Production Deployment

1. Set up AWS EC2 instance:
   - Launch Ubuntu-based EC2 instance
   - Configure security group to allow port 25
   - Install Node.js and npm

2. Deploy the application:
```bash
git clone <repository-url>
cd smtp-server
npm install
cp .env.example .env
# Edit .env with production settings
```

3. Set up SSL/TLS certificates:
```bash
sudo apt-get update
sudo apt-get install certbot
sudo certbot certonly --standalone -d mail.yourdomain.com
```

4. Configure DNS records:
   - Add MX record pointing to your EC2 instance
   - Configure SPF record
   - Set up DKIM keys
   - Add DMARC record

5. Start the server with PM2:
```bash
npm install -g pm2
pm2 start src/server.js
pm2 save
```

## Testing

Test the SMTP server using:
```bash
telnet localhost 25
```

Or use a test email client:
```bash
npm install -g swaks
swaks --to recipient@example.com --from sender@yourdomain.com --server localhost:25
```

## Security Considerations

- Always use TLS in production
- Implement proper authentication
- Keep private keys secure
- Regularly update dependencies
- Monitor logs for suspicious activity

## License

ISC

## Author

[Your Name] 