# COS20031 - Smart Fleet Management (Group 4)

A Smart Fleet Management web application with a Vite/TypeScript frontend, a PHP JSON API, and a MySQL database.

## Requirements

Install the following before running the project:

- [XAMPP](https://www.apachefriends.org/) with **Apache, PHP 8+, and MySQL/MariaDB**
- [Node.js](https://nodejs.org/) **20.19+ or 22.12+** (Node.js 22 LTS is recommended)
- npm (included with Node.js)
- A modern web browser

The PHP `pdo_mysql` extension must be enabled. It is enabled by default in a normal XAMPP installation.

## Recommended project location

Place or clone the **whole project folder** inside XAMPP's `htdocs` directory. Do not copy only `frontend` or `backend`.

On Windows, the recommended location is:

```text
C:\xampp\htdocs\COS20031---Database-Design-Project
```

For example:

```powershell
cd C:\xampp\htdocs
git clone <repository-url> COS20031---Database-Design-Project
cd COS20031---Database-Design-Project
```

The project may have a different folder name, but it must remain below `C:\xampp\htdocs` for the default Vite proxy configuration to find the PHP API automatically.

On Linux with XAMPP, use `/opt/lampp/htdocs/` instead. If XAMPP is installed elsewhere, see [Custom XAMPP or project location](#custom-xampp-or-project-location).

## First-time setup

### 1. Start XAMPP

Open the **XAMPP Control Panel**, then start:

- Apache
- MySQL

Both modules should show a green `Running` status. If either module cannot start, check whether another program is already using port 80 or 3306.

### 2. Create and seed the database

Open PowerShell or a terminal in the project folder:

```powershell
cd C:\xampp\htdocs\COS20031---Database-Design-Project\schema
npm install
node run_all.js root
```

This runs all SQL files in the required order and creates the `smart_fleet_management` database with sample data.

The default XAMPP MySQL account is usually user `root` with no password. If your account has a password, pass it as the second argument:

```powershell
node run_all.js root your_password
```

If a password or a different database account is used, update the matching values in `backend/config/database.php`:

```php
$dbHost = 'localhost';
$dbName = 'smart_fleet_management';
$dbUser = 'root';
$dbPass = '';
```

> The setup recreates database objects. Do not run it against a database containing data you need to keep.

### 3. Install and start the frontend

In a new terminal:

```powershell
cd C:\xampp\htdocs\COS20031---Database-Design-Project\frontend
npm install
npm run dev
```

Open [http://localhost:5173](http://localhost:5173) in your browser. Keep XAMPP's Apache and MySQL services running, and keep this terminal open while using the application.

For later runs, only start Apache and MySQL, then run:

```powershell
cd C:\xampp\htdocs\COS20031---Database-Design-Project\frontend
npm run dev
```

You do not need to rerun the database setup or `npm install` unless dependencies or schema files have changed.

## Default accounts

| Role | Username | Password |
|---|---|---|
| Fleet Admin | `fleet_admin` | `fleet_admin_pwd` |
| Safety Operations | `safety_lead` | `safety_lead_pwd` |
| Workshop Manager (North) | `workshop_north` | `workshop_north_pwd` |
| Workshop Manager (South) | `workshop_south` | `workshop_south_pwd` |
| Driver | `driver01` to `driver10` | `driver_pwd` |
| Mechanic | `mechanic01` to `mechanic10` | `mechanic_pwd` |

These accounts are for local development/demo use only.

## Custom XAMPP or project location

The easiest setup is to keep the repository under XAMPP's `htdocs`. If your Apache document root is somewhere else, tell Vite where it is before starting the frontend.

PowerShell example:

```powershell
cd path\to\project\frontend
$env:VITE_APACHE_DOCUMENT_ROOT = 'D:\my-xampp\htdocs'
npm run dev
```

The project must still be inside that document root.

Alternatively, run the backend with PHP's built-in development server. From the project root, use two terminals:

```powershell
# Terminal 1
C:\xampp\php\php.exe -S localhost:8000 -t backend
```

```powershell
# Terminal 2
cd frontend
$env:VITE_API_PROXY_TARGET = 'http://localhost:8000'
$env:VITE_API_PROXY_PATH = '/api'
npm run dev
```

MySQL must still be running in XAMPP. The environment variables above apply only to the current PowerShell window.

## Troubleshooting

- **`Database unavailable` or `Connection refused`:** start MySQL and verify the credentials in `backend/config/database.php`.
- **API requests return 404:** confirm the full project is inside `htdocs`, Apache is running, and you started Vite from the `frontend` directory.
- **Vite says the project is not below the Apache document root:** move the project into `C:\xampp\htdocs`, or set `VITE_APACHE_DOCUMENT_ROOT` as shown above.
- **`npm` or `node` is not recognized:** install a supported Node.js version, then reopen the terminal.
- **PowerShell says `npm.ps1` cannot be loaded because scripts are disabled:** run the same command with `npm.cmd` (for example, `npm.cmd run dev`) or use Command Prompt.
- **Port 5173 is already in use:** use the alternative URL printed by Vite, or stop the process using that port.
- **Apache or MySQL will not start:** use the XAMPP Control Panel logs to identify a port conflict.

## Project structure

```text
.
|-- backend/
|   |-- api/                  PHP JSON API endpoints
|   `-- config/database.php   Shared database connection settings
|-- frontend/                 Vite + TypeScript single-page application
|   `-- src/views/            Role-specific dashboards
`-- schema/                   Ordered SQL schema, seed files, and run_all.js
```

The frontend sends `/api` requests to Vite. During development, Vite proxies those requests to the PHP API served by Apache. PHP connects to the `smart_fleet_management` database through PDO.

## Production build check

To type-check the frontend and create an optimized build:

```powershell
cd frontend
npm run build
```

The generated files are placed in `frontend/dist/`. The documented `npm run dev` workflow is the recommended way to run this coursework project locally.
