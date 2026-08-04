-- =====================================================================
-- Smart Fleet Management Database â€” USER ROLE DOMAIN (app-level RBAC)
-- COS20031 Group 4 â€” MySQL 8.0 / MariaDB 10.4+
-- File 5 of 8. Requires 01 (Depots), 02 (Drivers), 03 (Mechanic) first,
-- since UserAccount optionally links to each of those.
-- =====================================================================
-- Tables: Role, Permission, UserAccount, UserRole, RolePermission
--
-- SCHEMA FIX IN THIS FILE â€” Permission.Description:
--   Two of the RBAC roles are deliberately *coarser* at this app level
--   than the real MariaDB grants in smartfleet_rbac.sql (safety_ops's app-level
--   "UPDATE Drivers" is really "UPDATE Drivers.EmploymentStatus only"
--   at the DB layer; mechanic's app-level "UPDATE MaintenanceActivity /
--   ActivityMechanic" is really "SELECT only, writes via v_my_labour /
--   v_my_activities views" at the DB layer). That gap is real and can't
--   be fully closed without a column/row-aware permission model, so
--   instead of leaving it silently inconsistent, Description now
--   documents the actual scope directly on the Permission row. See
--   smartfleet_rbac.sql for the authoritative enforcement.
-- =====================================================================

USE `smart_fleet_management`;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- Role
-- ---------------------------------------------------------------------
CREATE TABLE `Role` (
    `RoleID`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `RoleName` VARCHAR(50)  NOT NULL,
    PRIMARY KEY (`RoleID`),
    UNIQUE KEY `uq_role_name` (`RoleName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- Permission
-- ---------------------------------------------------------------------
CREATE TABLE `Permission` (
    `PermissionID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `TableName`    VARCHAR(64)  NOT NULL,
    `Action`       ENUM('SELECT','INSERT','UPDATE','DELETE','ALL') NOT NULL,
    `Description`  VARCHAR(255) NULL
        COMMENT 'Documents the ACTUAL enforced scope where it is narrower than TableName+Action imply (e.g. a single column, or own-rows-only via a view). See smartfleet_rbac.sql Part B/C.',
    PRIMARY KEY (`PermissionID`),
    UNIQUE KEY `uq_permission_table_action` (`TableName`, `Action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- UserAccount
-- ---------------------------------------------------------------------
CREATE TABLE `UserAccount` (
    `UserID`     INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `Username`   VARCHAR(50)  NOT NULL,
    `PasswordHash` VARCHAR(255) NOT NULL,
    `IsActive`   BOOLEAN      NOT NULL DEFAULT TRUE,
    `DriverID`   INT UNSIGNED NULL,
    `MechanicID` INT UNSIGNED NULL,
    `DepotID`    INT UNSIGNED NULL,
    PRIMARY KEY (`UserID`),
    UNIQUE KEY `uq_useraccount_username` (`Username`),
    UNIQUE KEY `uq_useraccount_driver` (`DriverID`),
    UNIQUE KEY `uq_useraccount_mechanic` (`MechanicID`),
    CONSTRAINT `chk_ua_single_person_identity` CHECK (
        NOT (`DriverID` IS NOT NULL AND `MechanicID` IS NOT NULL)
    ),
    CONSTRAINT `fk_ua_driver`
        FOREIGN KEY (`DriverID`) REFERENCES `Drivers` (`DriverID`)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_ua_mechanic`
        FOREIGN KEY (`MechanicID`) REFERENCES `Mechanic` (`MechanicID`)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_ua_depot`
        FOREIGN KEY (`DepotID`) REFERENCES `Depots` (`DepotID`)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- UserRole (junction)
-- ---------------------------------------------------------------------
CREATE TABLE `UserRole` (
    `UserID`      INT UNSIGNED NOT NULL,
    `RoleID`      INT UNSIGNED NOT NULL,
    `GrantedDate` DATE NOT NULL DEFAULT (CURRENT_DATE),
    PRIMARY KEY (`UserID`, `RoleID`),
    CONSTRAINT `fk_ur_user`
        FOREIGN KEY (`UserID`) REFERENCES `UserAccount` (`UserID`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_ur_role`
        FOREIGN KEY (`RoleID`) REFERENCES `Role` (`RoleID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- RolePermission (junction)
-- ---------------------------------------------------------------------
CREATE TABLE `RolePermission` (
    `RoleID`       INT UNSIGNED NOT NULL,
    `PermissionID` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`RoleID`, `PermissionID`),
    CONSTRAINT `fk_rp_role`
        FOREIGN KEY (`RoleID`) REFERENCES `Role` (`RoleID`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_rp_permission`
        FOREIGN KEY (`PermissionID`) REFERENCES `Permission` (`PermissionID`)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- End of 05_user_role_schema.sql
-- =====================================================================

