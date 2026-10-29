-- =====================================================================
--  Sample data for Cold Storage Food Management System
--  Run AFTER schema.sql.  Dates are relative to today so the demo
--  always shows "expiring soon" stock and recent temperature readings.
-- =====================================================================
USE cold_storage_db;

-- Login accounts   (admin / admin123   and   staff / staff123)
INSERT INTO users (full_name, username, password_hash, role) VALUES
('System Administrator', 'admin', '$2b$10$EkhWAjOxb.QTw6R.i4a/WuCKRcMxwy0L1Pdhu.peqUAhsi6dhaRu6', 'admin'),
('Ravi Patil',           'staff', '$2b$10$wC1i7l7SUzHO9c/DPoVHlOKjp7vTlyDYTONb2zakgIsGWT2aLwRp6', 'staff');

INSERT INTO customers (name, customer_type, phone, email, address) VALUES
('Suresh Jadhav',          'Farmer',     '9822011001', 'suresh.jadhav@example.com', 'Manchar, Ambegaon, Pune'),
('Meena Kulkarni',         'Farmer',     '9822011002', NULL,                        'Junnar, Pune'),
('Sai Agro Traders',       'Trader',     '9822011003', 'sales@saiagro.example.com', 'Market Yard, Gultekdi, Pune'),
('Fresh Basket Mart',      'Retailer',   '9822011004', 'store@freshbasket.example.com', 'Kothrud, Pune'),
('Coastal Seafoods',       'Trader',     '9822011005', 'orders@coastal.example.com', 'Ratnagiri'),
('Spice Route Restaurant', 'Restaurant', '9822011006', 'kitchen@spiceroute.example.com', 'Baner, Pune'),
('Anil Shinde',            'Farmer',     '9822011007', NULL,                        'Narayangaon, Pune'),
('Gokul Dairy Products',   'Trader',     '9822011008', 'info@gokuldairy.example.com', 'Chakan MIDC, Pune');

INSERT INTO food_categories (category_name, min_temp, max_temp, max_storage_days) VALUES
('Frozen Meat',      -22.00, -15.00, 180),
('Seafood',          -25.00, -18.00, 120),
('Dairy',              2.00,   6.00,  21),
('Fruits',             0.00,   8.00,  45),
('Vegetables',         2.00,  10.00,  30),
('Tubers & Bulbs',     4.00,  12.00, 180),
('Frozen Desserts',  -25.00, -18.00, 240);

INSERT INTO food_items (item_name, category_id, rent_per_kg_day) VALUES
('Chicken',       1, 1.50),
('Mutton',        1, 1.80),
('Prawns',        2, 2.00),
('Pomfret Fish',  2, 1.90),
('Paneer',        3, 1.20),
('Butter',        3, 1.10),
('Apples',        4, 0.60),
('Grapes',        4, 0.80),
('Mangoes',       4, 0.90),
('Green Peas',    5, 0.70),
('Carrots',       5, 0.50),
('Potatoes',      6, 0.25),
('Onions',        6, 0.20),
('Ice Cream',     7, 2.20);

INSERT INTO chambers (chamber_name, chamber_type, min_temp, max_temp, capacity_kg, status) VALUES
('C-1 Deep Freeze A', 'Frozen',  -22.00, -18.00, 20000, 'Active'),
('C-2 Deep Freeze B', 'Frozen',  -25.00, -20.00, 15000, 'Active'),
('C-3 Chiller A',     'Chilled',   0.00,   4.00, 25000, 'Active'),
('C-4 Chiller B',     'Chilled',   2.00,   6.00, 10000, 'Active'),
('C-5 Cool Room',     'Cool',      6.00,  12.00, 40000, 'Active'),
('C-6 Chiller C',     'Chilled',   0.00,   4.00, 12000, 'Maintenance');

-- Stock in (expiry_date left NULL -> trigger fills it from the category rule)
INSERT INTO stock_batches (customer_id, item_id, chamber_id, quantity_kg, entry_date, expiry_date, remarks, created_by) VALUES
(3,  1, 1, 2500, DATE_SUB(CURDATE(), INTERVAL 40 DAY), NULL, 'Broiler stock, 50 cartons', 1),
(6,  2, 1,  600, DATE_SUB(CURDATE(), INTERVAL 25 DAY), NULL, NULL, 2),
(5,  3, 2, 1800, DATE_SUB(CURDATE(), INTERVAL 60 DAY), NULL, 'Export grade', 1),
(5,  4, 2, 1200, DATE_SUB(CURDATE(), INTERVAL 116 DAY), NULL, 'Old lot - clear first', 1),
(8,  5, 4,  900, DATE_SUB(CURDATE(), INTERVAL 17 DAY), NULL, NULL, 2),
(8,  6, 4,  750, DATE_SUB(CURDATE(), INTERVAL 10 DAY), NULL, NULL, 2),
(1,  7, 3, 8000, DATE_SUB(CURDATE(), INTERVAL 30 DAY), NULL, 'Shimla variety', 1),
(2,  8, 3, 3500, DATE_SUB(CURDATE(), INTERVAL 40 DAY), NULL, 'Thompson seedless', 2),
(4,  9, 3, 1500, DATE_SUB(CURDATE(), INTERVAL 12 DAY), NULL, NULL, 2),
(4, 10, 4, 1200, DATE_SUB(CURDATE(), INTERVAL 8 DAY),  NULL, NULL, 2),
(7, 12, 5, 15000, DATE_SUB(CURDATE(), INTERVAL 90 DAY), NULL, 'Bulk potato storage', 1),
(1, 13, 5, 9000, DATE_SUB(CURDATE(), INTERVAL 70 DAY), NULL, NULL, 1),
(6, 14, 2,  400, DATE_SUB(CURDATE(), INTERVAL 20 DAY), NULL, NULL, 2),
(7, 11, 5, 2000, DATE_SUB(CURDATE(), INTERVAL 15 DAY), NULL, NULL, 2);

-- Stock out (triggers reduce remaining_kg and set the status)
INSERT INTO stock_releases (batch_id, quantity_kg, release_date, released_to, created_by) VALUES
(1,   1000, DATE_SUB(CURDATE(), INTERVAL 20 DAY), 'Sai Agro Traders - Hadapsar outlet', 1),
(2,    600, DATE_SUB(CURDATE(), INTERVAL 5 DAY),  'Spice Route Restaurant', 2),
(7,   3000, DATE_SUB(CURDATE(), INTERVAL 10 DAY), 'Market Yard auction', 1),
(11,  6000, DATE_SUB(CURDATE(), INTERVAL 30 DAY), 'Chips factory, Chakan', 1),
(11,  4000, DATE_SUB(CURDATE(), INTERVAL 7 DAY),  'Market Yard auction', 2),
(10,  1200, DATE_SUB(CURDATE(), INTERVAL 2 DAY),  'Fresh Basket Mart', 2);

-- Temperature readings (two of them are out of range -> show as alerts)
INSERT INTO temperature_logs (chamber_id, temperature, humidity, recorded_at, recorded_by) VALUES
(1, -19.5, 70, NOW() - INTERVAL 2 DAY, 2),
(1, -20.1, 68, NOW() - INTERVAL 1 DAY, 2),
(1, -16.4, 72, NOW() - INTERVAL 3 HOUR, 2),
(2, -22.0, 65, NOW() - INTERVAL 1 DAY, 2),
(2, -21.4, 66, NOW() - INTERVAL 2 HOUR, 2),
(3,   2.1, 90, NOW() - INTERVAL 1 DAY, 2),
(3,   3.0, 88, NOW() - INTERVAL 4 HOUR, 2),
(4,   4.2, 85, NOW() - INTERVAL 1 DAY, 2),
(4,   7.3, 87, NOW() - INTERVAL 1 HOUR, 2),
(5,   9.0, 75, NOW() - INTERVAL 1 DAY, 2),
(5,   8.5, 74, NOW() - INTERVAL 5 HOUR, 2);

-- Invoices for fully released batches + one still in storage
CALL sp_generate_invoice(2);
CALL sp_generate_invoice(10);
CALL sp_generate_invoice(11);
CALL sp_generate_invoice(1);
UPDATE invoices SET payment_status = 'Paid' WHERE batch_id IN (2, 11);
