const express = require('express');
const path = require('path');
const { MongoClient } = require('mongodb');
require('dotenv').config();

const app = express();
const port = process.env.WEB_PORT || 3000;

// MongoDB connection
const mongoClient = new MongoClient(process.env.MONGODB_URI);

// Set EJS as templating engine
app.set('view engine', 'ejs');
app.set('views', path.join(__dirname, 'views'));

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(express.static(path.join(__dirname, 'public')));

// Routes
app.get('/', async (req, res) => {
    try {
        await mongoClient.connect();
        const db = mongoClient.db(process.env.MONGODB_DB_NAME);
        
        // Get email statistics
        const stats = await db.collection('emails').aggregate([
            {
                $group: {
                    _id: null,
                    totalEmails: { $sum: 1 },
                    successfulEmails: {
                        $sum: { $cond: [{ $eq: ["$status", "delivered"] }, 1, 0] }
                    },
                    failedEmails: {
                        $sum: { $cond: [{ $eq: ["$status", "failed"] }, 1, 0] }
                    }
                }
            }
        ]).toArray();

        // Get recent emails
        const recentEmails = await db.collection('emails')
            .find()
            .sort({ timestamp: -1 })
            .limit(10)
            .toArray();

        res.render('dashboard', {
            stats: stats[0] || { totalEmails: 0, successfulEmails: 0, failedEmails: 0 },
            recentEmails
        });
    } catch (error) {
        console.error('Error fetching dashboard data:', error);
        res.status(500).render('error', { error: 'Failed to fetch dashboard data' });
    } finally {
        await mongoClient.close();
    }
});

// Start server
app.listen(port, () => {
    console.log(`Web interface running on port ${port}`);
}); 