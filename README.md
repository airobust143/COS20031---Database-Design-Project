# COS20031 — Database Design Project (Group 4)

## Project Structure

```
.
├── backend/        PHP server-rendered app (CRUD admin console)
├── frontend/       React + Vite frontend (in development)
├── schema/         SQL schema and seed scripts
└── README.md
```

## Backend (PHP)

Requires PHP 8+ with `pdo_mysql`.

```bash
cd backend
php -S localhost:8000
```

Open http://localhost:8000/index.php

## Frontend (React + Vite)

Requires Node 18+.

```bash
cd frontend
npm install
npm run dev
```

Open http://localhost:5173

## Database Setup

Requires MySQL 8.

```powershell
cd schema
.\run_all.ps1 -MysqlPass your_password
```

This runs all schema and seed files in order against `smart_fleet_management`.
