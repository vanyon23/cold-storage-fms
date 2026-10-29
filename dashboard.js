const router = require('express').Router();
const db = require('../config/db');

// GET /api/dashboard  -> summary numbers + reports built from the views
router.get('/', async (req, res) => {
  const [[totals]] = await db.query(`
    SELECT
      (SELECT COUNT(*) FROM customers)                                   AS customers,
      (SELECT COUNT(*) FROM stock_batches WHERE remaining_kg > 0)        AS active_batches,
      (SELECT COALESCE(SUM(remaining_kg),0) FROM stock_batches)          AS stored_kg,
      (SELECT COALESCE(SUM(capacity_kg),0) FROM chambers WHERE status='Active') AS capacity_kg,
      (SELECT COALESCE(SUM(amount),0) FROM invoices WHERE payment_status='Unpaid') AS pending_amount`);

  const [chambers] = await db.query('SELECT * FROM v_chamber_utilization ORDER BY chamber_id');
  const [expiring] = await db.query('SELECT * FROM v_expiring_stock ORDER BY days_to_expiry');
  const [alerts] = await db.query('SELECT * FROM v_temperature_alerts ORDER BY recorded_at DESC LIMIT 10');

  // Stock stored per food category (GROUP BY report)
  const [byCategory] = await db.query(`
    SELECT fc.category_name, SUM(b.remaining_kg) AS stored_kg
    FROM stock_batches b
    JOIN food_items i       ON i.item_id = b.item_id
    JOIN food_categories fc ON fc.category_id = i.category_id
    WHERE b.remaining_kg > 0
    GROUP BY fc.category_name
    ORDER BY stored_kg DESC`);

  res.json({ totals, chambers, expiring, alerts, byCategory });
});

module.exports = router;
