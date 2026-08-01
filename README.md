# COS20031 — Smart Fleet Management (Group 4)

## Project Structure

```
.
├── backend/               PHP admin CRUD app
├── frontend/              React + Vite frontend
├── schema/                SQL schema, seed data, and setup scripts
│   ├── 01_core_fleet_schema.sql
│   ├── 02_driver_safety_schema.sql
│   ├── 03_workshops_people_schema.sql
│   ├── 04_maintenance_schema.sql
│   ├── 05_user_role_schema.sql
│   ├── 06_seed_reference_data.sql
│   ├── smartfleet_rbac.sql
│   └── run_all.js         ← recommended (Node.js)
│   
└── smartfleet_sample_csv/ Sample CSV data
```

---

## Prerequisites

- **MySQL 8.0+** running on localhost
- **Node.js 18+** (for `run_all.js`)
- **PHP 8.0+** with `pdo_mysql` (for the backend app)

---

## Database Setup

The scripts run all schema and seed files in order and create the
`smart_fleet_management` database from scratch.

### Node.js (recommended, works on any OS)

```bash
cd schema
npm install        # first time only — installs mysql2
node run_all.js <user> <password>
```

**Examples:**
```bash
node run_all.js root ha431
node run_all.js root                      # no password
node run_all.js root ha431 192.168.1.10   # custom host
```


## Running the Backend (PHP)

```bash
cd backend
php -S localhost:8000
```

Open **http://localhost:8000/index.php** in your browser.

Requires PHP 8+ with the `pdo_mysql` extension enabled.

---

## Running the Frontend (React)

```bash
cd frontend
npm install        # first time only
npm run dev
```

Open **http://localhost:5173** in your browser.
