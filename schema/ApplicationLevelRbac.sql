USE `smart_fleet_management`;

-- =====================================================================
-- PART A — APPLICATION-LEVEL RBAC
-- =====================================================================

-- 1. Roles ------------------------------------------------------------
INSERT INTO `Role` (`RoleName`) VALUES
    ('fleet_admin'),
    ('safety_ops'),
    ('workshop_mgr'),
    ('mechanic'),
    ('driver');

-- 2. Permissions ------------------------------------------------------
INSERT INTO `Permission` (`TableName`, `Action`) VALUES
    -- core fleet
    ('Vehicles','SELECT'), ('Vehicles','UPDATE'),
    ('VehiclesCategory','SELECT'),
    ('VehiclesDepotHistory','SELECT'),
    ('VehicleAssignments','SELECT'), ('VehicleAssignments','INSERT'), ('VehicleAssignments','UPDATE'),
    ('Depots','SELECT'),
    -- drivers & safety
    ('Drivers','SELECT'), ('Drivers','UPDATE'),
    ('DriverCertifications','SELECT'), ('DriverCertifications','INSERT'), ('DriverCertifications','UPDATE'),
    ('CertificationType','SELECT'),
    ('VehicleCertRequirement','SELECT'),
    ('SafetyEvents','SELECT'), ('SafetyEvents','INSERT'), ('SafetyEvents','UPDATE'),
    ('SafetyEventsType','SELECT'),
    ('CoachingRecord','SELECT'), ('CoachingRecord','INSERT'), ('CoachingRecord','UPDATE'),
    ('DriverSafetyScore','SELECT'), ('DriverSafetyScore','UPDATE'),
    -- maintenance
    ('PredictiveAlert','SELECT'), ('PredictiveAlert','UPDATE'),
    ('MaintenanceJobs','SELECT'), ('MaintenanceJobs','INSERT'), ('MaintenanceJobs','UPDATE'), ('MaintenanceJobs','DELETE'),
    ('MaintenanceActivity','SELECT'), ('MaintenanceActivity','INSERT'), ('MaintenanceActivity','UPDATE'), ('MaintenanceActivity','DELETE'),
    ('ActivityType','SELECT'),
    ('ActivityMechanic','SELECT'), ('ActivityMechanic','INSERT'), ('ActivityMechanic','UPDATE'), ('ActivityMechanic','DELETE'),
    ('ActivityPart','SELECT'), ('ActivityPart','INSERT'), ('ActivityPart','UPDATE'), ('ActivityPart','DELETE'),
    -- workshops & people
    ('Workshop','SELECT'),
    ('Mechanic','SELECT'), ('Mechanic','INSERT'), ('Mechanic','UPDATE'),
    ('MechanicCertification','SELECT'), ('MechanicCertification','INSERT'), ('MechanicCertification','UPDATE'),
    ('MechanicCertType','SELECT'),
    -- parts & suppliers
    ('Part','SELECT'), ('Part','INSERT'), ('Part','UPDATE'), ('Part','DELETE'),
    ('Supplier','SELECT'), ('Supplier','INSERT'), ('Supplier','UPDATE'), ('Supplier','DELETE'),
    ('SupplyPart','SELECT'), ('SupplyPart','INSERT'), ('SupplyPart','UPDATE'), ('SupplyPart','DELETE'),
    ('WarrantyClaim','SELECT'), ('WarrantyClaim','INSERT'), ('WarrantyClaim','UPDATE'),
    ('WarrantyClaimPart','SELECT'), ('WarrantyClaimPart','INSERT'), ('WarrantyClaimPart','UPDATE');

-- 3. Role -> Permission mappings --------------------------------------

-- fleet_admin: everything
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r CROSS JOIN `Permission` p
WHERE r.RoleName = 'fleet_admin';

-- safety_ops
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r CROSS JOIN `Permission` p
WHERE r.RoleName = 'safety_ops'
  AND (
        (p.TableName IN ('Vehicles','VehiclesCategory','VehiclesDepotHistory',
                         'VehicleAssignments','Depots','DriverCertifications',
                         'CertificationType','VehicleCertRequirement',
                         'SafetyEventsType')
                                              AND p.Action = 'SELECT') OR
        (p.TableName = 'Drivers'              AND p.Action IN ('SELECT','UPDATE')) OR
        (p.TableName = 'SafetyEvents'         AND p.Action IN ('SELECT','INSERT','UPDATE')) OR
        (p.TableName = 'CoachingRecord'       AND p.Action IN ('SELECT','INSERT','UPDATE')) OR
        (p.TableName = 'DriverSafetyScore'    AND p.Action IN ('SELECT','UPDATE'))
      );

-- workshop_mgr
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r CROSS JOIN `Permission` p
WHERE r.RoleName = 'workshop_mgr'
  AND (
        (p.TableName IN ('Depots','Drivers','VehiclesCategory','Workshop',
                         'ActivityType','MechanicCertType')
                                              AND p.Action = 'SELECT') OR
        (p.TableName = 'Vehicles'             AND p.Action IN ('SELECT','UPDATE')) OR
        (p.TableName = 'PredictiveAlert'      AND p.Action IN ('SELECT','UPDATE')) OR
        (p.TableName IN ('MaintenanceJobs','MaintenanceActivity','ActivityMechanic',
                         'ActivityPart','Part','Supplier','SupplyPart')
                                              AND p.Action IN ('SELECT','INSERT','UPDATE','DELETE')) OR
        (p.TableName IN ('WarrantyClaim','WarrantyClaimPart','Mechanic',
                         'MechanicCertification')
                                              AND p.Action IN ('SELECT','INSERT','UPDATE'))
      );

-- mechanic (broad reads; write scope narrowed to own rows by the app /
-- Part C views)
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r CROSS JOIN `Permission` p
WHERE r.RoleName = 'mechanic'
  AND (
        (p.TableName IN ('Vehicles','MaintenanceJobs','ActivityType',
                         'ActivityPart','Part','Workshop')
                                              AND p.Action = 'SELECT') OR
        (p.TableName = 'MaintenanceActivity'  AND p.Action IN ('SELECT','UPDATE')) OR
        (p.TableName = 'ActivityMechanic'     AND p.Action IN ('SELECT','UPDATE'))
      );

-- driver (own data only — enforced by app / Part C views)
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r CROSS JOIN `Permission` p
WHERE r.RoleName = 'driver'
  AND p.TableName IN ('SafetyEvents','DriverSafetyScore','DriverCertifications')
  AND p.Action = 'SELECT';

-- App-level REVOKE example:
-- DELETE rp FROM `RolePermission` rp
-- JOIN `Role` r       ON r.RoleID = rp.RoleID
-- JOIN `Permission` p ON p.PermissionID = rp.PermissionID
-- WHERE r.RoleName = 'safety_ops' AND p.TableName = 'Drivers' AND p.Action = 'UPDATE';