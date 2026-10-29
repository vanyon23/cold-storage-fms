const router = require('express').Router();
const bcrypt = require('bcryptjs');
const db = require('../config/db');

// POST /api/auth/login
router.post('/login', async (req, res) => {
  const { username, password } = req.body;
  const [rows] = await db.query('SELECT * FROM users WHERE username = ?', [username]);
  const user = rows[0];
  if (!user || !(await bcrypt.compare(password || '', user.password_hash))) {
    return res.status(401).json({ error: 'Invalid username or password' });
  }
  req.session.user = { user_id: user.user_id, full_name: user.full_name, role: user.role };
  res.json(req.session.user);
});

// GET /api/auth/me  -> who is logged in
router.get('/me', (req, res) => {
  if (!req.session.user) return res.status(401).json({ error: 'Not logged in' });
  res.json(req.session.user);
});

// POST /api/auth/logout
router.post('/logout', (req, res) => {
  req.session.destroy(() => res.json({ message: 'Logged out' }));
});

module.exports = router;
