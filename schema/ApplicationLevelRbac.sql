USE `smart_fleet_management`;

-- =====================================================================
-- PART A — APPLICATION-LEVEL RBAC (data your app reads to authorise users)
-- =====================================================================
-- "Granting" a permission to a role here = inserting a RolePermission row.
-- "Revoking" = deleting that row. Your application checks these tables
-- before allowing an action; MySQL itself does not enforce them.

-- 1. Roles ------------------------------------------------------------
INSERT INTO `Role` (`RoleName`) VALUES
    ('fleet_admin'),
    ('safety_ops'),
    ('workshop_mgr'),
    ('mechanic'),
    ('driver');

-- 2. Permissions (one row per table + action your app cares about) -----
--    Seeding a compact but representative set. Add more TableName/Action
--    pairs as your app needs them.
INSERT INTO `Permission` (`TableName`, `Action`) VALUES
    ('Vehicles','SELECT'), ('Vehicles','UPDATE'),
    ('VehicleAssignments','SELECT'), ('VehicleAssignments','INSERT'), ('VehicleAssignments','UPDATE'),
    ('Drivers','SELECT'), ('Drivers','UPDATE'),
    ('DriverCertifications','SELECT'), ('DriverCertifications','INSERT'), ('DriverCertifications','UPDATE'),
    ('SafetyEvents','SELECT'), ('SafetyEvents','INSERT'), ('SafetyEvents','UPDATE'),
    ('CoachingRecord','SELECT'), ('CoachingRecord','INSERT'), ('CoachingRecord','UPDATE'),
    ('DriverSafetyScore','SELECT'), ('DriverSafetyScore','UPDATE'),
    ('PredictiveAlert','SELECT'), ('PredictiveAlert','UPDATE'),
    ('MaintenanceJobs','SELECT'), ('MaintenanceJobs','INSERT'), ('MaintenanceJobs','UPDATE'),
    ('MaintenanceActivity','SELECT'), ('MaintenanceActivity','INSERT'), ('MaintenanceActivity','UPDATE'),
    ('ActivityMechanic','SELECT'), ('ActivityMechanic','INSERT'), ('ActivityMechanic','UPDATE'),
    ('Part','SELECT'), ('Part','INSERT'), ('Part','UPDATE'),
    ('Supplier','SELECT'), ('Supplier','INSERT'), ('Supplier','UPDATE');

-- 3. Map permissions to roles ----------------------------------------

-- fleet_admin: every permission that exists
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r CROSS JOIN `Permission` p
WHERE r.RoleName = 'fleet_admin';

-- safety_ops: read fleet context; write safety/coaching/score + driver status
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r JOIN `Permission` p
WHERE r.RoleName = 'safety_ops'
  AND (
        (p.TableName = 'Vehicles'             AND p.Action = 'SELECT') OR
        (p.TableName = 'Drivers'              AND p.Action IN ('SELECT','UPDATE')) OR
        (p.TableName = 'DriverCertifications' AND p.Action = 'SELECT') OR
        (p.TableName = 'SafetyEvents'         AND p.Action IN ('SELECT','INSERT','UPDATE')) OR
        (p.TableName = 'CoachingRecord'       AND p.Action IN ('SELECT','INSERT','UPDATE')) OR
        (p.TableName = 'DriverSafetyScore'    AND p.Action IN ('SELECT','UPDATE'))
      );

-- workshop_mgr: read fleet/driver context; full CRUD on maintenance side
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r JOIN `Permission` p
WHERE r.RoleName = 'workshop_mgr'
  AND (
        (p.TableName = 'Vehicles'            AND p.Action IN ('SELECT','UPDATE')) OR
        (p.TableName = 'Drivers'             AND p.Action = 'SELECT') OR
        (p.TableName = 'PredictiveAlert'     AND p.Action IN ('SELECT','UPDATE')) OR
        (p.TableName = 'MaintenanceJobs'     AND p.Action IN ('SELECT','INSERT','UPDATE')) OR
        (p.TableName = 'MaintenanceActivity' AND p.Action IN ('SELECT','INSERT','UPDATE')) OR
        (p.TableName = 'ActivityMechanic'    AND p.Action IN ('SELECT','INSERT','UPDATE')) OR
        (p.TableName = 'Part'                AND p.Action IN ('SELECT','INSERT','UPDATE')) OR
        (p.TableName = 'Supplier'            AND p.Action IN ('SELECT','INSERT','UPDATE'))
      );

-- mechanic: read maintenance history; update own activity + labour rows
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r JOIN `Permission` p
WHERE r.RoleName = 'mechanic'
  AND (
        (p.TableName = 'Vehicles'            AND p.Action = 'SELECT') OR
        (p.TableName = 'MaintenanceJobs'     AND p.Action = 'SELECT') OR
        (p.TableName = 'MaintenanceActivity' AND p.Action IN ('SELECT','UPDATE')) OR
        (p.TableName = 'ActivityMechanic'    AND p.Action IN ('SELECT','UPDATE')) OR
        (p.TableName = 'Part'                AND p.Action = 'SELECT')
      );

-- driver: read own safety data only (enforced by the views in Part C)
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r JOIN `Permission` p
WHERE r.RoleName = 'driver'
  AND (
        (p.TableName = 'SafetyEvents'      AND p.Action = 'SELECT') OR
        (p.TableName = 'DriverSafetyScore' AND p.Action = 'SELECT')
      );

-- Example: REVOKE an app-level permission (safety_ops loses Drivers UPDATE)
-- DELETE rp FROM `RolePermission` rp
-- JOIN `Role` r       ON r.RoleID = rp.RoleID
-- JOIN `Permission` p ON p.PermissionID = rp.PermissionID
-- WHERE r.RoleName = 'safety_ops'
--   AND p.TableName = 'Drivers' AND p.Action = 'UPDATE';