-- =====================================================================
-- Smart Fleet Management Database â€” CORE FLEET DOMAIN
-- COS20031 Group 4 â€” MySQL 8.0 / MariaDB 10.4+
-- File 1. Run in numeric order.
-- =====================================================================
-- Tables: Depots, VehiclesCategory, VehicleModel, Vehicles, VehiclesDepotHistory,
--         VehicleAssignments
--
-- NOTE ON LOAD ORDER / CROSS-DOMAIN FOREIGN KEYS:
--   VehicleAssignments.DriverID references Drivers, which is defined in
--   02_driver_safety_schema.sql (a *later* file). This is intentional: it mirrors the ERD, which places VehicleAssignments in the Core
--   Fleet domain. FOREIGN_KEY_CHECKS=0 lets MySQL/MariaDB create the
--   constraint before the referenced table exists; this has been
--   verified to work (tables created out of order, checks re-enabled,
--   constraint still enforces correctly once all files have loaded).
--   Do not INSERT real data until all schema table files (01-05) have run.
--
-- NOTE ON THE ELIGIBILITY TRIGGER:
--   sp_check_vehicle_assignment_eligibility queries Drivers,
--   DriverCertifications, VehicleCertRequirement and DriverSafetyScore
--   â€” all defined in 02_driver_safety_schema.sql. MySQL/MariaDB does
--   NOT validate table existence inside trigger/procedure bodies at
--   CREATE time (only at CALL/execution time), so this is safe as long
--   as file 02 has been loaded before any row is ever inserted into
--   VehicleAssignments.
-- =====================================================================

-- ---------------------------------------------------------------------
-- BUG FIX: the original script's DROP DATABASE targeted a garbled name
-- (`smart_activitypartactivitymechanicfleet_management`, apparently a
-- leftover from search-and-replace) instead of the real database, so
-- re-running it failed on CREATE DATABASE. Fixed here.
-- ---------------------------------------------------------------------
DROP DATABASE IF EXISTS `smart_fleet_management`;
CREATE DATABASE IF NOT EXISTS `smart_fleet_management` DEFAULT CHARACTER SET utf8mb4 DEFAULT COLLATE utf8mb4_unicode_ci;
USE `smart_fleet_management`;

SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- Depots
-- ---------------------------------------------------------------------
CREATE TABLE `Depots` (
    `DepotID`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `Name`          VARCHAR(100) NOT NULL,
    `StreetAddress` VARCHAR(150) NOT NULL,
    `District`      VARCHAR(100) NOT NULL,
    `City`          VARCHAR(100) NOT NULL,
    `ContactPhone`  VARCHAR(20)  NULL,
    PRIMARY KEY (`DepotID`),
    UNIQUE KEY `uq_depots_name` (`Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- VehiclesCategory (lookup)
-- ---------------------------------------------------------------------
CREATE TABLE `VehiclesCategory` (
    `CategoryID`   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `CategoryName` VARCHAR(50)     NOT NULL,
    PRIMARY KEY (`CategoryID`),
    UNIQUE KEY `uq_vehiclescategory_name` (`CategoryName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- VehicleModel
-- ---------------------------------------------------------------------
CREATE TABLE `VehicleModel` (
    `ModelID`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `ModelName`    VARCHAR(100) NOT NULL,
    `Manufacturer` VARCHAR(100) NOT NULL,
    PRIMARY KEY (`ModelID`),
    UNIQUE KEY `uq_vehiclemodel_manufacturer_name` (`Manufacturer`, `ModelName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- Vehicles
-- ---------------------------------------------------------------------
CREATE TABLE `Vehicles` (
    `VehicleID`              INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    `RegistrationNumber`     VARCHAR(20)    NOT NULL,
    `CategoryID`             INT UNSIGNED   NOT NULL,
    `ModelID`                INT UNSIGNED   NOT NULL,   -- replaces Model + Manufacturer
    `YearOfManufacture`      YEAR           NOT NULL,
    `CurrentOdometerReading` INT UNSIGNED   NOT NULL DEFAULT 0,
    `DepotID`                INT UNSIGNED   NOT NULL,
    `OperationalStatus`      ENUM('Active','Available','Under Maintenance',
                                   'Awaiting Inspection','Out of Service','Retired')
                                             NOT NULL DEFAULT 'Available',
    PRIMARY KEY (`VehicleID`),
    UNIQUE KEY `uq_vehicles_regnumber` (`RegistrationNumber`),
    CONSTRAINT `fk_vehicles_category`
        FOREIGN KEY (`CategoryID`) REFERENCES `VehiclesCategory` (`CategoryID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_vehicles_model`
        FOREIGN KEY (`ModelID`) REFERENCES `VehicleModel` (`ModelID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_vehicles_depot`
        FOREIGN KEY (`DepotID`) REFERENCES `Depots` (`DepotID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- ---------------------------------------------------------------------
-- VehiclesDepotHistory
-- MovedFrom / MovedTo interpreted as the datetime range this vehicle
-- was stationed at DepotID (MovedTo is NULL while still assigned there).
-- ---------------------------------------------------------------------
CREATE TABLE `VehiclesDepotHistory` (
    `HistoryID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `VehicleID` INT UNSIGNED NOT NULL,
    `DepotID`   INT UNSIGNED NOT NULL,
    `MovedFrom` DATETIME     NOT NULL,
    `MovedTo`   DATETIME     NULL,
    PRIMARY KEY (`HistoryID`),
    CONSTRAINT `chk_vdh_dates` CHECK (`MovedTo` IS NULL OR `MovedTo` >= `MovedFrom`),
    CONSTRAINT `fk_vdh_vehicle`
        FOREIGN KEY (`VehicleID`) REFERENCES `Vehicles` (`VehicleID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_vdh_depot`
        FOREIGN KEY (`DepotID`) REFERENCES `Depots` (`DepotID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------------------
-- VehicleAssignments
-- ---------------------------------------------------------------------
CREATE TABLE `VehicleAssignments` (
    `AssignmentID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `VehicleID`    INT UNSIGNED NOT NULL,
    `DriverID`     INT UNSIGNED NOT NULL,
    `StartDate`    DATE         NOT NULL,
    `EndDate`      DATE         NULL,
    `IsPermanent`  BOOLEAN      NOT NULL DEFAULT FALSE,
    `DepotID`      INT UNSIGNED NOT NULL,
    PRIMARY KEY (`AssignmentID`),
    CONSTRAINT `chk_va_dates` CHECK (
        (`EndDate` IS NULL OR `EndDate` >= `StartDate`)
        AND (`IsPermanent` = FALSE OR `EndDate` IS NULL)
    ),
    CONSTRAINT `fk_va_vehicle`
        FOREIGN KEY (`VehicleID`) REFERENCES `Vehicles` (`VehicleID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_va_driver`
        FOREIGN KEY (`DriverID`) REFERENCES `Drivers` (`DriverID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_va_depot`
        FOREIGN KEY (`DepotID`) REFERENCES `Depots` (`DepotID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- End of 01_core_fleet_schema.sql
-- =====================================================================

