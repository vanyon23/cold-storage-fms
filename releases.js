const router = require('express').Router();
const db = require('../config/db');

// GET /api/releases  (stock out history)
router.get('/', async (req, res) => {
  const [rows] = await db.query(
    `SELECT r.*, s.customer_name, s.item_name, s.chamber_name, u.full_name AS released_by
     FROM stock_releases r
     JOIN v_stock_details s ON s.batch_id = r.batch_id
     LEFT JOIN users u       ON u.user_id = r.created_by
     ORDER BY r.release_date DESC, r.release_id DESC`
  );
  res.json(rows);
});

// POST /api/releases  (stock out) — triggers validate and update the batch
router.post('/', async (req, res) => {
  const { batch_id, quantity_kg, release_date, released_to } = req.body;
  const [r] = await db.query(
    `INSERT INTO stock_releases (batch_id, quantity_kg, release_date, released_to, created_by)
     VALUES (?,?,?,?,?)`,
    [batch_id, quantity_kg, release_date, released_to || null, req.session.user.user_id]
  );
  res.status(201).json({ release_id: r.insertId });
});

module.exports = router;
