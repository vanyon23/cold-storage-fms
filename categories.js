const router = require('express').Router();
const db = require('../config/db');
const { requireAdmin } = require('../middleware/auth');

router.get('/', async (req, res) => {
  const [rows] = await db.query(
    `SELECT fc.*, COUNT(i.item_id) AS item_count
     FROM food_categories fc
     LEFT JOIN food_items i ON i.category_id = fc.category_id
     GROUP BY fc.category_id
     ORDER BY fc.category_name`
  );
  res.json(rows);
});

router.post('/', requireAdmin, async (req, res) => {
  const { category_name, min_temp, max_temp, max_storage_days } = req.body;
  const [r] = await db.query(
    'INSERT INTO food_categories (category_name, min_temp, max_temp, max_storage_days) VALUES (?,?,?,?)',
    [category_name, min_temp, max_temp, max_storage_days]
  );
  res.status(201).json({ category_id: r.insertId });
});

router.put('/:id', requireAdmin, async (req, res) => {
  const { category_name, min_temp, max_temp, max_storage_days } = req.body;
  await db.query(
    'UPDATE food_categories SET category_name=?, min_temp=?, max_temp=?, max_storage_days=? WHERE category_id=?',
    [category_name, min_temp, max_temp, max_storage_days, req.params.id]
  );
  res.json({ message: 'Category updated' });
});

router.delete('/:id', requireAdmin, async (req, res) => {
  await db.query('DELETE FROM food_categories WHERE category_id=?', [req.params.id]);
  res.json({ message: 'Category deleted' });
});

module.exports = router;
