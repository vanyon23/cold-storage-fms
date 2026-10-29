-- =====================================================================
--  Cold Storage Food Management System  —  Database Schema
--  Works on MySQL 8.x and MariaDB 10.4+ (XAMPP)
-- =====================================================================

DROP DATABASE IF EXISTS cold_storage_db;
CREATE DATABASE cold_storage_db CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE cold_storage_db;

-- ---------------------------------------------------------------------
-- 1. USERS : people who log in to the system (admin / staff)
-- ---------------------------------------------------------------------
CREATE TABLE users (
    user_id        INT AUTO_INCREMENT PRIMARY KEY,
    full_name      VARCHAR(100) NOT NULL,
    username       VARCHAR(50)  NOT NULL UNIQUE,
    password_hash  VARCHAR(255) NOT NULL,
    role           ENUM('admin','staff') NOT NULL DEFAULT 'staff',
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ---------------------------------------------------------------------
-- 2. CUSTOMERS : farmers / traders / businesses who store food with us
-- ---------------------------------------------------------------------
CREATE TABLE customers (
    customer_id    INT AUTO_INCREMENT PRIMARY KEY,
    name           VARCHAR(100) NOT NULL,
    customer_type  ENUM('Farmer','Trader','Retailer','Restaurant') NOT NULL DEFAULT 'Farmer',
    phone          VARCHAR(15)  NOT NULL UNIQUE,
    email          VARCHAR(100),
    address        VARCHAR(255),
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT chk_phone CHECK (CHAR_LENGTH(phone) >= 10)
);

-- ---------------------------------------------------------------------
-- 3. FOOD_CATEGORIES : storage rules for each kind of food
-- ---------------------------------------------------------------------
CREATE TABLE food_categories (
    category_id       INT AUTO_INCREMENT PRIMARY KEY,
    category_name     VARCHAR(50) NOT NULL UNIQUE,
    min_temp          DECIMAL(5,2) NOT NULL,          -- °C
    max_temp          DECIMAL(5,2) NOT NULL,          -- °C
    max_storage_days  INT NOT NULL,
    CONSTRAINT chk_cat_temp CHECK (min_temp <= max_temp),
    CONSTRAINT chk_cat_days CHECK (max_storage_days > 0)
);

-- ---------------------------------------------------------------------
-- 4. FOOD_ITEMS : individual products and their storage rent
-- ---------------------------------------------------------------------
CREATE TABLE food_items (
    item_id           INT AUTO_INCREMENT PRIMARY KEY,
    item_name         VARCHAR(100) NOT NULL UNIQUE,
    category_id       INT NOT NULL,
    rent_per_kg_day   DECIMAL(8,2) NOT NULL,          -- ₹ per kg per day
    CONSTRAINT fk_item_category FOREIGN KEY (category_id)
        REFERENCES food_categories(category_id) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT chk_rent CHECK (rent_per_kg_day > 0)
);

-- ---------------------------------------------------------------------
-- 5. CHAMBERS : physical cold rooms
-- ---------------------------------------------------------------------
CREATE TABLE chambers (
    chamber_id     INT AUTO_INCREMENT PRIMARY KEY,
    chamber_name   VARCHAR(50) NOT NULL UNIQUE,
    chamber_type   ENUM('Frozen','Chilled','Cool') NOT NULL,
    min_temp       DECIMAL(5,2) NOT NULL,
    max_temp       DECIMAL(5,2) NOT NULL,
    capacity_kg    DECIMAL(10,2) NOT NULL,
    status         ENUM('Active','Maintenance') NOT NULL DEFAULT 'Active',
    CONSTRAINT chk_ch_temp CHECK (min_temp <= max_temp),
    CONSTRAINT chk_capacity CHECK (capacity_kg > 0)
);

-- ---------------------------------------------------------------------
-- 6. STOCK_BATCHES : every inward lot of food (stock in)
-- ---------------------------------------------------------------------
CREATE TABLE stock_batches (
    batch_id       INT AUTO_INCREMENT PRIMARY KEY,
    customer_id    INT NOT NULL,
    item_id        INT NOT NULL,
    chamber_id     INT NOT NULL,
    quantity_kg    DECIMAL(10,2) NOT NULL,
    remaining_kg   DECIMAL(10,2) NOT NULL DEFAULT 0,
    entry_date     DATE NOT NULL,
    expiry_date    DATE,
    status         ENUM('Stored','Partially Released','Released') NOT NULL DEFAULT 'Stored',
    remarks        VARCHAR(255),
    created_by     INT,
    CONSTRAINT fk_batch_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id) ON DELETE RESTRICT,
    CONSTRAINT fk_batch_item     FOREIGN KEY (item_id)     REFERENCES food_items(item_id)    ON DELETE RESTRICT,
    CONSTRAINT fk_batch_chamber  FOREIGN KEY (chamber_id)  REFERENCES chambers(chamber_id)   ON DELETE RESTRICT,
    CONSTRAINT fk_batch_user     FOREIGN KEY (created_by)  REFERENCES users(user_id)         ON DELETE SET NULL,
    CONSTRAINT chk_qty       CHECK (quantity_kg > 0),
    CONSTRAINT chk_remaining CHECK (remaining_kg >= 0 AND remaining_kg <= quantity_kg)
);

-- ---------------------------------------------------------------------
-- 7. STOCK_RELEASES : food taken out of storage (stock out)
-- ---------------------------------------------------------------------
CREATE TABLE stock_releases (
    release_id     INT AUTO_INCREMENT PRIMARY KEY,
    batch_id       INT NOT NULL,
    quantity_kg    DECIMAL(10,2) NOT NULL,
    release_date   DATE NOT NULL,
    released_to    VARCHAR(100),
    created_by     INT,
    CONSTRAINT fk_rel_batch FOREIGN KEY (batch_id)   REFERENCES stock_batches(batch_id) ON DELETE CASCADE,
    CONSTRAINT fk_rel_user  FOREIGN KEY (created_by) REFERENCES users(user_id)          ON DELETE SET NULL,
    CONSTRAINT chk_rel_qty CHECK (quantity_kg > 0)
);

-- ---------------------------------------------------------------------
-- 8. TEMPERATURE_LOGS : periodic chamber readings
-- ---------------------------------------------------------------------
CREATE TABLE temperature_logs (
    log_id         INT AUTO_INCREMENT PRIMARY KEY,
    chamber_id     INT NOT NULL,
    temperature    DECIMAL(5,2) NOT NULL,
    humidity       DECIMAL(5,2),
    recorded_at    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    recorded_by    INT,
    CONSTRAINT fk_log_chamber FOREIGN KEY (chamber_id)  REFERENCES chambers(chamber_id) ON DELETE CASCADE,
    CONSTRAINT fk_log_user    FOREIGN KEY (recorded_by) REFERENCES users(user_id)       ON DELETE SET NULL,
    CONSTRAINT chk_humidity CHECK (humidity IS NULL OR (humidity BETWEEN 0 AND 100))
);

-- ---------------------------------------------------------------------
-- 9. INVOICES : storage rent bill for a batch (one invoice per batch)
-- ---------------------------------------------------------------------
CREATE TABLE invoices (
    invoice_id      INT AUTO_INCREMENT PRIMARY KEY,
    batch_id        INT NOT NULL UNIQUE,
    customer_id     INT NOT NULL,
    days_stored     INT NOT NULL,
    amount          DECIMAL(12,2) NOT NULL,
    invoice_date    DATE NOT NULL,
    payment_status  ENUM('Unpaid','Paid') NOT NULL DEFAULT 'Unpaid',
    CONSTRAINT fk_inv_batch    FOREIGN KEY (batch_id)    REFERENCES stock_batches(batch_id) ON DELETE CASCADE,
    CONSTRAINT fk_inv_customer FOREIGN KEY (customer_id) REFERENCES customers(customer_id)  ON DELETE RESTRICT
);

-- Helpful indexes for frequent lookups
CREATE INDEX idx_batch_status   ON stock_batches(status);
CREATE INDEX idx_batch_expiry   ON stock_batches(expiry_date);
CREATE INDEX idx_log_chamber_dt ON temperature_logs(chamber_id, recorded_at);

-- =====================================================================
--  TRIGGERS  (business rules enforced inside the database)
-- =====================================================================
DELIMITER $$

-- Before a new batch is stored:
--   * remaining_kg starts equal to quantity_kg
--   * expiry_date defaults to entry_date + category's max_storage_days
--   * chamber must be Active
--   * chamber temperature range must suit the food category
--   * chamber must have enough free capacity
CREATE TRIGGER trg_batch_before_insert
BEFORE INSERT ON stock_batches
FOR EACH ROW
BEGIN
    DECLARE v_capacity DECIMAL(10,2);
    DECLARE v_used     DECIMAL(10,2);
    DECLARE v_status   VARCHAR(20);
    DECLARE v_ch_min   DECIMAL(5,2);
    DECLARE v_ch_max   DECIMAL(5,2);
    DECLARE v_cat_min  DECIMAL(5,2);
    DECLARE v_cat_max  DECIMAL(5,2);
    DECLARE v_days     INT;

    SET NEW.remaining_kg = NEW.quantity_kg;
    SET NEW.status = 'Stored';

    SELECT capacity_kg, status, min_temp, max_temp
      INTO v_capacity, v_status, v_ch_min, v_ch_max
      FROM chambers WHERE chamber_id = NEW.chamber_id;

    SELECT c.min_temp, c.max_temp, c.max_storage_days
      INTO v_cat_min, v_cat_max, v_days
      FROM food_items i JOIN food_categories c ON c.category_id = i.category_id
     WHERE i.item_id = NEW.item_id;

    IF NEW.expiry_date IS NULL THEN
        SET NEW.expiry_date = DATE_ADD(NEW.entry_date, INTERVAL v_days DAY);
    END IF;

    IF NEW.expiry_date <= NEW.entry_date THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Expiry date must be after entry date';
    END IF;

    IF v_status <> 'Active' THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chamber is under maintenance';
    END IF;

    IF v_ch_min > v_cat_max OR v_ch_max < v_cat_min THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Chamber temperature is not suitable for this food category';
    END IF;

    SELECT COALESCE(SUM(remaining_kg), 0) INTO v_used
      FROM stock_batches WHERE chamber_id = NEW.chamber_id;

    IF v_used + NEW.quantity_kg > v_capacity THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Not enough free capacity in this chamber';
    END IF;
END$$

-- Before a release: cannot release more than what is left, or before entry
CREATE TRIGGER trg_release_before_insert
BEFORE INSERT ON stock_releases
FOR EACH ROW
BEGIN
    DECLARE v_remaining DECIMAL(10,2);
    DECLARE v_entry     DATE;

    SELECT remaining_kg, entry_date INTO v_remaining, v_entry
      FROM stock_batches WHERE batch_id = NEW.batch_id;

    IF NEW.quantity_kg > v_remaining THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Release quantity exceeds remaining stock';
    END IF;

    IF NEW.release_date < v_entry THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Release date cannot be before entry date';
    END IF;
END$$

-- After a release: reduce remaining stock and update the batch status
CREATE TRIGGER trg_release_after_insert
AFTER INSERT ON stock_releases
FOR EACH ROW
BEGIN
    UPDATE stock_batches
       SET remaining_kg = remaining_kg - NEW.quantity_kg
     WHERE batch_id = NEW.batch_id;

    UPDATE stock_batches
       SET status = IF(remaining_kg = 0, 'Released', 'Partially Released')
     WHERE batch_id = NEW.batch_id;
END$$

-- =====================================================================
--  STORED PROCEDURE : generate (or refresh) the rent invoice of a batch
--  amount = quantity_kg x rent_per_kg_day x days_stored
--  days_stored = entry date -> last release date (or today if still stored)
-- =====================================================================
CREATE PROCEDURE sp_generate_invoice(IN p_batch_id INT)
BEGIN
    DECLARE v_customer INT;
    DECLARE v_qty      DECIMAL(10,2);
    DECLARE v_rate     DECIMAL(8,2);
    DECLARE v_entry    DATE;
    DECLARE v_end      DATE;
    DECLARE v_status   VARCHAR(30);
    DECLARE v_days     INT;

    SELECT b.customer_id, b.quantity_kg, i.rent_per_kg_day, b.entry_date, b.status
      INTO v_customer, v_qty, v_rate, v_entry, v_status
      FROM stock_batches b JOIN food_items i ON i.item_id = b.item_id
     WHERE b.batch_id = p_batch_id;

    IF v_customer IS NULL THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Batch not found';
    END IF;

    IF v_status = 'Released' THEN
        SELECT MAX(release_date) INTO v_end FROM stock_releases WHERE batch_id = p_batch_id;
    ELSE
        SET v_end = CURDATE();
    END IF;

    SET v_days = GREATEST(DATEDIFF(v_end, v_entry), 1);

    INSERT INTO invoices (batch_id, customer_id, days_stored, amount, invoice_date)
    VALUES (p_batch_id, v_customer, v_days, ROUND(v_qty * v_rate * v_days, 2), CURDATE())
    ON DUPLICATE KEY UPDATE
        days_stored  = VALUES(days_stored),
        amount       = VALUES(amount),
        invoice_date = VALUES(invoice_date);
END$$

DELIMITER ;

-- =====================================================================
--  VIEWS  (ready-made reports used by the dashboard)
-- =====================================================================

-- Space used / free in every chamber
CREATE VIEW v_chamber_utilization AS
SELECT  ch.chamber_id,
        ch.chamber_name,
        ch.chamber_type,
        ch.min_temp,
        ch.max_temp,
        ch.capacity_kg,
        ch.status,
        COALESCE(SUM(b.remaining_kg), 0)                          AS used_kg,
        ch.capacity_kg - COALESCE(SUM(b.remaining_kg), 0)          AS free_kg,
        ROUND(COALESCE(SUM(b.remaining_kg), 0) * 100 / ch.capacity_kg, 1) AS utilization_pct
FROM chambers ch
LEFT JOIN stock_batches b ON b.chamber_id = ch.chamber_id AND b.remaining_kg > 0
GROUP BY ch.chamber_id, ch.chamber_name, ch.chamber_type, ch.min_temp, ch.max_temp,
         ch.capacity_kg, ch.status;

-- Full readable stock list
CREATE VIEW v_stock_details AS
SELECT  b.batch_id,
        cu.customer_id,
        cu.name            AS customer_name,
        i.item_name,
        fc.category_name,
        ch.chamber_name,
        b.quantity_kg,
        b.remaining_kg,
        b.entry_date,
        b.expiry_date,
        DATEDIFF(b.expiry_date, CURDATE()) AS days_to_expiry,
        b.status,
        b.remarks
FROM stock_batches b
JOIN customers       cu ON cu.customer_id = b.customer_id
JOIN food_items      i  ON i.item_id      = b.item_id
JOIN food_categories fc ON fc.category_id = i.category_id
JOIN chambers        ch ON ch.chamber_id  = b.chamber_id;

-- Stock still in storage that expires within 7 days (or already expired)
CREATE VIEW v_expiring_stock AS
SELECT * FROM v_stock_details
WHERE remaining_kg > 0 AND days_to_expiry <= 7;

-- Temperature readings outside the chamber's allowed range
CREATE VIEW v_temperature_alerts AS
SELECT  t.log_id,
        ch.chamber_name,
        ch.min_temp,
        ch.max_temp,
        t.temperature,
        t.humidity,
        t.recorded_at
FROM temperature_logs t
JOIN chambers ch ON ch.chamber_id = t.chamber_id
WHERE t.temperature < ch.min_temp OR t.temperature > ch.max_temp;
