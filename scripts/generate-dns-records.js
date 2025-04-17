const fs = require('fs');
const path = require('path');
require('dotenv').config();

const generateDNSRecords = () => {
  const domain = process.env.DOMAIN;
  const mxRecord = process.env.MX_RECORD;
  const awsIP = process.env.AWS_EC2_IP;

  if (!domain || !mxRecord || !awsIP) {
    console.error('Please set DOMAIN, MX_RECORD, and AWS_EC2_IP in your .env file');
    process.exit(1);
  }

  const records = {
    'A Record': {
      name: `mail.${domain}`,
      value: awsIP,
      ttl: 3600
    },
    'MX Record': {
      name: domain,
      value: `mail.${domain}`,
      priority: 10,
      ttl: 3600
    },
    'SPF Record': {
      name: domain,
      value: `v=spf1 a mx ip4:${awsIP} ~all`,
      ttl: 3600
    },
    'DMARC Record': {
      name: `_dmarc.${domain}`,
      value: 'v=DMARC1; p=none; rua=mailto:dmarc@' + domain,
      ttl: 3600
    }
  };

  // Read DKIM public key if it exists
  const dkimPublicKeyPath = path.join(__dirname, '..', 'config', 'dkim', 'public.key');
  if (fs.existsSync(dkimPublicKeyPath)) {
    const publicKey = fs.readFileSync(dkimPublicKeyPath, 'utf8')
      .replace('-----BEGIN PUBLIC KEY-----\n', '')
      .replace('\n-----END PUBLIC KEY-----', '')
      .replace(/\n/g, '');

    records['DKIM Record'] = {
      name: `default._domainkey.${domain}`,
      value: `v=DKIM1; k=rsa; p=${publicKey}`,
      ttl: 3600
    };
  }

  console.log('DNS Records for your SMTP server:');
  console.log('==================================\n');

  Object.entries(records).forEach(([type, record]) => {
    console.log(`${type}:`);
    console.log(`Name: ${record.name}`);
    console.log(`Value: ${record.value}`);
    if (record.priority) console.log(`Priority: ${record.priority}`);
    console.log(`TTL: ${record.ttl}`);
    console.log('');
  });

  console.log('Add these records to your DNS provider (e.g., Vercel DNS)');
};

generateDNSRecords(); 