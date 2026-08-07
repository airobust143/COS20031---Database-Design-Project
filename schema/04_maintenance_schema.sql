
-- Requires 01 and 03 run first

-- Tables: ActivityType, PredictiveAlert, MaintenanceJobs, MaintenanceActivity, ActivityMechanic, Part, Supplier,SupplyPart, ActivityPart, WarrantyClaim, WarrantyClaimPart


USE `smart_fleet_management`;
SET FOREIGN_KEY_CHECKS = 0;

-- ActivityType (lookup) each type maps to the mechanic certification required to perform it (per the brief's certification table).

CREATE TABLE `ActivityType` (
    `ActivityTypeID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `Name` VARCHAR(100) NOT NULL,
    `MecCertTypeID` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`ActivityTypeID`),
    UNIQUE KEY `uq_activitytype_name` (`Name`),
    CONSTRAINT `fk_activitytype_certtype` FOREIGN KEY (`MecCertTypeID`) REFERENCES `MechanicCertType` (`MecCertTypeID`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- PredictiveAlert

CREATE TABLE `PredictiveAlert` (
    `AlertID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `VehicleID` INT UNSIGNED NOT NULL,
    `AlertType` ENUM(
        'Brake Wear Warning',
        'Engine Overheating Risk',
        'Battery Degradation',
        'Oil Quality Deterioration',
        'Transmission Fault Warning',
        'Cooling System Anomaly',
        'Tyre Pressure Irregularity',
        'Other'
    ) NOT NULL,
    `Severity` ENUM('Low', 'Medium', 'High', 'Critical') NOT NULL,
    `GeneratedAt` DATETIME NOT NULL,
    `Status` ENUM(
        'New',
        'Acknowledged',
        'Scheduled',
        'Escalated',
        'Resolved'
    ) NOT NULL DEFAULT 'New',
    `ResolvedAt` DATETIME NULL,
    PRIMARY KEY (`AlertID`),
    CONSTRAINT `chk_pa_resolved` CHECK (
        (
            `Status` = 'Resolved'
            AND `ResolvedAt` IS NOT NULL
        )
        OR (
            `Status` <> 'Resolved'
            AND `ResolvedAt` IS NULL
        )
    ),
    CONSTRAINT `fk_pa_vehicle` FOREIGN KEY (`VehicleID`) REFERENCES `Vehicles` (`VehicleID`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- MaintenanceJobs

CREATE TABLE `MaintenanceJobs` (
    `JobID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `VehicleID` INT UNSIGNED NOT NULL,
    `WorkshopID` INT UNSIGNED NOT NULL,
    `DateOpened` DATETIME NOT NULL,
    `DateClosed` DATETIME NULL,
    `OverallDowntime` DECIMAL(6, 2) NULL COMMENT 'Hours; typically populated on close',
    `TotalCost` DECIMAL(12, 2) NOT NULL DEFAULT 0.00 COMMENT 'VND',
    `AlertID` INT UNSIGNED NULL,
    PRIMARY KEY (`JobID`),
    UNIQUE KEY `uq_mj_alert` (`AlertID`),
    CONSTRAINT `chk_mj_dates` CHECK (
        `DateClosed` IS NULL
        OR `DateClosed` >= `DateOpened`
    ),
    CONSTRAINT `chk_mj_values` CHECK (
        `OverallDowntime` IS NULL
        OR `OverallDowntime` >= 0
    ),
    CONSTRAINT `chk_mj_cost` CHECK (`TotalCost` >= 0),
    CONSTRAINT `fk_mj_vehicle` FOREIGN KEY (`VehicleID`) REFERENCES `Vehicles` (`VehicleID`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_mj_workshop` FOREIGN KEY (`WorkshopID`) REFERENCES `Workshop` (`WorkshopID`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_mj_alert` FOREIGN KEY (`AlertID`) REFERENCES `PredictiveAlert` (`AlertID`) ON DELETE
    SET NULL ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- MaintenanceActivity

CREATE TABLE `MaintenanceActivity` (
    `ActivityID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `JobID` INT UNSIGNED NOT NULL,
    `ActivityTypeID` INT UNSIGNED NOT NULL,
    `DiagnosticResult` VARCHAR(500) NULL,
    `IsRepeatFault` BOOLEAN NOT NULL DEFAULT FALSE,
    `StartedAt` DATETIME NULL,
    `CompleteAt` DATETIME NULL,
    PRIMARY KEY (`ActivityID`),
    CONSTRAINT `chk_ma_dates` CHECK (
        `CompleteAt` IS NULL
        OR (
            `StartedAt` IS NOT NULL
            AND `CompleteAt` >= `StartedAt`
        )
    ),
    CONSTRAINT `fk_ma_job` FOREIGN KEY (`JobID`) REFERENCES `MaintenanceJobs` (`JobID`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_ma_activitytype` FOREIGN KEY (`ActivityTypeID`) REFERENCES `ActivityType` (`ActivityTypeID`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ActivityMechanic (junction table, an activity may need several mechanics,a mechanic may work multiple activities across different jobs)

CREATE TABLE `ActivityMechanic` (
    `ActivityID` INT UNSIGNED NOT NULL,
    `MechanicID` INT UNSIGNED NOT NULL,
    `LabourHours` DECIMAL(5, 2) NOT NULL,
    PRIMARY KEY (`ActivityID`, `MechanicID`),
    CONSTRAINT `chk_am_labourhours` CHECK (`LabourHours` > 0),
    CONSTRAINT `fk_am_activity` FOREIGN KEY (`ActivityID`) REFERENCES `MaintenanceActivity` (`ActivityID`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_am_mechanic` FOREIGN KEY (`MechanicID`) REFERENCES `Mechanic` (`MechanicID`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


CREATE TABLE `Part` (
    `PartID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `PartNumber` VARCHAR(50) NOT NULL,
    `Description` VARCHAR(255) NOT NULL,
    `UnitPrice` DECIMAL(12, 2) NOT NULL COMMENT 'VND, current catalogue/list price',
    `QuantityInStock` INT UNSIGNED NOT NULL DEFAULT 0,
    `ReorderThreshold` INT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`PartID`),
    UNIQUE KEY `uq_part_number` (`PartNumber`),
    CONSTRAINT `chk_part_unitprice` CHECK (`UnitPrice` >= 0)
) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Supplier

CREATE TABLE `Supplier` (
    `SupplierID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `Name` VARCHAR(150) NOT NULL,
    `ContactEmail` VARCHAR(254) NULL,
    `LeadTimeDays` SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`SupplierID`)
) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- SupplyPart (junction table, each part has one primary supplier and an optional backup, each with its own cost)

CREATE TABLE `SupplyPart` (
    `PartID` INT UNSIGNED NOT NULL,
    `SupplierID` INT UNSIGNED NOT NULL,
    `UnitCost` DECIMAL(12, 2) NOT NULL COMMENT 'VND, this supplier''s price for this part',
    `IsPrimary` BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (`PartID`, `SupplierID`),
    CONSTRAINT `chk_sp_unitcost` CHECK (`UnitCost` >= 0),
    CONSTRAINT `fk_sp_part` FOREIGN KEY (`PartID`) REFERENCES `Part` (`PartID`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_sp_supplier` FOREIGN KEY (`SupplierID`) REFERENCES `Supplier` (`SupplierID`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ActivityPart (junction table, parts consumed on an activity, price snapshotted at time of use so later catalogue/supplier price changes never rewrite historical job costs)

CREATE TABLE `ActivityPart` (
    `ActivityID` INT UNSIGNED NOT NULL,
    `PartID` INT UNSIGNED NOT NULL,
    `QuantityUsed` INT UNSIGNED NOT NULL DEFAULT 1,
    `UnitPriceAtTime` DECIMAL(12, 2) NOT NULL COMMENT 'VND, snapshot at time of use',
    PRIMARY KEY (`ActivityID`, `PartID`),
    CONSTRAINT `chk_ap_values` CHECK (
        `QuantityUsed` > 0
        AND `UnitPriceAtTime` >= 0
    ),
    CONSTRAINT `fk_ap_activity` FOREIGN KEY (`ActivityID`) REFERENCES `MaintenanceActivity` (`ActivityID`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_ap_part` FOREIGN KEY (`PartID`) REFERENCES `Part` (`PartID`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- WarrantyClaim (linked to the activity it arose from)

CREATE TABLE `WarrantyClaim` (
    `ClaimID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `ActivityID` INT UNSIGNED NOT NULL,
    `WarrantyType` ENUM('Manufacturer', 'Supplier') NOT NULL,
    `Status` ENUM('Submitted', 'Approved', 'Rejected', 'Completed') NOT NULL DEFAULT 'Submitted',
    `ClaimDate` DATE NOT NULL,
    PRIMARY KEY (`ClaimID`),
    CONSTRAINT `fk_wc_activity` FOREIGN KEY (`ActivityID`) REFERENCES `MaintenanceActivity` (`ActivityID`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- WarrantyClaimPart (junction table, a claim may cover one or more parts)

CREATE TABLE `WarrantyClaimPart` (
    `ClaimID` INT UNSIGNED NOT NULL,
    `PartID` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`ClaimID`, `PartID`),
    CONSTRAINT `fk_wcp_claim` FOREIGN KEY (`ClaimID`) REFERENCES `WarrantyClaim` (`ClaimID`) ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_wcp_part` FOREIGN KEY (`PartID`) REFERENCES `Part` (`PartID`) ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE = InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
SET FOREIGN_KEY_CHECKS = 1;


