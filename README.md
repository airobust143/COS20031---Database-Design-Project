# COS20031 — Smart Fleet Management (Group 4)

## Project Structure

```
.
├── backend/               PHP admin CRUD app
├── frontend/              Vite + TypeScript frontend
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
- **Node.js 20.19+ or 22.12+** (required by Vite 8.x for the frontend)
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

With XAMPP Apache (recommended), start XAMPP; the Vite development proxy
automatically derives the backend URL from the repository's location below
the Apache document root, including any intermediate subfolders.

```bash
sudo /opt/lampp/lampp start
```

The PHP admin app is then available at the repository's Apache path, for
example **http://localhost/web/COS20031---Database-Design-Project/backend/**.

To use PHP's development server instead, use XAMPP's PHP binary so the
`pdo_mysql` driver is available, then point the Vite proxy at port 8000:

```bash
cd backend
/opt/lampp/bin/php -S localhost:8000

# In a second terminal:
cd frontend
VITE_API_PROXY_TARGET=http://localhost:8000 VITE_API_PROXY_PATH=/api npm run dev
```

Requires PHP 8+ with the `pdo_mysql` extension enabled.

---

## Running the Frontend (Vite/TypeScript)

```bash
cd frontend
npm install        # first time only
npm run dev
```

Open **http://localhost:5173** in your browser.
