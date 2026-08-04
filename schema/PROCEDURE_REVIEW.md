# Stored Procedure Review and Web Implementation Guide

## Overview

`06_procedures_triggers.sql` defines 30 stored procedures:

- 3 business-rule procedures used by triggers or write operations.
- 27 query procedures intended for dashboards, searches, profiles, and role-specific pages.

The web application must authenticate the user and enforce permissions before
calling a procedure. Procedure parameters must come from validated server-side
values. A driver or mechanic must never be allowed to submit another person's ID
for a self-service procedure; use `DriverID` or `MechanicID` from the authenticated
session.

## PHP/PDO implementation pattern

Single-result procedures can be called from a PHP API endpoint as follows:

```php
$stmt = $pdo->prepare('CALL sp_search_vehicles(:status, :category, :depot, :search, :driver)');
$stmt->execute([
    ':status' => $status,
    ':category' => $categoryId,
    ':depot' => $depotId,
    ':search' => $searchTerm,
    ':driver' => $driverId,
]);
$rows = $stmt->fetchAll(PDO::FETCH_ASSOC);
$stmt->closeCursor();

echo json_encode(['data' => $rows]);
```

Profile/detail procedures return multiple result sets. Read every result set in
the documented order:

```php
$stmt = $pdo->prepare('CALL sp_get_vehicle_profile(:vehicle_id)');
$stmt->execute([':vehicle_id' => $vehicleId]);

$resultSets = [];
do {
    if ($stmt->columnCount() > 0) {
        $resultSets[] = $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
} while ($stmt->nextRowset());
$stmt->closeCursor();
```

Always call `closeCursor()` after a MySQL procedure call so the same PDO
connection can execute another statement.

## Business-rule procedures

These procedures enforce data integrity. They should not normally be exposed as
unrestricted public API endpoints.

### 1. `sp_check_vehicle_assignment_eligibility`

- Inputs: `p_vehicle_id`, `p_driver_id`.
- Purpose: verifies that the vehicle exists and is assignable, that the driver is
  active with a valid licence and certifications, and that the safety rules allow
  the assignment. It raises a SQL error when a rule fails.
- Database use: called by the vehicle-assignment insert and update triggers.
- Web functionality: the Fleet Admin "Assign driver" form submits an assignment
  through a transaction. The trigger calls this procedure automatically. Return
  its SQL error as a validation response such as HTTP 422. A preflight endpoint
  may call it to give early feedback, but the trigger remains authoritative.

### 2. `sp_recalc_driver_safety_score`

- Inputs: `p_driver_id`, `p_period` in `YYYY-MM` format.
- Purpose: counts the driver's monthly safety events, calculates deductions, and
  inserts or updates the corresponding `DriverSafetyScore` row.
- Database use: called automatically after safety-event insert, update, or delete.
- Web functionality: when Safety Operations records or edits an event, the API
  writes the event and then reads the refreshed score for the response. Do not
  let the browser submit calculated points or scores. An administrator-only
  repair action may call this procedure for a selected driver and month.

### 3. `sp_check_mechanic_certified`

- Inputs: `p_mechanic_id`, `p_activity_id`.
- Purpose: verifies that the mechanic and activity exist and that the mechanic
  holds a currently valid certification required by the activity type.
- Database use: called by `ActivityMechanic` insert and update triggers.
- Web functionality: the Workshop Manager's "Assign mechanic" dialog writes the
  assignment normally. Convert a certification failure into an HTTP 422 response
  and display it beside the mechanic selector. The UI may filter eligible
  mechanics, but the trigger is the final integrity check.

## Fleet Admin procedures

### 4. `sp_search_vehicles`

- Inputs: status, category ID, depot ID, search term, assigned-driver ID; use
  `NULL` for filters that are not selected.
- Purpose: returns vehicles with model, category, depot, and current-driver data.
- Web functionality: `GET /api/fleet.php?action=vehicles` for a searchable vehicle
  table. Map query-string filters to procedure parameters and render the result in
  the fleet list with links to each vehicle profile.

### 5. `sp_get_vehicle_profile`

- Input: `p_vehicle_id`.
- Purpose: returns four result sets: basic vehicle information, current
  assignment, maintenance summary, and five recent maintenance jobs.
- Web functionality: `GET /api/fleet.php?action=vehicle-profile&id=...`. Present
  the result sets as the profile header, assignment card, maintenance KPI cards,
  and recent-jobs table.

### 6. `sp_list_available_vehicles`

- Inputs: depot ID and category ID; either may be `NULL`.
- Purpose: lists active/available vehicles that do not have a current assignment.
- Web functionality: populate the vehicle selector in the assignment form. Reload
  the list when depot or category changes and disable submission if the selected
  vehicle is no longer returned.

### 7. `sp_vehicle_assignment_history`

- Inputs: vehicle ID, driver ID, result limit. Vehicle or driver may be `NULL` to
  select the other dimension.
- Purpose: returns historical and current assignment periods with vehicle,
  driver, and depot details.
- Web functionality: `GET /api/fleet.php?action=assignment-history`. Use it for
  the vehicle timeline, driver history, and assignment audit modal. Cap and
  validate the requested limit on the server.

### 8. `sp_vehicles_due_maintenance`

- Inputs: odometer threshold and days since last service.
- Purpose: identifies non-retired vehicles that exceed the configured distance or
  time maintenance thresholds.
- Web functionality: maintenance-due dashboard and reminder badge. Allow Fleet
  Admin to choose approved threshold presets, then link a result to the "Create
  maintenance job" workflow.

### 9. `sp_fleet_summary_counts`

- No inputs.
- Purpose: returns dashboard aggregates for vehicle status, vehicle category,
  driver status, and maintenance-job status.
- Web functionality: `GET /api/fleet.php?action=summary`. Map its result to KPI
  cards and charts on the Fleet Admin dashboard. Cache briefly if dashboard
  traffic becomes high.

### 10. `sp_list_users_by_role`

- Input: `p_role_name`; `NULL` can represent all roles if supported by the query.
- Purpose: lists user accounts and their associated role and identity information.
- Web functionality: user-management table with role filtering. Restrict the
  endpoint to account administrators and never return password hashes.

### 11. `sp_get_user_permissions`

- Input: `p_user_id`.
- Purpose: returns the user's effective table/action permissions through assigned
  roles.
- Web functionality: call after successful login and cache the permission set in
  `$_SESSION`. The frontend may use it to hide unavailable controls, while every
  API endpoint must still enforce the permission server-side.

## Authentication and authorization procedure

### 12. `sp_check_user_permission`

- Inputs: user ID, table name, and action such as `SELECT`, `INSERT`, `UPDATE`, or
  `DELETE`.
- Purpose: returns whether a user has a requested permission.
- Web functionality: use in authorization middleware when a fresh database check
  is required. Most requests can use the permission set cached at login by
  `sp_get_user_permissions`. Never accept the user ID from the request body; use
  the authenticated session.

## Safety Operations procedures

### 13. `sp_search_drivers`

- Inputs: search term, employment status, minimum score, maximum score, and depot
  ID; optional filters use `NULL`.
- Purpose: returns driver identity, depot, licence status, latest safety score,
  suspension/coaching flags, and current vehicle.
- Web functionality: Safety Operations driver directory with search controls,
  score range filters, warning badges, and links to a driver profile.

### 14. `sp_get_driver_profile`

- Input: `p_driver_id` selected by an authorized Safety Operations user.
- Purpose: returns seven result sets: basic driver information, current score,
  twenty recent safety events, coaching history, certifications, current vehicle,
  and twelve-month score history.
- Web functionality: oversight profile page with separate tabs/cards. This is an
  administrative view of any driver and must require permission to read driver
  safety information.

### 15. `sp_list_suspended_drivers`

- No inputs.
- Purpose: returns suspended/inactive drivers, current scores, recent critical
  event information, pending coaching counts, and suspension reason.
- Web functionality: high-priority suspension queue. Use status badges and actions
  for opening the profile, scheduling coaching, or starting an authorized status
  review; do not automatically reactivate a driver from the list page.

### 16. `sp_list_predictive_alerts`

- Inputs: severity, status, and vehicle ID; optional filters use `NULL`.
- Purpose: lists unresolved predictive alerts with vehicle, depot, linked-job, and
  age information.
- Web functionality: alert inbox with severity/status filters. Actions can
  acknowledge an alert or create/link a maintenance job. Refresh after each write
  because maintenance triggers synchronize alert status.

### 17. `sp_drivers_requiring_coaching`

- No inputs.
- Purpose: returns drivers requiring intervention, including current safety data,
  pending/completed coaching counts, and the reason coaching is required.
- Web functionality: coaching queue and notification count. Provide a "Schedule
  coaching" action that creates a `CoachingRecord`, followed by refreshing this
  procedure's result.

## Workshop Manager procedures

### 18. `sp_search_maintenance_jobs`

- Inputs: status, vehicle ID, workshop ID, mechanic ID, start date, and end date.
- Purpose: searches jobs and returns vehicle/workshop/alert data plus activity,
  mechanic, labour, cost, and calculated job-status information.
- Web functionality: maintenance-job table with combined filters. Use ISO dates,
  validate that the start date is not after the end date, and link each result to
  the detailed job page.

### 19. `sp_get_job_detail`

- Input: `p_job_id`.
- Purpose: returns five result sets: job header, activities, parts used, assigned
  mechanics, and warranty claims.
- Web functionality: Workshop Manager job workspace. Render the result sets as
  summary, activity checklist, parts ledger, staffing, and warranty tabs. Refresh
  the relevant result sets after editing an activity, part, or mechanic.

### 20. `sp_list_open_jobs`

- Input: workshop ID; `NULL` selects all workshops an authorized user may view.
- Purpose: returns open jobs with progress counts, assigned mechanics, labour,
  age, and timeliness status.
- Web functionality: workshop operations board. Group or color rows as open, in
  progress, at risk, and overdue. Depot/workshop-scoped users must have their
  permitted workshop enforced by the backend rather than trusting a query value.

### 21. `sp_low_stock_parts`

- No inputs.
- Purpose: lists parts at or below their reorder thresholds, primary supplier,
  estimated reorder cost, and recent usage.
- Web functionality: inventory reorder queue. Provide links to the supplier and a
  purchase-order workflow; the procedure itself is read-only and does not order
  stock.

### 22. `sp_list_mechanics_workload`

- Input: workshop ID; optional for users allowed to view multiple workshops.
- Purpose: returns mechanics, valid certifications, active workload, recent and
  lifetime statistics, and an availability label.
- Web functionality: mechanic allocation board and assignment selector. Display
  certification and workload context, but still rely on the certification trigger
  when an assignment is submitted.

### 23. `sp_workshop_summary`

- Input: `p_workshop_id`.
- Purpose: returns workshop details and aggregated job, activity, mechanic,
  revenue/cost, downtime, and performance information.
- Web functionality: Workshop Manager dashboard with KPI cards and workload or
  completion charts. Enforce workshop scope from the authenticated account.

## Mechanic self-service procedures

### 24. `sp_get_mechanic_assigned_jobs`

- Inputs: mechanic ID and `p_include_completed` boolean.
- Purpose: returns the mechanic's assigned activities and their jobs, vehicles,
  status, alert context, labour hours, and other mechanics on the activity.
- Web functionality: "My Jobs" page. Obtain mechanic ID from the session and use
  the boolean for active/all tabs. Do not accept an arbitrary mechanic ID from the
  browser.

### 25. `sp_get_mechanic_job_detail`

- Inputs: mechanic ID and job ID.
- Purpose: verifies the mechanic is assigned to the job and then returns job
  header, the mechanic's activities, parts used in those activities, and other
  assigned mechanics. It raises an error when access is invalid.
- Web functionality: mechanic job workspace. Translate the access error to HTTP
  403 or 404, and only expose update actions for activities assigned to the
  authenticated mechanic.

### 26. `sp_search_parts`

- Inputs: search term, minimum stock, and available-only boolean.
- Purpose: searches inventory and returns stock state, primary supplier, cost,
  lead time, and recent usage.
- Web functionality: part picker when logging activity consumption and a general
  inventory search. Debounce browser searches and validate available quantity
  again during the write because stock may change concurrently.

### 27. `sp_get_mechanic_workload_summary`

- Input: mechanic ID from the authenticated session.
- Purpose: returns current workload totals, thirty-day performance, and
  certification/expiry information.
- Web functionality: mechanic home dashboard with active-job cards, recent
  performance metrics, and certification-expiry warnings.

## Driver self-service procedures

### 28. `sp_get_driver_own_vehicle`

- Input: driver ID from the authenticated session.
- Purpose: returns the driver's current vehicle, depot, category, assignment,
  certification requirements, maintenance status, and recent maintenance data.
- Web functionality: "My Vehicle" page. Never accept a driver ID from the URL;
  derive it from the logged-in `UserAccount`.

### 29. `sp_get_driver_complete_profile`

- Input: driver ID from the authenticated session.
- Purpose: returns nine result sets: basic details, current vehicle, current
  safety score, recent events, coaching history, certifications, twelve-month
  score history, assignment history, and summary statistics.
- Web functionality: driver profile portal with personal information, vehicle,
  safety, coaching, certification, and history sections. The backend must bind the
  session's driver ID to preserve row-level privacy.

### 30. `sp_get_driver_safety_summary`

- Input: driver ID from the authenticated session.
- Purpose: returns a compact safety dashboard containing latest score, recent
  event counts, coaching state, certification state, performance level, and the
  highest-priority warning.
- Web functionality: driver home-page safety card. Use the warning field for an
  alert banner and link to the appropriate section of the complete profile.

## Endpoint design summary

| Role | Suggested endpoint group | Procedures |
|---|---|---|
| Fleet Admin | `/api/fleet.php` | `sp_search_vehicles`, `sp_get_vehicle_profile`, `sp_list_available_vehicles`, `sp_vehicle_assignment_history`, `sp_vehicles_due_maintenance`, `sp_fleet_summary_counts` |
| Account Admin/Auth | `/api/auth.php` or an admin-user endpoint | `sp_list_users_by_role`, `sp_get_user_permissions`, `sp_check_user_permission` |
| Safety Operations | a safety API endpoint | `sp_search_drivers`, `sp_get_driver_profile`, `sp_list_suspended_drivers`, `sp_list_predictive_alerts`, `sp_drivers_requiring_coaching` |
| Workshop Manager | `/api/workshop.php` | `sp_search_maintenance_jobs`, `sp_get_job_detail`, `sp_list_open_jobs`, `sp_low_stock_parts`, `sp_list_mechanics_workload`, `sp_workshop_summary` |
| Mechanic | `/api/mechanic.php` | `sp_get_mechanic_assigned_jobs`, `sp_get_mechanic_job_detail`, `sp_search_parts`, `sp_get_mechanic_workload_summary` |
| Driver | `/api/driver.php` | `sp_get_driver_own_vehicle`, `sp_get_driver_complete_profile`, `sp_get_driver_safety_summary` |

## Error and security handling

- Use prepared `CALL` statements; never concatenate request values into SQL.
- Validate IDs as positive integers, dates as ISO `YYYY-MM-DD`, safety periods as
  `YYYY-MM`, booleans explicitly, and list limits against a safe maximum.
- Use `NULL` for optional filters instead of empty strings.
- Convert business-rule `SQLSTATE 45000` errors into clear HTTP 422 responses.
- Return HTTP 403 for permission or self-service ownership failures.
- Do not expose raw database error messages or SQL text in production responses.
- Wrap related writes in transactions. Triggers and their procedure calls execute
  in the same transaction as the originating write.
- Treat frontend permission checks as presentation only; authorization belongs in
  PHP middleware.
- Test multi-result procedures carefully because changing result-set order is an
  API contract change.

## Similar driver-profile procedures

`sp_get_driver_profile` and `sp_get_driver_complete_profile` intentionally serve
different security contexts. Safety Operations can inspect an authorized driver,
whereas the driver version is self-service and must use the session identity.
Keeping separate procedures makes this boundary clearer even though some result
sets overlap.

## Deployment checklist

- Run schema files 01-08 and `smartfleet_rbac.sql` in the documented order.
- Replace duplicated inline `SELECT` statements in the PHP APIs incrementally,
  testing the JSON response contract after each replacement.
- Add integration tests for successful calls, optional filters, empty results,
  invalid IDs, business-rule failures, and cross-user access attempts.
- Run `EXPLAIN` on the individual statements inside slow procedures using
  production-sized data; an index is selected by the optimizer, not by the
  procedure name.
