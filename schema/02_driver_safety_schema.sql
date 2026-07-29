-- =====================================================================
-- Smart Fleet Management Database — DRIVER & SAFETY DOMAIN
-- COS20031 Group 4 — MySQL 8.0 / MariaDB 10.4+
-- File 2 of 7. Requires 01_core_fleet_schema.sql to have been run first
-- (Drivers.DepotID -> Depots, SafetyEvents.VehicleID -> Vehicles).
-- =====================================================================
-- Tables: CertificationType, SafetyEventsType, EventPenalty (new),
--         Drivers, DriverCertifications, VehicleCertRequirement,
--         DriverSafetyScore, SafetyEvents, CoachingRecord
--
-- NEW TABLE — EventPenalty:
--   The brief's "Event Penalties" table (Low/Medium/High/Critical ->
--   points deducted) was previously only an assumption baked into app
--   code. It is now a real lookup table so the point values are data,
--   not a hidden constant — consistent with "Historical Records must
--   remain available even when maintenance rules are updated" (if the
--   company changes penalty values later, past DriverSafetyScore rows
--   already store their own computed FinalScore and are unaffected).
--
-- TRIGGERS/PROCEDURES ADDED IN THIS FILE (business rules from the brief
-- that the original schema stored columns for but never enforced):
--   • SafetyEvents: High/Critical severity automatically sets
--     ReviewRequired/ReviewStatus ("High or Critical events will
--     automatically trigger a review").
--   • SafetyEvents: inserting a Critical event automatically sets the
--     driver's EmploymentStatus to 'Inactive' ("If a critical event
--     happens the driver will be made inactive and unable to be
--     assigned... until the review has been completed or he completes
--     the safety training") and logs a CoachingRecord.
--   • SafetyEvents: every insert recalculates that driver's monthly
--     DriverSafetyScore live via sp_recalc_driver_safety_score, so the
--     score is always current rather than a manually-run batch job.
--   • DriverSafetyScore: FinalScore/CoachingRequired/Suspended are
--     always derived (defensively) from BaseScore/DeductedPoints,
--     enforcing the "<=75 coaching, <=50 suspended" thresholds even if
--     a row is inserted/updated directly rather than through the
--     procedure.
--   • DriverSafetyScore: CoachingRequired becoming true automatically
--     logs a CoachingRecord (once per ScoreID).
-- =====================================================================

USE `smart_fleet_management`;
SET FOREIGN_KEY_CHECKS = 0;

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
    `DefaultSeverity` ENUM('Low','Medium','High','Critical') NOT NULL
        COMMENT 'Typical/default severity for this event type; the actual Severity is still recorded per-event on SafetyEvents, since the brief''s example log shows the same event type occurring at different severities.',
    PRIMARY KEY (`EventsTypeID`),
    UNIQUE KEY `uq_safetyeventstype_name` (`Name`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

-- ---------------------------------------------------------------------
-- EventPenalty (lookup) — NEW: implements the brief's "Event Penalties"
-- table as data rather than a hard-coded app constant.
-- ---------------------------------------------------------------------
CREATE TABLE `EventPenalty` (
    `Severity`       ENUM('Low','Medium','High','Critical') NOT NULL,
    `PointsDeducted` SMALLINT NOT NULL COMMENT 'Stored as a negative number, matching the brief''s table',
    `Description`    VARCHAR(255) NULL,
    PRIMARY KEY (`Severity`)
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
    KEY `idx_drivers_licexp` (`LicenceExpiryDate`),
    CONSTRAINT `fk_drivers_depot`
        FOREIGN KEY (`DepotID`) REFERENCES `Depots` (`DepotID`)
        ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;

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
    KEY `idx_dc_expire` (`ExpireDate`),
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
-- requires — implements the Vehicle Certification Matrix; a category
-- may need MULTIPLE cert types, all of which the driver must hold)
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

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- BUSINESS RULE ENFORCEMENT
-- =====================================================================

-- ---------------------------------------------------------------------
-- DriverSafetyScore: derive FinalScore + threshold flags defensively,
-- regardless of insert path (procedure OR direct INSERT/UPDATE).
--   FinalScore = 100 - DeductedPoints, floored at 0
--   CoachingRequired = FinalScore <= 75  ("must attend driver coaching")
--   Suspended        = FinalScore <= 50  ("cannot be assigned... until
--                       they complete safety training")
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS `trg_dss_bi_flags`;
DROP TRIGGER IF EXISTS `trg_dss_bu_flags`;

DELIMITER $$
CREATE TRIGGER `trg_dss_bi_flags`
BEFORE INSERT ON `DriverSafetyScore`
FOR EACH ROW
BEGIN
    SET NEW.FinalScore = GREATEST(0, NEW.BaseScore - NEW.DeductedPoints);
    SET NEW.CoachingRequired = (NEW.FinalScore <= 75);
    SET NEW.Suspended        = (NEW.FinalScore <= 50);
END$$

CREATE TRIGGER `trg_dss_bu_flags`
BEFORE UPDATE ON `DriverSafetyScore`
FOR EACH ROW
BEGIN
    SET NEW.FinalScore = GREATEST(0, NEW.BaseScore - NEW.DeductedPoints);
    SET NEW.CoachingRequired = (NEW.FinalScore <= 75);
    SET NEW.Suspended        = (NEW.FinalScore <= 50);
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- DriverSafetyScore: auto-log a CoachingRecord the moment a score
-- becomes "coaching required" (once per ScoreID, not spammed on every
-- recalculation within the same month).
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS `trg_dss_ai_auto_coaching`;
DROP TRIGGER IF EXISTS `trg_dss_au_auto_coaching`;

DELIMITER $$
CREATE TRIGGER `trg_dss_ai_auto_coaching`
AFTER INSERT ON `DriverSafetyScore`
FOR EACH ROW
BEGIN
    IF NEW.CoachingRequired = TRUE THEN
        INSERT INTO `CoachingRecord` (`DriverID`, `Reason`, `ScheduledDate`, `RecordType`, `ScoreID`)
        VALUES (NEW.DriverID,
                CONCAT('Automatic: monthly safety score ', NEW.FinalScore, ' for ', NEW.ScorePeriod, ' is 75 or below'),
                CURDATE(), 'Low Safety Score', NEW.ScoreID);
    END IF;
END$$

CREATE TRIGGER `trg_dss_au_auto_coaching`
AFTER UPDATE ON `DriverSafetyScore`
FOR EACH ROW
BEGIN
    IF NEW.CoachingRequired = TRUE
       AND NOT EXISTS (SELECT 1 FROM `CoachingRecord` WHERE `ScoreID` = NEW.ScoreID) THEN
        INSERT INTO `CoachingRecord` (`DriverID`, `Reason`, `ScheduledDate`, `RecordType`, `ScoreID`)
        VALUES (NEW.DriverID,
                CONCAT('Automatic: monthly safety score ', NEW.FinalScore, ' for ', NEW.ScorePeriod, ' is 75 or below'),
                CURDATE(), 'Low Safety Score', NEW.ScoreID);
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_recalc_driver_safety_score: recomputes a driver's score for one
-- calendar month straight from SafetyEvents, using EventPenalty for the
-- base per-event deduction and the brief's exact "Additional Deduction"
-- conditions:
--   • more than 3 "Excessive Speeding" events in the month -> extra -10
--   • more than 2 "Fatigue Warning" events in the month     -> extra -15
--   • any Critical event in the month                       -> extra -10
-- Result is floored at 0 (not specified in the brief; a documented
-- assumption — remove GREATEST(0, ...) if scores should go negative).
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_recalc_driver_safety_score`;

DELIMITER $$
CREATE PROCEDURE `sp_recalc_driver_safety_score` (
    IN p_driver_id INT UNSIGNED,
    IN p_period    CHAR(7)
)
BEGIN
    DECLARE v_low INT UNSIGNED DEFAULT 0;
    DECLARE v_medium INT UNSIGNED DEFAULT 0;
    DECLARE v_high INT UNSIGNED DEFAULT 0;
    DECLARE v_critical INT UNSIGNED DEFAULT 0;
    DECLARE v_speeding INT UNSIGNED DEFAULT 0;
    DECLARE v_fatigue INT UNSIGNED DEFAULT 0;
    DECLARE v_base_deduction INT DEFAULT 0;
    DECLARE v_additional_deduction INT DEFAULT 0;

    SELECT
        COALESCE(SUM(`Severity` = 'Low'), 0),
        COALESCE(SUM(`Severity` = 'Medium'), 0),
        COALESCE(SUM(`Severity` = 'High'), 0),
        COALESCE(SUM(`Severity` = 'Critical'), 0)
      INTO v_low, v_medium, v_high, v_critical
    FROM `SafetyEvents`
    WHERE `DriverID` = p_driver_id
      AND DATE_FORMAT(`Timestamp`, '%Y-%m') = p_period;

    SELECT COUNT(*) INTO v_speeding
    FROM `SafetyEvents` se
    JOIN `SafetyEventsType` t ON t.`EventsTypeID` = se.`EventsTypeID`
    WHERE se.`DriverID` = p_driver_id
      AND DATE_FORMAT(se.`Timestamp`, '%Y-%m') = p_period
      AND t.`Name` = 'Excessive Speeding';

    SELECT COUNT(*) INTO v_fatigue
    FROM `SafetyEvents` se
    JOIN `SafetyEventsType` t ON t.`EventsTypeID` = se.`EventsTypeID`
    WHERE se.`DriverID` = p_driver_id
      AND DATE_FORMAT(se.`Timestamp`, '%Y-%m') = p_period
      AND t.`Name` = 'Fatigue Warning';

    SET v_base_deduction =
          v_low      * (SELECT ABS(`PointsDeducted`) FROM `EventPenalty` WHERE `Severity` = 'Low')
        + v_medium   * (SELECT ABS(`PointsDeducted`) FROM `EventPenalty` WHERE `Severity` = 'Medium')
        + v_high     * (SELECT ABS(`PointsDeducted`) FROM `EventPenalty` WHERE `Severity` = 'High')
        + v_critical * (SELECT ABS(`PointsDeducted`) FROM `EventPenalty` WHERE `Severity` = 'Critical');

    IF v_speeding > 3 THEN SET v_additional_deduction = v_additional_deduction + 10; END IF;
    IF v_fatigue  > 2 THEN SET v_additional_deduction = v_additional_deduction + 15; END IF;
    IF v_critical >= 1 THEN SET v_additional_deduction = v_additional_deduction + 10; END IF;

    INSERT INTO `DriverSafetyScore`
        (`DriverID`, `ScorePeriod`, `BaseScore`, `DeductedPoints`,
         `LowCount`, `MediumCount`, `HighCount`, `CriticalCount`)
    VALUES
        (p_driver_id, p_period, 100, v_base_deduction + v_additional_deduction,
         v_low, v_medium, v_high, v_critical)
    ON DUPLICATE KEY UPDATE
        `DeductedPoints` = v_base_deduction + v_additional_deduction,
        `LowCount` = v_low, `MediumCount` = v_medium,
        `HighCount` = v_high, `CriticalCount` = v_critical;
        -- FinalScore/CoachingRequired/Suspended are recomputed by
        -- trg_dss_bi_flags / trg_dss_bu_flags automatically.
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- SafetyEvents: High/Critical severity automatically requires review.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS `trg_se_bi_review_flag`;

DELIMITER $$
CREATE TRIGGER `trg_se_bi_review_flag`
BEFORE INSERT ON `SafetyEvents`
FOR EACH ROW
BEGIN
    IF NEW.Severity IN ('High', 'Critical') THEN
        SET NEW.ReviewRequired = TRUE;
        SET NEW.ReviewStatus = 'Pending';
    ELSE
        SET NEW.ReviewRequired = FALSE;
        SET NEW.ReviewStatus = 'Not Required';
    END IF;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- SafetyEvents: after every insert — (a) recalculate that driver's
-- live monthly score, (b) on a Critical event, auto-inactivate the
-- driver and log a CoachingRecord.
-- ---------------------------------------------------------------------
DROP TRIGGER IF EXISTS `trg_se_ai_recalc_and_critical`;

DELIMITER $$
CREATE TRIGGER `trg_se_ai_recalc_and_critical`
AFTER INSERT ON `SafetyEvents`
FOR EACH ROW
BEGIN
    CALL `sp_recalc_driver_safety_score`(NEW.DriverID, DATE_FORMAT(NEW.`Timestamp`, '%Y-%m'));

    IF NEW.Severity = 'Critical' THEN
        UPDATE `Drivers`
           SET `EmploymentStatus` = 'Inactive'
         WHERE `DriverID` = NEW.DriverID
           AND `EmploymentStatus` = 'Active';

        INSERT INTO `CoachingRecord` (`DriverID`, `Reason`, `ScheduledDate`, `RecordType`, `EventID`)
        VALUES (NEW.DriverID,
                CONCAT('Automatic: critical safety event #', NEW.EventID, ' recorded'),
                CURDATE(), 'Critical Event', NEW.EventID);
    END IF;
END$$
DELIMITER ;

-- =====================================================================
-- End of 02_driver_safety_schema.sql
-- =====================================================================
