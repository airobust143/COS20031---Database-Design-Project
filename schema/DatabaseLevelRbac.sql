USE `smart_fleet_management`;

-- =====================================================================
-- PART B — DATABASE-LEVEL RBAC (real MySQL roles enforced by the engine)
-- =====================================================================
-- These are actual MySQL GRANT/REVOKE statements. They control what a
-- connected MySQL account can physically do, independent of your app.

-- 1. Create roles -----------------------------------------------------
CREATE ROLE IF NOT EXISTS
    'sf_fleet_admin',
    'sf_safety_ops',
    'sf_workshop_mgr',
    'sf_mechanic',
    'sf_driver';

-- 2. Grant privileges to each role -----------------------------------

-- fleet_admin: full control of the whole database
GRANT ALL PRIVILEGES ON `smart_fleet_management`.* TO 'sf_fleet_admin';

-- safety_ops: read fleet context, write the safety side
GRANT SELECT ON `smart_fleet_management`.`Vehicles`             TO 'sf_safety_ops';
GRANT SELECT ON `smart_fleet_management`.`Depots`               TO 'sf_safety_ops';
GRANT SELECT ON `smart_fleet_management`.`VehicleAssignments`   TO 'sf_safety_ops';
GRANT SELECT ON `smart_fleet_management`.`DriverCertifications` TO 'sf_safety_ops';
GRANT SELECT, UPDATE ON `smart_fleet_management`.`Drivers`      TO 'sf_safety_ops';
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`SafetyEvents`      TO 'sf_safety_ops';
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`CoachingRecord`    TO 'sf_safety_ops';
GRANT SELECT, UPDATE         ON `smart_fleet_management`.`DriverSafetyScore` TO 'sf_safety_ops';

-- Column-level grant example: let safety_ops update ONLY the review fields
-- of SafetyEvents, not rewrite the raw telemetry:
--   (replaces the table-level SafetyEvents UPDATE above if you prefer tighter control)
-- REVOKE UPDATE ON `smart_fleet_management`.`SafetyEvents` FROM 'sf_safety_ops';
-- GRANT  UPDATE (`ReviewRequired`, `ReviewStatus`)
--        ON `smart_fleet_management`.`SafetyEvents` TO 'sf_safety_ops';

-- workshop_mgr: read fleet/driver context, full CRUD on maintenance domain
GRANT SELECT ON `smart_fleet_management`.`Vehicles` TO 'sf_workshop_mgr';
GRANT SELECT ON `smart_fleet_management`.`Depots`   TO 'sf_workshop_mgr';
GRANT SELECT ON `smart_fleet_management`.`Drivers`  TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`PredictiveAlert`     TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`MaintenanceJobs`     TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`MaintenanceActivity` TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`ActivityMechanic`    TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`WarrantyClaim`       TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`WarrantyClaimPart`   TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`ActivityPart`        TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`Part`                TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`Supplier`            TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`SupplyPart`          TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE         ON `smart_fleet_management`.`Mechanic`            TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE         ON `smart_fleet_management`.`MechanicCertification` TO 'sf_workshop_mgr';

-- mechanic: read maintenance history, update own diagnostic/labour records
GRANT SELECT ON `smart_fleet_management`.`Vehicles`            TO 'sf_mechanic';
GRANT SELECT ON `smart_fleet_management`.`MaintenanceJobs`     TO 'sf_mechanic';
GRANT SELECT, UPDATE ON `smart_fleet_management`.`MaintenanceActivity` TO 'sf_mechanic';
GRANT SELECT, UPDATE ON `smart_fleet_management`.`ActivityMechanic`    TO 'sf_mechanic';
GRANT SELECT ON `smart_fleet_management`.`Part`               TO 'sf_mechanic';

-- driver: NO direct table access — only the filtered views (see Part C)
-- (grants are placed on the views, not the base tables)

-- 3. Create login users and assign roles ------------------------------
CREATE USER IF NOT EXISTS 'anna_admin'@'%'    IDENTIFIED BY 'change_me_admin';
CREATE USER IF NOT EXISTS 'sam_safety'@'%'    IDENTIFIED BY 'change_me_safety';
CREATE USER IF NOT EXISTS 'wendy_wshop'@'%'   IDENTIFIED BY 'change_me_wshop';
CREATE USER IF NOT EXISTS 'mike_mech'@'%'     IDENTIFIED BY 'change_me_mech';
CREATE USER IF NOT EXISTS 'dan_driver'@'%'    IDENTIFIED BY 'change_me_driver';

GRANT 'sf_fleet_admin'  TO 'anna_admin'@'%';
GRANT 'sf_safety_ops'   TO 'sam_safety'@'%';
GRANT 'sf_workshop_mgr' TO 'wendy_wshop'@'%';
GRANT 'sf_mechanic'     TO 'mike_mech'@'%';
GRANT 'sf_driver'       TO 'dan_driver'@'%';

-- Make the role active automatically on login (otherwise SET ROLE is needed)
SET DEFAULT ROLE ALL TO
    'anna_admin'@'%',
    'sam_safety'@'%',
    'wendy_wshop'@'%',
    'mike_mech'@'%',
    'dan_driver'@'%';

-- 4. REVOKE examples --------------------------------------------------
-- Take DELETE on Part away from workshop managers:
-- REVOKE DELETE ON `smart_fleet_management`.`Part` FROM 'sf_workshop_mgr';

-- Remove a role from a user entirely:
-- REVOKE 'sf_mechanic' FROM 'mike_mech'@'%';

-- Apply changes immediately (needed after editing the mysql.* grant tables
-- directly; not strictly required for GRANT/REVOKE statements, but harmless):
FLUSH PRIVILEGES;