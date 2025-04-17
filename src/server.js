const { SMTPServer } = require('smtp-server');
const winston = require('winston');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { MongoClient } = require('mongodb');
require('dotenv').config();

// Configure logger
const logger = winston.createLogger({
  level: 'info',
  format: winston.format.combine(
    winston.format.timestamp(),
    winston.format.json()
  ),
  transports: [
    new winston.transports.File({ filename: 'logs/error.log', level: 'error' }),
    new winston.transports.File({ filename: 'logs/combined.log' })
  ]
});

if (process.env.NODE_ENV !== 'production') {
  logger.add(new winston.transports.Console({
    format: winston.format.simple()
  }));
}

// Create logs directory if it doesn't exist
const logsDir = path.join(__dirname, '..', 'logs');
if (!fs.existsSync(logsDir)) {
  fs.mkdirSync(logsDir);
}

// Email storage directory
const emailStorageDir = path.join(__dirname, '..', 'storage', 'emails');
if (!fs.existsSync(emailStorageDir)) {
  fs.mkdirSync(emailStorageDir, { recursive: true });
}

// MongoDB connection
let mongoClient;
let db;

const connectToMongoDB = async () => {
  try {
    mongoClient = new MongoClient(process.env.MONGODB_URI);
    await mongoClient.connect();
    db = mongoClient.db(process.env.MONGODB_DB_NAME || 'smtp_server');
    logger.info('Connected to MongoDB');
    
    // Create indexes
    await db.collection('emails').createIndex({ from: 1 });
    await db.collection('emails').createIndex({ to: 1 });
    await db.collection('emails').createIndex({ receivedAt: 1 });
  } catch (error) {
    logger.error('MongoDB connection error', { error: error.message });
  }
};

// Load DKIM private key
let dkimPrivateKey;
try {
  dkimPrivateKey = fs.readFileSync(process.env.DKIM_PRIVATE_KEY_PATH, 'utf8');
} catch (error) {
  logger.warn('DKIM private key not found. DKIM signing will be disabled.');
}

// Function to sign email with DKIM
const signWithDKIM = (email) => {
  if (!dkimPrivateKey) return email;
  
  try {
    const domain = process.env.DOMAIN;
    const selector = process.env.DKIM_SELECTOR;
    const timestamp = Math.floor(Date.now() / 1000);
    const expiration = timestamp + 3600; // 1 hour
    
    const dkimHeader = [
      `v=1`,
      `a=rsa-sha256`,
      `c=relaxed/relaxed`,
      `d=${domain}`,
      `s=${selector}`,
      `t=${timestamp}`,
      `x=${expiration}`,
      `h=from:to:subject:date`,
      `bh=${crypto.createHash('sha256').update(email).digest('base64')}`,
      `b=${crypto.createSign('RSA-SHA256').update(email).sign(dkimPrivateKey, 'base64')}`
    ].join('; ');
    
    return `DKIM-Signature: ${dkimHeader}\r\n${email}`;
  } catch (error) {
    logger.error('DKIM signing failed', { error: error.message });
    return email;
  }
};

// Function to store email in MongoDB
const storeEmailInMongoDB = async (emailData) => {
  if (!db) {
    logger.warn('MongoDB not connected. Email will only be stored locally.');
    return;
  }
  
  try {
    await db.collection('emails').insertOne({
      ...emailData,
      receivedAt: new Date(),
      storedAt: new Date()
    });
    logger.info('Email stored in MongoDB');
  } catch (error) {
    logger.error('Error storing email in MongoDB', { error: error.message });
  }
};

// SMTP Server configuration
const server = new SMTPServer({
  secure: process.env.NODE_ENV === 'production',
  authOptional: process.env.NODE_ENV !== 'production',
  key: process.env.NODE_ENV === 'production' ? fs.readFileSync(process.env.TLS_KEY_PATH) : undefined,
  cert: process.env.NODE_ENV === 'production' ? fs.readFileSync(process.env.TLS_CERT_PATH) : undefined,
  onData(stream, session, callback) {
    let rawData = '';
    
    stream.on('data', (chunk) => {
      rawData += chunk.toString();
    });

    stream.on('end', async () => {
      try {
        // Sign with DKIM if in production
        if (process.env.NODE_ENV === 'production') {
          rawData = signWithDKIM(rawData);
        }
        
        // Extract email data
        const emailData = {
          from: session.envelope.mailFrom.address,
          to: session.envelope.rcptTo.map(rcpt => rcpt.address),
          raw: rawData,
          size: rawData.length,
          sessionId: session.id
        };
        
        // Log the received email
        logger.info('Received email', {
          from: emailData.from,
          to: emailData.to,
          size: emailData.size
        });

        // Store the email locally
        const timestamp = new Date().toISOString().replace(/[:.]/g, '-');
        const filename = `${timestamp}_${session.id}.eml`;
        fs.writeFileSync(path.join(emailStorageDir, filename), rawData);
        
        // Store the email in MongoDB
        await storeEmailInMongoDB(emailData);

        callback(null);
      } catch (error) {
        logger.error('Error processing email', { error: error.message });
        callback(error);
      }
    });
  },
  onAuth(auth, session, callback) {
    // Basic authentication - replace with your authentication logic
    if (auth.username === process.env.SMTP_USER && 
        auth.password === process.env.SMTP_PASS) {
      callback(null, { user: auth.username });
    } else {
      callback(new Error('Invalid username or password'));
    }
  }
});

// Connect to MongoDB and start the server
const startServer = async () => {
  await connectToMongoDB();
  
  // Start the server
  const port = process.env.SMTP_PORT || 25;
  server.listen(port, () => {
    logger.info(`SMTP server running on port ${port}`);
  });
};

startServer(); 