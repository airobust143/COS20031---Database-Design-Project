-- =====================================================================
-- Smart Fleet Management Database — STORED PROCEDURES & TRIGGERS
-- COS20031 Group 4 — MySQL 8.0 / MariaDB 10.4+
-- File 6 of 7. Run after 01–05 (all tables must exist first).
-- =====================================================================
-- Consolidated business-rule enforcement logic: procedures, triggers
-- and computed columns that implement the brief's requirements:
--
-- FROM 01_core_fleet_schema.sql:
--   • sp_check_vehicle_assignment_eligibility
--   • trg_va_bi_eligibility, trg_va_bu_eligibility
--
-- FROM 02_driver_safety_schema.sql:
--   • trg_dss_bi_flags, trg_dss_bu_flags
--   • trg_dss_ai_auto_coaching, trg_dss_au_auto_coaching
--   • sp_recalc_driver_safety_score
--   • trg_se_bi_review_flag
--   • trg_se_ai_recalc_and_critical
--
-- FROM 04_maintenance_schema.sql:
--   • sp_check_mechanic_certified
--   • trg_am_bi_mechanic_cert, trg_am_bu_mechanic_cert
--   • trg_ap_ai_stock
--   • trg_mj_ai_sync, trg_mj_au_sync
-- =====================================================================

USE `smart_fleet_management`;

-- =====================================================================
-- CORE FLEET DOMAIN — vehicle assignment eligibility
-- =====================================================================
-- Brief requirements enforced:
--   • "A vehicle that is currently under maintenance or marked out of
--      service cannot be assigned to a driver."
--   • "Drivers cannot be assigned to vehicles unless they hold the
--      required certifications for that vehicle category."
--   • "A driver with expired certificates cannot be assigned to a
--      vehicle."
--   • "A driver with a safety score of 50 or below cannot be assigned
--      to a vehicle until they complete safety training."
--   • (Implied) a driver whose employment/base licence is not currently
--      valid cannot be assigned either.
-- =====================================================================

DROP PROCEDURE IF EXISTS `sp_check_vehicle_assignment_eligibility`;

DELIMITER $$
CREATE PROCEDURE `sp_check_vehicle_assignment_eligibility` (
    IN p_vehicle_id INT UNSIGNED,
    IN p_driver_id  INT UNSIGNED
)
BEGIN
    DECLARE v_status        VARCHAR(30);
    DECLARE v_category_id    INT UNSIGNED;
    DECLARE v_emp_status     VARCHAR(30);
    DECLARE v_lic_expiry     DATE;
    DECLARE v_required_certs INT UNSIGNED DEFAULT 0;
    DECLARE v_held_certs     INT UNSIGNED DEFAULT 0;
    DECLARE v_suspended      BOOLEAN DEFAULT FALSE;

    -- 1) Vehicle must not be under maintenance / out of service
    SELECT `OperationalStatus`, `CategoryID`
      INTO v_status, v_category_id
    FROM `Vehicles`
    WHERE `VehicleID` = p_vehicle_id;

    IF v_status IN ('Under Maintenance', 'Out of Service') THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Vehicle is under maintenance or out of service and cannot be assigned to a driver.';
    END IF;

    -- 2) Driver must be an active employee with a currently valid base licence
    SELECT `EmploymentStatus`, `LicenceExpiryDate`
      INTO v_emp_status, v_lic_expiry
    FROM `Drivers`
    WHERE `DriverID` = p_driver_id;

    IF v_emp_status <> 'Active' THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Driver is not in Active employment status and cannot be assigned a vehicle.';
    END IF;

    IF v_lic_expiry < CURDATE() THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Driver''s base licence has expired and cannot be assigned a vehicle.';
    END IF;

    -- 3) Driver's most recent monthly safety score must not be <= 50 (Suspended)
    SELECT `Suspended` INTO v_suspended
    FROM `DriverSafetyScore`
    WHERE `DriverID` = p_driver_id
    ORDER BY `ScorePeriod` DESC
    LIMIT 1;

    IF v_suspended = TRUE THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Driver safety score is 50 or below; driver is suspended from assignment until safety training is completed.';
    END IF;

    -- 4) Driver must hold ALL certifications required for the vehicle's
    --    category (VehicleCertRequirement), each currently valid (issued,
    --    not expired).
    SELECT COUNT(*) INTO v_required_certs
    FROM `VehicleCertRequirement`
    WHERE `CategoryID` = v_category_id;

    SELECT COUNT(DISTINCT vcr.`CertTypeID`) INTO v_held_certs
    FROM `VehicleCertRequirement` vcr
    JOIN `DriverCertifications` dc
      ON dc.`CertTypeID` = vcr.`CertTypeID`
     AND dc.`DriverID`   = p_driver_id
     AND dc.`IssueDate` <= CURDATE()
     AND (dc.`ExpireDate` IS NULL OR dc.`ExpireDate` >= CURDATE())
    WHERE vcr.`CategoryID` = v_category_id;

    IF v_held_certs < v_required_certs THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Driver does not hold all currently-valid certifications required for this vehicle category.';
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_va_bi_eligibility`;
DROP TRIGGER IF EXISTS `trg_va_bu_eligibility`;

DELIMITER $$
CREATE TRIGGER `trg_va_bi_eligibility`
BEFORE INSERT ON `VehicleAssignments`
FOR EACH ROW
BEGIN
    CALL `sp_check_vehicle_assignment_eligibility`(NEW.`VehicleID`, NEW.`DriverID`);
END$$

CREATE TRIGGER `trg_va_bu_eligibility`
BEFORE UPDATE ON `VehicleAssignments`
FOR EACH ROW
BEGIN
    -- Only re-check when the vehicle or driver on the assignment actually
    -- changes; editing EndDate/IsPermanent on a still-valid assignment
    -- should not be blocked by rules meant for the moment of assignment.
    IF NOT (NEW.`VehicleID` <=> OLD.`VehicleID`) OR NOT (NEW.`DriverID` <=> OLD.`DriverID`) THEN
        CALL `sp_check_vehicle_assignment_eligibility`(NEW.`VehicleID`, NEW.`DriverID`);
    END IF;
END$$
DELIMITER ;

-- =====================================================================
-- DRIVER & SAFETY DOMAIN — safety score calculation & automation
-- =====================================================================
-- Enforces:
--   • FinalScore = 100 - DeductedPoints, floored at 0
--   • CoachingRequired = FinalScore <= 75
--   • Suspended = FinalScore <= 50
--   • Auto-log CoachingRecord when CoachingRequired becomes true
--   • High/Critical events require review
--   • Critical events auto-inactivate driver and log coaching
--   • Every SafetyEvent insert recalculates live monthly score
-- =====================================================================

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
-- MAINTENANCE DOMAIN — mechanic certification & stock/status sync
-- =====================================================================
-- Enforces:
--   • Mechanic must hold valid cert for activity type
--   • Part consumption decrements stock
--   • Opening a job sets vehicle to 'Under Maintenance'
--   • Closing a job returns vehicle to 'Available'
--   • Linking an alert to a job updates alert status to 'Scheduled'
-- =====================================================================

DROP PROCEDURE IF EXISTS `sp_check_mechanic_certified`;

DELIMITER $$
CREATE PROCEDURE `sp_check_mechanic_certified` (
    IN p_mechanic_id INT UNSIGNED,
    IN p_activity_id INT UNSIGNED
)
BEGIN
    DECLARE v_required_cert INT UNSIGNED;
    DECLARE v_held INT UNSIGNED DEFAULT 0;

    SELECT `MecCertTypeID` INTO v_required_cert
    FROM `MaintenanceActivity` ma
    JOIN `ActivityType` at ON at.`ActivityTypeID` = ma.`ActivityTypeID`
    WHERE ma.`ActivityID` = p_activity_id;

    SELECT COUNT(*) INTO v_held
    FROM `MechanicCertification`
    WHERE `MechanicID` = p_mechanic_id
      AND `MecCertTypeID` = v_required_cert
      AND `IssueDate` <= CURDATE()
      AND (`ExpireDate` IS NULL OR `ExpireDate` >= CURDATE());

    IF v_held = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Mechanic does not hold a currently-valid certification required for this activity type.';
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_am_bi_mechanic_cert`;
DROP TRIGGER IF EXISTS `trg_am_bu_mechanic_cert`;

DELIMITER $$
CREATE TRIGGER `trg_am_bi_mechanic_cert`
BEFORE INSERT ON `ActivityMechanic`
FOR EACH ROW
BEGIN
    CALL `sp_check_mechanic_certified`(NEW.MechanicID, NEW.ActivityID);
END$$

CREATE TRIGGER `trg_am_bu_mechanic_cert`
BEFORE UPDATE ON `ActivityMechanic`
FOR EACH ROW
BEGIN
    IF NOT (NEW.MechanicID <=> OLD.MechanicID) OR NOT (NEW.ActivityID <=> OLD.ActivityID) THEN
        CALL `sp_check_mechanic_certified`(NEW.MechanicID, NEW.ActivityID);
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_ap_ai_stock`;

DELIMITER $$
CREATE TRIGGER `trg_ap_ai_stock`
AFTER INSERT ON `ActivityPart`
FOR EACH ROW
BEGIN
    UPDATE `Part`
       SET `QuantityInStock` = GREATEST(0, `QuantityInStock` - NEW.QuantityUsed)
     WHERE `PartID` = NEW.PartID;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_mj_ai_sync`;
DROP TRIGGER IF EXISTS `trg_mj_au_sync`;

DELIMITER $$
CREATE TRIGGER `trg_mj_ai_sync`
AFTER INSERT ON `MaintenanceJobs`
FOR EACH ROW
BEGIN
    IF NEW.DateClosed IS NULL THEN
        UPDATE `Vehicles`
           SET `OperationalStatus` = 'Under Maintenance'
         WHERE `VehicleID` = NEW.VehicleID
           AND `OperationalStatus` <> 'Retired';
    END IF;

    IF NEW.AlertID IS NOT NULL THEN
        UPDATE `PredictiveAlert`
           SET `Status` = 'Scheduled'
         WHERE `AlertID` = NEW.AlertID
           AND `Status` IN ('New', 'Acknowledged');
    END IF;
END$$

CREATE TRIGGER `trg_mj_au_sync`
AFTER UPDATE ON `MaintenanceJobs`
FOR EACH ROW
BEGIN
    -- Job just closed: return the vehicle to Available, but only if
    -- nothing else has since moved it to a different status.
    IF OLD.DateClosed IS NULL AND NEW.DateClosed IS NOT NULL THEN
        UPDATE `Vehicles`
           SET `OperationalStatus` = 'Available'
         WHERE `VehicleID` = NEW.VehicleID
           AND `OperationalStatus` = 'Under Maintenance';
    END IF;

    -- Job just re-opened
    IF OLD.DateClosed IS NOT NULL AND NEW.DateClosed IS NULL THEN
        UPDATE `Vehicles`
           SET `OperationalStatus` = 'Under Maintenance'
         WHERE `VehicleID` = NEW.VehicleID
           AND `OperationalStatus` <> 'Retired';
    END IF;

    -- Alert newly linked after the job was created
    IF OLD.AlertID IS NULL AND NEW.AlertID IS NOT NULL THEN
        UPDATE `PredictiveAlert`
           SET `Status` = 'Scheduled'
         WHERE `AlertID` = NEW.AlertID
           AND `Status` IN ('New', 'Acknowledged');
    END IF;
END$$
DELIMITER ;

-- =====================================================================
-- End of 06_procedures_triggers.sql
-- =====================================================================
