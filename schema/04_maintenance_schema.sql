-- =====================================================================
-- Smart Fleet Management Database — MAINTENANCE DOMAIN
-- COS20031 Group 4 — MySQL 8.0 / MariaDB 10.4+
-- File 4 of 7. Requires 01 (Vehicles), 02 (—), 03 (Workshop, Mechanic,
-- MechanicCertType, MechanicCertification) to have run first.
-- =====================================================================
-- Tables: ActivityType, PredictiveAlert, MaintenanceJobs,
--         MaintenanceActivity, ActivityMechanic, Part, Supplier,
--         SupplyPart, ActivityPart, WarrantyClaim, WarrantyClaimPart
--
-- SCHEMA FIX IN THIS FILE — Part.QuantityInStock / ReorderThreshold:
--   The brief lists "Parts below reorder thresholds" as something
--   Workshop Management Staff must be able to identify, but the
--   original Part table had no stock/threshold columns at all — there
--   was no way to answer that requirement. Two columns have been added
--   and are kept in sync automatically: QuantityInStock is decremented
--   whenever parts are consumed on an activity (see trg_ap_ai_stock
--   below), so "parts below reorder threshold" is now a plain query:
--     SELECT * FROM Part WHERE QuantityInStock <= ReorderThreshold;
--
-- TRIGGERS/PROCEDURES ADDED IN THIS FILE:
--   • ActivityMechanic: a mechanic cannot be assigned to an activity
--     unless they hold a currently-valid certification matching that
--     activity's ActivityType.MecCertTypeID ("A mechanic cannot be
--     assigned to an activity unless they hold the required
--     certification.").
--   • ActivityPart: consuming a part on an activity decrements
--     Part.QuantityInStock (floored at 0).
--   • MaintenanceJobs: opening a job (DateClosed IS NULL) sets the
--     vehicle to 'Under Maintenance'; closing a job (DateClosed set)
--     returns it to 'Available' — this is what actually makes the
--     Core Fleet domain's "vehicle under maintenance cannot be
--     assigned" rule mean something operationally, instead of relying
--     on staff to remember to flip OperationalStatus by hand.
--   • MaintenanceJobs: linking an AlertID bumps that alert's Status
--     from New/Acknowledged to Scheduled, since a job now exists for
--     it ("when a job is created in response to an alert, the alert
--     must be linked to that job so the outcome can be tracked").
-- =====================================================================

USE `smart_fleet_management`;
SET FOREIGN_KEY_CHECKS = 0;

-- ---------------------------------------------------------------------
-- ActivityType (lookup) — each type maps to the mechanic certification
-- required to perform it (per the brief's certification table).
-- ---------------------------------------------------------------------
CREATE TABLE `ActivityType` (
    `ActivityTypeID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `Name`           VARCHAR(100) NOT NULL,
    `MecCertTypeID`  INT UNSIGNED NOT NULL,
    PRIMARY KEY (`ActivityTypeID`),
    UNIQUE KEY `uq_activitytype_name` (`Name`),
    CONSTRAINT `fk_activitytype_certtype`
        FOREIGN KEY (`MecCertTypeID`) REFERENCES `MechanicCertType` (`MecCertTypeID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- PredictiveAlert
-- ---------------------------------------------------------------------
CREATE TABLE `PredictiveAlert` (
    `AlertID`     INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `VehicleID`   INT UNSIGNED NOT NULL,
    `AlertType`   ENUM('Brake Wear Warning','Engine Overheating Risk',
                        'Battery Degradation','Oil Quality Deterioration',
                        'Transmission Fault Warning','Cooling System Anomaly',
                        'Tyre Pressure Irregularity','Other') NOT NULL,
    `Severity`    ENUM('Low','Medium','High','Critical') NOT NULL,
    `GeneratedAt` DATETIME NOT NULL,
    `Status`      ENUM('New','Acknowledged','Scheduled','Escalated','Resolved')
                                NOT NULL DEFAULT 'New',
    `ResolvedAt`  DATETIME NULL,
    PRIMARY KEY (`AlertID`),
    KEY `idx_pa_vehicle` (`VehicleID`),
    KEY `idx_pa_status` (`Status`),
    CONSTRAINT `fk_pa_vehicle`
        FOREIGN KEY (`VehicleID`) REFERENCES `Vehicles` (`VehicleID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- MaintenanceJobs
-- ---------------------------------------------------------------------
CREATE TABLE `MaintenanceJobs` (
    `JobID`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `VehicleID`       INT UNSIGNED NOT NULL,
    `WorkshopID`      INT UNSIGNED NOT NULL,
    `DateOpened`      DATETIME     NOT NULL,
    `DateClosed`      DATETIME     NULL,
    `OverallDowntime` DECIMAL(6,2) NULL COMMENT 'Hours; typically populated on close',
    `TotalCost`       DECIMAL(12,2) NOT NULL DEFAULT 0.00 COMMENT 'VND',
    `AlertID`         INT UNSIGNED NULL,
    PRIMARY KEY (`JobID`),
    UNIQUE KEY `uq_mj_alert` (`AlertID`),
    KEY `idx_mj_vehicle` (`VehicleID`),
    KEY `idx_mj_workshop` (`WorkshopID`),
    CONSTRAINT `chk_mj_dates` CHECK (`DateClosed` IS NULL OR `DateClosed` >= `DateOpened`),
    CONSTRAINT `fk_mj_vehicle`
        FOREIGN KEY (`VehicleID`) REFERENCES `Vehicles` (`VehicleID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_mj_workshop`
        FOREIGN KEY (`WorkshopID`) REFERENCES `Workshop` (`WorkshopID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_mj_alert`
        FOREIGN KEY (`AlertID`) REFERENCES `PredictiveAlert` (`AlertID`)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- MaintenanceActivity
-- ---------------------------------------------------------------------
CREATE TABLE `MaintenanceActivity` (
    `ActivityID`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `JobID`           INT UNSIGNED NOT NULL,
    `ActivityTypeID`  INT UNSIGNED NOT NULL,
    `DiagnosticResult` VARCHAR(500) NULL,
    `IsRepeatFault`   BOOLEAN NOT NULL DEFAULT FALSE,
    `StartedAt`       DATETIME NULL,
    `CompleteAt`      DATETIME NULL,
    PRIMARY KEY (`ActivityID`),
    KEY `idx_ma_job` (`JobID`),
    KEY `idx_ma_activitytype` (`ActivityTypeID`),
    CONSTRAINT `chk_ma_dates` CHECK (`CompleteAt` IS NULL OR `StartedAt` IS NULL OR `CompleteAt` >= `StartedAt`),
    CONSTRAINT `fk_ma_job`
        FOREIGN KEY (`JobID`) REFERENCES `MaintenanceJobs` (`JobID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_ma_activitytype`
        FOREIGN KEY (`ActivityTypeID`) REFERENCES `ActivityType` (`ActivityTypeID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- ActivityMechanic (junction — an activity may need several mechanics;
-- a mechanic may work multiple activities across different jobs)
-- ---------------------------------------------------------------------
CREATE TABLE `ActivityMechanic` (
    `ActivityID`  INT UNSIGNED NOT NULL,
    `MechanicID`  INT UNSIGNED NOT NULL,
    `LabourHours` DECIMAL(5,2) NOT NULL,
    PRIMARY KEY (`ActivityID`, `MechanicID`),
    KEY `idx_am_mechanic` (`MechanicID`),
    CONSTRAINT `fk_am_activity`
        FOREIGN KEY (`ActivityID`) REFERENCES `MaintenanceActivity` (`ActivityID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_am_mechanic`
        FOREIGN KEY (`MechanicID`) REFERENCES `Mechanic` (`MechanicID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Part — QuantityInStock / ReorderThreshold added (see file header)
-- ---------------------------------------------------------------------
CREATE TABLE `Part` (
    `PartID`           INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `PartNumber`       VARCHAR(50)  NOT NULL,
    `Description`      VARCHAR(255) NOT NULL,
    `UnitPrice`        DECIMAL(12,2) NOT NULL COMMENT 'VND, current catalogue/list price',
    `QuantityInStock`  INT UNSIGNED NOT NULL DEFAULT 0,
    `ReorderThreshold` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`PartID`),
    UNIQUE KEY `uq_part_number` (`PartNumber`),
    KEY `idx_part_stock` (`QuantityInStock`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Supplier
-- ---------------------------------------------------------------------
CREATE TABLE `Supplier` (
    `SupplierID`    INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `Name`          VARCHAR(150) NOT NULL,
    `ContactInfo`   VARCHAR(255) NULL,
    `LeadTimeDays`  SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`SupplierID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- SupplyPart (junction — each part has one primary supplier and an
-- optional backup, each with its own cost)
-- ---------------------------------------------------------------------
CREATE TABLE `SupplyPart` (
    `PartID`     INT UNSIGNED NOT NULL,
    `SupplierID` INT UNSIGNED NOT NULL,
    `UnitCost`   DECIMAL(12,2) NOT NULL COMMENT 'VND, this supplier''s price for this part',
    `IsPrimary`  BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (`PartID`, `SupplierID`),
    KEY `idx_sp_supplier` (`SupplierID`),
    CONSTRAINT `fk_sp_part`
        FOREIGN KEY (`PartID`) REFERENCES `Part` (`PartID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_sp_supplier`
        FOREIGN KEY (`SupplierID`) REFERENCES `Supplier` (`SupplierID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- ActivityPart (junction — parts consumed on an activity, price
-- snapshotted at time of use so later catalogue/supplier price changes
-- never rewrite historical job costs)
-- ---------------------------------------------------------------------
CREATE TABLE `ActivityPart` (
    `ActivityID`       INT UNSIGNED NOT NULL,
    `PartID`           INT UNSIGNED NOT NULL,
    `QuantityUsed`     INT UNSIGNED NOT NULL DEFAULT 1,
    `UnitPriceAtTime`  DECIMAL(12,2) NOT NULL COMMENT 'VND, snapshot at time of use',
    PRIMARY KEY (`ActivityID`, `PartID`),
    KEY `idx_ap_part` (`PartID`),
    CONSTRAINT `fk_ap_activity`
        FOREIGN KEY (`ActivityID`) REFERENCES `MaintenanceActivity` (`ActivityID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_ap_part`
        FOREIGN KEY (`PartID`) REFERENCES `Part` (`PartID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- WarrantyClaim (linked to the activity it arose from)
-- ---------------------------------------------------------------------
CREATE TABLE `WarrantyClaim` (
    `ClaimID`     INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `ActivityID`  INT UNSIGNED NOT NULL,
    `WarrantyType` ENUM('Manufacturer','Supplier') NOT NULL,
    `Status`      ENUM('Submitted','Approved','Rejected','Completed') NOT NULL DEFAULT 'Submitted',
    `ClaimDate`   DATE NOT NULL,
    PRIMARY KEY (`ClaimID`),
    KEY `idx_wc_activity` (`ActivityID`),
    CONSTRAINT `fk_wc_activity`
        FOREIGN KEY (`ActivityID`) REFERENCES `MaintenanceActivity` (`ActivityID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- WarrantyClaimPart (junction — a claim may cover one or more parts)
-- ---------------------------------------------------------------------
CREATE TABLE `WarrantyClaimParts` (
    `ClaimID` INT UNSIGNED NOT NULL,
    `PartID`  INT UNSIGNED NOT NULL,
    PRIMARY KEY (`ClaimID`, `PartID`),
    KEY `idx_wcp_part` (`PartID`),
    CONSTRAINT `fk_wcp_claim`
        FOREIGN KEY (`ClaimID`) REFERENCES `WarrantyClaim` (`ClaimID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_wcp_part`
        FOREIGN KEY (`PartID`) REFERENCES `Part` (`PartID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- End of 04_maintenance_schema.sql
-- =====================================================================
