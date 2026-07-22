-- =====================================================================
-- Smart Fleet Management Database — Physical Schema (MySQL 8.0 / MariaDB 10.4+)
-- COS20031 Group 4
-- =====================================================================
-- Generated directly from the SmartFleet ERD (5 domains: Core Fleet,
-- Driver & Safety, Maintenance, Workshops & People, User Role).
--
-- ASSUMPTIONS (please review / confirm — flagged inline with "-- NOTE"):
--   1. All primary keys are surrogate INT UNSIGNED AUTO_INCREMENT columns,
--      even where the brief shows business-style codes (e.g. "D-112").
--      Natural/business identifiers (RegistrationNumber, PartNumber,
--      Username, etc.) are kept as separate UNIQUE columns.
--   2. CertificationType.Expire and MechanicCertType.Expire are modelled
--      as a BOOLEAN flag ("does this certification type require renewal
--      at all?"), because the actual per-holder issue/expiry dates are
--      already stored on DriverCertifications / MechanicCertification.
--   3. DriverSafetyScore has an added `ScorePeriod` column (CHAR(7),
--      'YYYY-MM') — NOT explicitly drawn on the ERD, but the brief
--      requires monthly scores that can be compared over time, and the
--      ERD has no other column that distinguishes one month's score row
--      from another for the same driver. Remove this column if your
--      rubric wants a byte-for-byte column match to the diagram.
--   4. MaintenanceJobs.AlertID is nullable and UNIQUE — modelled as an
--      optional 0..1 link (a job may exist without an alert; an alert
--      leads to at most one job).
--   5. Workshop.DepotID is UNIQUE — brief states "one workshop per depot".
--   6. Status / classification fields that do NOT have their own lookup
--      table on the ERD (OperationalStatus, EmploymentStatus, Severity,
--      ReviewStatus, WarrantyType, Outcome, etc.) are implemented as
--      ENUMs using the value sets given in the project brief.
--   7. Money columns use DECIMAL(12,2) (VND).
--   8. Referential actions: RESTRICT on core/history-bearing relationships
--      (per "Historical Records must remain available" requirement),
--      SET NULL on optional links, CASCADE only on true composition /
--      pure junction rows (job -> activity -> parts/mechanics/warranty,
--      role/permission/user mappings).
-- =====================================================================

DROP DATABASE IF EXISTS `smart_activitypartactivitymechanicfleet_management`;
CREATE DATABASE `smart_fleet_management`
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;
USE `smart_fleet_management`;

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

-- =====================================================================
-- DOMAIN: CORE FLEET
-- =====================================================================

-- ---------------------------------------------------------------------
-- Depots
-- ---------------------------------------------------------------------
CREATE TABLE `Depots` (
    `DepotID`      INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `City`         VARCHAR(100)    NOT NULL,
    `Address`      VARCHAR(255)    NOT NULL,
    `Name`         VARCHAR(100)    NOT NULL,
    `ContactPhone` VARCHAR(20)     NULL,
    PRIMARY KEY (`DepotID`),
    UNIQUE KEY `uq_depots_name` (`Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- VehiclesCategory (lookup)
-- ---------------------------------------------------------------------
CREATE TABLE `VehiclesCategory` (
    `CategoryID`   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `CategoryName` VARCHAR(50)     NOT NULL,
    PRIMARY KEY (`CategoryID`),
    UNIQUE KEY `uq_vehiclescategory_name` (`CategoryName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- CertificationType (lookup)
-- ---------------------------------------------------------------------
CREATE TABLE `CertificationType` (
    `CertTypeID` INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `Name`       VARCHAR(100)  NOT NULL,
    `Expire`     BOOLEAN       NOT NULL DEFAULT TRUE
        COMMENT 'Whether this certification type requires periodic renewal',
    PRIMARY KEY (`CertTypeID`),
    UNIQUE KEY `uq_certtype_name` (`Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- SafetyEventsType (lookup)
-- ---------------------------------------------------------------------
CREATE TABLE `SafetyEventsType` (
    `EventsTypeID`    INT UNSIGNED               NOT NULL AUTO_INCREMENT,
    `Name`            VARCHAR(100)                NOT NULL,
    `DefaultSeverity` ENUM('Low','Medium','High','Critical') NOT NULL,
    PRIMARY KEY (`EventsTypeID`),
    UNIQUE KEY `uq_safetyeventstype_name` (`Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- MechanicCertType (lookup)
-- ---------------------------------------------------------------------
CREATE TABLE `MechanicCertType` (
    `MecCertTypeID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `Name`          VARCHAR(100) NOT NULL,
    `Expire`        BOOLEAN      NOT NULL DEFAULT TRUE
        COMMENT 'Whether this certification type requires periodic renewal',
    PRIMARY KEY (`MecCertTypeID`),
    UNIQUE KEY `uq_mecCertType_name` (`Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- ActivityType (lookup; each activity type requires one mechanic
-- certification type, per the brief's "Required Mechanic Certification"
-- table)
-- ---------------------------------------------------------------------
CREATE TABLE `ActivityType` (
    `ActivityTypeID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `Name`            VARCHAR(100) NOT NULL,
    `MecCertTypeID`   INT UNSIGNED NOT NULL,
    PRIMARY KEY (`ActivityTypeID`),
    UNIQUE KEY `uq_activitytype_name` (`Name`),
    CONSTRAINT `fk_activitytype_mecCertType`
        FOREIGN KEY (`MecCertTypeID`) REFERENCES `MechanicCertType` (`MecCertTypeID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Vehicles
-- ---------------------------------------------------------------------
CREATE TABLE `Vehicles` (
    `VehicleID`              INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    `RegistrationNumber`     VARCHAR(20)    NOT NULL,
    `CategoryID`             INT UNSIGNED   NOT NULL,
    `Model`                  VARCHAR(100)   NOT NULL,
    `Manufacturer`           VARCHAR(100)   NOT NULL,
    `YearOfManufacture`      YEAR           NOT NULL,
    `CurrentOdometerReading` INT UNSIGNED   NOT NULL DEFAULT 0,
    `DepotID`                INT UNSIGNED   NOT NULL,
    `OperationalStatus`      ENUM('Active','Available','Under Maintenance',
                                   'Awaiting Inspection','Out of Service','Retired')
                                             NOT NULL DEFAULT 'Available',
    PRIMARY KEY (`VehicleID`),
    UNIQUE KEY `uq_vehicles_regnumber` (`RegistrationNumber`),
    KEY `idx_vehicles_status` (`OperationalStatus`),
    CONSTRAINT `fk_vehicles_category`
        FOREIGN KEY (`CategoryID`) REFERENCES `VehiclesCategory` (`CategoryID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_vehicles_depot`
        FOREIGN KEY (`DepotID`) REFERENCES `Depots` (`DepotID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
    KEY `idx_vdh_vehicle` (`VehicleID`),
    KEY `idx_vdh_depot` (`DepotID`),
    CONSTRAINT `chk_vdh_dates` CHECK (`MovedTo` IS NULL OR `MovedTo` >= `MovedFrom`),
    CONSTRAINT `fk_vdh_vehicle`
        FOREIGN KEY (`VehicleID`) REFERENCES `Vehicles` (`VehicleID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_vdh_depot`
        FOREIGN KEY (`DepotID`) REFERENCES `Depots` (`DepotID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Drivers
-- ---------------------------------------------------------------------
CREATE TABLE `Drivers` (
    `DriverID`               INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `FirstName`              VARCHAR(100)  NOT NULL,
    `LastName`               VARCHAR(100)  NOT NULL,
    `ContactInformation`     VARCHAR(255)  NULL,
    `DepotID`                INT UNSIGNED  NOT NULL,
    `LicenceType`            VARCHAR(50)   NOT NULL
        COMMENT 'Base government driving-licence class (separate from company certifications)',
    `LicenceExpiryDate`      DATE          NOT NULL,
    `EmploymentStatus`       ENUM('Active','Inactive','Suspended','Terminated')
                                            NOT NULL DEFAULT 'Active',
    `EmergencyContactDetails` VARCHAR(255) NULL,
    PRIMARY KEY (`DriverID`),
    KEY `idx_drivers_depot` (`DepotID`),
    KEY `idx_drivers_status` (`EmploymentStatus`),
    CONSTRAINT `fk_drivers_depot`
        FOREIGN KEY (`DepotID`) REFERENCES `Depots` (`DepotID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
    KEY `idx_va_vehicle` (`VehicleID`),
    KEY `idx_va_driver` (`DriverID`),
    KEY `idx_va_depot` (`DepotID`),
    CONSTRAINT `chk_va_dates` CHECK (`EndDate` IS NULL OR `EndDate` >= `StartDate`),
    CONSTRAINT `fk_va_vehicle`
        FOREIGN KEY (`VehicleID`) REFERENCES `Vehicles` (`VehicleID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_va_driver`
        FOREIGN KEY (`DriverID`) REFERENCES `Drivers` (`DriverID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_va_depot`
        FOREIGN KEY (`DepotID`) REFERENCES `Depots` (`DepotID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
-- DOMAIN: DRIVER & SAFETY
-- =====================================================================

-- ---------------------------------------------------------------------
-- DriverCertifications (full history retained — multiple rows per
-- driver/cert type over time as renewals occur)
-- ---------------------------------------------------------------------
CREATE TABLE `DriverCertifications` (
    `DriverCertID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `DriverID`     INT UNSIGNED NOT NULL,
    `CertTypeID`   INT UNSIGNED NOT NULL,
    `IssueDate`    DATE         NOT NULL,
    `ExpireDate`   DATE         NULL,
    PRIMARY KEY (`DriverCertID`),
    KEY `idx_dc_driver` (`DriverID`),
    KEY `idx_dc_certtype` (`CertTypeID`),
    CONSTRAINT `chk_dc_dates` CHECK (`ExpireDate` IS NULL OR `ExpireDate` >= `IssueDate`),
    CONSTRAINT `fk_dc_driver`
        FOREIGN KEY (`DriverID`) REFERENCES `Drivers` (`DriverID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_dc_certtype`
        FOREIGN KEY (`CertTypeID`) REFERENCES `CertificationType` (`CertTypeID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- VehicleCertRequirement (which certification types a vehicle category
-- requires — implements the Vehicle Certification Matrix)
-- ---------------------------------------------------------------------
CREATE TABLE `VehicleCertRequirement` (
    `ReqID`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `CategoryID` INT UNSIGNED NOT NULL,
    `CertTypeID` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`ReqID`),
    UNIQUE KEY `uq_vcr_category_cert` (`CategoryID`, `CertTypeID`),
    CONSTRAINT `fk_vcr_category`
        FOREIGN KEY (`CategoryID`) REFERENCES `VehiclesCategory` (`CategoryID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_vcr_certtype`
        FOREIGN KEY (`CertTypeID`) REFERENCES `CertificationType` (`CertTypeID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- DriverSafetyScore
-- ---------------------------------------------------------------------
CREATE TABLE `DriverSafetyScore` (
    `ScoreID`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `DriverID`        INT UNSIGNED NOT NULL,
    -- NOTE: ScorePeriod is an addition beyond the ERD, see header notes.
    `ScorePeriod`     CHAR(7)      NOT NULL COMMENT 'YYYY-MM the score applies to',
    `BaseScore`       SMALLINT     NOT NULL DEFAULT 100,
    `DeductedPoints`  SMALLINT     NOT NULL DEFAULT 0,
    `FinalScore`      SMALLINT     NOT NULL DEFAULT 100,
    `CoachingRequired` BOOLEAN     NOT NULL DEFAULT FALSE,
    `Suspended`       BOOLEAN      NOT NULL DEFAULT FALSE,
    `LowCount`        SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `MediumCount`     SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `HighCount`       SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    `CriticalCount`   SMALLINT UNSIGNED NOT NULL DEFAULT 0,
    PRIMARY KEY (`ScoreID`),
    UNIQUE KEY `uq_dss_driver_period` (`DriverID`, `ScorePeriod`),
    CONSTRAINT `fk_dss_driver`
        FOREIGN KEY (`DriverID`) REFERENCES `Drivers` (`DriverID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- SafetyEvents
-- ---------------------------------------------------------------------
CREATE TABLE `SafetyEvents` (
    `EventID`        INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `Timestamp`       DATETIME    NOT NULL,
    `VehicleID`       INT UNSIGNED NOT NULL,
    `DriverID`        INT UNSIGNED NOT NULL,
    `EventsTypeID`    INT UNSIGNED NOT NULL,
    `Severity`        ENUM('Low','Medium','High','Critical') NOT NULL,
    `DepotID`         INT UNSIGNED NOT NULL,
    `Odometer`        INT UNSIGNED NOT NULL,
    `ReviewRequired`  BOOLEAN      NOT NULL DEFAULT FALSE,
    `ReviewStatus`    ENUM('Not Required','Pending','In Review','Completed')
                                    NOT NULL DEFAULT 'Not Required',
    PRIMARY KEY (`EventID`),
    KEY `idx_se_driver` (`DriverID`),
    KEY `idx_se_vehicle` (`VehicleID`),
    KEY `idx_se_depot` (`DepotID`),
    KEY `idx_se_eventstype` (`EventsTypeID`),
    KEY `idx_se_severity` (`Severity`),
    KEY `idx_se_timestamp` (`Timestamp`),
    CONSTRAINT `fk_se_vehicle`
        FOREIGN KEY (`VehicleID`) REFERENCES `Vehicles` (`VehicleID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_se_driver`
        FOREIGN KEY (`DriverID`) REFERENCES `Drivers` (`DriverID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_se_eventstype`
        FOREIGN KEY (`EventsTypeID`) REFERENCES `SafetyEventsType` (`EventsTypeID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_se_depot`
        FOREIGN KEY (`DepotID`) REFERENCES `Depots` (`DepotID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- CoachingRecord
-- ---------------------------------------------------------------------
CREATE TABLE `CoachingRecord` (
    `CoachingID`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `DriverID`     INT UNSIGNED NOT NULL,
    `Reason`       VARCHAR(255) NOT NULL,
    `ScheduledDate` DATE        NOT NULL,
    `CompleteDate` DATE         NULL,
    `Outcome`      ENUM('Pending','Passed','Failed','Cancelled') NOT NULL DEFAULT 'Pending',
    `RecordType`   ENUM('Low Safety Score','Repeated High-Severity Incidents',
                         'Critical Event','Other') NOT NULL,
    `EventID`      INT UNSIGNED NULL,
    `ScoreID`      INT UNSIGNED NULL,
    PRIMARY KEY (`CoachingID`),
    KEY `idx_cr_driver` (`DriverID`),
    KEY `idx_cr_event` (`EventID`),
    KEY `idx_cr_score` (`ScoreID`),
    CONSTRAINT `chk_cr_dates` CHECK (`CompleteDate` IS NULL OR `CompleteDate` >= `ScheduledDate`),
    CONSTRAINT `fk_cr_driver`
        FOREIGN KEY (`DriverID`) REFERENCES `Drivers` (`DriverID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_cr_event`
        FOREIGN KEY (`EventID`) REFERENCES `SafetyEvents` (`EventID`)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_cr_score`
        FOREIGN KEY (`ScoreID`) REFERENCES `DriverSafetyScore` (`ScoreID`)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
-- DOMAIN: WORKSHOPS & PEOPLE
-- =====================================================================

-- ---------------------------------------------------------------------
-- Workshop (one per depot)
-- ---------------------------------------------------------------------
CREATE TABLE `Workshop` (
    `WorkshopID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `DepotID`    INT UNSIGNED NOT NULL,
    `Name`       VARCHAR(100) NOT NULL,
    `NumBays`    SMALLINT UNSIGNED NOT NULL DEFAULT 1,
    `Contacts`   VARCHAR(255) NULL,
    PRIMARY KEY (`WorkshopID`),
    UNIQUE KEY `uq_workshop_depot` (`DepotID`),
    CONSTRAINT `fk_workshop_depot`
        FOREIGN KEY (`DepotID`) REFERENCES `Depots` (`DepotID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Mechanic
-- ---------------------------------------------------------------------
CREATE TABLE `Mechanic` (
    `MechanicID`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `FirstName`        VARCHAR(100) NOT NULL,
    `LastName`         VARCHAR(100) NOT NULL,
    `WorkshopID`       INT UNSIGNED NOT NULL,
    `EmploymentStatus` ENUM('Active','Inactive','Suspended','Terminated')
                                     NOT NULL DEFAULT 'Active',
    PRIMARY KEY (`MechanicID`),
    KEY `idx_mechanic_workshop` (`WorkshopID`),
    CONSTRAINT `fk_mechanic_workshop`
        FOREIGN KEY (`WorkshopID`) REFERENCES `Workshop` (`WorkshopID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- MechanicCertification (full renewal history retained)
-- ---------------------------------------------------------------------
CREATE TABLE `MechanicCertification` (
    `MecCertID`     INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `MechanicID`    INT UNSIGNED NOT NULL,
    `MecCertTypeID` INT UNSIGNED NOT NULL,
    `IssueDate`     DATE         NOT NULL,
    `ExpireDate`    DATE         NULL,
    PRIMARY KEY (`MecCertID`),
    KEY `idx_mc_mechanic` (`MechanicID`),
    KEY `idx_mc_certtype` (`MecCertTypeID`),
    CONSTRAINT `chk_mc_dates` CHECK (`ExpireDate` IS NULL OR `ExpireDate` >= `IssueDate`),
    CONSTRAINT `fk_mc_mechanic`
        FOREIGN KEY (`MechanicID`) REFERENCES `Mechanic` (`MechanicID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_mc_certtype`
        FOREIGN KEY (`MecCertTypeID`) REFERENCES `MechanicCertType` (`MecCertTypeID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
-- DOMAIN: MAINTENANCE
-- =====================================================================

-- ---------------------------------------------------------------------
-- PredictiveAlert
-- ---------------------------------------------------------------------
CREATE TABLE `PredictiveAlert` (
    `AlertID`     INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `VehicleID`   INT UNSIGNED NOT NULL,
    `AlertType`   ENUM('Brake Wear Warning','Engine Overheating Risk','Battery Degradation',
                        'Oil Quality Deterioration','Transmission Fault Warning',
                        'Cooling System Anomaly','Tyre Pressure Irregularity','Other') NOT NULL,
    `Severity`    ENUM('Low','Medium','High','Critical') NOT NULL,
    `GeneratedAt` DATETIME     NOT NULL,
    `Status`      ENUM('New','Acknowledged','Scheduled','Escalated','Resolved')
                                NOT NULL DEFAULT 'New',
    `ResolvedAt`  DATETIME     NULL,
    PRIMARY KEY (`AlertID`),
    KEY `idx_pa_vehicle` (`VehicleID`),
    KEY `idx_pa_status` (`Status`),
    CONSTRAINT `chk_pa_dates` CHECK (`ResolvedAt` IS NULL OR `ResolvedAt` >= `GeneratedAt`),
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
    `OverallDowntime` DECIMAL(8,2) NULL COMMENT 'hours',
    `TotalCost`       DECIMAL(12,2) NULL,
    `AlertID`         INT UNSIGNED NULL,
    PRIMARY KEY (`JobID`),
    UNIQUE KEY `uq_mj_alert` (`AlertID`),
    KEY `idx_mj_vehicle` (`VehicleID`),
    KEY `idx_mj_workshop` (`WorkshopID`),
    KEY `idx_mj_dateopened` (`DateOpened`),
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
    `DiagnosticResult` TEXT        NULL,
    `IsRepeatFault`   BOOLEAN      NOT NULL DEFAULT FALSE,
    `StartedAt`       DATETIME     NOT NULL,
    `CompleteAt`      DATETIME     NULL,
    PRIMARY KEY (`ActivityID`),
    KEY `idx_ma_job` (`JobID`),
    KEY `idx_ma_activitytype` (`ActivityTypeID`),
    CONSTRAINT `chk_ma_dates` CHECK (`CompleteAt` IS NULL OR `CompleteAt` >= `StartedAt`),
    CONSTRAINT `fk_ma_job`
        FOREIGN KEY (`JobID`) REFERENCES `MaintenanceJobs` (`JobID`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_ma_activitytype`
        FOREIGN KEY (`ActivityTypeID`) REFERENCES `ActivityType` (`ActivityTypeID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- WarrantyClaim
-- ---------------------------------------------------------------------
CREATE TABLE `WarrantyClaim` (
    `ClaimID`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `ActivityID`   INT UNSIGNED NOT NULL,
    `WarrantyType` ENUM('Manufacturer','Supplier') NOT NULL,
    `Status`       ENUM('Submitted','Approved','Rejected','Completed') NOT NULL DEFAULT 'Submitted',
    `ClaimDate`    DATE         NOT NULL,
    PRIMARY KEY (`ClaimID`),
    KEY `idx_wc_activity` (`ActivityID`),
    CONSTRAINT `fk_wc_activity`
        FOREIGN KEY (`ActivityID`) REFERENCES `MaintenanceActivity` (`ActivityID`)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Part
-- ---------------------------------------------------------------------
CREATE TABLE `Part` (
    `PartID`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `PartNumber`  VARCHAR(50)  NOT NULL,
    `Description` VARCHAR(255) NULL,
    `UnitPrice`   DECIMAL(12,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (`PartID`),
    UNIQUE KEY `uq_part_number` (`PartNumber`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Supplier
-- ---------------------------------------------------------------------
CREATE TABLE `Supplier` (
    `SupplierID`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `Name`         VARCHAR(150) NOT NULL,
    `ContactInfo`  VARCHAR(255) NULL,
    `LeadTimeDays` SMALLINT UNSIGNED NULL,
    PRIMARY KEY (`SupplierID`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- SupplyPart (junction: which suppliers can supply which parts, at what
-- cost; IsPrimary marks the designated primary supplier for that part)
-- ---------------------------------------------------------------------
CREATE TABLE `SupplyPart` (
    `PartID`     INT UNSIGNED NOT NULL,
    `SupplierID` INT UNSIGNED NOT NULL,
    `UnitCost`   DECIMAL(12,2) NOT NULL,
    `IsPrimary`  BOOLEAN      NOT NULL DEFAULT FALSE,
    PRIMARY KEY (`PartID`, `SupplierID`),
    KEY `idx_sp_supplier` (`SupplierID`),
    CONSTRAINT `fk_sp_part`
        FOREIGN KEY (`PartID`) REFERENCES `Part` (`PartID`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_sp_supplier`
        FOREIGN KEY (`SupplierID`) REFERENCES `Supplier` (`SupplierID`)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- ActivityPart (junction: parts consumed by a maintenance activity)
-- ---------------------------------------------------------------------
CREATE TABLE `ActivityPart` (
    `ActivityID`      INT UNSIGNED NOT NULL,
    `PartID`          INT UNSIGNED NOT NULL,
    `QuantityUsed`    INT UNSIGNED NOT NULL DEFAULT 1,
    `UnitPriceAtTime` DECIMAL(12,2) NOT NULL,
    PRIMARY KEY (`ActivityID`, `PartID`),
    KEY `idx_ap_part` (`PartID`),
    CONSTRAINT `fk_ap_activity`
        FOREIGN KEY (`ActivityID`) REFERENCES `MaintenanceActivity` (`ActivityID`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_ap_part`
        FOREIGN KEY (`PartID`) REFERENCES `Part` (`PartID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- WarrantyClaimPart (junction: which parts a warranty claim covers)
-- ---------------------------------------------------------------------
CREATE TABLE `WarrantyClaimPart` (
    `ClaimID` INT UNSIGNED NOT NULL,
    `PartID`  INT UNSIGNED NOT NULL,
    PRIMARY KEY (`ClaimID`, `PartID`),
    KEY `idx_wcp_part` (`PartID`),
    CONSTRAINT `fk_wcp_claim`
        FOREIGN KEY (`ClaimID`) REFERENCES `WarrantyClaim` (`ClaimID`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_wcp_part`
        FOREIGN KEY (`PartID`) REFERENCES `Part` (`PartID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- ActivityMechanic (junction: mechanics working on an activity)
-- ---------------------------------------------------------------------
CREATE TABLE `ActivityMechanic` (
    `ActivityID`   INT UNSIGNED NOT NULL,
    `MechanicID`   INT UNSIGNED NOT NULL,
    `LabourHours`  DECIMAL(5,2) NOT NULL DEFAULT 0.00,
    PRIMARY KEY (`ActivityID`, `MechanicID`),
    KEY `idx_am_mechanic` (`MechanicID`),
    CONSTRAINT `fk_am_activity`
        FOREIGN KEY (`ActivityID`) REFERENCES `MaintenanceActivity` (`ActivityID`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_am_mechanic`
        FOREIGN KEY (`MechanicID`) REFERENCES `Mechanic` (`MechanicID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- =====================================================================
-- DOMAIN: USER ROLE
-- =====================================================================

-- ---------------------------------------------------------------------
-- UserAccount (optionally linked to a Driver and/or Mechanic and/or Depot,
-- e.g. depot-level admin accounts with no Driver/Mechanic record)
-- ---------------------------------------------------------------------
CREATE TABLE `UserAccount` (
    `UserID`       INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `Username`     VARCHAR(50)  NOT NULL,
    `PasswordHash` VARCHAR(255) NOT NULL,
    `IsActive`     BOOLEAN      NOT NULL DEFAULT TRUE,
    `DriverID`     INT UNSIGNED NULL,
    `MechanicID`   INT UNSIGNED NULL,
    `DepotID`      INT UNSIGNED NULL,
    PRIMARY KEY (`UserID`),
    UNIQUE KEY `uq_useraccount_username` (`Username`),
    UNIQUE KEY `uq_useraccount_driver` (`DriverID`),
    UNIQUE KEY `uq_useraccount_mechanic` (`MechanicID`),
    KEY `idx_ua_depot` (`DepotID`),
    CONSTRAINT `fk_ua_driver`
        FOREIGN KEY (`DriverID`) REFERENCES `Drivers` (`DriverID`)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_ua_mechanic`
        FOREIGN KEY (`MechanicID`) REFERENCES `Mechanic` (`MechanicID`)
        ON DELETE SET NULL ON UPDATE CASCADE,
    CONSTRAINT `fk_ua_depot`
        FOREIGN KEY (`DepotID`) REFERENCES `Depots` (`DepotID`)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Role
-- ---------------------------------------------------------------------
CREATE TABLE `Role` (
    `RoleID`   INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `RoleName` VARCHAR(50)  NOT NULL,
    PRIMARY KEY (`RoleID`),
    UNIQUE KEY `uq_role_name` (`RoleName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- Permission
-- ---------------------------------------------------------------------
CREATE TABLE `Permission` (
    `PermissionID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `TableName`    VARCHAR(100) NOT NULL,
    `Action`       ENUM('SELECT','INSERT','UPDATE','DELETE','ALL') NOT NULL,
    PRIMARY KEY (`PermissionID`),
    UNIQUE KEY `uq_permission_table_action` (`TableName`, `Action`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- UserRole (junction)
-- ---------------------------------------------------------------------
CREATE TABLE `UserRole` (
    `UserID`      INT UNSIGNED NOT NULL,
    `RoleID`      INT UNSIGNED NOT NULL,
    `GrantedDate` DATE         NOT NULL,
    PRIMARY KEY (`UserID`, `RoleID`),
    KEY `idx_ur_role` (`RoleID`),
    CONSTRAINT `fk_ur_user`
        FOREIGN KEY (`UserID`) REFERENCES `UserAccount` (`UserID`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_ur_role`
        FOREIGN KEY (`RoleID`) REFERENCES `Role` (`RoleID`)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- RolePermission (junction)
-- ---------------------------------------------------------------------
CREATE TABLE `RolePermission` (
    `RoleID`       INT UNSIGNED NOT NULL,
    `PermissionID` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`RoleID`, `PermissionID`),
    KEY `idx_rp_permission` (`PermissionID`),
    CONSTRAINT `fk_rp_role`
        FOREIGN KEY (`RoleID`) REFERENCES `Role` (`RoleID`)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT `fk_rp_permission`
        FOREIGN KEY (`PermissionID`) REFERENCES `Permission` (`PermissionID`)
        ON DELETE CASCADE ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- End of script
-- =====================================================================
