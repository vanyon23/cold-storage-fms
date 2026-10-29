const router = require('express').Router();
const db = require('../config/db');

router.get('/', async (req, res) => {
  const [rows] = await db.query(
    `SELECT inv.*, s.customer_name, s.item_name, s.quantity_kg, s.entry_date, s.status AS batch_status
     FROM invoices inv
     JOIN v_stock_details s ON s.batch_id = inv.batch_id
     ORDER BY inv.invoice_id DESC`
  );
  res.json(rows);
});

// POST /api/invoices/generate/:batchId  -> calls the stored procedure
router.post('/generate/:batchId', async (req, res) => {
  await db.query('CALL sp_generate_invoice(?)', [req.params.batchId]);
  const [[inv]] = await db.query('SELECT * FROM invoices WHERE batch_id=?', [req.params.batchId]);
  res.json(inv);
});

// PUT /api/invoices/:id/pay  -> mark as paid
router.put('/:id/pay', async (req, res) => {
  await db.query("UPDATE invoices SET payment_status='Paid' WHERE invoice_id=?", [req.params.id]);
  res.json({ message: 'Invoice marked as paid' });
});

module.exports = router;
