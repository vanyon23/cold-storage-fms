const router = require('express').Router();
const db = require('../config/db');
const { requireAdmin } = require('../middleware/auth');

// List chambers with used / free space (from the utilization view)
router.get('/', async (req, res) => {
  const [rows] = await db.query('SELECT * FROM v_chamber_utilization ORDER BY chamber_id');
  res.json(rows);
});

router.post('/', requireAdmin, async (req, res) => {
  const { chamber_name, chamber_type, min_temp, max_temp, capacity_kg, status } = req.body;
  const [r] = await db.query(
    `INSERT INTO chambers (chamber_name, chamber_type, min_temp, max_temp, capacity_kg, status)
     VALUES (?,?,?,?,?,?)`,
    [chamber_name, chamber_type, min_temp, max_temp, capacity_kg, status || 'Active']
  );
  res.status(201).json({ chamber_id: r.insertId });
});

router.put('/:id', requireAdmin, async (req, res) => {
  const { chamber_name, chamber_type, min_temp, max_temp, capacity_kg, status } = req.body;
  await db.query(
    `UPDATE chambers SET chamber_name=?, chamber_type=?, min_temp=?, max_temp=?, capacity_kg=?, status=?
     WHERE chamber_id=?`,
    [chamber_name, chamber_type, min_temp, max_temp, capacity_kg, status, req.params.id]
  );
  res.json({ message: 'Chamber updated' });
});

router.delete('/:id', requireAdmin, async (req, res) => {
  await db.query('DELETE FROM chambers WHERE chamber_id=?', [req.params.id]);
  res.json({ message: 'Chamber deleted' });
});

module.exports = router;
