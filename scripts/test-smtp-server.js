const nodemailer = require('nodemailer');
require('dotenv').config();

const testSMTP = async () => {
  // Create a test transporter
  const transporter = nodemailer.createTransport({
    host: 'localhost',
    port: process.env.SMTP_PORT || 25,
    secure: process.env.NODE_ENV === 'production',
    auth: {
      user: process.env.SMTP_USER,
      pass: process.env.SMTP_PASS
    }
  });

  try {
    // Send a test email
    const info = await transporter.sendMail({
      from: process.env.SMTP_USER,
      to: process.env.SMTP_USER, // Send to yourself for testing
      subject: 'SMTP Server Test',
      text: 'This is a test email from your SMTP server.',
      html: '<p>This is a test email from your SMTP server.</p>'
    });

    console.log('Test email sent successfully!');
    console.log('Message ID:', info.messageId);
    console.log('Response:', info.response);
  } catch (error) {
    console.error('Error sending test email:', error);
  }
};

testSMTP(); 