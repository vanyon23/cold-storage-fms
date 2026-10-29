const router = require('express').Router();
const db = require('../config/db');
const { requireAdmin } = require('../middleware/auth');

// GET /api/batches?status=&search=   (stock list, from the v_stock_details view)
router.get('/', async (req, res) => {
  const params = [];
  let sql = 'SELECT * FROM v_stock_details WHERE 1=1';
  if (req.query.status) {
    sql += ' AND status = ?';
    params.push(req.query.status);
  }
  if (req.query.search) {
    sql += ' AND (customer_name LIKE ? OR item_name LIKE ? OR chamber_name LIKE ?)';
    const s = `%${req.query.search}%`;
    params.push(s, s, s);
  }
  sql += ' ORDER BY batch_id DESC';
  const [rows] = await db.query(sql, params);
  res.json(rows);
});

// POST /api/batches  (stock in) — the trigger checks capacity, temperature and maintenance
router.post('/', async (req, res) => {
  const { customer_id, item_id, chamber_id, quantity_kg, entry_date, expiry_date, remarks } = req.body;
  const [r] = await db.query(
    `INSERT INTO stock_batches
       (customer_id, item_id, chamber_id, quantity_kg, entry_date, expiry_date, remarks, created_by)
     VALUES (?,?,?,?,?,?,?,?)`,
    [customer_id, item_id, chamber_id, quantity_kg, entry_date, expiry_date || null,
     remarks || null, req.session.user.user_id]
  );
  res.status(201).json({ batch_id: r.insertId });
});

// Release history of one batch
router.get('/:id/releases', async (req, res) => {
  const [rows] = await db.query(
    'SELECT * FROM stock_releases WHERE batch_id=? ORDER BY release_date', [req.params.id]);
  res.json(rows);
});

router.delete('/:id', requireAdmin, async (req, res) => {
  await db.query('DELETE FROM stock_batches WHERE batch_id=?', [req.params.id]);
  res.json({ message: 'Batch deleted' });
});

module.exports = router;
