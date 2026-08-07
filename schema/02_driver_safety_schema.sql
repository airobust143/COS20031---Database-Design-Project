
-- Requires 01_core_fleet_schema.sql to run first


-- Tables: CertificationType, SafetyEventsType, Drivers, DriverCertifications, VehicleCertRequirement, DriverSafetyScore, SafetyEvents, CoachingRecord



USE `smart_fleet_management`;
SET FOREIGN_KEY_CHECKS = 0;


-- CertificationType (lookup)

CREATE TABLE `CertificationType` (
    `CertTypeID` INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `Name`       VARCHAR(100)  NOT NULL,
    `Expire`     BOOLEAN       NOT NULL DEFAULT TRUE
        COMMENT 'Whether this certification type requires periodic renewal',
    PRIMARY KEY (`CertTypeID`),
    UNIQUE KEY `uq_certtype_name` (`Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- SafetyEventsType (lookup)

CREATE TABLE `SafetyEventsType` (
    `EventsTypeID`    INT UNSIGNED               NOT NULL AUTO_INCREMENT,
    `Name`            VARCHAR(100)                NOT NULL,
    `DefaultSeverity` ENUM('Low','Medium','High','Critical') NOT NULL
        COMMENT 'Typical/default severity for this event type; the actual Severity is still recorded per-event on SafetyEvents, since the brief''s example log shows the same event type occurring at different severities.',
    PRIMARY KEY (`EventsTypeID`),
    UNIQUE KEY `uq_safetyeventstype_name` (`Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- Drivers

CREATE TABLE `Drivers` (
    `DriverID`               INT UNSIGNED  NOT NULL AUTO_INCREMENT,
    `FirstName`              VARCHAR(100)  NOT NULL,
    `LastName`               VARCHAR(100)  NOT NULL,
    `ContactPhoneNumber`     VARCHAR(20)   NULL,
    `DepotID`                INT UNSIGNED  NOT NULL,
    `LicenceType`            VARCHAR(50)   NOT NULL
        COMMENT 'Base government driving-licence class (separate from company certifications)',
    `LicenceExpiryDate`      DATE          NOT NULL,
    `EmploymentStatus`       ENUM('Active','Inactive','Suspended','Terminated')
                                            NOT NULL DEFAULT 'Active',
    `EmergencyContactPhone`  VARCHAR(20)   NULL,
    PRIMARY KEY (`DriverID`),
    CONSTRAINT `fk_drivers_depot`
        FOREIGN KEY (`DepotID`) REFERENCES `Depots` (`DepotID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- DriverCertifications 

CREATE TABLE `DriverCertifications` (
    `DriverCertID` INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `DriverID`     INT UNSIGNED NOT NULL,
    `CertTypeID`   INT UNSIGNED NOT NULL,
    `IssueDate`    DATE         NOT NULL,
    `ExpireDate`   DATE         NULL,
    PRIMARY KEY (`DriverCertID`),
    CONSTRAINT `chk_dc_dates` CHECK (`ExpireDate` IS NULL OR `ExpireDate` >= `IssueDate`),
    CONSTRAINT `fk_dc_driver`
        FOREIGN KEY (`DriverID`) REFERENCES `Drivers` (`DriverID`)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT `fk_dc_certtype`
        FOREIGN KEY (`CertTypeID`) REFERENCES `CertificationType` (`CertTypeID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- VehicleCertRequirement 

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- DriverSafetyScore

CREATE TABLE `DriverSafetyScore` (
    `ScoreID`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `DriverID`        INT UNSIGNED NOT NULL,
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
    CONSTRAINT `chk_dss_period` CHECK (`ScorePeriod` REGEXP '^[0-9]{4}-(0[1-9]|1[0-2])$'),
    CONSTRAINT `chk_dss_scores` CHECK (`BaseScore` >= 0 AND `DeductedPoints` >= 0 AND `FinalScore` >= 0),
    CONSTRAINT `fk_dss_driver`
        FOREIGN KEY (`DriverID`) REFERENCES `Drivers` (`DriverID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- SafetyEvents
-
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
    CONSTRAINT `chk_se_review_state` CHECK (
        (`ReviewRequired` = FALSE AND `ReviewStatus` = 'Not Required') OR
        (`ReviewRequired` = TRUE AND `ReviewStatus` IN ('Pending','In Review','Completed'))
    ),
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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- CoachingRecord

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
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

SET FOREIGN_KEY_CHECKS = 1;



