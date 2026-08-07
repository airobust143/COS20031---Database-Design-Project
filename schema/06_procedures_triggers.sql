-- =====================================================================
-- Smart Fleet Management Database â€” STORED PROCEDURES & TRIGGERS
-- COS20031 Group 4 â€” MySQL 8.0 / MariaDB 10.4+
-- File 6. Run after 01â€“05 (all tables must exist first).
-- =====================================================================
-- Consolidated business-rule enforcement logic: procedures, triggers
-- and computed columns that implement the brief's requirements:
--
-- FROM 01_core_fleet_schema.sql:
--   â€¢ sp_check_vehicle_assignment_eligibility
--   â€¢ trg_va_bi_eligibility, trg_va_bu_eligibility
--
-- FROM 02_driver_safety_schema.sql:
--   â€¢ trg_dss_bi_flags, trg_dss_bu_flags
--   â€¢ trg_dss_ai_auto_coaching, trg_dss_au_auto_coaching
--   â€¢ sp_recalc_driver_safety_score
--   â€¢ trg_se_bi_review_flag / trg_se_bu_review_flag
--   â€¢ trg_se_ai_recalc_and_critical / trg_se_au_recalc / trg_se_ad_recalc
--
-- FROM 04_maintenance_schema.sql:
--   â€¢ sp_check_mechanic_certified
--   â€¢ trg_am_bi_mechanic_cert, trg_am_bu_mechanic_cert
--   â€¢ trg_ap_bi_stock / trg_ap_bu_stock / trg_ap_ad_stock
--   â€¢ trg_mj_ai_sync, trg_mj_au_sync
-- =====================================================================

USE `smart_fleet_management`;

-- =====================================================================
-- CORE FLEET DOMAIN â€” vehicle assignment eligibility
-- =====================================================================
-- Brief requirements enforced:
--   â€¢ "A vehicle that is currently under maintenance or marked out of
--      service cannot be assigned to a driver."
--   â€¢ "Drivers cannot be assigned to vehicles unless they hold the
--      required certifications for that vehicle category."
--   â€¢ "A driver with expired certificates cannot be assigned to a
--      vehicle."
--   â€¢ "A driver with a safety score of 50 or below cannot be assigned
--      to a vehicle until they complete safety training."
--   â€¢ (Implied) a driver whose employment/base licence is not currently
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

    IF NOT EXISTS (SELECT 1 FROM `Vehicles` WHERE `VehicleID` = p_vehicle_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle does not exist.';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM `Drivers` WHERE `DriverID` = p_driver_id) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Driver does not exist.';
    END IF;

    -- 1) Vehicle must not be under maintenance / out of service
    SELECT `OperationalStatus`, `CategoryID`
      INTO v_status, v_category_id
    FROM `Vehicles`
    WHERE `VehicleID` = p_vehicle_id;

    IF v_status NOT IN ('Active', 'Available') THEN
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
    IF EXISTS (
        SELECT 1 FROM `VehicleAssignments` va
        WHERE (va.VehicleID = NEW.VehicleID OR va.DriverID = NEW.DriverID)
          AND va.StartDate <= COALESCE(NEW.EndDate, '9999-12-31')
          AND NEW.StartDate <= COALESCE(va.EndDate, '9999-12-31')
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle or driver has an overlapping assignment.';
    END IF;
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
    IF EXISTS (
        SELECT 1 FROM `VehicleAssignments` va
        WHERE va.AssignmentID <> OLD.AssignmentID
          AND (va.VehicleID = NEW.VehicleID OR va.DriverID = NEW.DriverID)
          AND va.StartDate <= COALESCE(NEW.EndDate, '9999-12-31')
          AND NEW.StartDate <= COALESCE(va.EndDate, '9999-12-31')
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle or driver has an overlapping assignment.';
    END IF;
END$$
DELIMITER ;

-- =====================================================================
-- DRIVER & SAFETY DOMAIN  safety score calculation & automation
-- =====================================================================
-- Enforces:
--   â€¢ FinalScore = 100 - DeductedPoints, floored at 0
--   â€¢ CoachingRequired = FinalScore <= 75
--   â€¢ Suspended = FinalScore <= 50
--   â€¢ Auto-log CoachingRecord when CoachingRequired becomes true
--   â€¢ High/Critical events require review
--   â€¢ Critical events auto-inactivate driver and log coaching
--   â€¢ Every SafetyEvent insert recalculates live monthly score
-- =====================================================================

DROP TRIGGER IF EXISTS `trg_vdh_bi_no_overlap`;
DROP TRIGGER IF EXISTS `trg_vdh_bu_no_overlap`;

DELIMITER $$
CREATE TRIGGER `trg_vdh_bi_no_overlap`
BEFORE INSERT ON `VehiclesDepotHistory`
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM `VehiclesDepotHistory` h
        WHERE h.VehicleID = NEW.VehicleID
          AND h.MovedFrom <= COALESCE(NEW.MovedTo, '9999-12-31 23:59:59')
          AND NEW.MovedFrom <= COALESCE(h.MovedTo, '9999-12-31 23:59:59')
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle depot-history periods cannot overlap.';
    END IF;
END$$

CREATE TRIGGER `trg_vdh_bu_no_overlap`
BEFORE UPDATE ON `VehiclesDepotHistory`
FOR EACH ROW
BEGIN
    IF EXISTS (
        SELECT 1 FROM `VehiclesDepotHistory` h
        WHERE h.HistoryID <> OLD.HistoryID
          AND h.VehicleID = NEW.VehicleID
          AND h.MovedFrom <= COALESCE(NEW.MovedTo, '9999-12-31 23:59:59')
          AND NEW.MovedFrom <= COALESCE(h.MovedTo, '9999-12-31 23:59:59')
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Vehicle depot-history periods cannot overlap.';
    END IF;
END$$
DELIMITER ;

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
        COALESCE(SUM(CASE WHEN `Severity` = 'Low' THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN `Severity` = 'Medium' THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN `Severity` = 'High' THEN 1 ELSE 0 END), 0),
        COALESCE(SUM(CASE WHEN `Severity` = 'Critical' THEN 1 ELSE 0 END), 0)
      INTO v_low, v_medium, v_high, v_critical
    FROM `SafetyEvents`
    WHERE `DriverID` = p_driver_id
      AND `Timestamp` >= STR_TO_DATE(CONCAT(p_period, '-01'), '%Y-%m-%d')
      AND `Timestamp` < DATE_ADD(
          STR_TO_DATE(CONCAT(p_period, '-01'), '%Y-%m-%d'),
          INTERVAL 1 MONTH
      );

    SELECT COUNT(*) INTO v_speeding
    FROM `SafetyEvents` se
    JOIN `SafetyEventsType` t ON t.`EventsTypeID` = se.`EventsTypeID`
    WHERE se.`DriverID` = p_driver_id
      AND se.`Timestamp` >= STR_TO_DATE(CONCAT(p_period, '-01'), '%Y-%m-%d')
      AND se.`Timestamp` < DATE_ADD(
          STR_TO_DATE(CONCAT(p_period, '-01'), '%Y-%m-%d'),
          INTERVAL 1 MONTH
      )
      AND t.`Name` = 'Excessive Speeding';

    SELECT COUNT(*) INTO v_fatigue
    FROM `SafetyEvents` se
    JOIN `SafetyEventsType` t ON t.`EventsTypeID` = se.`EventsTypeID`
    WHERE se.`DriverID` = p_driver_id
      AND se.`Timestamp` >= STR_TO_DATE(CONCAT(p_period, '-01'), '%Y-%m-%d')
      AND se.`Timestamp` < DATE_ADD(
          STR_TO_DATE(CONCAT(p_period, '-01'), '%Y-%m-%d'),
          INTERVAL 1 MONTH
      )
      AND t.`Name` = 'Fatigue Warning';

    -- ERD-defined severity penalties: Low=2, Medium=5, High=10, Critical=20.
    SET v_base_deduction =
          v_low      * 2
        + v_medium   * 5
        + v_high     * 10
        + v_critical * 20;

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
DROP TRIGGER IF EXISTS `trg_se_bu_review_flag`;

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
DROP TRIGGER IF EXISTS `trg_se_au_recalc`;
DROP TRIGGER IF EXISTS `trg_se_ad_recalc`;

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

CREATE TRIGGER `trg_se_au_recalc`
AFTER UPDATE ON `SafetyEvents`
FOR EACH ROW
BEGIN
    CALL `sp_recalc_driver_safety_score`(OLD.DriverID, DATE_FORMAT(OLD.`Timestamp`, '%Y-%m'));
    IF NEW.DriverID <> OLD.DriverID OR DATE_FORMAT(NEW.`Timestamp`, '%Y-%m') <> DATE_FORMAT(OLD.`Timestamp`, '%Y-%m') THEN
        CALL `sp_recalc_driver_safety_score`(NEW.DriverID, DATE_FORMAT(NEW.`Timestamp`, '%Y-%m'));
    END IF;

    IF NEW.Severity = 'Critical'
       AND (OLD.Severity <> 'Critical' OR NEW.DriverID <> OLD.DriverID) THEN
        UPDATE `Drivers`
           SET `EmploymentStatus` = 'Inactive'
         WHERE `DriverID` = NEW.DriverID
           AND `EmploymentStatus` = 'Active';

        INSERT INTO `CoachingRecord` (`DriverID`, `Reason`, `ScheduledDate`, `RecordType`, `EventID`)
        VALUES (NEW.DriverID,
                CONCAT('Automatic: safety event #', NEW.EventID, ' updated to Critical'),
                CURDATE(), 'Critical Event', NEW.EventID);
    END IF;
END$$

CREATE TRIGGER `trg_se_ad_recalc`
AFTER DELETE ON `SafetyEvents`
FOR EACH ROW
BEGIN
    CALL `sp_recalc_driver_safety_score`(OLD.DriverID, DATE_FORMAT(OLD.`Timestamp`, '%Y-%m'));
END$$

CREATE TRIGGER `trg_se_bu_review_flag`
BEFORE UPDATE ON `SafetyEvents`
FOR EACH ROW
BEGIN
    IF NEW.Severity IN ('High', 'Critical') THEN
        SET NEW.ReviewRequired = TRUE;
        IF NEW.ReviewStatus = 'Not Required' THEN SET NEW.ReviewStatus = 'Pending'; END IF;
    ELSE
        SET NEW.ReviewRequired = FALSE;
        SET NEW.ReviewStatus = 'Not Required';
    END IF;
END$$
DELIMITER ;

-- =====================================================================
-- MAINTENANCE DOMAIN â€” mechanic certification & stock/status sync
-- =====================================================================
-- Enforces:
--   â€¢ Mechanic must hold valid cert for activity type
--   â€¢ Part consumption decrements stock
--   â€¢ Opening a job sets vehicle to 'Under Maintenance'
--   â€¢ Closing a job returns vehicle to 'Available'
--   â€¢ Linking an alert to a job updates alert status to 'Scheduled'
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

DROP TRIGGER IF EXISTS `trg_sp_bi_one_primary`;
DROP TRIGGER IF EXISTS `trg_sp_bu_one_primary`;

DELIMITER $$
CREATE TRIGGER `trg_sp_bi_one_primary`
BEFORE INSERT ON `SupplyPart`
FOR EACH ROW
BEGIN
    IF NEW.IsPrimary = TRUE AND EXISTS (
        SELECT 1 FROM `SupplyPart` sp
        WHERE sp.PartID = NEW.PartID AND sp.IsPrimary = TRUE
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A part can have only one primary supplier.';
    END IF;
END$$

CREATE TRIGGER `trg_sp_bu_one_primary`
BEFORE UPDATE ON `SupplyPart`
FOR EACH ROW
BEGIN
    IF NEW.IsPrimary = TRUE AND EXISTS (
        SELECT 1 FROM `SupplyPart` sp
        WHERE sp.PartID = NEW.PartID
          AND NOT (sp.PartID = OLD.PartID AND sp.SupplierID = OLD.SupplierID)
          AND sp.IsPrimary = TRUE
    ) THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'A part can have only one primary supplier.';
    END IF;
END$$
DELIMITER ;

DROP TRIGGER IF EXISTS `trg_ap_bi_stock`;
DROP TRIGGER IF EXISTS `trg_ap_bu_stock`;
DROP TRIGGER IF EXISTS `trg_ap_ad_stock`;

DELIMITER $$
CREATE TRIGGER `trg_ap_bi_stock`
BEFORE INSERT ON `ActivityPart`
FOR EACH ROW
BEGIN
    IF COALESCE((SELECT `QuantityInStock` FROM `Part` WHERE `PartID` = NEW.PartID), 0) < NEW.QuantityUsed THEN
        SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient part stock.';
    END IF;
    UPDATE `Part`
       SET `QuantityInStock` = `QuantityInStock` - NEW.QuantityUsed
     WHERE `PartID` = NEW.PartID;
END$$

CREATE TRIGGER `trg_ap_bu_stock`
BEFORE UPDATE ON `ActivityPart`
FOR EACH ROW
BEGIN
    IF NEW.PartID = OLD.PartID THEN
        IF (SELECT `QuantityInStock` FROM `Part` WHERE `PartID` = NEW.PartID) + OLD.QuantityUsed < NEW.QuantityUsed THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient part stock.';
        END IF;
        UPDATE `Part` SET `QuantityInStock` = `QuantityInStock` + OLD.QuantityUsed - NEW.QuantityUsed
        WHERE `PartID` = NEW.PartID;
    ELSE
        IF COALESCE((SELECT `QuantityInStock` FROM `Part` WHERE `PartID` = NEW.PartID), 0) < NEW.QuantityUsed THEN
            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Insufficient part stock.';
        END IF;
        UPDATE `Part` SET `QuantityInStock` = `QuantityInStock` + OLD.QuantityUsed WHERE `PartID` = OLD.PartID;
        UPDATE `Part` SET `QuantityInStock` = `QuantityInStock` - NEW.QuantityUsed WHERE `PartID` = NEW.PartID;
    END IF;
END$$

CREATE TRIGGER `trg_ap_ad_stock`
AFTER DELETE ON `ActivityPart`
FOR EACH ROW
BEGIN
    UPDATE `Part` SET `QuantityInStock` = `QuantityInStock` + OLD.QuantityUsed WHERE `PartID` = OLD.PartID;
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
        IF NEW.DateClosed IS NULL THEN
            UPDATE `PredictiveAlert`
               SET `Status` = 'Scheduled', `ResolvedAt` = NULL
             WHERE `AlertID` = NEW.AlertID;
        ELSE
            UPDATE `PredictiveAlert`
               SET `Status` = 'Resolved', `ResolvedAt` = NEW.DateClosed
             WHERE `AlertID` = NEW.AlertID;
        END IF;
    END IF;
END$$

CREATE TRIGGER `trg_mj_au_sync`
AFTER UPDATE ON `MaintenanceJobs`
FOR EACH ROW
BEGIN
    -- Release the old vehicle when an open job closes or moves to another vehicle.
    IF OLD.DateClosed IS NULL
       AND (NEW.DateClosed IS NOT NULL OR NEW.VehicleID <> OLD.VehicleID) THEN
        UPDATE `Vehicles`
           SET `OperationalStatus` = 'Available'
         WHERE `VehicleID` = OLD.VehicleID
           AND `OperationalStatus` = 'Under Maintenance'
           AND NOT EXISTS (
               SELECT 1 FROM `MaintenanceJobs` mj
               WHERE mj.VehicleID = OLD.VehicleID AND mj.DateClosed IS NULL AND mj.JobID <> NEW.JobID
           );
    END IF;

    -- Mark the new vehicle when a job reopens or an open job changes vehicle.
    IF NEW.DateClosed IS NULL
       AND (OLD.DateClosed IS NOT NULL OR NEW.VehicleID <> OLD.VehicleID) THEN
        UPDATE `Vehicles`
           SET `OperationalStatus` = 'Under Maintenance'
         WHERE `VehicleID` = NEW.VehicleID
           AND `OperationalStatus` <> 'Retired';
    END IF;

    -- Detaching or replacing an alert returns the previous alert to review.
    IF OLD.AlertID IS NOT NULL AND NOT (OLD.AlertID <=> NEW.AlertID) THEN
        UPDATE `PredictiveAlert`
           SET `Status` = 'Acknowledged', `ResolvedAt` = NULL
         WHERE `AlertID` = OLD.AlertID;
    END IF;

    -- Keep the linked alert synchronized with the job's open/closed state.
    IF NEW.AlertID IS NOT NULL
       AND (NOT (OLD.AlertID <=> NEW.AlertID) OR NOT (OLD.DateClosed <=> NEW.DateClosed)) THEN
        IF NEW.DateClosed IS NULL THEN
            UPDATE `PredictiveAlert`
               SET `Status` = 'Scheduled', `ResolvedAt` = NULL
             WHERE `AlertID` = NEW.AlertID;
        ELSE
            UPDATE `PredictiveAlert`
               SET `Status` = 'Resolved', `ResolvedAt` = NEW.DateClosed
             WHERE `AlertID` = NEW.AlertID;
        END IF;
    END IF;
END$$
DELIMITER ;

-- =====================================================================
-- End of 06_procedures_triggers.sql
-- =====================================================================


-- =====================================================================
-- QUERY HELPER PROCEDURES â€” for backend API use
-- =====================================================================
-- These procedures encapsulate common query patterns used by the
-- backend API, ensuring consistent query structure and taking advantage
-- of indexes defined in 08_indexes.sql.
--
-- ROLE: FLEET ADMIN
-- The procedures below are primarily used by the Fleet Admin role
-- for vehicle management, assignment tracking, and fleet oversight.
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_search_vehicles: Search/filter vehicles by multiple criteria
-- ROLE: Fleet Admin
-- Uses indexes: idx_vehicles_status, idx_va_vehicle, idx_va_driver
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_search_vehicles`;

DELIMITER $$
CREATE PROCEDURE `sp_search_vehicles` (
    IN p_status VARCHAR(50),
    IN p_category_id INT UNSIGNED,
    IN p_depot_id INT UNSIGNED,
    IN p_search_term VARCHAR(100),
    IN p_assigned_driver_id INT UNSIGNED
)
BEGIN
    SELECT 
        v.VehicleID,
        v.RegistrationNumber,
        v.CategoryID,
        v.ModelID,
        v.DepotID,
        vm.ModelName AS Model,
        vm.Manufacturer,
        v.YearOfManufacture,
        v.CurrentOdometerReading,
        v.OperationalStatus,
        vc.CategoryName,
        d.Name AS DepotName,
        CONCAT(dr.FirstName, ' ', dr.LastName) AS AssignedDriver,
        va.StartDate AS AssignedSince
    FROM Vehicles v
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN VehiclesCategory vc ON vc.CategoryID = v.CategoryID
    JOIN Depots d ON d.DepotID = v.DepotID
    LEFT JOIN (
        SELECT ranked.*
        FROM (
            SELECT va.*,
                   ROW_NUMBER() OVER (
                       PARTITION BY va.VehicleID
                       ORDER BY va.StartDate DESC, va.AssignmentID DESC
                   ) AS rn
            FROM VehicleAssignments va
            WHERE va.StartDate <= CURDATE()
              AND (va.EndDate IS NULL OR va.EndDate >= CURDATE())
        ) ranked
        WHERE ranked.rn = 1
    ) va ON va.VehicleID = v.VehicleID
    LEFT JOIN Drivers dr ON dr.DriverID = va.DriverID
    WHERE 
        (p_status IS NULL OR v.OperationalStatus = p_status)
        AND (p_category_id IS NULL OR v.CategoryID = p_category_id)
        AND (p_depot_id IS NULL OR v.DepotID = p_depot_id)
        AND (p_search_term IS NULL OR 
             v.RegistrationNumber LIKE CONCAT('%', p_search_term, '%') OR
             vm.ModelName LIKE CONCAT('%', p_search_term, '%') OR
             vm.Manufacturer LIKE CONCAT('%', p_search_term, '%') OR
             vc.CategoryName LIKE CONCAT('%', p_search_term, '%') OR
             d.Name LIKE CONCAT('%', p_search_term, '%') OR
             CONCAT(dr.FirstName, ' ', dr.LastName) LIKE CONCAT('%', p_search_term, '%'))
        AND (p_assigned_driver_id IS NULL OR va.DriverID = p_assigned_driver_id)
    ORDER BY v.RegistrationNumber;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_get_vehicle_profile: Get complete vehicle information with history
-- ROLE: Fleet Admin
-- Uses indexes: idx_vdh_vehicle, idx_va_vehicle, idx_mj_vehicle
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_get_vehicle_profile`;

DELIMITER $$
CREATE PROCEDURE `sp_get_vehicle_profile` (
    IN p_vehicle_id INT UNSIGNED
)
BEGIN
    -- Basic vehicle info
    SELECT 
        v.VehicleID,
        v.RegistrationNumber,
        vm.ModelName AS Model,
        vm.Manufacturer,
        v.YearOfManufacture,
        v.CurrentOdometerReading,
        v.OperationalStatus,
        vc.CategoryName,
        vc.CategoryID,
        d.Name AS CurrentDepot,
        d.DepotID AS CurrentDepotID,
        d.City AS DepotCity,
        CONCAT_WS(', ', d.StreetAddress, d.District, d.City) AS DepotAddress
    FROM Vehicles v
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN VehiclesCategory vc ON vc.CategoryID = v.CategoryID
    JOIN Depots d ON d.DepotID = v.DepotID
    WHERE v.VehicleID = p_vehicle_id;

    -- Current assignment
    SELECT 
        va.AssignmentID,
        va.StartDate,
        va.EndDate,
        va.IsPermanent,
        CONCAT(dr.FirstName, ' ', dr.LastName) AS DriverName,
        dr.DriverID,
        dr.EmploymentStatus AS DriverStatus,
        dep.Name AS AssignmentDepot
    FROM VehicleAssignments va
    JOIN Drivers dr ON dr.DriverID = va.DriverID
    JOIN Depots dep ON dep.DepotID = va.DepotID
    WHERE va.VehicleID = p_vehicle_id
        AND va.StartDate <= CURDATE() AND (va.EndDate IS NULL OR va.EndDate >= CURDATE())
    ORDER BY va.StartDate DESC
    LIMIT 1;

    -- Maintenance summary
    SELECT 
        COUNT(*) AS TotalJobs,
        SUM(CASE WHEN DateClosed IS NULL THEN 1 ELSE 0 END) AS OpenJobs,
        SUM(CASE WHEN DateClosed IS NOT NULL THEN 1 ELSE 0 END) AS ClosedJobs,
        COALESCE(SUM(TotalCost), 0) AS TotalMaintenanceCost,
        COALESCE(SUM(OverallDowntime), 0) AS TotalDowntimeHours,
        MAX(DateOpened) AS LastMaintenanceDate
    FROM MaintenanceJobs
    WHERE VehicleID = p_vehicle_id;

    -- Recent maintenance jobs (last 5)
    SELECT 
        mj.JobID,
        mj.DateOpened,
        mj.DateClosed,
        mj.OverallDowntime,
        mj.TotalCost,
        w.Name AS WorkshopName,
        CASE 
            WHEN mj.DateClosed IS NOT NULL THEN 'Closed'
            WHEN EXISTS(SELECT 1 FROM MaintenanceActivity ma 
                        WHERE ma.JobID = mj.JobID AND ma.StartedAt IS NOT NULL) 
            THEN 'In Progress'
            ELSE 'Open'
        END AS Status
    FROM MaintenanceJobs mj
    JOIN Workshop w ON w.WorkshopID = mj.WorkshopID
    WHERE mj.VehicleID = p_vehicle_id
    ORDER BY mj.DateOpened DESC
    LIMIT 5;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_list_available_vehicles: List vehicles available for assignment
-- ROLE: Fleet Admin
-- Uses indexes: idx_vehicles_status, idx_va_vehicle
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_list_available_vehicles`;

DELIMITER $$
CREATE PROCEDURE `sp_list_available_vehicles` (
    IN p_depot_id INT UNSIGNED,
    IN p_category_id INT UNSIGNED
)
BEGIN
    SELECT 
        v.VehicleID,
        v.RegistrationNumber,
        CONCAT(vm.Manufacturer, ' ', vm.ModelName) AS VehicleModel,
        v.YearOfManufacture,
        v.CurrentOdometerReading,
        vc.CategoryName,
        d.Name AS DepotName
    FROM Vehicles v
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN VehiclesCategory vc ON vc.CategoryID = v.CategoryID
    JOIN Depots d ON d.DepotID = v.DepotID
    WHERE v.OperationalStatus IN ('Available', 'Active')
        AND NOT EXISTS (
            SELECT 1 FROM VehicleAssignments va
            WHERE va.VehicleID = v.VehicleID
                AND va.StartDate <= CURDATE() AND (va.EndDate IS NULL OR va.EndDate >= CURDATE())
        )
        AND (p_depot_id IS NULL OR v.DepotID = p_depot_id)
        AND (p_category_id IS NULL OR v.CategoryID = p_category_id)
    ORDER BY v.RegistrationNumber;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_vehicle_assignment_history: Get assignment history
-- ROLE: Fleet Admin
-- Uses indexes: idx_va_vehicle, idx_va_driver
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_vehicle_assignment_history`;

DELIMITER $$
CREATE PROCEDURE `sp_vehicle_assignment_history` (
    IN p_vehicle_id INT UNSIGNED,
    IN p_driver_id INT UNSIGNED,
    IN p_limit INT
)
BEGIN
    IF p_limit IS NULL OR p_limit <= 0 THEN
        SET p_limit = 50;
    END IF;
    
    SELECT 
        va.AssignmentID,
        va.VehicleID,
        va.DriverID,
        va.DepotID,
        v.RegistrationNumber,
        CONCAT(vm.Manufacturer, ' ', vm.ModelName) AS VehicleModel,
        CONCAT(dr.FirstName, ' ', dr.LastName) AS DriverName,
        dep.Name AS DepotName,
        va.StartDate,
        va.EndDate,
        va.IsPermanent,
        CASE 
            WHEN va.StartDate <= CURDATE() AND (va.EndDate IS NULL OR va.EndDate >= CURDATE()) THEN 'Active'
            ELSE 'Completed'
        END AS Status,
        DATEDIFF(IF(va.EndDate IS NULL, CURDATE(), va.EndDate), va.StartDate) AS DurationDays
    FROM VehicleAssignments va
    JOIN Vehicles v ON v.VehicleID = va.VehicleID
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN Drivers dr ON dr.DriverID = va.DriverID
    JOIN Depots dep ON dep.DepotID = va.DepotID
    WHERE 
        (p_vehicle_id IS NULL OR va.VehicleID = p_vehicle_id)
        AND (p_driver_id IS NULL OR va.DriverID = p_driver_id)
    ORDER BY va.StartDate DESC
    LIMIT p_limit;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_vehicles_due_maintenance: Vehicles due/overdue for maintenance
-- ROLE: Fleet Admin
-- Uses indexes: idx_mj_vehicle, idx_vehicles_status
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_vehicles_due_maintenance`;

DELIMITER $$
CREATE PROCEDURE `sp_vehicles_due_maintenance` (
    IN p_odometer_threshold INT,
    IN p_days_since_last_service INT
)
BEGIN
    SELECT 
        v.VehicleID,
        v.RegistrationNumber,
        CONCAT(vm.Manufacturer, ' ', vm.ModelName) AS VehicleModel,
        v.CurrentOdometerReading,
        v.OperationalStatus,
        vc.CategoryName,
        d.Name AS DepotName,
        COALESCE(latest_job.LastServiceDate, 'Never') AS LastServiceDate,
        COALESCE(latest_job.LastServiceOdo, 0) AS LastServiceOdometer,
        (v.CurrentOdometerReading - COALESCE(latest_job.LastServiceOdo, 0)) AS OdoSinceService,
        COALESCE(DATEDIFF(CURDATE(), latest_job.LastServiceDate), 9999) AS DaysSinceService,
        CASE
            WHEN latest_job.LastServiceDate IS NULL THEN 'No Service History'
            WHEN (v.CurrentOdometerReading - COALESCE(latest_job.LastServiceOdo, 0)) >= p_odometer_threshold 
            THEN 'Odometer Threshold Exceeded'
            WHEN DATEDIFF(CURDATE(), latest_job.LastServiceDate) >= p_days_since_last_service 
            THEN 'Time Threshold Exceeded'
            ELSE 'Due Soon'
        END AS MaintenanceReason
    FROM Vehicles v
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN VehiclesCategory vc ON vc.CategoryID = v.CategoryID
    JOIN Depots d ON d.DepotID = v.DepotID
    LEFT JOIN (
        SELECT 
            mj.VehicleID,
            MAX(mj.DateClosed) AS LastServiceDate,
            v2.CurrentOdometerReading AS LastServiceOdo
        FROM MaintenanceJobs mj
        JOIN Vehicles v2 ON v2.VehicleID = mj.VehicleID
        WHERE mj.DateClosed IS NOT NULL
        GROUP BY mj.VehicleID, v2.CurrentOdometerReading
    ) latest_job ON latest_job.VehicleID = v.VehicleID
    WHERE v.OperationalStatus NOT IN ('Retired', 'Out of Service')
        AND (
            latest_job.LastServiceDate IS NULL
            OR (v.CurrentOdometerReading - COALESCE(latest_job.LastServiceOdo, 0)) >= p_odometer_threshold
            OR DATEDIFF(CURDATE(), latest_job.LastServiceDate) >= p_days_since_last_service
        )
    ORDER BY DaysSinceService DESC, OdoSinceService DESC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_fleet_summary_counts: Dashboard fleet summary by status/type
-- ROLE: Fleet Admin
-- Uses indexes: idx_vehicles_status, idx_drivers_status
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_fleet_summary_counts`;

DELIMITER $$
CREATE PROCEDURE `sp_fleet_summary_counts` ()
BEGIN
    -- Vehicle counts by status
    SELECT 
        'VehiclesByStatus' AS MetricType,
        v.OperationalStatus AS Category,
        COUNT(*) AS Count
    FROM Vehicles v
    GROUP BY v.OperationalStatus
    
    UNION ALL
    
    -- Vehicle counts by category
    SELECT 
        'VehiclesByCategory' AS MetricType,
        vc.CategoryName AS Category,
        COUNT(*) AS Count
    FROM Vehicles v
    JOIN VehiclesCategory vc ON vc.CategoryID = v.CategoryID
    GROUP BY vc.CategoryName
    
    UNION ALL
    
    -- Driver counts by status
    SELECT 
        'DriversByStatus' AS MetricType,
        dr.EmploymentStatus AS Category,
        COUNT(*) AS Count
    FROM Drivers dr
    GROUP BY dr.EmploymentStatus
    
    UNION ALL
    
    -- Active assignments
    SELECT 
        'ActiveAssignments' AS MetricType,
        'Current' AS Category,
        COUNT(*) AS Count
    FROM VehicleAssignments va
    WHERE va.StartDate <= CURDATE() AND (va.EndDate IS NULL OR va.EndDate >= CURDATE())
    
    UNION ALL
    
    -- Open maintenance jobs
    SELECT 
        'MaintenanceJobs' AS MetricType,
        CASE 
            WHEN mj.DateClosed IS NULL AND EXISTS(
                SELECT 1 FROM MaintenanceActivity ma 
                WHERE ma.JobID = mj.JobID AND ma.StartedAt IS NOT NULL
            ) THEN 'In Progress'
            WHEN mj.DateClosed IS NULL THEN 'Open'
            ELSE 'Closed'
        END AS Category,
        COUNT(*) AS Count
    FROM MaintenanceJobs mj
    GROUP BY Category;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_list_users_by_role: Get users filtered by role
-- ROLE: Fleet Admin (User Management)
-- Uses indexes: idx_ur_role, idx_ua_driver, idx_ua_mechanic, idx_ua_depot
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_list_users_by_role`;

DELIMITER $$
CREATE PROCEDURE `sp_list_users_by_role` (
    IN p_role_name VARCHAR(50)
)
BEGIN
    SELECT 
        ua.UserID,
        ua.Username,
        ua.IsActive,
        r.RoleName,
        r.RoleID,
        ur.GrantedDate,
        ua.DriverID,
        CONCAT(d.FirstName, ' ', d.LastName) AS LinkedDriver,
        ua.MechanicID,
        CONCAT(m.FirstName, ' ', m.LastName) AS LinkedMechanic,
        ua.DepotID,
        dep.Name AS DepotName
    FROM UserAccount ua
    LEFT JOIN UserRole ur ON ur.UserID = ua.UserID
    LEFT JOIN Role r ON r.RoleID = ur.RoleID
    LEFT JOIN Drivers d ON d.DriverID = ua.DriverID
    LEFT JOIN Mechanic m ON m.MechanicID = ua.MechanicID
    LEFT JOIN Depots dep ON dep.DepotID = ua.DepotID
    WHERE (p_role_name IS NULL OR r.RoleName = p_role_name)
    ORDER BY ua.Username;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_get_user_permissions: Get user's role + resolved permissions
-- ROLE: Fleet Admin (User Management) / System
-- Uses indexes: idx_ur_role, idx_rp_permission
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_get_user_permissions`;

DELIMITER $$
CREATE PROCEDURE `sp_get_user_permissions` (
    IN p_user_id INT UNSIGNED
)
BEGIN
    -- User roles
    SELECT 
        r.RoleID,
        r.RoleName,
        ur.GrantedDate
    FROM UserRole ur
    JOIN Role r ON r.RoleID = ur.RoleID
    WHERE ur.UserID = p_user_id;

    -- Resolved permissions (deduplicated across all user's roles)
    SELECT DISTINCT
        p.PermissionID,
        p.TableName,
        p.Action,
        p.Description,
        CONCAT(p.TableName, '.', p.Action) AS PermissionKey
    FROM UserRole ur
    JOIN RolePermission rp ON rp.RoleID = ur.RoleID
    JOIN Permission p ON p.PermissionID = rp.PermissionID
    WHERE ur.UserID = p_user_id
    ORDER BY p.TableName, p.Action;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_check_user_permission: Check if user has specific permission
-- ROLE: System (Authentication/Authorization)
-- Uses indexes: idx_ur_role, idx_rp_permission
-- Returns: 1 if permission exists, 0 if not
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_check_user_permission`;

DELIMITER $$
CREATE PROCEDURE `sp_check_user_permission` (
    IN p_user_id INT UNSIGNED,
    IN p_table_name VARCHAR(64),
    IN p_action VARCHAR(10)
)
BEGIN
    SELECT 
        CASE 
            WHEN COUNT(*) > 0 THEN 1 
            ELSE 0 
        END AS HasPermission
    FROM UserRole ur
    JOIN RolePermission rp ON rp.RoleID = ur.RoleID
    JOIN Permission p ON p.PermissionID = rp.PermissionID
    WHERE ur.UserID = p_user_id
        AND p.TableName = p_table_name
        AND (p.Action = p_action OR p.Action = 'ALL');
END$$
DELIMITER ;

-- =====================================================================
-- End of query helper procedures
-- =====================================================================


-- =====================================================================
-- SAFETY OPS PROCEDURES â€” for safety operations management
-- =====================================================================
-- ROLE: SAFETY OPS
-- These procedures support driver safety monitoring, coaching,
-- suspension management, and predictive alert tracking.
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_search_drivers: Search/filter drivers by multiple criteria
-- ROLE: Safety Ops
-- Uses indexes: idx_drivers_status, idx_drivers_depot, idx_drivers_licexp
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_search_drivers`;

DELIMITER $$
CREATE PROCEDURE `sp_search_drivers` (
    IN p_search_term VARCHAR(100),
    IN p_employment_status VARCHAR(20),
    IN p_min_score INT,
    IN p_max_score INT,
    IN p_depot_id INT UNSIGNED
)
BEGIN
    SELECT 
        dr.DriverID,
        dr.FirstName,
        dr.LastName,
        dr.ContactPhoneNumber,
        dr.ContactPhoneNumber AS ContactInformation,
        dr.EmergencyContactPhone,
        dr.EmergencyContactPhone AS EmergencyContactDetails,
        dr.DepotID,
        dr.LicenceType,
        dr.LicenceExpiryDate,
        dr.EmploymentStatus,
        dep.Name AS DepotName,
        COALESCE(latest_score.FinalScore, 100) AS CurrentSafetyScore,
        COALESCE(latest_score.CoachingRequired, FALSE) AS CoachingRequired,
        COALESCE(latest_score.Suspended, FALSE) AS Suspended,
        COALESCE(latest_score.ScorePeriod, DATE_FORMAT(CURDATE(), '%Y-%m')) AS ScorePeriod,
        v.RegistrationNumber AS CurrentVehicle,
        CASE 
            WHEN dr.LicenceExpiryDate < CURDATE() THEN 'Expired'
            WHEN dr.LicenceExpiryDate <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 'Expiring Soon'
            ELSE 'Valid'
        END AS LicenceStatus
    FROM Drivers dr
    JOIN Depots dep ON dep.DepotID = dr.DepotID
    LEFT JOIN (
        SELECT 
            DriverID, 
            FinalScore, 
            CoachingRequired, 
            Suspended,
            ScorePeriod,
            ROW_NUMBER() OVER (PARTITION BY DriverID ORDER BY ScorePeriod DESC) AS rn
        FROM DriverSafetyScore
    ) latest_score ON latest_score.DriverID = dr.DriverID AND latest_score.rn = 1
    LEFT JOIN (
        SELECT ranked.*
        FROM (
            SELECT va.*,
                   ROW_NUMBER() OVER (
                       PARTITION BY va.DriverID
                       ORDER BY va.StartDate DESC, va.AssignmentID DESC
                   ) AS rn
            FROM VehicleAssignments va
            WHERE va.StartDate <= CURDATE()
              AND (va.EndDate IS NULL OR va.EndDate >= CURDATE())
        ) ranked
        WHERE ranked.rn = 1
    ) va ON va.DriverID = dr.DriverID
    LEFT JOIN Vehicles v ON v.VehicleID = va.VehicleID
    WHERE 
        (p_search_term IS NULL OR 
         dr.FirstName LIKE CONCAT('%', p_search_term, '%') OR
         dr.LastName LIKE CONCAT('%', p_search_term, '%') OR
         CONCAT(dr.FirstName, ' ', dr.LastName) LIKE CONCAT('%', p_search_term, '%') OR
         dr.LicenceType LIKE CONCAT('%', p_search_term, '%') OR
         dep.Name LIKE CONCAT('%', p_search_term, '%') OR
         v.RegistrationNumber LIKE CONCAT('%', p_search_term, '%'))
        AND (p_employment_status IS NULL OR dr.EmploymentStatus = p_employment_status)
        AND (p_min_score IS NULL OR COALESCE(latest_score.FinalScore, 100) >= p_min_score)
        AND (p_max_score IS NULL OR COALESCE(latest_score.FinalScore, 100) <= p_max_score)
        AND (p_depot_id IS NULL OR dr.DepotID = p_depot_id)
    ORDER BY dr.LastName, dr.FirstName;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_get_driver_profile: Get complete driver profile with safety data
-- ROLE: Safety Ops
-- Uses indexes: idx_se_driver, idx_dc_driver, idx_va_driver
-- Returns multiple result sets: basic info, current score, events, 
-- coaching records, certifications, current assignment
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_get_driver_profile`;

DELIMITER $$
CREATE PROCEDURE `sp_get_driver_profile` (
    IN p_driver_id INT UNSIGNED
)
BEGIN
    -- Basic driver info
    SELECT 
        dr.DriverID,
        dr.FirstName,
        dr.LastName,
        dr.ContactPhoneNumber,
        dr.LicenceType,
        dr.LicenceExpiryDate,
        dr.EmploymentStatus,
        dr.EmergencyContactPhone,
        dep.Name AS DepotName,
        dep.DepotID,
        dep.City AS DepotCity,
        CASE 
            WHEN dr.LicenceExpiryDate < CURDATE() THEN 'Expired'
            WHEN dr.LicenceExpiryDate <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 'Expiring Soon'
            ELSE 'Valid'
        END AS LicenceStatus
    FROM Drivers dr
    JOIN Depots dep ON dep.DepotID = dr.DepotID
    WHERE dr.DriverID = p_driver_id;

    -- Current safety score
    SELECT 
        dss.ScoreID,
        dss.ScorePeriod,
        dss.BaseScore,
        dss.DeductedPoints,
        dss.FinalScore,
        dss.CoachingRequired,
        dss.Suspended,
        dss.LowCount,
        dss.MediumCount,
        dss.HighCount,
        dss.CriticalCount
    FROM DriverSafetyScore dss
    WHERE dss.DriverID = p_driver_id
    ORDER BY dss.ScorePeriod DESC
    LIMIT 1;

    -- Safety event history (last 20 events)
    SELECT 
        se.EventID,
        se.Timestamp,
        sevt.Name AS EventType,
        se.Severity,
        v.RegistrationNumber AS Vehicle,
        dep.Name AS DepotName,
        se.Odometer,
        se.ReviewRequired,
        se.ReviewStatus
    FROM SafetyEvents se
    JOIN SafetyEventsType sevt ON sevt.EventsTypeID = se.EventsTypeID
    JOIN Vehicles v ON v.VehicleID = se.VehicleID
    JOIN Depots dep ON dep.DepotID = se.DepotID
    WHERE se.DriverID = p_driver_id
    ORDER BY se.Timestamp DESC
    LIMIT 20;

    -- Coaching history
    SELECT 
        cr.CoachingID,
        cr.Reason,
        cr.RecordType,
        cr.ScheduledDate,
        cr.CompleteDate,
        cr.Outcome,
        cr.EventID,
        cr.ScoreID
    FROM CoachingRecord cr
    WHERE cr.DriverID = p_driver_id
    ORDER BY cr.ScheduledDate DESC;

    -- Certifications
    SELECT 
        dc.DriverCertID,
        ct.Name AS CertificationType,
        dc.IssueDate,
        dc.ExpireDate,
        CASE 
            WHEN dc.ExpireDate IS NULL THEN 'No Expiry'
            WHEN dc.ExpireDate < CURDATE() THEN 'Expired'
            WHEN dc.ExpireDate <= DATE_ADD(CURDATE(), INTERVAL 60 DAY) THEN 'Expiring Soon'
            ELSE 'Valid'
        END AS CertStatus
    FROM DriverCertifications dc
    JOIN CertificationType ct ON ct.CertTypeID = dc.CertTypeID
    WHERE dc.DriverID = p_driver_id
    ORDER BY dc.ExpireDate IS NULL DESC, dc.ExpireDate ASC;

    -- Current vehicle assignment
    SELECT 
        va.AssignmentID,
        v.VehicleID,
        v.RegistrationNumber,
        CONCAT(vm.Manufacturer, ' ', vm.ModelName) AS VehicleModel,
        vc.CategoryName,
        va.StartDate,
        va.EndDate,
        va.IsPermanent,
        dep.Name AS AssignmentDepot,
        DATEDIFF(COALESCE(va.EndDate, CURDATE()), va.StartDate) AS AssignmentDurationDays
    FROM VehicleAssignments va
    JOIN Vehicles v ON v.VehicleID = va.VehicleID
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN VehiclesCategory vc ON vc.CategoryID = v.CategoryID
    JOIN Depots dep ON dep.DepotID = va.DepotID
    WHERE va.DriverID = p_driver_id
        AND va.StartDate <= CURDATE() AND (va.EndDate IS NULL OR va.EndDate >= CURDATE())
    ORDER BY va.StartDate DESC
    LIMIT 1;

    -- Score history (last 12 months)
    SELECT 
        dss.ScorePeriod,
        dss.FinalScore,
        dss.DeductedPoints,
        dss.CoachingRequired,
        dss.Suspended,
        dss.LowCount + dss.MediumCount + dss.HighCount + dss.CriticalCount AS TotalEvents
    FROM DriverSafetyScore dss
    WHERE dss.DriverID = p_driver_id
    ORDER BY dss.ScorePeriod DESC
    LIMIT 12;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_list_suspended_drivers: Get all suspended/inactive drivers
-- ROLE: Safety Ops
-- Uses indexes: idx_drivers_status
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_list_suspended_drivers`;

DELIMITER $$
CREATE PROCEDURE `sp_list_suspended_drivers` ()
BEGIN
    SELECT 
        dr.DriverID,
        dr.FirstName,
        dr.LastName,
        dr.ContactPhoneNumber,
        dr.EmploymentStatus,
        dep.Name AS DepotName,
        COALESCE(latest_score.FinalScore, 100) AS CurrentSafetyScore,
        COALESCE(latest_score.Suspended, FALSE) AS Suspended,
        COALESCE(latest_score.ScorePeriod, DATE_FORMAT(CURDATE(), '%Y-%m')) AS ScorePeriod,
        latest_critical.LastCriticalEvent,
        latest_critical.CriticalEventType,
        pending_coaching.PendingCoachingCount,
        CASE 
            WHEN dr.EmploymentStatus = 'Suspended' THEN 'Suspended by Admin'
            WHEN dr.EmploymentStatus = 'Inactive' THEN 'Inactive (Critical Event)'
            WHEN latest_score.Suspended = TRUE THEN 'Suspended (Safety Score â‰¤ 50)'
            ELSE 'Unknown'
        END AS SuspensionReason
    FROM Drivers dr
    JOIN Depots dep ON dep.DepotID = dr.DepotID
    LEFT JOIN (
        SELECT 
            DriverID, 
            FinalScore, 
            Suspended,
            ScorePeriod,
            ROW_NUMBER() OVER (PARTITION BY DriverID ORDER BY ScorePeriod DESC) AS rn
        FROM DriverSafetyScore
    ) latest_score ON latest_score.DriverID = dr.DriverID AND latest_score.rn = 1
    LEFT JOIN (
        SELECT 
            se.DriverID,
            MAX(se.Timestamp) AS LastCriticalEvent,
            sevt.Name AS CriticalEventType
        FROM SafetyEvents se
        JOIN SafetyEventsType sevt ON sevt.EventsTypeID = se.EventsTypeID
        WHERE se.Severity = 'Critical'
        GROUP BY se.DriverID, sevt.Name
    ) latest_critical ON latest_critical.DriverID = dr.DriverID
    LEFT JOIN (
        SELECT 
            cr.DriverID,
            COUNT(*) AS PendingCoachingCount
        FROM CoachingRecord cr
        WHERE cr.Outcome = 'Pending'
        GROUP BY cr.DriverID
    ) pending_coaching ON pending_coaching.DriverID = dr.DriverID
    WHERE 
        dr.EmploymentStatus IN ('Suspended', 'Inactive')
        OR latest_score.Suspended = TRUE
    ORDER BY 
        dr.EmploymentStatus DESC,
        latest_score.FinalScore ASC,
        dr.LastName;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_list_predictive_alerts: Active/unresolved alerts by severity
-- ROLE: Safety Ops
-- Uses indexes: idx_pa_vehicle, idx_pa_status
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_list_predictive_alerts`;

DELIMITER $$
CREATE PROCEDURE `sp_list_predictive_alerts` (
    IN p_severity VARCHAR(20),
    IN p_status VARCHAR(20),
    IN p_vehicle_id INT UNSIGNED
)
BEGIN
    SELECT 
        pa.AlertID,
        pa.VehicleID,
        v.RegistrationNumber,
        CONCAT(vm.Manufacturer, ' ', vm.ModelName) AS VehicleModel,
        v.OperationalStatus AS VehicleStatus,
        dep.Name AS DepotName,
        pa.AlertType,
        pa.Severity,
        pa.GeneratedAt,
        pa.Status,
        pa.ResolvedAt,
        mj.JobID AS LinkedJobID,
        CASE 
            WHEN mj.JobID IS NOT NULL AND mj.DateClosed IS NULL THEN 'Job In Progress'
            WHEN mj.JobID IS NOT NULL AND mj.DateClosed IS NOT NULL THEN 'Job Completed'
            WHEN pa.Status = 'Scheduled' THEN 'Scheduled'
            WHEN pa.Status = 'Acknowledged' THEN 'Acknowledged'
            WHEN pa.Status = 'Escalated' THEN 'Escalated'
            ELSE 'New'
        END AS ActionStatus,
        DATEDIFF(CURDATE(), DATE(pa.GeneratedAt)) AS DaysOpen
    FROM PredictiveAlert pa
    JOIN Vehicles v ON v.VehicleID = pa.VehicleID
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN Depots dep ON dep.DepotID = v.DepotID
    LEFT JOIN MaintenanceJobs mj ON mj.AlertID = pa.AlertID
    WHERE 
        (p_severity IS NULL OR pa.Severity = p_severity)
        AND (p_status IS NULL OR pa.Status = p_status)
        AND (p_vehicle_id IS NULL OR pa.VehicleID = p_vehicle_id)
        AND pa.Status NOT IN ('Resolved')  -- Only active/unresolved alerts
    ORDER BY 
        FIELD(pa.Severity, 'Critical', 'High', 'Medium', 'Low'),
        pa.GeneratedAt ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_drivers_requiring_coaching: Drivers who need coaching intervention
-- ROLE: Safety Ops
-- Uses indexes: idx_drivers_status, idx_cr_driver
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_drivers_requiring_coaching`;

DELIMITER $$
CREATE PROCEDURE `sp_drivers_requiring_coaching` ()
BEGIN
    SELECT 
        dr.DriverID,
        dr.FirstName,
        dr.LastName,
        dr.EmploymentStatus,
        dep.Name AS DepotName,
        latest_score.FinalScore,
        latest_score.CoachingRequired,
        latest_score.ScorePeriod,
        latest_score.HighCount,
        latest_score.CriticalCount,
        pending_coaching.PendingCount AS PendingCoachingSessions,
        completed_coaching.CompletedCount AS CompletedCoachingSessions,
        CASE 
            WHEN latest_score.CriticalCount > 0 THEN 'Critical Event'
            WHEN latest_score.HighCount >= 3 THEN 'Repeated High-Severity Incidents'
            WHEN latest_score.FinalScore <= 75 THEN 'Low Safety Score'
            ELSE 'Other'
        END AS CoachingReason
    FROM Drivers dr
    JOIN Depots dep ON dep.DepotID = dr.DepotID
    LEFT JOIN (
        SELECT 
            DriverID, 
            FinalScore, 
            CoachingRequired,
            ScorePeriod,
            HighCount,
            CriticalCount,
            ROW_NUMBER() OVER (PARTITION BY DriverID ORDER BY ScorePeriod DESC) AS rn
        FROM DriverSafetyScore
    ) latest_score ON latest_score.DriverID = dr.DriverID AND latest_score.rn = 1
    LEFT JOIN (
        SELECT DriverID, COUNT(*) AS PendingCount
        FROM CoachingRecord
        WHERE Outcome = 'Pending'
        GROUP BY DriverID
    ) pending_coaching ON pending_coaching.DriverID = dr.DriverID
    LEFT JOIN (
        SELECT DriverID, COUNT(*) AS CompletedCount
        FROM CoachingRecord
        WHERE Outcome IN ('Passed', 'Failed')
        GROUP BY DriverID
    ) completed_coaching ON completed_coaching.DriverID = dr.DriverID
    WHERE 
        latest_score.CoachingRequired = TRUE
        OR pending_coaching.PendingCount > 0
    ORDER BY 
        latest_score.FinalScore ASC,
        latest_score.CriticalCount DESC,
        dr.LastName;
END$$
DELIMITER ;

-- =====================================================================
-- End of Safety Ops procedures
-- =====================================================================


-- =====================================================================
-- WORKSHOP MANAGER PROCEDURES â€” for maintenance operations management
-- =====================================================================
-- ROLE: WORKSHOP MANAGER
-- These procedures support maintenance job tracking, parts inventory
-- management, mechanic workload monitoring, and workshop operations.
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_search_maintenance_jobs: Search/filter jobs by multiple criteria
-- ROLE: Workshop Manager
-- Uses indexes: idx_mj_vehicle, idx_mj_workshop, idx_ma_job, idx_am_mechanic
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_search_maintenance_jobs`;

DELIMITER $$
CREATE PROCEDURE `sp_search_maintenance_jobs` (
    IN p_status VARCHAR(20),
    IN p_vehicle_id INT UNSIGNED,
    IN p_workshop_id INT UNSIGNED,
    IN p_mechanic_id INT UNSIGNED,
    IN p_date_from DATE,
    IN p_date_to DATE
)
BEGIN
    SELECT 
        mj.JobID,
        mj.VehicleID,
        v.RegistrationNumber,
        CONCAT(vm.Manufacturer, ' ', vm.ModelName) AS VehicleModel,
        mj.WorkshopID,
        w.Name AS WorkshopName,
        mj.DateOpened,
        mj.DateClosed,
        mj.OverallDowntime,
        mj.TotalCost,
        mj.AlertID,
        pa.AlertType,
        pa.Severity AS AlertSeverity,
        CASE 
            WHEN mj.DateClosed IS NOT NULL THEN 'Closed'
            WHEN EXISTS(SELECT 1 FROM MaintenanceActivity ma 
                        WHERE ma.JobID = mj.JobID AND ma.StartedAt IS NOT NULL) 
            THEN 'In Progress'
            ELSE 'Open'
        END AS JobStatus,
        COUNT(DISTINCT ma.ActivityID) AS ActivityCount,
        COUNT(DISTINCT am.MechanicID) AS MechanicCount,
        SUM(am.LabourHours) AS TotalLabourHours,
        DATEDIFF(COALESCE(mj.DateClosed, CURDATE()), mj.DateOpened) AS DaysOpen
    FROM MaintenanceJobs mj
    JOIN Vehicles v ON v.VehicleID = mj.VehicleID
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN Workshop w ON w.WorkshopID = mj.WorkshopID
    LEFT JOIN PredictiveAlert pa ON pa.AlertID = mj.AlertID
    LEFT JOIN MaintenanceActivity ma ON ma.JobID = mj.JobID
    LEFT JOIN ActivityMechanic am ON am.ActivityID = ma.ActivityID
    WHERE 
        (p_vehicle_id IS NULL OR mj.VehicleID = p_vehicle_id)
        AND (p_workshop_id IS NULL OR mj.WorkshopID = p_workshop_id)
        AND (p_date_from IS NULL OR mj.DateOpened >= p_date_from)
        AND (p_date_to IS NULL OR mj.DateOpened < DATE_ADD(p_date_to, INTERVAL 1 DAY))
        AND (p_mechanic_id IS NULL OR am.MechanicID = p_mechanic_id)
        AND (
            p_status IS NULL OR
            (p_status = 'Open' AND mj.DateClosed IS NULL 
                AND NOT EXISTS(SELECT 1 FROM MaintenanceActivity ma2 
                               WHERE ma2.JobID = mj.JobID AND ma2.StartedAt IS NOT NULL)) OR
            (p_status = 'In Progress' AND mj.DateClosed IS NULL 
                AND EXISTS(SELECT 1 FROM MaintenanceActivity ma2 
                           WHERE ma2.JobID = mj.JobID AND ma2.StartedAt IS NOT NULL)) OR
            (p_status = 'Closed' AND mj.DateClosed IS NOT NULL)
        )
    GROUP BY 
        mj.JobID, mj.VehicleID, v.RegistrationNumber, vm.Manufacturer, vm.ModelName,
        mj.WorkshopID, w.Name, mj.DateOpened, mj.DateClosed, mj.OverallDowntime,
        mj.TotalCost, mj.AlertID, pa.AlertType, pa.Severity
    ORDER BY 
        mj.DateOpened DESC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_get_job_detail: Get complete job details with parts, labor, history
-- ROLE: Workshop Manager
-- Uses indexes: idx_ma_job, idx_am_mechanic, idx_ap_part
-- Returns multiple result sets: job info, activities, parts, mechanics, warranty
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_get_job_detail`;

DELIMITER $$
CREATE PROCEDURE `sp_get_job_detail` (
    IN p_job_id INT UNSIGNED
)
BEGIN
    -- Job header info
    SELECT 
        mj.JobID,
        mj.VehicleID,
        v.RegistrationNumber,
        CONCAT(vm.Manufacturer, ' ', vm.ModelName) AS VehicleModel,
        v.YearOfManufacture,
        v.CurrentOdometerReading,
        mj.WorkshopID,
        w.Name AS WorkshopName,
        w.NumBays,
        dep.Name AS DepotName,
        mj.DateOpened,
        mj.DateClosed,
        mj.OverallDowntime,
        mj.TotalCost,
        mj.AlertID,
        pa.AlertType,
        pa.Severity AS AlertSeverity,
        pa.GeneratedAt AS AlertGeneratedAt,
        CASE 
            WHEN mj.DateClosed IS NOT NULL THEN 'Closed'
            WHEN EXISTS(SELECT 1 FROM MaintenanceActivity ma 
                        WHERE ma.JobID = mj.JobID AND ma.StartedAt IS NOT NULL) 
            THEN 'In Progress'
            ELSE 'Open'
        END AS JobStatus
    FROM MaintenanceJobs mj
    JOIN Vehicles v ON v.VehicleID = mj.VehicleID
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN Workshop w ON w.WorkshopID = mj.WorkshopID
    JOIN Depots dep ON dep.DepotID = w.DepotID
    LEFT JOIN PredictiveAlert pa ON pa.AlertID = mj.AlertID
    WHERE mj.JobID = p_job_id;

    -- Activities
    SELECT 
        ma.ActivityID,
        at.Name AS ActivityType,
        ma.DiagnosticResult,
        ma.IsRepeatFault,
        ma.StartedAt,
        ma.CompleteAt,
        CASE 
            WHEN ma.CompleteAt IS NOT NULL THEN 'Completed'
            WHEN ma.StartedAt IS NOT NULL THEN 'In Progress'
            ELSE 'Not Started'
        END AS ActivityStatus,
        TIMESTAMPDIFF(HOUR, ma.StartedAt, COALESCE(ma.CompleteAt, NOW())) AS HoursSpent
    FROM MaintenanceActivity ma
    JOIN ActivityType at ON at.ActivityTypeID = ma.ActivityTypeID
    WHERE ma.JobID = p_job_id
    ORDER BY ma.StartedAt DESC, ma.ActivityID;

    -- Parts used
    SELECT 
        ap.ActivityID,
        p.PartID,
        p.PartNumber,
        p.Description AS PartDescription,
        ap.QuantityUsed,
        ap.UnitPriceAtTime,
        (ap.QuantityUsed * ap.UnitPriceAtTime) AS TotalPartCost,
        p.QuantityInStock AS CurrentStock,
        p.ReorderThreshold
    FROM MaintenanceActivity ma
    JOIN ActivityPart ap ON ap.ActivityID = ma.ActivityID
    JOIN Part p ON p.PartID = ap.PartID
    WHERE ma.JobID = p_job_id
    ORDER BY ap.ActivityID, p.PartNumber;

    -- Mechanics assigned
    SELECT 
        am.ActivityID,
        m.MechanicID,
        CONCAT(m.FirstName, ' ', m.LastName) AS MechanicName,
        m.EmploymentStatus,
        am.LabourHours,
        GROUP_CONCAT(mct.Name ORDER BY mct.Name SEPARATOR ', ') AS Certifications
    FROM MaintenanceActivity ma
    JOIN ActivityMechanic am ON am.ActivityID = ma.ActivityID
    JOIN Mechanic m ON m.MechanicID = am.MechanicID
    LEFT JOIN MechanicCertification mc ON mc.MechanicID = m.MechanicID
        AND (mc.ExpireDate IS NULL OR mc.ExpireDate >= CURDATE())
    LEFT JOIN MechanicCertType mct ON mct.MecCertTypeID = mc.MecCertTypeID
    WHERE ma.JobID = p_job_id
    GROUP BY am.ActivityID, m.MechanicID, m.FirstName, m.LastName, 
             m.EmploymentStatus, am.LabourHours
    ORDER BY am.ActivityID;

    -- Warranty claims
    SELECT 
        wc.ClaimID,
        wc.ActivityID,
        wc.WarrantyType,
        wc.Status AS ClaimStatus,
        wc.ClaimDate,
        GROUP_CONCAT(p.PartNumber ORDER BY p.PartNumber SEPARATOR ', ') AS ClaimedParts
    FROM MaintenanceActivity ma
    LEFT JOIN WarrantyClaim wc ON wc.ActivityID = ma.ActivityID
    LEFT JOIN WarrantyClaimPart wcp ON wcp.ClaimID = wc.ClaimID
    LEFT JOIN Part p ON p.PartID = wcp.PartID
    WHERE ma.JobID = p_job_id
        AND wc.ClaimID IS NOT NULL
    GROUP BY wc.ClaimID, wc.ActivityID, wc.WarrantyType, wc.Status, wc.ClaimDate
    ORDER BY wc.ClaimDate DESC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_list_open_jobs: List all open and in-progress jobs
-- ROLE: Workshop Manager
-- Uses indexes: idx_mj_workshop, idx_ma_job
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_list_open_jobs`;

DELIMITER $$
CREATE PROCEDURE `sp_list_open_jobs` (
    IN p_workshop_id INT UNSIGNED
)
BEGIN
    SELECT 
        mj.JobID,
        v.RegistrationNumber,
        CONCAT(vm.Manufacturer, ' ', vm.ModelName) AS VehicleModel,
        w.Name AS WorkshopName,
        mj.DateOpened,
        mj.TotalCost,
        CASE 
            WHEN EXISTS(SELECT 1 FROM MaintenanceActivity ma 
                        WHERE ma.JobID = mj.JobID AND ma.StartedAt IS NOT NULL) 
            THEN 'In Progress'
            ELSE 'Open'
        END AS JobStatus,
        pa.AlertType,
        pa.Severity AS AlertSeverity,
        COUNT(DISTINCT ma.ActivityID) AS TotalActivities,
        COUNT(DISTINCT CASE WHEN ma.CompleteAt IS NOT NULL THEN ma.ActivityID END) AS CompletedActivities,
        COUNT(DISTINCT CASE WHEN ma.StartedAt IS NOT NULL AND ma.CompleteAt IS NULL THEN ma.ActivityID END) AS InProgressActivities,
        COUNT(DISTINCT am.MechanicID) AS AssignedMechanics,
        COALESCE(SUM(am.LabourHours), 0) AS TotalLabourHours,
        DATEDIFF(CURDATE(), mj.DateOpened) AS DaysOpen,
        CASE 
            WHEN DATEDIFF(CURDATE(), mj.DateOpened) > 7 THEN 'Overdue'
            WHEN DATEDIFF(CURDATE(), mj.DateOpened) > 3 THEN 'At Risk'
            ELSE 'On Track'
        END AS TimelinessStatus
    FROM MaintenanceJobs mj
    JOIN Vehicles v ON v.VehicleID = mj.VehicleID
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN Workshop w ON w.WorkshopID = mj.WorkshopID
    LEFT JOIN PredictiveAlert pa ON pa.AlertID = mj.AlertID
    LEFT JOIN MaintenanceActivity ma ON ma.JobID = mj.JobID
    LEFT JOIN ActivityMechanic am ON am.ActivityID = ma.ActivityID
    WHERE 
        mj.DateClosed IS NULL
        AND (p_workshop_id IS NULL OR mj.WorkshopID = p_workshop_id)
    GROUP BY 
        mj.JobID, v.RegistrationNumber, vm.Manufacturer, vm.ModelName,
        w.Name, mj.DateOpened, mj.TotalCost, pa.AlertType, pa.Severity
    ORDER BY 
        TimelinessStatus DESC,
        mj.DateOpened ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_low_stock_parts: Parts below reorder threshold (reorder queue)
-- ROLE: Workshop Manager
-- Uses indexes: idx_part_stock
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_low_stock_parts`;

DELIMITER $$
CREATE PROCEDURE `sp_low_stock_parts` ()
BEGIN
    SELECT 
        p.PartID,
        p.PartNumber,
        p.Description,
        p.UnitPrice,
        p.QuantityInStock,
        p.ReorderThreshold,
        (p.ReorderThreshold - p.QuantityInStock) AS QuantityNeeded,
        s.SupplierID AS PrimarySupplierID,
        s.Name AS PrimarySupplierName,
        s.ContactEmail AS SupplierContact,
        s.LeadTimeDays,
        sp.UnitCost AS SupplierCost,
        ((p.ReorderThreshold - p.QuantityInStock) * sp.UnitCost) AS EstimatedOrderCost,
        recent_usage.UsageCount AS RecentUsageCount,
        recent_usage.LastUsedDate,
        CASE 
            WHEN p.QuantityInStock = 0 THEN 'Out of Stock'
            WHEN p.QuantityInStock <= (p.ReorderThreshold * 0.25) THEN 'Critical'
            WHEN p.QuantityInStock <= (p.ReorderThreshold * 0.5) THEN 'Low'
            ELSE 'Below Threshold'
        END AS StockStatus
    FROM Part p
    LEFT JOIN SupplyPart sp ON sp.PartID = p.PartID AND sp.IsPrimary = TRUE
    LEFT JOIN Supplier s ON s.SupplierID = sp.SupplierID
    LEFT JOIN (
        SELECT 
            ap.PartID,
            COUNT(*) AS UsageCount,
            MAX(ma.CompleteAt) AS LastUsedDate
        FROM ActivityPart ap
        JOIN MaintenanceActivity ma ON ma.ActivityID = ap.ActivityID
        WHERE ma.CompleteAt >= DATE_SUB(CURDATE(), INTERVAL 90 DAY)
        GROUP BY ap.PartID
    ) recent_usage ON recent_usage.PartID = p.PartID
    WHERE p.QuantityInStock <= p.ReorderThreshold
    ORDER BY 
        FIELD(StockStatus, 'Out of Stock', 'Critical', 'Low', 'Below Threshold'),
        p.QuantityInStock ASC,
        recent_usage.UsageCount DESC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_list_mechanics_workload: Mechanics by workshop with workload stats
-- ROLE: Workshop Manager
-- Uses indexes: idx_mechanic_workshop, idx_am_mechanic, idx_mc_mechanic
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_list_mechanics_workload`;

DELIMITER $$
CREATE PROCEDURE `sp_list_mechanics_workload` (
    IN p_workshop_id INT UNSIGNED
)
BEGIN
    SELECT 
        m.MechanicID,
        CONCAT(m.FirstName, ' ', m.LastName) AS MechanicName,
        m.EmploymentStatus,
        w.WorkshopID,
        w.Name AS WorkshopName,
        GROUP_CONCAT(DISTINCT mct.Name ORDER BY mct.Name SEPARATOR ', ') AS Certifications,
        COUNT(DISTINCT cert_check.MecCertTypeID) AS CertificationCount,
        -- Current workload (open/in-progress activities)
        COALESCE(current_work.ActiveActivities, 0) AS ActiveActivities,
        COALESCE(current_work.TotalActiveHours, 0) AS TotalActiveHours,
        -- Last 30 days statistics
        COALESCE(recent_work.CompletedActivities, 0) AS CompletedActivitiesLast30Days,
        COALESCE(recent_work.TotalHoursLast30Days, 0) AS TotalHoursLast30Days,
        COALESCE(recent_work.RepeatFaults, 0) AS RepeatFaultsLast30Days,
        -- All-time statistics
        COALESCE(lifetime_work.TotalActivities, 0) AS LifetimeActivities,
        COALESCE(lifetime_work.TotalLifetimeHours, 0) AS LifetimeHours,
        -- Availability assessment
        CASE 
            WHEN m.EmploymentStatus != 'Active' THEN 'Unavailable'
            WHEN COALESCE(current_work.ActiveActivities, 0) = 0 THEN 'Available'
            WHEN COALESCE(current_work.ActiveActivities, 0) <= 2 THEN 'Light Load'
            WHEN COALESCE(current_work.ActiveActivities, 0) <= 5 THEN 'Moderate Load'
            ELSE 'Heavy Load'
        END AS AvailabilityStatus
    FROM Mechanic m
    JOIN Workshop w ON w.WorkshopID = m.WorkshopID
    LEFT JOIN MechanicCertification mc ON mc.MechanicID = m.MechanicID
        AND (mc.ExpireDate IS NULL OR mc.ExpireDate >= CURDATE())
    LEFT JOIN MechanicCertType mct ON mct.MecCertTypeID = mc.MecCertTypeID
    LEFT JOIN MechanicCertification cert_check ON cert_check.MechanicID = m.MechanicID
        AND (cert_check.ExpireDate IS NULL OR cert_check.ExpireDate >= CURDATE())
    LEFT JOIN (
        SELECT 
            am.MechanicID,
            COUNT(DISTINCT am.ActivityID) AS ActiveActivities,
            SUM(am.LabourHours) AS TotalActiveHours
        FROM ActivityMechanic am
        JOIN MaintenanceActivity ma ON ma.ActivityID = am.ActivityID
        JOIN MaintenanceJobs mj ON mj.JobID = ma.JobID
        WHERE mj.DateClosed IS NULL
            AND ma.CompleteAt IS NULL
        GROUP BY am.MechanicID
    ) current_work ON current_work.MechanicID = m.MechanicID
    LEFT JOIN (
        SELECT 
            am.MechanicID,
            COUNT(DISTINCT am.ActivityID) AS CompletedActivities,
            SUM(am.LabourHours) AS TotalHoursLast30Days,
            COUNT(DISTINCT CASE WHEN ma.IsRepeatFault = TRUE THEN ma.ActivityID END) AS RepeatFaults
        FROM ActivityMechanic am
        JOIN MaintenanceActivity ma ON ma.ActivityID = am.ActivityID
        WHERE ma.CompleteAt >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        GROUP BY am.MechanicID
    ) recent_work ON recent_work.MechanicID = m.MechanicID
    LEFT JOIN (
        SELECT 
            am.MechanicID,
            COUNT(DISTINCT am.ActivityID) AS TotalActivities,
            SUM(am.LabourHours) AS TotalLifetimeHours
        FROM ActivityMechanic am
        GROUP BY am.MechanicID
    ) lifetime_work ON lifetime_work.MechanicID = m.MechanicID
    WHERE 
        (p_workshop_id IS NULL OR m.WorkshopID = p_workshop_id)
    GROUP BY 
        m.MechanicID, m.FirstName, m.LastName, m.EmploymentStatus,
        w.WorkshopID, w.Name,
        current_work.ActiveActivities, current_work.TotalActiveHours,
        recent_work.CompletedActivities, recent_work.TotalHoursLast30Days, recent_work.RepeatFaults,
        lifetime_work.TotalActivities, lifetime_work.TotalLifetimeHours
    ORDER BY 
        w.Name,
        FIELD(AvailabilityStatus, 'Available', 'Light Load', 'Moderate Load', 'Heavy Load', 'Unavailable'),
        m.LastName;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_workshop_summary: Workshop performance metrics
-- ROLE: Workshop Manager
-- Uses indexes: idx_mj_workshop, idx_ma_job
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_workshop_summary`;

DELIMITER $$
CREATE PROCEDURE `sp_workshop_summary` (
    IN p_workshop_id INT UNSIGNED
)
BEGIN
    SELECT 
        w.WorkshopID,
        w.Name AS WorkshopName,
        dep.Name AS DepotName,
        w.NumBays,
        COALESCE(js.TotalJobs, 0) AS TotalJobs,
        COALESCE(js.OpenJobs, 0) AS OpenJobs,
        COALESCE(js.ClosedJobs, 0) AS ClosedJobs,
        COALESCE(js.TotalRevenue, 0) AS TotalRevenue,
        COALESCE(js.AvgJobCost, 0) AS AvgJobCost,
        COALESCE(js.AvgDaysToComplete, 0) AS AvgDaysToComplete,
        COALESCE(js.TotalDowntimeHours, 0) AS TotalDowntimeHours,
        COALESCE(ms.TotalMechanics, 0) AS TotalMechanics,
        COALESCE(ms.ActiveMechanics, 0) AS ActiveMechanics,
        ROUND((COALESCE(js.OpenJobs, 0) / NULLIF(w.NumBays, 0)) * 100, 2) AS BayUtilizationPercent
    FROM Workshop w
    JOIN Depots dep ON dep.DepotID = w.DepotID
    LEFT JOIN (
        SELECT WorkshopID, COUNT(*) AS TotalJobs,
               SUM(DateClosed IS NULL) AS OpenJobs, SUM(DateClosed IS NOT NULL) AS ClosedJobs,
               SUM(TotalCost) AS TotalRevenue, AVG(TotalCost) AS AvgJobCost,
               AVG(CASE WHEN DateClosed IS NOT NULL THEN DATEDIFF(DateClosed, DateOpened) END) AS AvgDaysToComplete,
               SUM(OverallDowntime) AS TotalDowntimeHours
        FROM MaintenanceJobs GROUP BY WorkshopID
    ) js ON js.WorkshopID = w.WorkshopID
    LEFT JOIN (
        SELECT WorkshopID, COUNT(*) AS TotalMechanics,
               SUM(EmploymentStatus = 'Active') AS ActiveMechanics
        FROM Mechanic GROUP BY WorkshopID
    ) ms ON ms.WorkshopID = w.WorkshopID
    WHERE 
        (p_workshop_id IS NULL OR w.WorkshopID = p_workshop_id)
    ;
END$$
DELIMITER ;

-- =====================================================================
-- End of Workshop Manager procedures
-- =====================================================================


-- =====================================================================
-- MECHANIC PROCEDURES â€” for individual mechanic operations
-- =====================================================================
-- ROLE: MECHANIC
-- These procedures provide row-scoped access to jobs and activities
-- assigned to the specific mechanic, supporting their daily work tasks.
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_get_mechanic_assigned_jobs: Get own assigned jobs/activities
-- ROLE: Mechanic
-- Uses indexes: idx_am_mechanic, idx_ma_job, idx_mj_workshop
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_get_mechanic_assigned_jobs`;

DELIMITER $$
CREATE PROCEDURE `sp_get_mechanic_assigned_jobs` (
    IN p_mechanic_id INT UNSIGNED,
    IN p_include_completed BOOLEAN
)
BEGIN
    SELECT 
        mj.JobID,
        mj.VehicleID,
        v.RegistrationNumber,
        CONCAT(vm.Manufacturer, ' ', vm.ModelName) AS VehicleModel,
        v.YearOfManufacture,
        v.CurrentOdometerReading,
        w.Name AS WorkshopName,
        mj.DateOpened,
        mj.DateClosed,
        ma.ActivityID,
        at.Name AS ActivityType,
        ma.DiagnosticResult,
        ma.IsRepeatFault,
        ma.StartedAt,
        ma.CompleteAt,
        am.LabourHours,
        CASE 
            WHEN ma.CompleteAt IS NOT NULL THEN 'Completed'
            WHEN ma.StartedAt IS NOT NULL THEN 'In Progress'
            ELSE 'Not Started'
        END AS ActivityStatus,
        CASE 
            WHEN mj.DateClosed IS NOT NULL THEN 'Job Closed'
            ELSE 'Job Open'
        END AS JobStatus,
        pa.AlertType,
        pa.Severity AS AlertSeverity,
        DATEDIFF(CURDATE(), mj.DateOpened) AS DaysOpen,
        -- Other mechanics on the same activity
        GROUP_CONCAT(
            DISTINCT CASE 
                WHEN am2.MechanicID != p_mechanic_id 
                THEN CONCAT(m2.FirstName, ' ', m2.LastName) 
            END 
            ORDER BY m2.LastName 
            SEPARATOR ', '
        ) AS OtherMechanics
    FROM ActivityMechanic am
    JOIN MaintenanceActivity ma ON ma.ActivityID = am.ActivityID
    JOIN MaintenanceJobs mj ON mj.JobID = ma.JobID
    JOIN Vehicles v ON v.VehicleID = mj.VehicleID
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN Workshop w ON w.WorkshopID = mj.WorkshopID
    JOIN ActivityType at ON at.ActivityTypeID = ma.ActivityTypeID
    LEFT JOIN PredictiveAlert pa ON pa.AlertID = mj.AlertID
    LEFT JOIN ActivityMechanic am2 ON am2.ActivityID = ma.ActivityID
    LEFT JOIN Mechanic m2 ON m2.MechanicID = am2.MechanicID
    WHERE 
        am.MechanicID = p_mechanic_id
        AND (
            p_include_completed = TRUE 
            OR (mj.DateClosed IS NULL AND ma.CompleteAt IS NULL)
        )
    GROUP BY 
        mj.JobID, mj.VehicleID, v.RegistrationNumber, vm.Manufacturer, vm.ModelName,
        v.YearOfManufacture, v.CurrentOdometerReading, w.Name, mj.DateOpened, 
        mj.DateClosed, ma.ActivityID, at.Name, ma.DiagnosticResult, 
        ma.IsRepeatFault, ma.StartedAt, ma.CompleteAt, am.LabourHours,
        pa.AlertType, pa.Severity
    ORDER BY 
        CASE 
            WHEN ma.StartedAt IS NOT NULL AND ma.CompleteAt IS NULL THEN 1
            WHEN ma.StartedAt IS NULL THEN 2
            ELSE 3
        END,
        mj.DateOpened ASC;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_get_mechanic_job_detail: Get detailed info for own assigned job
-- ROLE: Mechanic
-- Uses indexes: idx_am_mechanic, idx_ma_job, idx_ap_part
-- Returns multiple result sets: job info, own activities, parts used, team
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_get_mechanic_job_detail`;

DELIMITER $$
CREATE PROCEDURE `sp_get_mechanic_job_detail` (
    IN p_mechanic_id INT UNSIGNED,
    IN p_job_id INT UNSIGNED
)
BEGIN
    -- Verify mechanic is assigned to this job
    DECLARE v_is_assigned INT DEFAULT 0;
    
    SELECT COUNT(*) INTO v_is_assigned
    FROM ActivityMechanic am
    JOIN MaintenanceActivity ma ON ma.ActivityID = am.ActivityID
    WHERE am.MechanicID = p_mechanic_id
        AND ma.JobID = p_job_id;
    
    IF v_is_assigned = 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Access denied: mechanic is not assigned to this job';
    END IF;

    -- Job header info
    SELECT 
        mj.JobID,
        mj.VehicleID,
        v.RegistrationNumber,
        CONCAT(vm.Manufacturer, ' ', vm.ModelName) AS VehicleModel,
        v.YearOfManufacture,
        v.CurrentOdometerReading,
        vc.CategoryName AS VehicleCategory,
        w.Name AS WorkshopName,
        dep.Name AS DepotName,
        mj.DateOpened,
        mj.DateClosed,
        mj.TotalCost,
        pa.AlertType,
        pa.Severity AS AlertSeverity,
        pa.GeneratedAt AS AlertGeneratedAt,
        CASE 
            WHEN mj.DateClosed IS NOT NULL THEN 'Closed'
            ELSE 'Open'
        END AS JobStatus
    FROM MaintenanceJobs mj
    JOIN Vehicles v ON v.VehicleID = mj.VehicleID
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN VehiclesCategory vc ON vc.CategoryID = v.CategoryID
    JOIN Workshop w ON w.WorkshopID = mj.WorkshopID
    JOIN Depots dep ON dep.DepotID = w.DepotID
    LEFT JOIN PredictiveAlert pa ON pa.AlertID = mj.AlertID
    WHERE mj.JobID = p_job_id;

    -- Own activities in this job
    SELECT 
        ma.ActivityID,
        at.Name AS ActivityType,
        ma.DiagnosticResult,
        ma.IsRepeatFault,
        ma.StartedAt,
        ma.CompleteAt,
        am.LabourHours,
        CASE 
            WHEN ma.CompleteAt IS NOT NULL THEN 'Completed'
            WHEN ma.StartedAt IS NOT NULL THEN 'In Progress'
            ELSE 'Not Started'
        END AS Status,
        TIMESTAMPDIFF(HOUR, ma.StartedAt, COALESCE(ma.CompleteAt, NOW())) AS HoursSpent
    FROM MaintenanceActivity ma
    JOIN ActivityType at ON at.ActivityTypeID = ma.ActivityTypeID
    JOIN ActivityMechanic am ON am.ActivityID = ma.ActivityID
    WHERE ma.JobID = p_job_id
        AND am.MechanicID = p_mechanic_id
    ORDER BY ma.StartedAt DESC, ma.ActivityID;

    -- Parts used in own activities
    SELECT 
        ma.ActivityID,
        p.PartID,
        p.PartNumber,
        p.Description AS PartDescription,
        ap.QuantityUsed,
        ap.UnitPriceAtTime,
        (ap.QuantityUsed * ap.UnitPriceAtTime) AS TotalCost,
        p.QuantityInStock AS CurrentStock
    FROM MaintenanceActivity ma
    JOIN ActivityMechanic am ON am.ActivityID = ma.ActivityID
    JOIN ActivityPart ap ON ap.ActivityID = ma.ActivityID
    JOIN Part p ON p.PartID = ap.PartID
    WHERE ma.JobID = p_job_id
        AND am.MechanicID = p_mechanic_id
    ORDER BY ma.ActivityID, p.PartNumber;

    -- Other team members on this job
    SELECT 
        m.MechanicID,
        CONCAT(m.FirstName, ' ', m.LastName) AS MechanicName,
        COUNT(DISTINCT am.ActivityID) AS ActivitiesCount,
        SUM(am.LabourHours) AS TotalHours,
        GROUP_CONCAT(DISTINCT at.Name ORDER BY at.Name SEPARATOR ', ') AS ActivityTypes
    FROM ActivityMechanic am
    JOIN Mechanic m ON m.MechanicID = am.MechanicID
    JOIN MaintenanceActivity ma ON ma.ActivityID = am.ActivityID
    JOIN ActivityType at ON at.ActivityTypeID = ma.ActivityTypeID
    WHERE ma.JobID = p_job_id
        AND am.MechanicID != p_mechanic_id
    GROUP BY m.MechanicID, m.FirstName, m.LastName
    ORDER BY m.LastName;

    -- All activities in job (for context)
    SELECT 
        ma.ActivityID,
        at.Name AS ActivityType,
        ma.StartedAt,
        ma.CompleteAt,
        CASE 
            WHEN ma.CompleteAt IS NOT NULL THEN 'Completed'
            WHEN ma.StartedAt IS NOT NULL THEN 'In Progress'
            ELSE 'Not Started'
        END AS Status,
        CASE 
            WHEN am_check.MechanicID = p_mechanic_id THEN TRUE
            ELSE FALSE
        END AS IsOwnActivity
    FROM MaintenanceActivity ma
    JOIN ActivityType at ON at.ActivityTypeID = ma.ActivityTypeID
    LEFT JOIN ActivityMechanic am_check ON am_check.ActivityID = ma.ActivityID 
        AND am_check.MechanicID = p_mechanic_id
    WHERE ma.JobID = p_job_id
    ORDER BY ma.StartedAt DESC, ma.ActivityID;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_search_parts: Search parts inventory for logging usage
-- ROLE: Mechanic
-- Uses indexes: idx_part_stock
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_search_parts`;

DELIMITER $$
CREATE PROCEDURE `sp_search_parts` (
    IN p_search_term VARCHAR(100),
    IN p_min_stock INT,
    IN p_show_available_only BOOLEAN
)
BEGIN
    SELECT 
        p.PartID,
        p.PartNumber,
        p.Description,
        p.UnitPrice,
        p.QuantityInStock,
        p.ReorderThreshold,
        CASE 
            WHEN p.QuantityInStock = 0 THEN 'Out of Stock'
            WHEN p.QuantityInStock <= p.ReorderThreshold THEN 'Low Stock'
            WHEN p.QuantityInStock <= (p.ReorderThreshold * 2) THEN 'Moderate Stock'
            ELSE 'Good Stock'
        END AS StockStatus,
        s.Name AS PrimarySupplier,
        sp.UnitCost AS SupplierCost,
        s.LeadTimeDays,
        recent_usage.RecentUsageCount,
        recent_usage.LastUsedDate
    FROM Part p
    LEFT JOIN SupplyPart sp ON sp.PartID = p.PartID AND sp.IsPrimary = TRUE
    LEFT JOIN Supplier s ON s.SupplierID = sp.SupplierID
    LEFT JOIN (
        SELECT 
            ap.PartID,
            COUNT(*) AS RecentUsageCount,
            MAX(ma.CompleteAt) AS LastUsedDate
        FROM ActivityPart ap
        JOIN MaintenanceActivity ma ON ma.ActivityID = ap.ActivityID
        WHERE ma.CompleteAt >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
        GROUP BY ap.PartID
    ) recent_usage ON recent_usage.PartID = p.PartID
    WHERE 
        (p_search_term IS NULL OR 
         p.PartNumber LIKE CONCAT('%', p_search_term, '%') OR
         p.Description LIKE CONCAT('%', p_search_term, '%'))
        AND (p_min_stock IS NULL OR p.QuantityInStock >= p_min_stock)
        AND (p_show_available_only = FALSE OR p.QuantityInStock > 0)
    ORDER BY 
        CASE WHEN p.PartNumber LIKE CONCAT(p_search_term, '%') THEN 1 ELSE 2 END,
        p.PartNumber;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_get_mechanic_workload_summary: Get own workload summary
-- ROLE: Mechanic
-- Uses indexes: idx_am_mechanic, idx_mc_mechanic
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_get_mechanic_workload_summary`;

DELIMITER $$
CREATE PROCEDURE `sp_get_mechanic_workload_summary` (
    IN p_mechanic_id INT UNSIGNED
)
BEGIN
    -- Personal info and certifications
    SELECT 
        m.MechanicID,
        CONCAT(m.FirstName, ' ', m.LastName) AS MechanicName,
        m.EmploymentStatus,
        w.Name AS WorkshopName,
        GROUP_CONCAT(DISTINCT mct.Name ORDER BY mct.Name SEPARATOR ', ') AS Certifications,
        COUNT(DISTINCT mc.MecCertID) AS CertificationCount,
        SUM(CASE WHEN mc.ExpireDate IS NOT NULL AND mc.ExpireDate <= DATE_ADD(CURDATE(), INTERVAL 60 DAY) 
            THEN 1 ELSE 0 END) AS ExpiringCertificationsCount
    FROM Mechanic m
    JOIN Workshop w ON w.WorkshopID = m.WorkshopID
    LEFT JOIN MechanicCertification mc ON mc.MechanicID = m.MechanicID
        AND (mc.ExpireDate IS NULL OR mc.ExpireDate >= CURDATE())
    LEFT JOIN MechanicCertType mct ON mct.MecCertTypeID = mc.MecCertTypeID
    WHERE m.MechanicID = p_mechanic_id
    GROUP BY m.MechanicID, m.FirstName, m.LastName, m.EmploymentStatus, w.Name;

    -- Current workload
    SELECT 
        COUNT(DISTINCT am.ActivityID) AS ActiveActivities,
        COUNT(DISTINCT ma.JobID) AS ActiveJobs,
        SUM(am.LabourHours) AS TotalActiveHours,
        COUNT(DISTINCT CASE WHEN ma.StartedAt IS NOT NULL AND ma.CompleteAt IS NULL THEN ma.ActivityID END) AS InProgressActivities,
        COUNT(DISTINCT CASE WHEN ma.StartedAt IS NULL THEN ma.ActivityID END) AS NotStartedActivities
    FROM ActivityMechanic am
    JOIN MaintenanceActivity ma ON ma.ActivityID = am.ActivityID
    JOIN MaintenanceJobs mj ON mj.JobID = ma.JobID
    WHERE am.MechanicID = p_mechanic_id
        AND mj.DateClosed IS NULL
        AND ma.CompleteAt IS NULL;

    -- Recent performance (last 30 days)
    SELECT 
        COUNT(DISTINCT am.ActivityID) AS CompletedActivities,
        SUM(am.LabourHours) AS TotalHours,
        COUNT(DISTINCT ma.JobID) AS JobsWorkedOn,
        COUNT(DISTINCT CASE WHEN ma.IsRepeatFault = TRUE THEN ma.ActivityID END) AS RepeatFaults,
        AVG(TIMESTAMPDIFF(HOUR, ma.StartedAt, ma.CompleteAt)) AS AvgHoursPerActivity
    FROM ActivityMechanic am
    JOIN MaintenanceActivity ma ON ma.ActivityID = am.ActivityID
    WHERE am.MechanicID = p_mechanic_id
        AND ma.CompleteAt >= DATE_SUB(CURDATE(), INTERVAL 30 DAY);

    -- Certifications with expiry dates
    SELECT 
        mc.MecCertID,
        mct.Name AS CertificationType,
        mc.IssueDate,
        mc.ExpireDate,
        CASE 
            WHEN mc.ExpireDate IS NULL THEN 'No Expiry'
            WHEN mc.ExpireDate < CURDATE() THEN 'Expired'
            WHEN mc.ExpireDate <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 'Expiring Very Soon'
            WHEN mc.ExpireDate <= DATE_ADD(CURDATE(), INTERVAL 60 DAY) THEN 'Expiring Soon'
            ELSE 'Valid'
        END AS Status,
        DATEDIFF(mc.ExpireDate, CURDATE()) AS DaysUntilExpiry
    FROM MechanicCertification mc
    JOIN MechanicCertType mct ON mct.MecCertTypeID = mc.MecCertTypeID
    WHERE mc.MechanicID = p_mechanic_id
    ORDER BY 
        FIELD(Status, 'Expired', 'Expiring Very Soon', 'Expiring Soon', 'Valid', 'No Expiry'),
        mc.ExpireDate ASC;
END$$
DELIMITER ;

-- =====================================================================
-- End of Mechanic procedures
-- =====================================================================


-- =====================================================================
-- DRIVER PROCEDURES â€” for individual driver self-service operations
-- =====================================================================
-- ROLE: DRIVER
-- These procedures provide row-scoped read-only access to the driver's
-- own vehicle assignments, safety records, and coaching history.
-- =====================================================================

-- ---------------------------------------------------------------------
-- sp_get_driver_own_vehicle: Get own currently assigned vehicle
-- ROLE: Driver
-- Uses indexes: idx_va_driver
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_get_driver_own_vehicle`;

DELIMITER $$
CREATE PROCEDURE `sp_get_driver_own_vehicle` (
    IN p_driver_id INT UNSIGNED
)
BEGIN
    SELECT 
        v.VehicleID,
        v.RegistrationNumber,
        vm.ModelName AS Model,
        vm.Manufacturer,
        v.YearOfManufacture,
        v.CurrentOdometerReading,
        v.OperationalStatus,
        vc.CategoryName AS VehicleCategory,
        dep.Name AS DepotName,
        dep.City AS DepotCity,
        CONCAT_WS(', ', dep.StreetAddress, dep.District, dep.City) AS DepotAddress,
        va.AssignmentID,
        va.StartDate AS AssignedSince,
        va.EndDate AS AssignmentEndDate,
        va.IsPermanent,
        DATEDIFF(COALESCE(va.EndDate, CURDATE()), va.StartDate) AS AssignmentDurationDays,
        -- Vehicle certification requirements
        GROUP_CONCAT(DISTINCT ct.Name ORDER BY ct.Name SEPARATOR ', ') AS RequiredCertifications,
        -- Recent maintenance info
        recent_maint.LastMaintenanceDate,
        recent_maint.LastMaintenanceType,
        open_job.HasOpenMaintenanceJob
    FROM VehicleAssignments va
    JOIN Vehicles v ON v.VehicleID = va.VehicleID
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN VehiclesCategory vc ON vc.CategoryID = v.CategoryID
    JOIN Depots dep ON dep.DepotID = va.DepotID
    LEFT JOIN VehicleCertRequirement vcr ON vcr.CategoryID = v.CategoryID
    LEFT JOIN CertificationType ct ON ct.CertTypeID = vcr.CertTypeID
    LEFT JOIN (
        SELECT 
            mj.VehicleID,
            MAX(mj.DateClosed) AS LastMaintenanceDate,
            GROUP_CONCAT(DISTINCT at.Name ORDER BY at.Name SEPARATOR ', ') AS LastMaintenanceType
        FROM MaintenanceJobs mj
        JOIN MaintenanceActivity ma ON ma.JobID = mj.JobID
        JOIN ActivityType at ON at.ActivityTypeID = ma.ActivityTypeID
        WHERE mj.DateClosed IS NOT NULL
        GROUP BY mj.VehicleID
    ) recent_maint ON recent_maint.VehicleID = v.VehicleID
    LEFT JOIN (
        SELECT 
            VehicleID,
            TRUE AS HasOpenMaintenanceJob
        FROM MaintenanceJobs
        WHERE DateClosed IS NULL
    ) open_job ON open_job.VehicleID = v.VehicleID
    WHERE 
        va.DriverID = p_driver_id
        AND va.StartDate <= CURDATE() AND (va.EndDate IS NULL OR va.EndDate >= CURDATE())
    GROUP BY 
        v.VehicleID, v.RegistrationNumber, vm.ModelName, vm.Manufacturer,
        v.YearOfManufacture, v.CurrentOdometerReading, v.OperationalStatus,
        vc.CategoryName, dep.Name, dep.StreetAddress, dep.District, dep.City,
        va.AssignmentID, va.StartDate, va.EndDate, va.IsPermanent,
        recent_maint.LastMaintenanceDate, recent_maint.LastMaintenanceType,
        open_job.HasOpenMaintenanceJob
    LIMIT 1;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_get_driver_complete_profile: Get complete driver profile 
-- ROLE: Driver
-- Uses indexes: idx_se_driver, idx_dc_driver, idx_va_driver, idx_cr_driver
-- Returns multiple result sets: personal info, current vehicle, safety score,
-- events, coaching, certifications, score history
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_get_driver_complete_profile`;

DELIMITER $$
CREATE PROCEDURE `sp_get_driver_complete_profile` (
    IN p_driver_id INT UNSIGNED
)
BEGIN
    -- Personal information
    SELECT 
        dr.DriverID,
        dr.FirstName,
        dr.LastName,
        dr.ContactPhoneNumber,
        dr.LicenceType,
        dr.LicenceExpiryDate,
        dr.EmploymentStatus,
        dr.EmergencyContactPhone,
        dep.Name AS DepotName,
        dep.City AS DepotCity,
        dep.ContactPhone AS DepotContact,
        CASE 
            WHEN dr.LicenceExpiryDate < CURDATE() THEN 'Expired'
            WHEN dr.LicenceExpiryDate <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 'Expiring Soon'
            ELSE 'Valid'
        END AS LicenceStatus,
        DATEDIFF(dr.LicenceExpiryDate, CURDATE()) AS DaysUntilLicenceExpiry
    FROM Drivers dr
    JOIN Depots dep ON dep.DepotID = dr.DepotID
    WHERE dr.DriverID = p_driver_id;

    -- Current vehicle assignment
    SELECT 
        v.VehicleID,
        v.RegistrationNumber,
        CONCAT(vm.Manufacturer, ' ', vm.ModelName) AS VehicleModel,
        vc.CategoryName AS VehicleCategory,
        v.CurrentOdometerReading,
        v.OperationalStatus,
        va.StartDate AS AssignedSince,
        va.IsPermanent,
        DATEDIFF(CURDATE(), va.StartDate) AS AssignmentDays
    FROM VehicleAssignments va
    JOIN Vehicles v ON v.VehicleID = va.VehicleID
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN VehiclesCategory vc ON vc.CategoryID = v.CategoryID
    WHERE va.DriverID = p_driver_id
        AND va.StartDate <= CURDATE() AND (va.EndDate IS NULL OR va.EndDate >= CURDATE())
    LIMIT 1;

    -- Current safety score
    SELECT 
        dss.ScoreID,
        dss.ScorePeriod,
        dss.BaseScore,
        dss.DeductedPoints,
        dss.FinalScore,
        dss.CoachingRequired,
        dss.Suspended,
        dss.LowCount,
        dss.MediumCount,
        dss.HighCount,
        dss.CriticalCount,
        (dss.LowCount + dss.MediumCount + dss.HighCount + dss.CriticalCount) AS TotalEventsThisMonth,
        CASE 
            WHEN dss.Suspended = TRUE THEN 'Suspended - Complete safety training required'
            WHEN dss.CoachingRequired = TRUE THEN 'Coaching Required'
            WHEN dss.FinalScore >= 90 THEN 'Excellent'
            WHEN dss.FinalScore >= 75 THEN 'Good'
            WHEN dss.FinalScore >= 50 THEN 'Fair'
            ELSE 'Poor'
        END AS PerformanceLevel
    FROM DriverSafetyScore dss
    WHERE dss.DriverID = p_driver_id
    ORDER BY dss.ScorePeriod DESC
    LIMIT 1;

    -- Safety event history (last 20 events)
    SELECT 
        se.EventID,
        se.Timestamp,
        sevt.Name AS EventType,
        se.Severity,
        v.RegistrationNumber AS Vehicle,
        dep.Name AS Location,
        se.Odometer,
        se.ReviewRequired,
        se.ReviewStatus,
        DATEDIFF(CURDATE(), DATE(se.Timestamp)) AS DaysAgo
    FROM SafetyEvents se
    JOIN SafetyEventsType sevt ON sevt.EventsTypeID = se.EventsTypeID
    JOIN Vehicles v ON v.VehicleID = se.VehicleID
    JOIN Depots dep ON dep.DepotID = se.DepotID
    WHERE se.DriverID = p_driver_id
    ORDER BY se.Timestamp DESC
    LIMIT 20;

    -- Coaching history
    SELECT 
        cr.CoachingID,
        cr.Reason,
        cr.RecordType,
        cr.ScheduledDate,
        cr.CompleteDate,
        cr.Outcome,
        CASE 
            WHEN cr.Outcome = 'Pending' AND cr.ScheduledDate < CURDATE() THEN 'Overdue'
            WHEN cr.Outcome = 'Pending' THEN 'Upcoming'
            ELSE cr.Outcome
        END AS Status,
        CASE 
            WHEN cr.Outcome = 'Pending' THEN DATEDIFF(cr.ScheduledDate, CURDATE())
            ELSE NULL
        END AS DaysUntilScheduled
    FROM CoachingRecord cr
    WHERE cr.DriverID = p_driver_id
    ORDER BY 
        FIELD(cr.Outcome, 'Pending', 'Passed', 'Failed', 'Cancelled'),
        cr.ScheduledDate DESC;

    -- Certifications
    SELECT 
        dc.DriverCertID,
        ct.Name AS CertificationType,
        dc.IssueDate,
        dc.ExpireDate,
        CASE 
            WHEN dc.ExpireDate IS NULL THEN 'No Expiry'
            WHEN dc.ExpireDate < CURDATE() THEN 'Expired'
            WHEN dc.ExpireDate <= DATE_ADD(CURDATE(), INTERVAL 30 DAY) THEN 'Expiring Very Soon'
            WHEN dc.ExpireDate <= DATE_ADD(CURDATE(), INTERVAL 60 DAY) THEN 'Expiring Soon'
            ELSE 'Valid'
        END AS Status,
        DATEDIFF(dc.ExpireDate, CURDATE()) AS DaysUntilExpiry
    FROM DriverCertifications dc
    JOIN CertificationType ct ON ct.CertTypeID = dc.CertTypeID
    WHERE dc.DriverID = p_driver_id
    ORDER BY 
        FIELD(Status, 'Expired', 'Expiring Very Soon', 'Expiring Soon', 'Valid', 'No Expiry'),
        dc.ExpireDate ASC;

    -- Safety score history (last 12 months)
    SELECT 
        dss.ScorePeriod,
        dss.FinalScore,
        dss.DeductedPoints,
        dss.CoachingRequired,
        dss.Suspended,
        (dss.LowCount + dss.MediumCount + dss.HighCount + dss.CriticalCount) AS TotalEvents,
        dss.CriticalCount,
        CASE 
            WHEN dss.FinalScore >= 90 THEN 'Excellent'
            WHEN dss.FinalScore >= 75 THEN 'Good'
            WHEN dss.FinalScore >= 50 THEN 'Fair'
            ELSE 'Poor'
        END AS PerformanceLevel
    FROM DriverSafetyScore dss
    WHERE dss.DriverID = p_driver_id
    ORDER BY dss.ScorePeriod DESC
    LIMIT 12;

    -- Assignment history (last 5 assignments)
    SELECT 
        va.AssignmentID,
        v.RegistrationNumber,
        CONCAT(vm.Manufacturer, ' ', vm.ModelName) AS VehicleModel,
        dep.Name AS DepotName,
        va.StartDate,
        va.EndDate,
        va.IsPermanent,
        DATEDIFF(COALESCE(va.EndDate, CURDATE()), va.StartDate) AS DurationDays,
        CASE 
            WHEN va.StartDate <= CURDATE() AND (va.EndDate IS NULL OR va.EndDate >= CURDATE()) THEN 'Current'
            ELSE 'Past'
        END AS Status
    FROM VehicleAssignments va
    JOIN Vehicles v ON v.VehicleID = va.VehicleID
    JOIN VehicleModel vm ON vm.ModelID = v.ModelID
    JOIN Depots dep ON dep.DepotID = va.DepotID
    WHERE va.DriverID = p_driver_id
    ORDER BY va.StartDate DESC
    LIMIT 5;

    -- Summary statistics
    SELECT 
        'Summary' AS MetricType,
        COUNT(DISTINCT se.EventID) AS TotalSafetyEvents,
        COUNT(DISTINCT CASE WHEN se.Severity = 'Critical' THEN se.EventID END) AS CriticalEvents,
        COUNT(DISTINCT CASE WHEN se.Severity = 'High' THEN se.EventID END) AS HighEvents,
        COUNT(DISTINCT cr.CoachingID) AS TotalCoachingSessions,
        COUNT(DISTINCT CASE WHEN cr.Outcome = 'Pending' THEN cr.CoachingID END) AS PendingCoaching,
        COUNT(DISTINCT CASE WHEN cr.Outcome = 'Passed' THEN cr.CoachingID END) AS PassedCoaching,
        COUNT(DISTINCT va.AssignmentID) AS TotalAssignments,
        COUNT(DISTINCT dc.DriverCertID) AS TotalCertifications,
        COUNT(DISTINCT CASE WHEN dc.ExpireDate < CURDATE() THEN dc.DriverCertID END) AS ExpiredCertifications
    FROM Drivers dr
    LEFT JOIN SafetyEvents se ON se.DriverID = dr.DriverID
    LEFT JOIN CoachingRecord cr ON cr.DriverID = dr.DriverID
    LEFT JOIN VehicleAssignments va ON va.DriverID = dr.DriverID
    LEFT JOIN DriverCertifications dc ON dc.DriverID = dr.DriverID
    WHERE dr.DriverID = p_driver_id;
END$$
DELIMITER ;

-- ---------------------------------------------------------------------
-- sp_get_driver_safety_summary: Get safety performance summary
-- ROLE: Driver
-- Uses indexes: idx_se_driver, idx_cr_driver
-- ---------------------------------------------------------------------
DROP PROCEDURE IF EXISTS `sp_get_driver_safety_summary`;

DELIMITER $$
CREATE PROCEDURE `sp_get_driver_safety_summary` (
    IN p_driver_id INT UNSIGNED
)
BEGIN
    SELECT 
        -- Current score
        COALESCE(latest_score.FinalScore, 100) AS CurrentSafetyScore,
        COALESCE(latest_score.ScorePeriod, DATE_FORMAT(CURDATE(), '%Y-%m')) AS CurrentPeriod,
        COALESCE(latest_score.CoachingRequired, FALSE) AS CoachingRequired,
        COALESCE(latest_score.Suspended, FALSE) AS Suspended,
        
        -- Event counts (last 3 months)
        COUNT(DISTINCT CASE WHEN se.Timestamp >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH) 
                            THEN se.EventID END) AS EventsLast3Months,
        COUNT(DISTINCT CASE WHEN se.Severity = 'Critical' AND se.Timestamp >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
                            THEN se.EventID END) AS CriticalEventsLast3Months,
        COUNT(DISTINCT CASE WHEN se.Severity = 'High' AND se.Timestamp >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
                            THEN se.EventID END) AS HighEventsLast3Months,
        
        -- Coaching status
        COUNT(DISTINCT CASE WHEN cr.Outcome = 'Pending' THEN cr.CoachingID END) AS PendingCoachingSessions,
        MAX(CASE WHEN cr.Outcome = 'Pending' THEN cr.ScheduledDate END) AS NextCoachingDate,
        
        -- Certifications
        COUNT(DISTINCT dc.DriverCertID) AS TotalCertifications,
        COUNT(DISTINCT CASE WHEN dc.ExpireDate IS NOT NULL AND dc.ExpireDate < CURDATE()
                            THEN dc.DriverCertID END) AS ExpiredCertifications,
        COUNT(DISTINCT CASE WHEN dc.ExpireDate BETWEEN CURDATE() AND DATE_ADD(CURDATE(), INTERVAL 60 DAY)
                            THEN dc.DriverCertID END) AS CertificationsExpiringSoon,
        
        -- Performance level
        CASE 
            WHEN COALESCE(latest_score.Suspended, FALSE) = TRUE THEN 'Suspended'
            WHEN COALESCE(latest_score.CoachingRequired, FALSE) = TRUE THEN 'Coaching Required'
            WHEN COALESCE(latest_score.FinalScore, 100) >= 90 THEN 'Excellent'
            WHEN COALESCE(latest_score.FinalScore, 100) >= 75 THEN 'Good'
            WHEN COALESCE(latest_score.FinalScore, 100) >= 50 THEN 'Fair'
            ELSE 'Poor'
        END AS PerformanceLevel,
        
        -- Alerts/warnings
        CASE 
            WHEN dr.LicenceExpiryDate < CURDATE() THEN 'URGENT: Driving licence expired'
            WHEN EXISTS(SELECT 1 FROM DriverCertifications dc2 
                        WHERE dc2.DriverID = p_driver_id 
                        AND dc2.ExpireDate < CURDATE()) THEN 'WARNING: Expired certifications'
            WHEN COALESCE(latest_score.Suspended, FALSE) = TRUE THEN 'ALERT: Suspended - Complete safety training'
            WHEN COALESCE(latest_score.CoachingRequired, FALSE) = TRUE THEN 'NOTICE: Coaching required'
            ELSE 'No alerts'
        END AS Alert
        
    FROM Drivers dr
    LEFT JOIN (
        SELECT 
            DriverID, 
            FinalScore, 
            ScorePeriod,
            CoachingRequired,
            Suspended,
            ROW_NUMBER() OVER (PARTITION BY DriverID ORDER BY ScorePeriod DESC) AS rn
        FROM DriverSafetyScore
    ) latest_score ON latest_score.DriverID = dr.DriverID AND latest_score.rn = 1
    LEFT JOIN SafetyEvents se ON se.DriverID = dr.DriverID
    LEFT JOIN CoachingRecord cr ON cr.DriverID = dr.DriverID
    LEFT JOIN DriverCertifications dc ON dc.DriverID = dr.DriverID
    WHERE dr.DriverID = p_driver_id
    GROUP BY 
        dr.DriverID, dr.LicenceExpiryDate,
        latest_score.FinalScore, latest_score.ScorePeriod,
        latest_score.CoachingRequired, latest_score.Suspended;
END$$
DELIMITER ;

-- =====================================================================
-- End of Driver procedures
-- =====================================================================


-- =====================================================================
-- SYSTEM/AUTHENTICATION PROCEDURES 
-- =====================================================================
-- ROLE: System (Authentication/Authorization)
-- 
-- The following procedures were implemented earlier in this file and
-- are used by the backend authentication and authorization system:
--
-- 1. sp_get_user_permissions (lines ~840-865)
--    - Get user's roles and resolved permissions
--    - Used during login to load user's permission set
--    - Returns 2 result sets: roles and permissions
--    - Uses indexes: idx_ur_role, idx_rp_permission
--
-- 2. sp_check_user_permission (lines ~877-892)
--    - Check if user has specific permission (table.action)
--    - Used by requirePermission() middleware in _bootstrap.php
--    - Returns: 1 if permission exists, 0 if not
--    - Uses indexes: idx_ur_role, idx_rp_permission
--
-- 3. sp_list_users_by_role (lines ~804-830)
--    - List users filtered by role
--    - Used by Fleet Admin for user management
--    - Uses indexes: idx_ur_role, idx_ua_driver, idx_ua_mechanic, idx_ua_depot
--
-- AUTHENTICATION IMPLEMENTATION (in backend/api/auth.php):
-- 
--  POST /api/auth.php?action=login                                 
--    - Authenticates user with username/password                   
--    - Rate limiting (5 attempts per 15 minutes per IP)            
--    - Uses login_attempts table for brute-force protection        
--    - Stores user session with permissions in $_SESSION           
--    - Calls sp_get_user_permissions to load permission set        
--                                                                    
--  POST /api/auth.php?action=logout                                
--    - Destroys user session                                       
--                                                                    
--  GET /api/auth.php?action=me                                     
--    - Returns current user info and permissions                   
-- 
--
-- AUTHORIZATION MIDDLEWARE (in backend/api/_bootstrap.php):
-- 
-- â”‚ requirePermission($table, $action)                              â”‚
-- â”‚   - Called before each API operation                            â”‚
-- â”‚   - Checks $_SESSION['permissions'] against requested action    â”‚
-- â”‚   - Returns 403 Forbidden if permission denied                  â”‚
-- â”‚   - Uses cached permissions (no DB query per request)           â”‚
-- â”‚                                                                   â”‚
-- â”‚ hasPermission($table, $action)                                  â”‚
-- â”‚   - Helper function to check permission                         â”‚
-- â”‚   - Returns boolean                                             â”‚
-- 
--
-- USAGE EXAMPLE:
--   // In any API endpoint (fleet.php, workshop.php, etc.):
--   requirePermission('Vehicles', 'SELECT');  // Check read permission
--   requirePermission('Vehicles', 'INSERT');  // Check create permission
--   requirePermission('Vehicles', 'UPDATE');  // Check update permission
--   requirePermission('Vehicles', 'DELETE');  // Check delete permission
--
-- SECURITY FEATURES:
--   âœ“ Bcrypt password hashing (PASSWORD_DEFAULT)
--   âœ“ Automatic hash rehashing when algorithm improves
--   âœ“ Timing-safe username enumeration protection
--   âœ“ Rate limiting (5 attempts / 15 minutes / IP)
--   âœ“ Session-based authentication
--   âœ“ Permission caching in session (no DB query per request)
--   âœ“ Role-based access control (RBAC)
--   âœ“ Table.Action granular permissions
--
-- NOTES:
--   - No additional authentication procedures needed
--   - System already implements best-practice auth/authz
--   - Permissions are loaded once at login and cached in session
--   - requirePermission() is called before every sensitive operation
-- =====================================================================
