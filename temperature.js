const router = require('express').Router();
const db = require('../config/db');

// GET /api/temperature?chamber_id=   (readings, flagged if out of range)
router.get('/', async (req, res) => {
  const params = [];
  let sql = `
    SELECT t.*, ch.chamber_name, ch.min_temp, ch.max_temp,
           (t.temperature < ch.min_temp OR t.temperature > ch.max_temp) AS is_alert
    FROM temperature_logs t
    JOIN chambers ch ON ch.chamber_id = t.chamber_id`;
  if (req.query.chamber_id) {
    sql += ' WHERE t.chamber_id = ?';
    params.push(req.query.chamber_id);
  }
  sql += ' ORDER BY t.recorded_at DESC LIMIT 100';
  const [rows] = await db.query(sql, params);
  res.json(rows);
});

router.post('/', async (req, res) => {
  const { chamber_id, temperature, humidity } = req.body;
  const [r] = await db.query(
    'INSERT INTO temperature_logs (chamber_id, temperature, humidity, recorded_by) VALUES (?,?,?,?)',
    [chamber_id, temperature, humidity === '' ? null : humidity, req.session.user.user_id]
  );
  res.status(201).json({ log_id: r.insertId });
});

module.exports = router;
