const router = require('express').Router();
const db = require('../config/db');
const { requireAdmin } = require('../middleware/auth');

// GET /api/customers?search=   (list with how much stock each customer has)
router.get('/', async (req, res) => {
  const search = `%${req.query.search || ''}%`;
  const [rows] = await db.query(
    `SELECT c.*,
            COUNT(b.batch_id)                AS total_batches,
            COALESCE(SUM(b.remaining_kg), 0) AS stored_kg
     FROM customers c
     LEFT JOIN stock_batches b ON b.customer_id = c.customer_id
     WHERE c.name LIKE ? OR c.phone LIKE ?
     GROUP BY c.customer_id
     ORDER BY c.name`,
    [search, search]
  );
  res.json(rows);
});

router.post('/', async (req, res) => {
  const { name, customer_type, phone, email, address } = req.body;
  const [r] = await db.query(
    'INSERT INTO customers (name, customer_type, phone, email, address) VALUES (?,?,?,?,?)',
    [name, customer_type, phone, email || null, address || null]
  );
  res.status(201).json({ customer_id: r.insertId });
});

router.put('/:id', async (req, res) => {
  const { name, customer_type, phone, email, address } = req.body;
  await db.query(
    'UPDATE customers SET name=?, customer_type=?, phone=?, email=?, address=? WHERE customer_id=?',
    [name, customer_type, phone, email || null, address || null, req.params.id]
  );
  res.json({ message: 'Customer updated' });
});

router.delete('/:id', requireAdmin, async (req, res) => {
  await db.query('DELETE FROM customers WHERE customer_id=?', [req.params.id]);
  res.json({ message: 'Customer deleted' });
});

module.exports = router;
