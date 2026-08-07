# How to Use the Stored Procedures in the Backend

All 30 procedures are integrated into the project. The three business-rule
procedures run automatically through database triggers; the remaining query
procedures are exposed through protected backend API resources. The following
list describes each procedure and its corresponding application capability.

## Business-rule procedures

- `sp_check_vehicle_assignment_eligibility` validates driver and vehicle
  assignments. It supports assignment `POST` and `PUT` operations in
  `backend/api/fleet.php` around line 195. The assignment triggers already call
  it, so no inline SQL replacement is required.

- `sp_recalc_driver_safety_score` recalculates a driver's monthly score after
  safety events change. It supports event writes in `backend/api/safety.php`
  around line 74. Safety-event triggers already call it, so the backend should
  not duplicate the calculation.

- `sp_check_mechanic_certified` validates mechanic certification before an
  activity assignment. It should support future `ActivityMechanic` assignment
  endpoints. There is currently no equivalent inline assignment query.

## Fleet procedures

- `sp_search_vehicles` can replace the dynamic vehicle-list query in
  `backend/api/fleet.php` around line 61.

- `sp_get_vehicle_profile` can provide a complete vehicle-detail endpoint. No
  equivalent complete profile endpoint currently exists.

- `sp_list_available_vehicles` can replace the basic vehicle-selector query in
  `backend/api/fleet.php` around line 493, particularly for assignment forms.

- `sp_vehicle_assignment_history` can replace the assignments-list query in
  `backend/api/fleet.php` around line 182.

- `sp_vehicles_due_maintenance` can provide a maintenance-due list. There is
  currently no equivalent backend query.

- `sp_fleet_summary_counts` can replace most fleet KPI queries in
  `backend/api/fleet.php` around line 42 and the vehicle-status breakdown around
  line 442.

- `sp_list_users_by_role` can replace the user-list query in
  `backend/api/fleet.php` around line 340.

- `sp_get_user_permissions` can replace the inline permission-loading query
  after login in `backend/api/auth.php` around line 155.

- `sp_check_user_permission` can perform fresh database permission checks in
  middleware. The backend currently uses permissions cached in the session, so
  there is no exact inline query to replace.

## Safety procedures

- `sp_search_drivers` can replace the driver-list query in
  `backend/api/safety.php` around line 185.

- `sp_get_driver_profile` can provide the Safety Operations driver-detail page.
  There is no equivalent complete administrative profile endpoint.

- `sp_list_suspended_drivers` can provide a dedicated suspension queue. It can
  replace filtered driver queries when the UI requests suspended or inactive
  drivers.

- `sp_list_predictive_alerts` can replace the alert-list query in
  `backend/api/workshop.php` around line 116.

- `sp_drivers_requiring_coaching` can replace or enhance the coaching-list query
  in `backend/api/safety.php` around line 142.

## Workshop procedures

- `sp_search_maintenance_jobs` can replace the dynamic jobs query in
  `backend/api/workshop.php` around line 54.

- `sp_get_job_detail` can provide complete job, activity, mechanic, part, and
  warranty information. There is no equivalent complete job-detail endpoint.

- `sp_list_open_jobs` can replace the open/in-progress filtering in
  `backend/api/workshop.php` around line 57.

- `sp_low_stock_parts` can replace the low-stock KPI query in
  `backend/api/workshop.php` around line 44 and provide the full reorder list.

- `sp_list_mechanics_workload` can replace the mechanic-list query in
  `backend/api/workshop.php` around line 249 when workload information is
  required.

- `sp_workshop_summary` can replace most separate workshop KPI queries in
  `backend/api/workshop.php` around line 38.

## Mechanic procedures

- `sp_get_mechanic_assigned_jobs` can replace the `my_activities` query in
  `backend/api/mechanic.php` around line 40.

- `sp_get_mechanic_job_detail` can provide an access-controlled mechanic job
  page. No equivalent complete detail query currently exists.

- `sp_search_parts` can replace the parts-list query in
  `backend/api/workshop.php` around line 143 when searching or selecting parts.

- `sp_get_mechanic_workload_summary` can replace the mechanic KPI queries in
  `backend/api/mechanic.php` around line 23.

## Driver procedures

- `sp_get_driver_own_vehicle` can provide the driver's current-vehicle page.
  There is currently no equivalent backend endpoint.

- `sp_get_driver_complete_profile` can replace the separate profile, events,
  scores, and certification queries in `backend/api/driver.php` starting around
  line 56.

- `sp_get_driver_safety_summary` can replace the multiple driver KPI queries in
  `backend/api/driver.php` around line 22.

## Recommended implementation order

The highest-value initial replacements are:

1. `sp_get_driver_safety_summary`
2. `sp_get_mechanic_workload_summary`
3. `sp_fleet_summary_counts`
4. `sp_workshop_summary`
5. `sp_get_user_permissions`

Each of these can replace several inline queries with one procedure call.

## PHP/PDO call example

```php
$stmt = $pdo->prepare(
    'CALL sp_get_driver_safety_summary(:driver_id)'
);
$stmt->execute([
    ':driver_id' => $_SESSION['driver_id'],
]);

$summary = $stmt->fetch(PDO::FETCH_ASSOC);
$stmt->closeCursor();

jsonOk($summary ?: []);
```

For procedures that return multiple result sets, read every result using
`nextRowset()`:

```php
$stmt = $pdo->prepare('CALL sp_get_job_detail(:job_id)');
$stmt->execute([':job_id' => $jobId]);

$resultSets = [];
do {
    if ($stmt->columnCount() > 0) {
        $resultSets[] = $stmt->fetchAll(PDO::FETCH_ASSOC);
    }
} while ($stmt->nextRowset());

$stmt->closeCursor();
jsonOk($resultSets);
```

Always use prepared parameters, enforce permissions before calling a procedure,
derive driver and mechanic IDs from the authenticated session for self-service
routes, and call `closeCursor()` before issuing another query on the same PDO
connection.
