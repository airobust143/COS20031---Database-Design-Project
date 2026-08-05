-- =====================================================================
-- Smart Fleet Management — RBAC companion script (MariaDB 10.4 / XAMPP)
-- Run AFTER smartfleet_schema.sql
-- Tested target: 10.4.32-MariaDB
--
-- Part A: Application-level RBAC  (rows in Role/Permission tables — read
--         and enforced by YOUR APP CODE, not by the database)
-- Part B: Database-level RBAC     (real MariaDB roles + GRANT/REVOKE —
--         enforced by the ENGINE on every query)
-- Part C: Row-level access via views (drivers: own reads; mechanics:
--         own writes)
-- =====================================================================

USE `smart_fleet_management`;

-- Table for logging database activities
DROP TABLE IF EXISTS `AuditLog`;

CREATE TABLE `AuditLog` (
    `LogID`        BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `UserID`       INT UNSIGNED NULL,
    `Username`     VARCHAR(50) NULL,
    -- What was affected
    `TableName`    VARCHAR(100) NOT NULL,
    `RecordID`     VARCHAR(100) NOT NULL,
    -- Action type
    `Action`       ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    -- Data snapshots
    `OldData`      JSON NULL,
    `NewData`      JSON NULL,
    -- Extra metadata
    `ChangedAt`    DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    `ChangedByDBUser` VARCHAR(100) NULL, -- DB login (CURRENT_USER())

    PRIMARY KEY (`LogID`),

    KEY `idx_audit_table` (`TableName`),
    KEY `idx_audit_user` (`UserID`),
    KEY `idx_audit_time` (`ChangedAt`),

    CONSTRAINT `fk_audit_user`
        FOREIGN KEY (`UserID`) REFERENCES `UserAccount` (`UserID`)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;





DELETE FROM `RolePermission`;
DELETE FROM `UserRole`;
DELETE FROM `Permission`;
DELETE FROM `Role`;

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
    ('Depots','SELECT'), ('Depots','INSERT'), ('Depots','UPDATE'), ('Depots','DELETE'),
    ('VehiclesCategory','SELECT'), ('VehiclesCategory','INSERT'), ('VehiclesCategory','UPDATE'), ('VehiclesCategory','DELETE'),
    ('Vehicles','SELECT'), ('Vehicles','INSERT'), ('Vehicles','UPDATE'), ('Vehicles','DELETE'),
    ('VehiclesDepotHistory','SELECT'), ('VehiclesDepotHistory','INSERT'), ('VehiclesDepotHistory','UPDATE'), ('VehiclesDepotHistory','DELETE'),
    ('VehicleAssignments','SELECT'), ('VehicleAssignments','INSERT'), ('VehicleAssignments','UPDATE'), ('VehicleAssignments','DELETE'),
    -- drivers & safety
    ('CertificationType','SELECT'), ('CertificationType','INSERT'), ('CertificationType','UPDATE'), ('CertificationType','DELETE'),
    ('SafetyEventsType','SELECT'), ('SafetyEventsType','INSERT'), ('SafetyEventsType','UPDATE'), ('SafetyEventsType','DELETE'),
    ('Drivers','SELECT'), ('Drivers','INSERT'), ('Drivers','UPDATE'), ('Drivers','DELETE'),
    ('DriverCertifications','SELECT'), ('DriverCertifications','INSERT'), ('DriverCertifications','UPDATE'), ('DriverCertifications','DELETE'),
    ('VehicleCertRequirement','SELECT'), ('VehicleCertRequirement','INSERT'), ('VehicleCertRequirement','UPDATE'), ('VehicleCertRequirement','DELETE'),
    ('DriverSafetyScore','SELECT'), ('DriverSafetyScore','INSERT'), ('DriverSafetyScore','UPDATE'), ('DriverSafetyScore','DELETE'),
    ('SafetyEvents','SELECT'), ('SafetyEvents','INSERT'), ('SafetyEvents','UPDATE'), ('SafetyEvents','DELETE'),
    ('CoachingRecord','SELECT'), ('CoachingRecord','INSERT'), ('CoachingRecord','UPDATE'), ('CoachingRecord','DELETE'),
    -- maintenance
    ('ActivityType','SELECT'), ('ActivityType','INSERT'), ('ActivityType','UPDATE'), ('ActivityType','DELETE'),
    ('PredictiveAlert','SELECT'), ('PredictiveAlert','INSERT'), ('PredictiveAlert','UPDATE'), ('PredictiveAlert','DELETE'),
    ('MaintenanceJobs','SELECT'), ('MaintenanceJobs','INSERT'), ('MaintenanceJobs','UPDATE'), ('MaintenanceJobs','DELETE'),
    ('MaintenanceActivity','SELECT'), ('MaintenanceActivity','INSERT'), ('MaintenanceActivity','UPDATE'), ('MaintenanceActivity','DELETE'),
    ('ActivityMechanic','SELECT'), ('ActivityMechanic','INSERT'), ('ActivityMechanic','UPDATE'), ('ActivityMechanic','DELETE'),
    ('ActivityPart','SELECT'), ('ActivityPart','INSERT'), ('ActivityPart','UPDATE'), ('ActivityPart','DELETE'),
    -- workshops & people
    ('Workshop','SELECT'), ('Workshop','INSERT'), ('Workshop','UPDATE'), ('Workshop','DELETE'),
    ('MechanicCertType','SELECT'), ('MechanicCertType','INSERT'), ('MechanicCertType','UPDATE'), ('MechanicCertType','DELETE'),
    ('Mechanic','SELECT'), ('Mechanic','INSERT'), ('Mechanic','UPDATE'), ('Mechanic','DELETE'),
    ('MechanicCertification','SELECT'), ('MechanicCertification','INSERT'), ('MechanicCertification','UPDATE'), ('MechanicCertification','DELETE'),
    -- parts & suppliers
    ('Part','SELECT'), ('Part','INSERT'), ('Part','UPDATE'), ('Part','DELETE'),
    ('Supplier','SELECT'), ('Supplier','INSERT'), ('Supplier','UPDATE'), ('Supplier','DELETE'),
    ('SupplyPart','SELECT'), ('SupplyPart','INSERT'), ('SupplyPart','UPDATE'), ('SupplyPart','DELETE'),
    ('WarrantyClaim','SELECT'), ('WarrantyClaim','INSERT'), ('WarrantyClaim','UPDATE'), ('WarrantyClaim','DELETE'),
    ('WarrantyClaimPart','SELECT'), ('WarrantyClaimPart','INSERT'), ('WarrantyClaimPart','UPDATE'), ('WarrantyClaimPart','DELETE'),
    -- user role (RBAC itself)
    ('Role','SELECT'), ('Role','INSERT'), ('Role','UPDATE'), ('Role','DELETE'),
    ('Permission','SELECT'), ('Permission','INSERT'), ('Permission','UPDATE'), ('Permission','DELETE'),
    ('UserAccount','SELECT'), ('UserAccount','INSERT'), ('UserAccount','UPDATE'), ('UserAccount','DELETE'), -- FIXED: changed semicolon to comma
    ('UserRole','SELECT'), ('UserRole','INSERT'), ('UserRole','UPDATE'), ('UserRole','DELETE'),
    ('RolePermission','SELECT'), ('RolePermission','INSERT'), ('RolePermission','UPDATE'), ('RolePermission','DELETE'),
    -- audit log
    ('AuditLog','SELECT'), ('AuditLog','INSERT'), ('AuditLog','UPDATE'), ('AuditLog','DELETE');

-- 3. Role -> Permission mappings --------------------------------------

-- fleet_admin: everything
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r, `Permission` p
WHERE r.RoleName = 'fleet_admin';

-- safety_ops
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r CROSS JOIN `Permission` p
WHERE r.RoleName = 'safety_ops'
  AND (p.TableName IN ('Depots', 'Vehicles', 'VehiclesCategory', 'VehiclesDepotHistory',
                         'VehicleAssignments', 'CertificationType', 'SafetyEventsType',
                         'DriverCertifications', 'VehicleCertRequirement')
                                              AND p.Action = 'SELECT'
       OR p.TableName = 'Drivers'             AND p.Action IN ('SELECT','UPDATE')
       OR p.TableName = 'SafetyEvents'        AND p.Action IN ('SELECT','INSERT','UPDATE')
       OR p.TableName = 'CoachingRecord'      AND p.Action IN ('SELECT','INSERT','UPDATE')
       OR p.TableName = 'DriverSafetyScore'   AND p.Action IN ('SELECT','UPDATE')
      );

-- workshop_mgr
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r CROSS JOIN `Permission` p
WHERE r.RoleName = 'workshop_mgr'
  AND (p.TableName IN ('Depots', 'Drivers', 'VehiclesCategory', 'Workshop',
                         'ActivityType', 'MechanicCertType')
                                              AND p.Action = 'SELECT'
       OR p.TableName = 'Vehicles'            AND p.Action IN ('SELECT','UPDATE')
       OR p.TableName = 'PredictiveAlert'     AND p.Action IN ('SELECT','UPDATE')
       OR p.TableName IN ('MaintenanceJobs', 'MaintenanceActivity', 'ActivityMechanic',
                         'ActivityPart', 'Part', 'Supplier', 'SupplyPart')
                                              AND p.Action IN ('SELECT','INSERT','UPDATE','DELETE')
       OR p.TableName IN ('WarrantyClaim', 'Mechanic', 'WarrantyClaimPart',
                         'MechanicCertification')
                                              AND p.Action IN ('SELECT','INSERT','UPDATE')
      );

-- mechanic (broad reads; write scope narrowed to own rows by Part C views)
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r CROSS JOIN `Permission` p
WHERE r.RoleName = 'mechanic'
  AND (p.TableName IN ('Vehicles', 'MaintenanceJobs', 'ActivityType',
                         'ActivityPart', 'Part', 'Workshop')
                                              AND p.Action = 'SELECT'
       OR p.TableName = 'MaintenanceActivity' AND p.Action IN ('SELECT','UPDATE')
       OR p.TableName = 'ActivityMechanic'    AND p.Action IN ('SELECT','UPDATE')
      );

-- driver (own data only — enforced by app / Part C views)
INSERT INTO `RolePermission` (`RoleID`, `PermissionID`)
SELECT r.RoleID, p.PermissionID
FROM `Role` r CROSS JOIN `Permission` p
WHERE r.RoleName = 'driver' AND p.Action = 'SELECT'
  AND p.TableName IN ('SafetyEvents', 'DriverSafetyScore', 'DriverCertifications',
                      'Vehicles', 'VehiclesCategory', 'VehiclesDepotHistory',
                      'VehicleAssignments', 'Depots', 'CertificationType',
                      'SafetyEventsType', 'Drivers');

-- App-level REVOKE example:
-- DELETE rp FROM `RolePermission` rp
-- JOIN `Role` r       ON r.RoleID = rp.RoleID
-- JOIN `Permission` p ON p.PermissionID = rp.PermissionID
-- WHERE r.RoleName = 'safety_ops' AND p.TableName = 'Drivers' AND p.Action = 'UPDATE';

-- 4. User -> Role mappings --------------------------------------------
-- This part links the application users in UserAccount to the roles defined above.
-- It assumes you have already created these users in the UserAccount table.

-- Link every seeded driver account (driver01-driver10) to the driver role.
-- DriverID is used instead of the username pattern so the mapping remains
-- correct if an account is renamed later.
INSERT INTO `UserRole` (`UserID`, `RoleID`, `GrantedDate`)
SELECT ua.UserID, r.RoleID, CURDATE()
FROM `UserAccount` ua
JOIN `Role` r ON r.RoleName = 'driver'
WHERE ua.DriverID IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM `UserRole` ur
      WHERE ur.UserID = ua.UserID AND ur.RoleID = r.RoleID
  );

-- Link every seeded mechanic account (mechanic01-mechanic10) to the
-- mechanic role.
INSERT INTO `UserRole` (`UserID`, `RoleID`, `GrantedDate`)
SELECT ua.UserID, r.RoleID, CURDATE()
FROM `UserAccount` ua
JOIN `Role` r ON r.RoleName = 'mechanic'
WHERE ua.MechanicID IS NOT NULL
  AND NOT EXISTS (
      SELECT 1
      FROM `UserRole` ur
      WHERE ur.UserID = ua.UserID AND ur.RoleID = r.RoleID
  );

INSERT INTO `UserRole` (`UserID`, `RoleID`, `GrantedDate`)
SELECT ua.UserID, r.RoleID, CURDATE()
FROM `UserAccount` ua JOIN `Role` r ON r.RoleName = 'fleet_admin'
WHERE ua.Username = 'fleet_admin' AND NOT EXISTS (SELECT 1 FROM UserRole ur WHERE ur.UserID = ua.UserID);

INSERT INTO `UserRole` (`UserID`, `RoleID`, `GrantedDate`)
SELECT ua.UserID, r.RoleID, CURDATE()
FROM `UserAccount` ua JOIN `Role` r ON r.RoleName = 'safety_ops'
WHERE ua.Username = 'safety_lead' AND NOT EXISTS (SELECT 1 FROM UserRole ur WHERE ur.UserID = ua.UserID);

INSERT INTO `UserRole` (`UserID`, `RoleID`, `GrantedDate`)
SELECT ua.UserID, r.RoleID, CURDATE()
FROM `UserAccount` ua JOIN `Role` r ON r.RoleName = 'workshop_mgr'
WHERE ua.Username = 'workshop_north' AND NOT EXISTS (SELECT 1 FROM UserRole ur WHERE ur.UserID = ua.UserID);

INSERT INTO `UserRole` (`UserID`, `RoleID`, `GrantedDate`)
SELECT ua.UserID, r.RoleID, CURDATE()
FROM `UserAccount` ua JOIN `Role` r ON r.RoleName = 'workshop_mgr'
WHERE ua.Username = 'workshop_south' AND NOT EXISTS (SELECT 1 FROM UserRole ur WHERE ur.UserID = ua.UserID);

INSERT INTO `UserRole` (`UserID`, `RoleID`, `GrantedDate`)
SELECT ua.UserID, r.RoleID, CURDATE()
FROM `UserAccount` ua JOIN `Role` r ON r.RoleName = 'fleet_admin'
WHERE ua.Username = 'auditor' AND NOT EXISTS (SELECT 1 FROM UserRole ur WHERE ur.UserID = ua.UserID);

-- =====================================================================
-- PART B — DATABASE-LEVEL RBAC (MariaDB 10.4 syntax)
-- =====================================================================

-- 1. Create roles (MariaDB: ONE role per statement) -------------------
CREATE ROLE IF NOT EXISTS sf_fleet_admin;
CREATE ROLE IF NOT EXISTS sf_safety_ops;
CREATE ROLE IF NOT EXISTS sf_workshop_mgr;
CREATE ROLE IF NOT EXISTS sf_mechanic;
CREATE ROLE IF NOT EXISTS sf_driver;

-- 2. Grant privileges to roles ----------------------------------------

-- fleet_admin
GRANT ALL PRIVILEGES ON `smart_fleet_management`.* TO sf_fleet_admin;

-- safety_ops: context/lookup reads
GRANT SELECT ON `smart_fleet_management`.`Depots`                 TO sf_safety_ops;
GRANT SELECT ON `smart_fleet_management`.`Vehicles`               TO sf_safety_ops;
GRANT SELECT ON `smart_fleet_management`.`VehiclesCategory`       TO sf_safety_ops;
GRANT SELECT ON `smart_fleet_management`.`VehiclesDepotHistory`   TO sf_safety_ops;
GRANT SELECT ON `smart_fleet_management`.`VehicleAssignments`     TO sf_safety_ops;
GRANT SELECT ON `smart_fleet_management`.`DriverCertifications`   TO sf_safety_ops;
GRANT SELECT ON `smart_fleet_management`.`CertificationType`      TO sf_safety_ops;
GRANT SELECT ON `smart_fleet_management`.`VehicleCertRequirement` TO sf_safety_ops;
GRANT SELECT ON `smart_fleet_management`.`SafetyEventsType`       TO sf_safety_ops;
-- safety_ops: writes on the safety side
-- (column-level UPDATE: can suspend/reactivate a driver but not edit
--  personal details)
GRANT SELECT, UPDATE (`EmploymentStatus`)
      ON `smart_fleet_management`.`Drivers` TO sf_safety_ops;
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`SafetyEvents`      TO sf_safety_ops;
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`CoachingRecord`    TO sf_safety_ops;
GRANT SELECT, UPDATE         ON `smart_fleet_management`.`DriverSafetyScore` TO sf_safety_ops;

-- workshop_mgr
GRANT SELECT ON `smart_fleet_management`.`Depots`           TO sf_workshop_mgr;
GRANT SELECT ON `smart_fleet_management`.`Drivers`          TO sf_workshop_mgr;
GRANT SELECT ON `smart_fleet_management`.`VehiclesCategory` TO sf_workshop_mgr;
GRANT SELECT ON `smart_fleet_management`.`Workshop`         TO sf_workshop_mgr;
GRANT SELECT ON `smart_fleet_management`.`ActivityType`     TO sf_workshop_mgr;
GRANT SELECT ON `smart_fleet_management`.`MechanicCertType` TO sf_workshop_mgr;
GRANT SELECT, UPDATE ON `smart_fleet_management`.`Vehicles`        TO sf_workshop_mgr;
GRANT SELECT, UPDATE ON `smart_fleet_management`.`PredictiveAlert` TO sf_workshop_mgr;
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`MaintenanceJobs`     TO sf_workshop_mgr;
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`MaintenanceActivity` TO sf_workshop_mgr;
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`ActivityMechanic`    TO sf_workshop_mgr;
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`ActivityPart`        TO sf_workshop_mgr;
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`Part`                TO sf_workshop_mgr;
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`Supplier`            TO sf_workshop_mgr;
GRANT SELECT, INSERT, UPDATE, DELETE ON `smart_fleet_management`.`SupplyPart`          TO sf_workshop_mgr;
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`WarrantyClaim`         TO sf_workshop_mgr;
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`WarrantyClaimPart`     TO sf_workshop_mgr;
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`Mechanic`              TO sf_workshop_mgr;
GRANT SELECT, INSERT, UPDATE ON `smart_fleet_management`.`MechanicCertification` TO sf_workshop_mgr;

-- mechanic: broad READS only (writes go through Part C views)
GRANT SELECT ON `smart_fleet_management`.`Vehicles`            TO sf_mechanic;
GRANT SELECT ON `smart_fleet_management`.`Workshop`            TO sf_mechanic;
GRANT SELECT ON `smart_fleet_management`.`MaintenanceJobs`     TO sf_mechanic;
GRANT SELECT ON `smart_fleet_management`.`MaintenanceActivity` TO sf_mechanic;
GRANT SELECT ON `smart_fleet_management`.`ActivityMechanic`    TO sf_mechanic;
GRANT SELECT ON `smart_fleet_management`.`ActivityType`        TO sf_mechanic;
GRANT SELECT ON `smart_fleet_management`.`ActivityPart`        TO sf_mechanic;
GRANT SELECT ON `smart_fleet_management`.`Part`                TO sf_mechanic;

-- driver: no base-table access — Part C views only.

-- 3. Login users ------------------------------------------------------
CREATE USER IF NOT EXISTS 'fleet_admin'@'localhost'    IDENTIFIED BY 'fleet_admin_pwd';
CREATE USER IF NOT EXISTS 'safety_lead'@'localhost'    IDENTIFIED BY 'safety_lead_pwd';
CREATE USER IF NOT EXISTS 'workshop_north'@'localhost' IDENTIFIED BY 'workshop_north_pwd';
CREATE USER IF NOT EXISTS 'workshop_south'@'localhost' IDENTIFIED BY 'workshop_south_pwd';
CREATE USER IF NOT EXISTS 'auditor'@'localhost'        IDENTIFIED BY 'auditor_pwd';

ALTER USER 'fleet_admin'@'localhost'    IDENTIFIED BY 'fleet_admin_pwd';
ALTER USER 'safety_lead'@'localhost'    IDENTIFIED BY 'safety_lead_pwd';
ALTER USER 'workshop_north'@'localhost' IDENTIFIED BY 'workshop_north_pwd';
ALTER USER 'workshop_south'@'localhost' IDENTIFIED BY 'workshop_south_pwd';
ALTER USER 'auditor'@'localhost'        IDENTIFIED BY 'auditor_pwd';

-- 4. Assign roles to users -------------------------------------------
GRANT sf_fleet_admin  TO 'fleet_admin'@'localhost';
GRANT sf_safety_ops   TO 'safety_lead'@'localhost';
GRANT sf_workshop_mgr TO 'workshop_north'@'localhost';
GRANT sf_workshop_mgr TO 'workshop_south'@'localhost';
GRANT sf_fleet_admin  TO 'auditor'@'localhost';

-- 5. Default roles (MariaDB: ONE role, ONE user per statement) --------
SET DEFAULT ROLE sf_fleet_admin  FOR 'fleet_admin'@'localhost';
SET DEFAULT ROLE sf_safety_ops   FOR 'safety_lead'@'localhost';
SET DEFAULT ROLE sf_workshop_mgr FOR 'workshop_north'@'localhost';
SET DEFAULT ROLE sf_workshop_mgr FOR 'workshop_south'@'localhost';
SET DEFAULT ROLE sf_fleet_admin  FOR 'auditor'@'localhost';

-- REVOKE examples:
-- REVOKE DELETE ON `smart_fleet_management`.`Part` FROM sf_workshop_mgr;
-- REVOKE sf_workshop_mgr FROM 'workshop_north'@'localhost';


-- =====================================================================
-- PART C — ROW-LEVEL ACCESS VIA VIEWS
-- =====================================================================
-- No native row-level security in MariaDB. Views filtered by
-- CURRENT_USER() give per-row control WHEN people connect with their own
-- database accounts. (If your app uses one shared connection, the app
-- must enforce these rules instead.)
-- Assumes UserAccount.Username == the database login name.

-- ---- Drivers: OWN READS --------------------------------------------
CREATE OR REPLACE VIEW `v_my_safety_events` AS
SELECT se.EventID, se.Timestamp, se.VehicleID, se.EventsTypeID,
       se.Severity, se.DepotID, se.Odometer, se.ReviewStatus
FROM `SafetyEvents` se
JOIN `UserAccount` ua ON ua.DriverID = se.DriverID
WHERE ua.Username = SUBSTRING_INDEX(USER(), '@', 1);

CREATE OR REPLACE VIEW `v_my_safety_scores` AS
SELECT dss.ScorePeriod, dss.BaseScore, dss.DeductedPoints, dss.FinalScore,
       dss.CoachingRequired, dss.Suspended
FROM `DriverSafetyScore` dss
JOIN `UserAccount` ua ON ua.DriverID = dss.DriverID
WHERE ua.Username = SUBSTRING_INDEX(USER(), '@', 1);

CREATE OR REPLACE VIEW `v_my_certifications` AS
SELECT dc.DriverCertID, ct.Name AS Certification, dc.IssueDate, dc.ExpireDate
FROM `DriverCertifications` dc
JOIN `CertificationType` ct ON ct.CertTypeID = dc.CertTypeID
JOIN `UserAccount` ua       ON ua.DriverID = dc.DriverID
WHERE ua.Username = SUBSTRING_INDEX(USER(), '@', 1);

GRANT SELECT ON `smart_fleet_management`.`v_my_safety_events`  TO sf_driver;
GRANT SELECT ON `smart_fleet_management`.`v_my_safety_scores`  TO sf_driver;
GRANT SELECT ON `smart_fleet_management`.`v_my_certifications` TO sf_driver;

-- ---- Mechanics: OWN WRITES ------------------------------------------
-- Reads stay broad (base-table grants above); writes are funnelled
-- through these filtered views.

CREATE OR REPLACE VIEW `v_my_labour` AS
SELECT am.ActivityID, am.MechanicID, am.LabourHours
FROM `ActivityMechanic` am
WHERE am.MechanicID = (
    SELECT ua.MechanicID FROM `UserAccount` ua
    WHERE ua.Username = SUBSTRING_INDEX(USER(), '@', 1)
);

CREATE OR REPLACE VIEW `v_my_activities` AS
SELECT ma.ActivityID, ma.JobID, ma.DiagnosticResult, ma.IsRepeatFault,
       ma.StartedAt, ma.CompleteAt
FROM `MaintenanceActivity` ma
WHERE ma.ActivityID IN (
    SELECT am.ActivityID
    FROM `ActivityMechanic` am
    JOIN `UserAccount` ua ON ua.MechanicID = am.MechanicID
    WHERE ua.Username = SUBSTRING_INDEX(USER(), '@', 1)
);

GRANT SELECT, UPDATE (`LabourHours`)
      ON `smart_fleet_management`.`v_my_labour` TO sf_mechanic;
GRANT SELECT, UPDATE (`DiagnosticResult`, `IsRepeatFault`, `StartedAt`, `CompleteAt`)
      ON `smart_fleet_management`.`v_my_activities` TO sf_mechanic;

-- If either column-level view grant errors on your build, use the
-- table-level fallback (still row-filtered by the view's WHERE):
-- GRANT SELECT, UPDATE ON `smart_fleet_management`.`v_my_labour`     TO sf_mechanic;
-- GRANT SELECT, UPDATE ON `smart_fleet_management`.`v_my_activities` TO sf_mechanic;

-- =====================================================================
-- Verification:
--   SHOW GRANTS FOR sf_safety_ops;
--   SHOW GRANTS FOR 'safety_lead'@'localhost';
--   -- test as a user: SET ROLE sf_mechanic; then try a SELECT/UPDATE
-- =====================================================================
