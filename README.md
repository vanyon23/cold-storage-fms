# ColdStore FMS — Cold Storage Food Management System

Full-stack DBMS project: **HTML/CSS/JS frontend + Node.js/Express backend + MySQL database**.

## Folder structure

```
cold-storage-fms/
│
├── frontend/                  ← what the user sees (served by the backend)
│   ├── login.html             login page
│   ├── index.html             main app (dashboard + 8 modules)
│   ├── css/style.css          all styling
│   └── js/app.js              all frontend logic (calls the API)
│
├── backend/                   ← Node.js + Express server (REST API)
│   ├── server.js              starts the server, serves frontend, error handling
│   ├── package.json           dependencies + "npm start"
│   ├── .env.example           database settings template → copy to .env
│   ├── config/db.js           MySQL connection pool
│   ├── middleware/auth.js     login check + admin-only check
│   └── routes/                one file per module
│       ├── auth.js            login / logout
│       ├── dashboard.js       summary + reports
│       ├── customers.js       customers CRUD
│       ├── categories.js      food categories CRUD
│       ├── items.js           food items CRUD
│       ├── chambers.js        cold chambers CRUD
│       ├── batches.js         stock in
│       ├── releases.js        stock out
│       ├── temperature.js     temperature logs
│       └── invoices.js        invoices (calls stored procedure)
│
├── database/                  ← MySQL
│   ├── schema.sql             9 tables, 3 triggers, 1 procedure, 4 views
│   └── seed.sql               sample data + login users
│
└── docs/                      ← for the report / viva
    ├── er-diagram.png / .svg
    └── screenshots/
```

## How to run (Mac / Windows)

**Needs:** Node.js LTS (nodejs.org) and MySQL 8 (dev.mysql.com/downloads/mysql) or XAMPP.

1. **Load the database** (run from the `cold-storage-fms` folder):
   ```
   mysql -u root -p < database/schema.sql
   mysql -u root -p < database/seed.sql
   ```
   (Or in MySQL Workbench: open each file → ⚡ Execute. In phpMyAdmin: Import tab.)

2. **Set your MySQL password:** in `backend/`, copy `.env.example` to `.env` and fill `DB_PASSWORD=`.

3. **Start the backend:**
   ```
   cd backend
   npm install
   npm start
   ```

4. Open **http://localhost:3000** → log in with **admin / admin123** (or staff / staff123).

Keep the terminal open while using the app. The frontend only works through `http://localhost:3000`, not by double-clicking the HTML files.

## DBMS concepts used
- 9 tables in 3NF with primary keys, foreign keys (RESTRICT / CASCADE / SET NULL), UNIQUE, CHECK, ENUM, DEFAULT
- **Triggers:** capacity check, temperature suitability, maintenance block, auto expiry date, over-release block, auto stock update
- **Stored procedure:** `sp_generate_invoice(batch_id)` — rent = qty × rate × days
- **Views:** chamber utilization, stock details, expiring stock, temperature alerts
- Joins, GROUP BY, aggregates, subqueries, indexes, parameterized queries, bcrypt passwords

## Troubleshooting
| Error | Fix |
|---|---|
| `command not found: node` / `npm` | Install Node.js, then reopen the terminal |
| `localhost refused to connect` | Backend isn't running — run `npm start` inside `backend/` |
| `ER_ACCESS_DENIED_ERROR` | Wrong password in `backend/.env` |
| `ER_BAD_DB_ERROR` | Run `database/schema.sql` first |
| `ECONNREFUSED 127.0.0.1:3306` | MySQL server isn't running — start it |
| `command not found: mysql` (Mac) | Use `/usr/local/mysql/bin/mysql -u root -p < ...` or MySQL Workbench |
