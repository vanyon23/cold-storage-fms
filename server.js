require('dotenv').config();
const path = require('path');
const express = require('express');
const session = require('express-session');
const { requireLogin } = require('./middleware/auth');

const app = express();
app.use(express.json());
app.use(
  session({
    secret: process.env.SESSION_SECRET || 'cold-storage-secret',
    resave: false,
    saveUninitialized: false,
    cookie: { maxAge: 8 * 60 * 60 * 1000 }, // 8 hours
  })
);

// Frontend files (HTML, CSS, JS)
app.use(express.static(path.join(__dirname, '..', 'frontend')));

// API routes
app.use('/api/auth', require('./routes/auth'));
app.use('/api/dashboard', requireLogin, require('./routes/dashboard'));
app.use('/api/customers', requireLogin, require('./routes/customers'));
app.use('/api/categories', requireLogin, require('./routes/categories'));
app.use('/api/items', requireLogin, require('./routes/items'));
app.use('/api/chambers', requireLogin, require('./routes/chambers'));
app.use('/api/batches', requireLogin, require('./routes/batches'));
app.use('/api/releases', requireLogin, require('./routes/releases'));
app.use('/api/temperature', requireLogin, require('./routes/temperature'));
app.use('/api/invoices', requireLogin, require('./routes/invoices'));

// Central error handler: turns MySQL errors into readable messages
app.use((err, req, res, next) => {
  console.error(err.message);
  let message = err.message;
  if (err.code === 'ER_DUP_ENTRY') message = 'A record with this value already exists';
  else if (err.code === 'ER_ROW_IS_REFERENCED_2') message = 'Cannot delete: this record is used elsewhere';
  else if (err.code === 'ER_NO_REFERENCED_ROW_2') message = 'Linked record does not exist';
  else if (err.code === 'ER_CHECK_CONSTRAINT_VIOLATED' || err.errno === 4025 || err.errno === 3819)
    message = 'Invalid value: ' + (err.sqlMessage || err.message);
  else if (err.sqlState === '45000') message = err.sqlMessage; // messages from our triggers
  res.status(400).json({ error: message });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Cold Storage app running at http://localhost:${PORT}`));
