const crypto = require('crypto');
const fs = require('fs');
const path = require('path');

const generateDKIMKeys = () => {
  // Generate key pair
  const { privateKey, publicKey } = crypto.generateKeyPairSync('rsa', {
    modulusLength: 2048,
    publicKeyEncoding: {
      type: 'spki',
      format: 'pem'
    },
    privateKeyEncoding: {
      type: 'pkcs8',
      format: 'pem'
    }
  });

  // Create keys directory if it doesn't exist
  const keysDir = path.join(__dirname, '..', 'config', 'dkim');
  if (!fs.existsSync(keysDir)) {
    fs.mkdirSync(keysDir, { recursive: true });
  }

  // Save private key
  fs.writeFileSync(path.join(keysDir, 'private.key'), privateKey);
  
  // Save public key
  fs.writeFileSync(path.join(keysDir, 'public.key'), publicKey);

  // Generate DNS TXT record
  const publicKeyBase64 = publicKey
    .replace('-----BEGIN PUBLIC KEY-----\n', '')
    .replace('\n-----END PUBLIC KEY-----', '')
    .replace(/\n/g, '');

  const dnsRecord = `v=DKIM1; k=rsa; p=${publicKeyBase64}`;

  console.log('DKIM keys generated successfully!');
  console.log('\nAdd the following DNS TXT record:');
  console.log(`Selector: default`);
  console.log(`Record: ${dnsRecord}`);
  console.log('\nPrivate key saved to: config/dkim/private.key');
  console.log('Public key saved to: config/dkim/public.key');
};

generateDKIMKeys(); 