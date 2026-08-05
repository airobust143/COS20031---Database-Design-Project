# COS20031 — Smart Fleet Management (Group 4)

## Project Structure

```
.
├── backend/
│   ├── api/                  JSON REST API (used by TypeScript frontend)
│   │   ├── _bootstrap.php    Shared API setup (auth, DB, helpers)
│   │   ├── auth.php          Authentication endpoint
│   │   ├── driver.php        Driver dashboard API
│   │   ├── fleet.php         Fleet admin API (vehicles, depots, users, etc.)
│   │   ├── mechanic.php      Mechanic API
│   │   ├── safety.php        Safety operations API
│   │   └── workshop.php      Workshop manager API
│   └── config/
│       └── database.php      Shared database configuration (SINGLE SOURCE OF TRUTH)
│
├── frontend/                 Vite + TypeScript SPA
│   └── src/
│       ├── api.ts            API client for backend/api/*.php
│       ├── app.ts            Main application & routing
│       └── views/            Role-specific dashboards
│
├── schema/                   SQL schema, seed data, and setup scripts
│   ├── 01_core_fleet_schema.sql
│   ├── 02_driver_safety_schema.sql
│   ├── 03_workshops_people_schema.sql
│   ├── 04_maintenance_schema.sql
│   ├── 05_user_role_schema.sql
│   ├── 06_procedures_triggers.sql
│   ├── smartfleet_rbac.sql
│   ├── smartfleet_seed_quick_data.sql
│   └── run_all.js            ← recommended (Node.js)
│
└── smartfleet_sample_csv/    Sample CSV data for manual import
```

---

## Prerequisites

- **MySQL 8.0+** running on localhost
- **Node.js 20.19+ or 22.12+** (required by Vite 8.x for the frontend)
- **PHP 8.0+** with `pdo_mysql` (for the backend app)

---

## Architecture

### Modern API-Based Architecture
The application uses a clean API-based architecture with complete separation between frontend and backend:

```
Frontend (Vite/TypeScript SPA)
    ↓ fetch() calls to /api/*
Backend JSON APIs (backend/api/*.php)
    ↓ PDO via backend/config/database.php
MySQL Database
```

**Features:**
- 5 role-specific dashboards (Driver, Mechanic, Safety Ops, Workshop Manager, Fleet Admin)
- Real-time data updates via API
- Modern UI with navigation-based routing
- User account management (Fleet Admin can create/delete users)
- Single database configuration file
- CORS-enabled for local development

**Access:** `http://localhost:5173` (Vite dev server)

**Key Capabilities:**
- ✅ User authentication via API
- ✅ Role-based permissions
- ✅ Full CRUD operations for all entities
- ✅ User account creation with role assignment
- ✅ Real-time validation and error handling
- ✅ Transaction-based operations for data integrity

**See also:** 
- `DATABASE_CONFIG.md` - Database configuration guide
- `MIGRATION_COMPLETE.md` - Complete migration summary
- Dashboard navigation docs (DRIVER_DASHBOARD_STRUCTURE.md, FLEET_ADMIN_NAVIGATION.md, etc.)

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

---

## Running the Application

### Frontend (Primary Application) — TypeScript SPA

```bash
cd frontend
npm install        # first time only
npm run dev
```

Open **http://localhost:5173** in your browser.

**Default users:**
- `fleet_admin` / `fleet_admin_pwd` - Fleet Admin (full access)
- `safety_lead` / `safety_lead_pwd` - Safety Operations
- `workshop_north` / `workshop_north_pwd` - Workshop Manager (Northern Branch)
- `workshop_south` / `workshop_south_pwd` - Workshop Manager (Southern Branch)
- `mechanic_lead` / `mechanic_lead_pwd` - Mechanic

### Backend API (Auto-loaded by Frontend)

The frontend automatically proxies API requests to the PHP backend running on XAMPP.

**With XAMPP (recommended):**
```bash
sudo /opt/lampp/lampp start
```

**With PHP built-in server (alternative):**
```bash
cd backend
/opt/lampp/bin/php -S localhost:8000
D:\xampp\php\php.exe
# In a second terminal:
cd frontend
VITE_API_PROXY_TARGET=http://localhost:8000 VITE_API_PROXY_PATH=/api npm run dev
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
