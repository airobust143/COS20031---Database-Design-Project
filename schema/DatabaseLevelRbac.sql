USE `smart_fleet_management`;

-- =====================================================================
-- PART B — DATABASE-LEVEL RBAC (MySQL 8.0 syntax)
-- =====================================================================
-- MariaDB: CREATE ROLE takes ONE role per statement, e.g.
--   CREATE ROLE IF NOT EXISTS sf_fleet_admin;  (repeat per role)

CREATE ROLE IF NOT EXISTS
    'sf_fleet_admin', 'sf_safety_ops', 'sf_workshop_mgr',
    'sf_mechanic', 'sf_driver';

-- fleet_admin -----------------------------------------------------------
GRANT ALL PRIVILEGES ON `smart_fleet_management`.* TO 'sf_fleet_admin';

-- safety_ops ------------------------------------------------------------
-- Context/lookup reads (F1: SafetyEventsType etc. were missing in v1)
GRANT SELECT ON `smart_fleet_management`.`Depots`                TO 'sf_safety_ops';
GRANT SELECT ON `smart_fleet_management`.`Vehicles`              TO 'sf_safety_ops';
GRANT SELECT ON `smart_fleet_management`.`VehiclesCategory`      TO 'sf_safety_ops';
GRANT SELECT ON `smart_fleet_management`.`VehiclesDepotHistory`  TO 'sf_safety_ops';
GRANT SELECT ON `smart_fleet_management`.`VehicleAssignments`    TO 'sf_safety_ops';
GRANT SELECT ON `smart_fleet_management`.`DriverCertifications`  TO 'sf_safety_ops';
GRANT SELECT ON `smart_fleet_management`.`CertificationType`     TO 'sf_safety_ops';
GRANT SELECT ON `smart_fleet_management`.`VehicleCertRequirement` TO 'sf_safety_ops';
GRANT SELECT ON `smart_fleet_management`.`SafetyEventsType`      TO 'sf_safety_ops';
-- Writes on the safety side
GRANT SELECT, UPDATE (`EmploymentStatus`)
      ON `smart_fleet_management`.`Drivers` TO 'sf_safety_ops';
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`SafetyEvents`      TO 'sf_safety_ops';
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`CoachingRecord`    TO 'sf_safety_ops';
GRANT SELECT, UPDATE         ON `smart_fleet_management`.`DriverSafetyScore` TO 'sf_safety_ops';

-- workshop_mgr ----------------------------------------------------------
GRANT SELECT ON `smart_fleet_management`.`Depots`           TO 'sf_workshop_mgr';
GRANT SELECT ON `smart_fleet_management`.`Drivers`          TO 'sf_workshop_mgr';
GRANT SELECT ON `smart_fleet_management`.`VehiclesCategory` TO 'sf_workshop_mgr';
GRANT SELECT ON `smart_fleet_management`.`Workshop`         TO 'sf_workshop_mgr';  -- F1: missing in v1
GRANT SELECT ON `smart_fleet_management`.`ActivityType`     TO 'sf_workshop_mgr';  -- F1
GRANT SELECT ON `smart_fleet_management`.`MechanicCertType` TO 'sf_workshop_mgr';  -- F1
GRANT SELECT, UPDATE ON `smart_fleet_management`.`Vehicles`        TO 'sf_workshop_mgr';
GRANT SELECT, UPDATE ON `smart_fleet_management`.`PredictiveAlert` TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`MaintenanceJobs`     TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`MaintenanceActivity` TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`ActivityMechanic`    TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`ActivityPart`        TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`Part`                TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`Supplier`            TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`SupplyPart`          TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`WarrantyClaim`         TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`WarrantyClaimPart`     TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`Mechanic`              TO 'sf_workshop_mgr';
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`MechanicCertification` TO 'sf_workshop_mgr';

-- mechanic --------------------------------------------------------------
-- Broad READS (brief: full maintenance history / diagnostics / prior repairs)
GRANT SELECT ON `smart_fleet_management`.`Vehicles`            TO 'sf_mechanic';
GRANT SELECT ON `smart_fleet_management`.`Workshop`            TO 'sf_mechanic';
GRANT SELECT ON `smart_fleet_management`.`MaintenanceJobs`     TO 'sf_mechanic';
GRANT SELECT ON `smart_fleet_management`.`MaintenanceActivity` TO 'sf_mechanic';
GRANT SELECT ON `smart_fleet_management`.`ActivityMechanic`    TO 'sf_mechanic';
GRANT SELECT ON `smart_fleet_management`.`ActivityType`        TO 'sf_mechanic';  -- F1
GRANT SELECT ON `smart_fleet_management`.`ActivityPart`        TO 'sf_mechanic';  -- F1
GRANT SELECT ON `smart_fleet_management`.`Part`                TO 'sf_mechanic';
-- NO table-level UPDATE here (F2) — writes go through Part C views only.

-- driver ----------------------------------------------------------------
-- No base-table access at all — Part C views only.

-- Login users + role assignment ----------------------------------------
CREATE USER IF NOT EXISTS 'anna_admin'@'%'  IDENTIFIED BY 'change_me_admin';
CREATE USER IF NOT EXISTS 'sam_safety'@'%'  IDENTIFIED BY 'change_me_safety';
CREATE USER IF NOT EXISTS 'wendy_wshop'@'%' IDENTIFIED BY 'change_me_wshop';
CREATE USER IF NOT EXISTS 'mike_mech'@'%'   IDENTIFIED BY 'change_me_mech';
CREATE USER IF NOT EXISTS 'dan_driver'@'%'  IDENTIFIED BY 'change_me_driver';

GRANT 'sf_fleet_admin'  TO 'anna_admin'@'%';
GRANT 'sf_safety_ops'   TO 'sam_safety'@'%';
GRANT 'sf_workshop_mgr' TO 'wendy_wshop'@'%';
GRANT 'sf_mechanic'     TO 'mike_mech'@'%';
GRANT 'sf_driver'       TO 'dan_driver'@'%';

-- MySQL 8.0. MariaDB: SET DEFAULT ROLE sf_fleet_admin FOR 'anna_admin'@'%'; etc.
SET DEFAULT ROLE ALL TO
    'anna_admin'@'%', 'sam_safety'@'%', 'wendy_wshop'@'%',
    'mike_mech'@'%', 'dan_driver'@'%';

-- REVOKE examples:
-- REVOKE DELETE ON `smart_fleet_management`.`Part` FROM 'sf_workshop_mgr';
-- REVOKE 'sf_mechanic' FROM 'mike_mech'@'%';
