const router = require('express').Router();
const db = require('../config/db');
const { requireAdmin } = require('../middleware/auth');

router.get('/', async (req, res) => {
  const [rows] = await db.query(
    `SELECT i.*, fc.category_name, fc.min_temp, fc.max_temp, fc.max_storage_days
     FROM food_items i
     JOIN food_categories fc ON fc.category_id = i.category_id
     ORDER BY i.item_name`
  );
  res.json(rows);
});

router.post('/', requireAdmin, async (req, res) => {
  const { item_name, category_id, rent_per_kg_day } = req.body;
  const [r] = await db.query(
    'INSERT INTO food_items (item_name, category_id, rent_per_kg_day) VALUES (?,?,?)',
    [item_name, category_id, rent_per_kg_day]
  );
  res.status(201).json({ item_id: r.insertId });
});

router.put('/:id', requireAdmin, async (req, res) => {
  const { item_name, category_id, rent_per_kg_day } = req.body;
  await db.query(
    'UPDATE food_items SET item_name=?, category_id=?, rent_per_kg_day=? WHERE item_id=?',
    [item_name, category_id, rent_per_kg_day, req.params.id]
  );
  res.json({ message: 'Item updated' });
});

router.delete('/:id', requireAdmin, async (req, res) => {
  await db.query('DELETE FROM food_items WHERE item_id=?', [req.params.id]);
  res.json({ message: 'Item deleted' });
});

module.exports = router;
