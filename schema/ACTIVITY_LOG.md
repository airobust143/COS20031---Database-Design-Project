# Activity Log — SmartFleet Database

This document describes the audit-trail feature added on top of the existing
schema, why it's built the way it is, and how to verify it. It was built
under one explicit constraint: **touch as few existing files as possible.**

## What it does

Every INSERT, UPDATE, and DELETE on all 34 business tables (everything
defined in `01_core_fleet_schema.sql` through `05_user_role_schema.sql`) is
recorded as a row in a new `AuditLog` table. Each row captures the table and
record affected, the action, a full before/after JSON snapshot of the row,
exactly which columns changed (for updates), and who made the change: the
app user and their role at the time, the raw MySQL login, the client IP, and
a `RequestID` that groups every row written during the same HTTP request.

Two tables are deliberately excluded: `login_attempts` (security
bookkeeping, not business data) and `AuditLog` itself.

## Files touched

Only one new file and two one-line-scale edits — nothing else in the
repository changed.

- `schema/09_activity_log.sql` (new) — the entire feature: the `AuditLog`
  table, a `sp_write_audit_log` procedure, and 100 triggers (three per
  table — `AFTER INSERT`/`UPDATE`/`DELETE` — except two composite-key
  junction tables with no non-key columns to update, which get two).
- `backend/api/_bootstrap.php` (edited, 6 lines added) — sets who's making
  the request before any query runs, so triggers can attribute changes to a
  real app user instead of just the shared database login.
- `schema/run_all.js` (edited, 1 line added) — appends the new filename to
  the automated setup script's file list.

Nothing else was touched: no existing trigger, procedure, view, or table
definition was modified, and no API endpoint files changed.

## Why triggers instead of application code

The database already does a lot of its own writing — closing a maintenance
job flips `Vehicles.OperationalStatus` and `PredictiveAlert.Status`, a
critical safety event can suspend a driver and insert a `CoachingRecord`,
using parts adjusts `Part.QuantityInStock`. None of that goes through the
API layer directly; it happens inside existing triggers in
`06_procedures_triggers.sql`. Logging at the database layer is the only way
to capture those writes too, not just the ones the API makes directly.
MySQL/MariaDB allow multiple `AFTER` triggers per table/event, so these new
triggers run alongside the existing business-rule triggers without touching
them.

## Why one file is enough

`smartfleet_rbac.sql` already creates a placeholder `AuditLog` table that
nothing ever writes to. Rather than editing that file to remove it,
`09_activity_log.sql` opens with `DROP TABLE IF EXISTS AuditLog` followed by
a richer `CREATE TABLE AuditLog`, and is registered to run *after*
`smartfleet_rbac.sql` in `run_all.js`. The new definition simply supersedes
the placeholder by virtue of running later — no edit to
`smartfleet_rbac.sql` required. If you ever run schema files by hand
instead of through `run_all.js`, just make sure `09_activity_log.sql` runs
last.

## How actor attribution works

The app connects to MySQL through one shared `root` connection rather than
per-user logins, so triggers can't rely on `CURRENT_USER()` alone to know
which app user made a change (it would always say `root@localhost`).
`_bootstrap.php` closes that gap: right after it confirms the session is
authenticated, it sets five MySQL session variables from `$_SESSION`:

```php
$pdo->prepare('SET @sf_actor_id = ?, @sf_actor_username = ?, @sf_actor_role = ?, @sf_client_ip = ?, @sf_request_id = UUID()')
    ->execute([...]);
```

`sp_write_audit_log` reads those variables on every call and stores them
alongside `CURRENT_USER()` (the raw DB login, always populated). If a write
happens outside the API — a seed script, phpMyAdmin, the `mysql` CLI — the
session variables are simply `NULL` and the row is still captured, just
attributed to `DbUser` alone.

`_bootstrap.php` is required by all six protected API endpoints (`driver.php`,
`fleet.php`, `fleet_filtered.php`, `mechanic.php`, `safety.php`,
`workshop.php`), so one edit covers all of them. `auth.php` does not include
`_bootstrap.php` (it has its own session handling for login/logout), so
writes it makes directly — failed-login bookkeeping, password rehashing on
login — are captured with `DbUser` only, not an app actor. This is a known,
accepted gap in exchange for not touching a seventh file; those writes are
still fully visible in the log, just without the actor columns filled in.

## Avoiding duplicated diff logic

Rather than hand-writing "did column X change" checks in a hundred
triggers, every trigger calls one shared procedure, `sp_write_audit_log`,
passing the full old/new row as JSON. The procedure walks the JSON keys
with `JSON_KEYS`/`JSON_EXTRACT` and a null-safe `<=>` comparison to build
the `ChangedFields` list itself. A no-op `UPDATE` (nothing actually
different) is silently skipped instead of writing an empty log row.

## Composite-key tables

Junction tables with a composite primary key store it as `"val1-val2"` in
`RecordPK` (e.g. `ActivityMechanic` → `"42-7"`). Two junction tables —
`WarrantyClaimPart` and `RolePermission` — have no columns beyond their
composite key, so there's nothing an `UPDATE` could ever change; those two
only get `INSERT`/`DELETE` triggers.

## Password handling

`UserAccount.PasswordHash` is never written to the log in cleartext or as
its bcrypt hash. `INSERT`/`DELETE` triggers always write the literal
`'***REDACTED***'`. The `UPDATE` trigger compares `OLD.PasswordHash` and
`NEW.PasswordHash` itself and writes `'***REDACTED-OLD***'` /
`'***REDACTED-NEW***'` only when they actually differ (both stay
`'***REDACTED***'` otherwise) — so a real password change still shows up in
`ChangedFields`, without the hash ever leaving the trigger.

## Setting it up

`node run_all.js <user> <password> <host>` already picks up
`09_activity_log.sql` automatically since it's now the last entry in the
`files` array. On an existing database, run the file by itself to add
auditing without touching anything else:

```
mysql -u root -p smart_fleet_management < schema/09_activity_log.sql
```

## Verifying it

After the schema is loaded, make any write through the app (e.g. edit a
vehicle) and check:

```sql
SELECT LogID, TableName, RecordPK, Action, ChangedFields,
       ActorUsername, ActorRole, DbUser, ClientIP, ChangedAt
FROM AuditLog
ORDER BY ChangedAt DESC
LIMIT 20;
```

To see every row written by one request (useful for cascading writes, e.g.
closing a `MaintenanceJobs` row that also touches `Vehicles` and
`PredictiveAlert`):

```sql
SELECT * FROM AuditLog WHERE RequestID = (
  SELECT RequestID FROM AuditLog ORDER BY ChangedAt DESC LIMIT 1
);
```

Full history of one record:

```sql
SELECT * FROM AuditLog
WHERE TableName = 'Vehicles' AND RecordPK = '12'
ORDER BY ChangedAt;
```

Everything one user has done:

```sql
SELECT * FROM AuditLog WHERE ActorUserID = 3 ORDER BY ChangedAt DESC;
```
