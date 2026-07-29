# Smart Fleet Management — Admin Console (PHP)

A PHP web GUI for the Smart Fleet Management database (COS20031). This first
version is a metadata-driven **admin-style CRUD console**: every table in the
schema gets a browse/search list, an add form, an edit form, and delete —
with foreign keys rendered as dropdowns and enum columns as select lists and
status badges. Role-based, stakeholder-specific views (Fleet Safety vs.
Workshop Management) are the natural next step, using the `UserAccount` /
`Role` / `Permission` tables already in the schema.

## What's included

```
fleetapp/
├── db/
│   ├── schema.sql      SQLite version of the physical schema (30 tables)
│   ├── seed.sql         Demo data drawn from the project brief's examples
│   └── fleet.sqlite      Pre-built demo database (schema + seed data)
├── includes/
│   ├── db.php            PDO connection (SQLite by default)
│   ├── tables.php         Table metadata: labels, column types, FKs, enums
│   ├── functions.php      Helper functions used by the CRUD engine
│   ├── layout_top.php     Shared header/sidebar nav
│   └── layout_bottom.php  Shared footer
├── assets/style.css       App styling
├── index.php               Dashboard (KPIs + links into every table)
├── list.php                 Generic browse/search view for any table
├── form.php                  Generic add/edit form for any table
└── delete.php                 Delete handler
```

## Running it

This demo uses **SQLite** so there's nothing to install or configure —
`db/fleet.sqlite` is a ready-to-use file-based database, already seeded.

1. Make sure you have PHP 8+ with the `pdo_sqlite` extension (bundled with
   most PHP installs; on Ubuntu/Debian: `sudo apt install php-cli php-sqlite3`).
2. From the `fleetapp` folder, run:
   ```
   php -S localhost:8000
   ```
3. Open `http://localhost:8000/index.php` in your browser.

That's it — no database server, no credentials, no extra setup.

## Switching to a real MySQL server

Since the underlying schema was designed for MySQL, moving to a live MySQL
server later is a small change, confined to one file:

1. Run the original `Database.sql` (the MySQL version you already have)
   against your MySQL server to create `smart_fleet_management`.
2. Edit `includes/db.php` and replace the SQLite connection with:
   ```php
   $pdo = new PDO(
       'mysql:host=localhost;dbname=smart_fleet_management;charset=utf8mb4',
       'your_username',
       'your_password'
   );
   ```
3. Everything else (list.php, form.php, delete.php, tables.php) works
   unchanged — they only use standard PDO/ANSI SQL and don't rely on any
   SQLite-specific syntax.

## How the CRUD engine works

Rather than hand-writing 30 separate list/add/edit pages, every table is
described once in `includes/tables.php`:

```php
'Vehicles' => [
    'label' => 'Vehicles', 'group' => 'Core Fleet', 'pk' => 'VehicleID',
    'columns' => [
        ['name' => 'RegistrationNumber', 'label' => 'Registration No.', 'type' => 'text', 'required' => true],
        ['name' => 'CategoryID', 'label' => 'Category', 'type' => 'fk', 'fk_table' => 'VehiclesCategory', 'fk_label' => 'CategoryName'],
        ['name' => 'OperationalStatus', 'label' => 'Status', 'type' => 'select', 'options' => [...]],
        // ...
    ],
],
```

`list.php` and `form.php` read this metadata to render the right widget for
each column (text input, number input, date picker, dropdown of foreign-key
options, enum dropdown, checkbox) and to build the SQL — so adding a new
column, or a whole new table, is a metadata edit rather than new PHP pages.

Composite-key junction tables (`ActivityMechanic`, `ActivityPart`,
`SupplyPart`, `WarrantyClaimPart`, `UserRole`, `RolePermission`) are
supported the same way — their two key columns are treated as fixed once a
row exists, and only the non-key columns (e.g. `LabourHours`) are editable.

## Notes / things worth knowing

- **Referential integrity is enforced.** Deleting a record that's still
  referenced elsewhere (e.g. a Depot with vehicles assigned to it) is
  blocked with a friendly message rather than a raw SQL error, matching the
  brief's requirement that historical records stay available.
- **Search** on the list view does a simple `LIKE` match across the table's
  text columns — good enough for a demo dataset, worth upgrading to
  full-text search or per-column filters as data volume grows.
- **Business-rule automation is not yet wired up** — e.g. the app doesn't
  currently *compute* monthly safety scores from `SafetyEvents`, or
  auto-block assigning a driver whose certifications are expired. Those
  values are editable directly for now; turning the brief's business rules
  (safety score penalties, certification checks, "critical event ⇒ driver
  inactive") into enforced logic is the natural next increment once the
  CRUD layer is confirmed to match the schema.
- Passwords in `UserAccount` are placeholder hashes for demo purposes only —
  there's no login/auth layer yet, by design, since this version is scoped
  to CRUD access to the schema.
