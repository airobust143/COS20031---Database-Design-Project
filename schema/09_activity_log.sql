-- ACTIVITY LOG / AUDIT TRAIL

USE `smart_fleet_management`;


-- 1. AuditLog table

DROP TABLE IF EXISTS `AuditLog`;

CREATE TABLE `AuditLog` (
    `LogID`          BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
    `RequestID`      CHAR(36)        NULL     COMMENT 'Groups every row written during one HTTP request/transaction',
    `TableName`      VARCHAR(64)     NOT NULL,
    `RecordPK`       VARCHAR(150)    NOT NULL COMMENT 'Textual PK; composite keys are stored as "val1-val2"',
    `Action`         ENUM('INSERT','UPDATE','DELETE') NOT NULL,
    `ChangedFields`  JSON            NULL     COMMENT 'UPDATE only: JSON array of column names that actually changed',
    `OldData`        JSON            NULL     COMMENT 'Full row snapshot before the change (NULL for INSERT)',
    `NewData`        JSON            NULL     COMMENT 'Full row snapshot after the change (NULL for DELETE)',
    `ActorUserID`    INT UNSIGNED    NULL     COMMENT 'UserAccount.UserID at the time of the change',
    `ActorUsername`  VARCHAR(50)     NULL     COMMENT 'Snapshotted so the log still reads correctly if the account is later renamed/deleted',
    `ActorRole`      VARCHAR(50)     NULL     COMMENT 'RoleName snapshot at the time of the change ($_SESSION[\'role\'])',
    `DbUser`         VARCHAR(100)    NULL     COMMENT 'Raw MySQL login (CURRENT_USER()) — always populated, even for non-app writers',
    `ClientIP`       VARCHAR(45)     NULL,
    `ChangedAt`      DATETIME(6)     NOT NULL DEFAULT CURRENT_TIMESTAMP(6),

    PRIMARY KEY (`LogID`),
    KEY `idx_audit_table_record`      (`TableName`, `RecordPK`),
    KEY `idx_audit_table_action_time` (`TableName`, `Action`, `ChangedAt`),
    KEY `idx_audit_actor`             (`ActorUserID`),
    KEY `idx_audit_time`              (`ChangedAt`),
    KEY `idx_audit_request`           (`RequestID`),

    CONSTRAINT `fk_audit_actor`
        FOREIGN KEY (`ActorUserID`) REFERENCES `UserAccount` (`UserID`)
        ON DELETE SET NULL ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- 2. sp_write_audit_log — single insertion point for every trigger below.
--    Diffs OldData/NewData generically; a no-op UPDATE is not logged.

DROP PROCEDURE IF EXISTS `sp_write_audit_log`;

DELIMITER $$
CREATE PROCEDURE `sp_write_audit_log` (
    IN p_table     VARCHAR(64),
    IN p_action    ENUM('INSERT','UPDATE','DELETE'),
    IN p_record_pk VARCHAR(150),
    IN p_old_data  JSON,
    IN p_new_data  JSON
)
BEGIN
    DECLARE v_changed  JSON DEFAULT JSON_ARRAY();
    DECLARE v_keys     JSON;
    DECLARE v_count     INT DEFAULT 0;
    DECLARE v_i         INT DEFAULT 0;
    DECLARE v_key       VARCHAR(191);
    DECLARE v_path      VARCHAR(200);
    DECLARE v_should_write TINYINT DEFAULT 1;

    IF p_action = 'UPDATE' THEN
        SET v_keys  = JSON_KEYS(p_new_data);
        SET v_count = JSON_LENGTH(v_keys);
        WHILE v_i < v_count DO
            SET v_key  = JSON_UNQUOTE(JSON_EXTRACT(v_keys, CONCAT('$[', v_i, ']')));
            SET v_path = CONCAT('$."', v_key, '"');
            IF NOT (JSON_EXTRACT(p_old_data, v_path) <=> JSON_EXTRACT(p_new_data, v_path)) THEN
                SET v_changed = JSON_ARRAY_APPEND(v_changed, '$', v_key);
            END IF;
            SET v_i = v_i + 1;
        END WHILE;

        IF JSON_LENGTH(v_changed) = 0 THEN
            SET v_should_write = 0; -- nothing actually changed; don't spam the log
        END IF;
    END IF;

    IF v_should_write = 1 THEN
        INSERT INTO `AuditLog`
            (`RequestID`, `TableName`, `RecordPK`, `Action`,
             `ChangedFields`, `OldData`, `NewData`,
             `ActorUserID`, `ActorUsername`, `ActorRole`, `DbUser`, `ClientIP`)
        VALUES
            (@sf_request_id, p_table, p_record_pk, p_action,
             IF(p_action = 'UPDATE', v_changed, NULL), p_old_data, p_new_data,
             @sf_actor_id, @sf_actor_username, @sf_actor_role, CURRENT_USER(), @sf_client_ip);
    END IF;
END$$
DELIMITER ;


-- 3. Per-table audit triggers

-- Depots 
DROP TRIGGER IF EXISTS `trg_dep_ai_audit`;
DROP TRIGGER IF EXISTS `trg_dep_au_audit`;
DROP TRIGGER IF EXISTS `trg_dep_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_dep_ai_audit` AFTER INSERT ON `Depots` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Depots', 'INSERT', CAST(NEW.`DepotID` AS CHAR), NULL,
        JSON_OBJECT('DepotID',NEW.`DepotID`,'Name',NEW.`Name`,'StreetAddress',NEW.`StreetAddress`,
                     'District',NEW.`District`,'City',NEW.`City`,'ContactPhone',NEW.`ContactPhone`));
END$$

CREATE TRIGGER `trg_dep_au_audit` AFTER UPDATE ON `Depots` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Depots', 'UPDATE', CAST(NEW.`DepotID` AS CHAR),
        JSON_OBJECT('DepotID',OLD.`DepotID`,'Name',OLD.`Name`,'StreetAddress',OLD.`StreetAddress`,
                     'District',OLD.`District`,'City',OLD.`City`,'ContactPhone',OLD.`ContactPhone`),
        JSON_OBJECT('DepotID',NEW.`DepotID`,'Name',NEW.`Name`,'StreetAddress',NEW.`StreetAddress`,
                     'District',NEW.`District`,'City',NEW.`City`,'ContactPhone',NEW.`ContactPhone`));
END$$

CREATE TRIGGER `trg_dep_ad_audit` AFTER DELETE ON `Depots` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Depots', 'DELETE', CAST(OLD.`DepotID` AS CHAR),
        JSON_OBJECT('DepotID',OLD.`DepotID`,'Name',OLD.`Name`,'StreetAddress',OLD.`StreetAddress`,
                     'District',OLD.`District`,'City',OLD.`City`,'ContactPhone',OLD.`ContactPhone`),
        NULL);
END$$
DELIMITER ;

-- VehiclesCategory 
DROP TRIGGER IF EXISTS `trg_vc_ai_audit`;
DROP TRIGGER IF EXISTS `trg_vc_au_audit`;
DROP TRIGGER IF EXISTS `trg_vc_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_vc_ai_audit` AFTER INSERT ON `VehiclesCategory` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehiclesCategory', 'INSERT', CAST(NEW.`CategoryID` AS CHAR), NULL,
        JSON_OBJECT('CategoryID',NEW.`CategoryID`,'CategoryName',NEW.`CategoryName`));
END$$

CREATE TRIGGER `trg_vc_au_audit` AFTER UPDATE ON `VehiclesCategory` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehiclesCategory', 'UPDATE', CAST(NEW.`CategoryID` AS CHAR),
        JSON_OBJECT('CategoryID',OLD.`CategoryID`,'CategoryName',OLD.`CategoryName`),
        JSON_OBJECT('CategoryID',NEW.`CategoryID`,'CategoryName',NEW.`CategoryName`));
END$$

CREATE TRIGGER `trg_vc_ad_audit` AFTER DELETE ON `VehiclesCategory` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehiclesCategory', 'DELETE', CAST(OLD.`CategoryID` AS CHAR),
        JSON_OBJECT('CategoryID',OLD.`CategoryID`,'CategoryName',OLD.`CategoryName`),
        NULL);
END$$
DELIMITER ;

-- VehicleModel 
DROP TRIGGER IF EXISTS `trg_vm_ai_audit`;
DROP TRIGGER IF EXISTS `trg_vm_au_audit`;
DROP TRIGGER IF EXISTS `trg_vm_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_vm_ai_audit` AFTER INSERT ON `VehicleModel` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehicleModel', 'INSERT', CAST(NEW.`ModelID` AS CHAR), NULL,
        JSON_OBJECT('ModelID',NEW.`ModelID`,'ModelName',NEW.`ModelName`,'Manufacturer',NEW.`Manufacturer`));
END$$

CREATE TRIGGER `trg_vm_au_audit` AFTER UPDATE ON `VehicleModel` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehicleModel', 'UPDATE', CAST(NEW.`ModelID` AS CHAR),
        JSON_OBJECT('ModelID',OLD.`ModelID`,'ModelName',OLD.`ModelName`,'Manufacturer',OLD.`Manufacturer`),
        JSON_OBJECT('ModelID',NEW.`ModelID`,'ModelName',NEW.`ModelName`,'Manufacturer',NEW.`Manufacturer`));
END$$

CREATE TRIGGER `trg_vm_ad_audit` AFTER DELETE ON `VehicleModel` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehicleModel', 'DELETE', CAST(OLD.`ModelID` AS CHAR),
        JSON_OBJECT('ModelID',OLD.`ModelID`,'ModelName',OLD.`ModelName`,'Manufacturer',OLD.`Manufacturer`),
        NULL);
END$$
DELIMITER ;

-- Vehicles
DROP TRIGGER IF EXISTS `trg_v_ai_audit`;
DROP TRIGGER IF EXISTS `trg_v_au_audit`;
DROP TRIGGER IF EXISTS `trg_v_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_v_ai_audit` AFTER INSERT ON `Vehicles` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Vehicles', 'INSERT', CAST(NEW.`VehicleID` AS CHAR), NULL,
        JSON_OBJECT('VehicleID',NEW.`VehicleID`,'RegistrationNumber',NEW.`RegistrationNumber`,'CategoryID',NEW.`CategoryID`,
                     'ModelID',NEW.`ModelID`,'YearOfManufacture',NEW.`YearOfManufacture`,
                     'CurrentOdometerReading',NEW.`CurrentOdometerReading`,'DepotID',NEW.`DepotID`,'OperationalStatus',NEW.`OperationalStatus`));
END$$

CREATE TRIGGER `trg_v_au_audit` AFTER UPDATE ON `Vehicles` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Vehicles', 'UPDATE', CAST(NEW.`VehicleID` AS CHAR),
        JSON_OBJECT('VehicleID',OLD.`VehicleID`,'RegistrationNumber',OLD.`RegistrationNumber`,'CategoryID',OLD.`CategoryID`,
                     'ModelID',OLD.`ModelID`,'YearOfManufacture',OLD.`YearOfManufacture`,
                     'CurrentOdometerReading',OLD.`CurrentOdometerReading`,'DepotID',OLD.`DepotID`,'OperationalStatus',OLD.`OperationalStatus`),
        JSON_OBJECT('VehicleID',NEW.`VehicleID`,'RegistrationNumber',NEW.`RegistrationNumber`,'CategoryID',NEW.`CategoryID`,
                     'ModelID',NEW.`ModelID`,'YearOfManufacture',NEW.`YearOfManufacture`,
                     'CurrentOdometerReading',NEW.`CurrentOdometerReading`,'DepotID',NEW.`DepotID`,'OperationalStatus',NEW.`OperationalStatus`));
END$$

CREATE TRIGGER `trg_v_ad_audit` AFTER DELETE ON `Vehicles` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Vehicles', 'DELETE', CAST(OLD.`VehicleID` AS CHAR),
        JSON_OBJECT('VehicleID',OLD.`VehicleID`,'RegistrationNumber',OLD.`RegistrationNumber`,'CategoryID',OLD.`CategoryID`,
                     'ModelID',OLD.`ModelID`,'YearOfManufacture',OLD.`YearOfManufacture`,
                     'CurrentOdometerReading',OLD.`CurrentOdometerReading`,'DepotID',OLD.`DepotID`,'OperationalStatus',OLD.`OperationalStatus`),
        NULL);
END$$
DELIMITER ;

-- VehiclesDepotHistory 
DROP TRIGGER IF EXISTS `trg_vdh_ai_audit`;
DROP TRIGGER IF EXISTS `trg_vdh_au_audit`;
DROP TRIGGER IF EXISTS `trg_vdh_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_vdh_ai_audit` AFTER INSERT ON `VehiclesDepotHistory` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehiclesDepotHistory', 'INSERT', CAST(NEW.`HistoryID` AS CHAR), NULL,
        JSON_OBJECT('HistoryID',NEW.`HistoryID`,'VehicleID',NEW.`VehicleID`,'DepotID',NEW.`DepotID`,'MovedFrom',NEW.`MovedFrom`,'MovedTo',NEW.`MovedTo`));
END$$

CREATE TRIGGER `trg_vdh_au_audit` AFTER UPDATE ON `VehiclesDepotHistory` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehiclesDepotHistory', 'UPDATE', CAST(NEW.`HistoryID` AS CHAR),
        JSON_OBJECT('HistoryID',OLD.`HistoryID`,'VehicleID',OLD.`VehicleID`,'DepotID',OLD.`DepotID`,'MovedFrom',OLD.`MovedFrom`,'MovedTo',OLD.`MovedTo`),
        JSON_OBJECT('HistoryID',NEW.`HistoryID`,'VehicleID',NEW.`VehicleID`,'DepotID',NEW.`DepotID`,'MovedFrom',NEW.`MovedFrom`,'MovedTo',NEW.`MovedTo`));
END$$

CREATE TRIGGER `trg_vdh_ad_audit` AFTER DELETE ON `VehiclesDepotHistory` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehiclesDepotHistory', 'DELETE', CAST(OLD.`HistoryID` AS CHAR),
        JSON_OBJECT('HistoryID',OLD.`HistoryID`,'VehicleID',OLD.`VehicleID`,'DepotID',OLD.`DepotID`,'MovedFrom',OLD.`MovedFrom`,'MovedTo',OLD.`MovedTo`),
        NULL);
END$$
DELIMITER ;

-- VehicleAssignments 
DROP TRIGGER IF EXISTS `trg_va_ai_audit`;
DROP TRIGGER IF EXISTS `trg_va_au_audit`;
DROP TRIGGER IF EXISTS `trg_va_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_va_ai_audit` AFTER INSERT ON `VehicleAssignments` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehicleAssignments', 'INSERT', CAST(NEW.`AssignmentID` AS CHAR), NULL,
        JSON_OBJECT('AssignmentID',NEW.`AssignmentID`,'VehicleID',NEW.`VehicleID`,'DriverID',NEW.`DriverID`,
                     'StartDate',NEW.`StartDate`,'EndDate',NEW.`EndDate`,'IsPermanent',NEW.`IsPermanent`,'DepotID',NEW.`DepotID`));
END$$

CREATE TRIGGER `trg_va_au_audit` AFTER UPDATE ON `VehicleAssignments` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehicleAssignments', 'UPDATE', CAST(NEW.`AssignmentID` AS CHAR),
        JSON_OBJECT('AssignmentID',OLD.`AssignmentID`,'VehicleID',OLD.`VehicleID`,'DriverID',OLD.`DriverID`,
                     'StartDate',OLD.`StartDate`,'EndDate',OLD.`EndDate`,'IsPermanent',OLD.`IsPermanent`,'DepotID',OLD.`DepotID`),
        JSON_OBJECT('AssignmentID',NEW.`AssignmentID`,'VehicleID',NEW.`VehicleID`,'DriverID',NEW.`DriverID`,
                     'StartDate',NEW.`StartDate`,'EndDate',NEW.`EndDate`,'IsPermanent',NEW.`IsPermanent`,'DepotID',NEW.`DepotID`));
END$$

CREATE TRIGGER `trg_va_ad_audit` AFTER DELETE ON `VehicleAssignments` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehicleAssignments', 'DELETE', CAST(OLD.`AssignmentID` AS CHAR),
        JSON_OBJECT('AssignmentID',OLD.`AssignmentID`,'VehicleID',OLD.`VehicleID`,'DriverID',OLD.`DriverID`,
                     'StartDate',OLD.`StartDate`,'EndDate',OLD.`EndDate`,'IsPermanent',OLD.`IsPermanent`,'DepotID',OLD.`DepotID`),
        NULL);
END$$
DELIMITER ;



-- CertificationType 
DROP TRIGGER IF EXISTS `trg_cty_ai_audit`;
DROP TRIGGER IF EXISTS `trg_cty_au_audit`;
DROP TRIGGER IF EXISTS `trg_cty_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_cty_ai_audit` AFTER INSERT ON `CertificationType` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('CertificationType', 'INSERT', CAST(NEW.`CertTypeID` AS CHAR), NULL,
        JSON_OBJECT('CertTypeID',NEW.`CertTypeID`,'Name',NEW.`Name`,'Expire',NEW.`Expire`));
END$$

CREATE TRIGGER `trg_cty_au_audit` AFTER UPDATE ON `CertificationType` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('CertificationType', 'UPDATE', CAST(NEW.`CertTypeID` AS CHAR),
        JSON_OBJECT('CertTypeID',OLD.`CertTypeID`,'Name',OLD.`Name`,'Expire',OLD.`Expire`),
        JSON_OBJECT('CertTypeID',NEW.`CertTypeID`,'Name',NEW.`Name`,'Expire',NEW.`Expire`));
END$$

CREATE TRIGGER `trg_cty_ad_audit` AFTER DELETE ON `CertificationType` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('CertificationType', 'DELETE', CAST(OLD.`CertTypeID` AS CHAR),
        JSON_OBJECT('CertTypeID',OLD.`CertTypeID`,'Name',OLD.`Name`,'Expire',OLD.`Expire`),
        NULL);
END$$
DELIMITER ;

-- SafetyEventsType 
DROP TRIGGER IF EXISTS `trg_sety_ai_audit`;
DROP TRIGGER IF EXISTS `trg_sety_au_audit`;
DROP TRIGGER IF EXISTS `trg_sety_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_sety_ai_audit` AFTER INSERT ON `SafetyEventsType` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('SafetyEventsType', 'INSERT', CAST(NEW.`EventsTypeID` AS CHAR), NULL,
        JSON_OBJECT('EventsTypeID',NEW.`EventsTypeID`,'Name',NEW.`Name`,'DefaultSeverity',NEW.`DefaultSeverity`));
END$$

CREATE TRIGGER `trg_sety_au_audit` AFTER UPDATE ON `SafetyEventsType` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('SafetyEventsType', 'UPDATE', CAST(NEW.`EventsTypeID` AS CHAR),
        JSON_OBJECT('EventsTypeID',OLD.`EventsTypeID`,'Name',OLD.`Name`,'DefaultSeverity',OLD.`DefaultSeverity`),
        JSON_OBJECT('EventsTypeID',NEW.`EventsTypeID`,'Name',NEW.`Name`,'DefaultSeverity',NEW.`DefaultSeverity`));
END$$

CREATE TRIGGER `trg_sety_ad_audit` AFTER DELETE ON `SafetyEventsType` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('SafetyEventsType', 'DELETE', CAST(OLD.`EventsTypeID` AS CHAR),
        JSON_OBJECT('EventsTypeID',OLD.`EventsTypeID`,'Name',OLD.`Name`,'DefaultSeverity',OLD.`DefaultSeverity`),
        NULL);
END$$
DELIMITER ;

-- Drivers
DROP TRIGGER IF EXISTS `trg_drv_ai_audit`;
DROP TRIGGER IF EXISTS `trg_drv_au_audit`;
DROP TRIGGER IF EXISTS `trg_drv_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_drv_ai_audit` AFTER INSERT ON `Drivers` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Drivers', 'INSERT', CAST(NEW.`DriverID` AS CHAR), NULL,
        JSON_OBJECT('DriverID',NEW.`DriverID`,'FirstName',NEW.`FirstName`,'LastName',NEW.`LastName`,
                     'ContactPhoneNumber',NEW.`ContactPhoneNumber`,'DepotID',NEW.`DepotID`,'LicenceType',NEW.`LicenceType`,
                     'LicenceExpiryDate',NEW.`LicenceExpiryDate`,'EmploymentStatus',NEW.`EmploymentStatus`,
                     'EmergencyContactPhone',NEW.`EmergencyContactPhone`));
END$$

CREATE TRIGGER `trg_drv_au_audit` AFTER UPDATE ON `Drivers` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Drivers', 'UPDATE', CAST(NEW.`DriverID` AS CHAR),
        JSON_OBJECT('DriverID',OLD.`DriverID`,'FirstName',OLD.`FirstName`,'LastName',OLD.`LastName`,
                     'ContactPhoneNumber',OLD.`ContactPhoneNumber`,'DepotID',OLD.`DepotID`,'LicenceType',OLD.`LicenceType`,
                     'LicenceExpiryDate',OLD.`LicenceExpiryDate`,'EmploymentStatus',OLD.`EmploymentStatus`,
                     'EmergencyContactPhone',OLD.`EmergencyContactPhone`),
        JSON_OBJECT('DriverID',NEW.`DriverID`,'FirstName',NEW.`FirstName`,'LastName',NEW.`LastName`,
                     'ContactPhoneNumber',NEW.`ContactPhoneNumber`,'DepotID',NEW.`DepotID`,'LicenceType',NEW.`LicenceType`,
                     'LicenceExpiryDate',NEW.`LicenceExpiryDate`,'EmploymentStatus',NEW.`EmploymentStatus`,
                     'EmergencyContactPhone',NEW.`EmergencyContactPhone`));
END$$

CREATE TRIGGER `trg_drv_ad_audit` AFTER DELETE ON `Drivers` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Drivers', 'DELETE', CAST(OLD.`DriverID` AS CHAR),
        JSON_OBJECT('DriverID',OLD.`DriverID`,'FirstName',OLD.`FirstName`,'LastName',OLD.`LastName`,
                     'ContactPhoneNumber',OLD.`ContactPhoneNumber`,'DepotID',OLD.`DepotID`,'LicenceType',OLD.`LicenceType`,
                     'LicenceExpiryDate',OLD.`LicenceExpiryDate`,'EmploymentStatus',OLD.`EmploymentStatus`,
                     'EmergencyContactPhone',OLD.`EmergencyContactPhone`),
        NULL);
END$$
DELIMITER ;

-- DriverCertifications 
DROP TRIGGER IF EXISTS `trg_dc_ai_audit`;
DROP TRIGGER IF EXISTS `trg_dc_au_audit`;
DROP TRIGGER IF EXISTS `trg_dc_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_dc_ai_audit` AFTER INSERT ON `DriverCertifications` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('DriverCertifications', 'INSERT', CAST(NEW.`DriverCertID` AS CHAR), NULL,
        JSON_OBJECT('DriverCertID',NEW.`DriverCertID`,'DriverID',NEW.`DriverID`,'CertTypeID',NEW.`CertTypeID`,
                     'IssueDate',NEW.`IssueDate`,'ExpireDate',NEW.`ExpireDate`));
END$$

CREATE TRIGGER `trg_dc_au_audit` AFTER UPDATE ON `DriverCertifications` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('DriverCertifications', 'UPDATE', CAST(NEW.`DriverCertID` AS CHAR),
        JSON_OBJECT('DriverCertID',OLD.`DriverCertID`,'DriverID',OLD.`DriverID`,'CertTypeID',OLD.`CertTypeID`,
                     'IssueDate',OLD.`IssueDate`,'ExpireDate',OLD.`ExpireDate`),
        JSON_OBJECT('DriverCertID',NEW.`DriverCertID`,'DriverID',NEW.`DriverID`,'CertTypeID',NEW.`CertTypeID`,
                     'IssueDate',NEW.`IssueDate`,'ExpireDate',NEW.`ExpireDate`));
END$$

CREATE TRIGGER `trg_dc_ad_audit` AFTER DELETE ON `DriverCertifications` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('DriverCertifications', 'DELETE', CAST(OLD.`DriverCertID` AS CHAR),
        JSON_OBJECT('DriverCertID',OLD.`DriverCertID`,'DriverID',OLD.`DriverID`,'CertTypeID',OLD.`CertTypeID`,
                     'IssueDate',OLD.`IssueDate`,'ExpireDate',OLD.`ExpireDate`),
        NULL);
END$$
DELIMITER ;

-- VehicleCertRequirement 
DROP TRIGGER IF EXISTS `trg_vcr_ai_audit`;
DROP TRIGGER IF EXISTS `trg_vcr_au_audit`;
DROP TRIGGER IF EXISTS `trg_vcr_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_vcr_ai_audit` AFTER INSERT ON `VehicleCertRequirement` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehicleCertRequirement', 'INSERT', CAST(NEW.`ReqID` AS CHAR), NULL,
        JSON_OBJECT('ReqID',NEW.`ReqID`,'CategoryID',NEW.`CategoryID`,'CertTypeID',NEW.`CertTypeID`));
END$$

CREATE TRIGGER `trg_vcr_au_audit` AFTER UPDATE ON `VehicleCertRequirement` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehicleCertRequirement', 'UPDATE', CAST(NEW.`ReqID` AS CHAR),
        JSON_OBJECT('ReqID',OLD.`ReqID`,'CategoryID',OLD.`CategoryID`,'CertTypeID',OLD.`CertTypeID`),
        JSON_OBJECT('ReqID',NEW.`ReqID`,'CategoryID',NEW.`CategoryID`,'CertTypeID',NEW.`CertTypeID`));
END$$

CREATE TRIGGER `trg_vcr_ad_audit` AFTER DELETE ON `VehicleCertRequirement` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('VehicleCertRequirement', 'DELETE', CAST(OLD.`ReqID` AS CHAR),
        JSON_OBJECT('ReqID',OLD.`ReqID`,'CategoryID',OLD.`CategoryID`,'CertTypeID',OLD.`CertTypeID`),
        NULL);
END$$
DELIMITER ;

-- DriverSafetyScore
DROP TRIGGER IF EXISTS `trg_dss_ai_audit`;
DROP TRIGGER IF EXISTS `trg_dss_au_audit`;
DROP TRIGGER IF EXISTS `trg_dss_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_dss_ai_audit` AFTER INSERT ON `DriverSafetyScore` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('DriverSafetyScore', 'INSERT', CAST(NEW.`ScoreID` AS CHAR), NULL,
        JSON_OBJECT('ScoreID',NEW.`ScoreID`,'DriverID',NEW.`DriverID`,'ScorePeriod',NEW.`ScorePeriod`,
                     'BaseScore',NEW.`BaseScore`,'DeductedPoints',NEW.`DeductedPoints`,'FinalScore',NEW.`FinalScore`,
                     'CoachingRequired',NEW.`CoachingRequired`,'Suspended',NEW.`Suspended`,'LowCount',NEW.`LowCount`,
                     'MediumCount',NEW.`MediumCount`,'HighCount',NEW.`HighCount`,'CriticalCount',NEW.`CriticalCount`));
END$$

CREATE TRIGGER `trg_dss_au_audit` AFTER UPDATE ON `DriverSafetyScore` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('DriverSafetyScore', 'UPDATE', CAST(NEW.`ScoreID` AS CHAR),
        JSON_OBJECT('ScoreID',OLD.`ScoreID`,'DriverID',OLD.`DriverID`,'ScorePeriod',OLD.`ScorePeriod`,
                     'BaseScore',OLD.`BaseScore`,'DeductedPoints',OLD.`DeductedPoints`,'FinalScore',OLD.`FinalScore`,
                     'CoachingRequired',OLD.`CoachingRequired`,'Suspended',OLD.`Suspended`,'LowCount',OLD.`LowCount`,
                     'MediumCount',OLD.`MediumCount`,'HighCount',OLD.`HighCount`,'CriticalCount',OLD.`CriticalCount`),
        JSON_OBJECT('ScoreID',NEW.`ScoreID`,'DriverID',NEW.`DriverID`,'ScorePeriod',NEW.`ScorePeriod`,
                     'BaseScore',NEW.`BaseScore`,'DeductedPoints',NEW.`DeductedPoints`,'FinalScore',NEW.`FinalScore`,
                     'CoachingRequired',NEW.`CoachingRequired`,'Suspended',NEW.`Suspended`,'LowCount',NEW.`LowCount`,
                     'MediumCount',NEW.`MediumCount`,'HighCount',NEW.`HighCount`,'CriticalCount',NEW.`CriticalCount`));
END$$

CREATE TRIGGER `trg_dss_ad_audit` AFTER DELETE ON `DriverSafetyScore` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('DriverSafetyScore', 'DELETE', CAST(OLD.`ScoreID` AS CHAR),
        JSON_OBJECT('ScoreID',OLD.`ScoreID`,'DriverID',OLD.`DriverID`,'ScorePeriod',OLD.`ScorePeriod`,
                     'BaseScore',OLD.`BaseScore`,'DeductedPoints',OLD.`DeductedPoints`,'FinalScore',OLD.`FinalScore`,
                     'CoachingRequired',OLD.`CoachingRequired`,'Suspended',OLD.`Suspended`,'LowCount',OLD.`LowCount`,
                     'MediumCount',OLD.`MediumCount`,'HighCount',OLD.`HighCount`,'CriticalCount',OLD.`CriticalCount`),
        NULL);
END$$
DELIMITER ;

-- SafetyEvents 
DROP TRIGGER IF EXISTS `trg_se_ai_audit`;
DROP TRIGGER IF EXISTS `trg_se_au_audit`;
DROP TRIGGER IF EXISTS `trg_se_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_se_ai_audit` AFTER INSERT ON `SafetyEvents` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('SafetyEvents', 'INSERT', CAST(NEW.`EventID` AS CHAR), NULL,
        JSON_OBJECT('EventID',NEW.`EventID`,'Timestamp',NEW.`Timestamp`,'VehicleID',NEW.`VehicleID`,'DriverID',NEW.`DriverID`,
                     'EventsTypeID',NEW.`EventsTypeID`,'Severity',NEW.`Severity`,'DepotID',NEW.`DepotID`,'Odometer',NEW.`Odometer`,
                     'ReviewRequired',NEW.`ReviewRequired`,'ReviewStatus',NEW.`ReviewStatus`));
END$$

CREATE TRIGGER `trg_se_au_audit` AFTER UPDATE ON `SafetyEvents` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('SafetyEvents', 'UPDATE', CAST(NEW.`EventID` AS CHAR),
        JSON_OBJECT('EventID',OLD.`EventID`,'Timestamp',OLD.`Timestamp`,'VehicleID',OLD.`VehicleID`,'DriverID',OLD.`DriverID`,
                     'EventsTypeID',OLD.`EventsTypeID`,'Severity',OLD.`Severity`,'DepotID',OLD.`DepotID`,'Odometer',OLD.`Odometer`,
                     'ReviewRequired',OLD.`ReviewRequired`,'ReviewStatus',OLD.`ReviewStatus`),
        JSON_OBJECT('EventID',NEW.`EventID`,'Timestamp',NEW.`Timestamp`,'VehicleID',NEW.`VehicleID`,'DriverID',NEW.`DriverID`,
                     'EventsTypeID',NEW.`EventsTypeID`,'Severity',NEW.`Severity`,'DepotID',NEW.`DepotID`,'Odometer',NEW.`Odometer`,
                     'ReviewRequired',NEW.`ReviewRequired`,'ReviewStatus',NEW.`ReviewStatus`));
END$$

CREATE TRIGGER `trg_se_ad_audit` AFTER DELETE ON `SafetyEvents` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('SafetyEvents', 'DELETE', CAST(OLD.`EventID` AS CHAR),
        JSON_OBJECT('EventID',OLD.`EventID`,'Timestamp',OLD.`Timestamp`,'VehicleID',OLD.`VehicleID`,'DriverID',OLD.`DriverID`,
                     'EventsTypeID',OLD.`EventsTypeID`,'Severity',OLD.`Severity`,'DepotID',OLD.`DepotID`,'Odometer',OLD.`Odometer`,
                     'ReviewRequired',OLD.`ReviewRequired`,'ReviewStatus',OLD.`ReviewStatus`),
        NULL);
END$$
DELIMITER ;

-- CoachingRecord 
DROP TRIGGER IF EXISTS `trg_cr_ai_audit`;
DROP TRIGGER IF EXISTS `trg_cr_au_audit`;
DROP TRIGGER IF EXISTS `trg_cr_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_cr_ai_audit` AFTER INSERT ON `CoachingRecord` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('CoachingRecord', 'INSERT', CAST(NEW.`CoachingID` AS CHAR), NULL,
        JSON_OBJECT('CoachingID',NEW.`CoachingID`,'DriverID',NEW.`DriverID`,'Reason',NEW.`Reason`,
                     'ScheduledDate',NEW.`ScheduledDate`,'CompleteDate',NEW.`CompleteDate`,'Outcome',NEW.`Outcome`,
                     'RecordType',NEW.`RecordType`,'EventID',NEW.`EventID`,'ScoreID',NEW.`ScoreID`));
END$$

CREATE TRIGGER `trg_cr_au_audit` AFTER UPDATE ON `CoachingRecord` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('CoachingRecord', 'UPDATE', CAST(NEW.`CoachingID` AS CHAR),
        JSON_OBJECT('CoachingID',OLD.`CoachingID`,'DriverID',OLD.`DriverID`,'Reason',OLD.`Reason`,
                     'ScheduledDate',OLD.`ScheduledDate`,'CompleteDate',OLD.`CompleteDate`,'Outcome',OLD.`Outcome`,
                     'RecordType',OLD.`RecordType`,'EventID',OLD.`EventID`,'ScoreID',OLD.`ScoreID`),
        JSON_OBJECT('CoachingID',NEW.`CoachingID`,'DriverID',NEW.`DriverID`,'Reason',NEW.`Reason`,
                     'ScheduledDate',NEW.`ScheduledDate`,'CompleteDate',NEW.`CompleteDate`,'Outcome',NEW.`Outcome`,
                     'RecordType',NEW.`RecordType`,'EventID',NEW.`EventID`,'ScoreID',NEW.`ScoreID`));
END$$

CREATE TRIGGER `trg_cr_ad_audit` AFTER DELETE ON `CoachingRecord` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('CoachingRecord', 'DELETE', CAST(OLD.`CoachingID` AS CHAR),
        JSON_OBJECT('CoachingID',OLD.`CoachingID`,'DriverID',OLD.`DriverID`,'Reason',OLD.`Reason`,
                     'ScheduledDate',OLD.`ScheduledDate`,'CompleteDate',OLD.`CompleteDate`,'Outcome',OLD.`Outcome`,
                     'RecordType',OLD.`RecordType`,'EventID',OLD.`EventID`,'ScoreID',OLD.`ScoreID`),
        NULL);
END$$
DELIMITER ;



-- Workshop 
DROP TRIGGER IF EXISTS `trg_ws_ai_audit`;
DROP TRIGGER IF EXISTS `trg_ws_au_audit`;
DROP TRIGGER IF EXISTS `trg_ws_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_ws_ai_audit` AFTER INSERT ON `Workshop` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Workshop', 'INSERT', CAST(NEW.`WorkshopID` AS CHAR), NULL,
        JSON_OBJECT('WorkshopID',NEW.`WorkshopID`,'DepotID',NEW.`DepotID`,'Name',NEW.`Name`,
                     'NumBays',NEW.`NumBays`,'ContactEmail',NEW.`ContactEmail`));
END$$

CREATE TRIGGER `trg_ws_au_audit` AFTER UPDATE ON `Workshop` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Workshop', 'UPDATE', CAST(NEW.`WorkshopID` AS CHAR),
        JSON_OBJECT('WorkshopID',OLD.`WorkshopID`,'DepotID',OLD.`DepotID`,'Name',OLD.`Name`,
                     'NumBays',OLD.`NumBays`,'ContactEmail',OLD.`ContactEmail`),
        JSON_OBJECT('WorkshopID',NEW.`WorkshopID`,'DepotID',NEW.`DepotID`,'Name',NEW.`Name`,
                     'NumBays',NEW.`NumBays`,'ContactEmail',NEW.`ContactEmail`));
END$$

CREATE TRIGGER `trg_ws_ad_audit` AFTER DELETE ON `Workshop` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Workshop', 'DELETE', CAST(OLD.`WorkshopID` AS CHAR),
        JSON_OBJECT('WorkshopID',OLD.`WorkshopID`,'DepotID',OLD.`DepotID`,'Name',OLD.`Name`,
                     'NumBays',OLD.`NumBays`,'ContactEmail',OLD.`ContactEmail`),
        NULL);
END$$
DELIMITER ;

-- MechanicCertType 
DROP TRIGGER IF EXISTS `trg_mct_ai_audit`;
DROP TRIGGER IF EXISTS `trg_mct_au_audit`;
DROP TRIGGER IF EXISTS `trg_mct_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_mct_ai_audit` AFTER INSERT ON `MechanicCertType` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('MechanicCertType', 'INSERT', CAST(NEW.`MecCertTypeID` AS CHAR), NULL,
        JSON_OBJECT('MecCertTypeID',NEW.`MecCertTypeID`,'Name',NEW.`Name`,'Expire',NEW.`Expire`));
END$$

CREATE TRIGGER `trg_mct_au_audit` AFTER UPDATE ON `MechanicCertType` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('MechanicCertType', 'UPDATE', CAST(NEW.`MecCertTypeID` AS CHAR),
        JSON_OBJECT('MecCertTypeID',OLD.`MecCertTypeID`,'Name',OLD.`Name`,'Expire',OLD.`Expire`),
        JSON_OBJECT('MecCertTypeID',NEW.`MecCertTypeID`,'Name',NEW.`Name`,'Expire',NEW.`Expire`));
END$$

CREATE TRIGGER `trg_mct_ad_audit` AFTER DELETE ON `MechanicCertType` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('MechanicCertType', 'DELETE', CAST(OLD.`MecCertTypeID` AS CHAR),
        JSON_OBJECT('MecCertTypeID',OLD.`MecCertTypeID`,'Name',OLD.`Name`,'Expire',OLD.`Expire`),
        NULL);
END$$
DELIMITER ;

-- Mechanic 
DROP TRIGGER IF EXISTS `trg_mec_ai_audit`;
DROP TRIGGER IF EXISTS `trg_mec_au_audit`;
DROP TRIGGER IF EXISTS `trg_mec_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_mec_ai_audit` AFTER INSERT ON `Mechanic` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Mechanic', 'INSERT', CAST(NEW.`MechanicID` AS CHAR), NULL,
        JSON_OBJECT('MechanicID',NEW.`MechanicID`,'FirstName',NEW.`FirstName`,'LastName',NEW.`LastName`,
                     'WorkshopID',NEW.`WorkshopID`,'EmploymentStatus',NEW.`EmploymentStatus`));
END$$

CREATE TRIGGER `trg_mec_au_audit` AFTER UPDATE ON `Mechanic` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Mechanic', 'UPDATE', CAST(NEW.`MechanicID` AS CHAR),
        JSON_OBJECT('MechanicID',OLD.`MechanicID`,'FirstName',OLD.`FirstName`,'LastName',OLD.`LastName`,
                     'WorkshopID',OLD.`WorkshopID`,'EmploymentStatus',OLD.`EmploymentStatus`),
        JSON_OBJECT('MechanicID',NEW.`MechanicID`,'FirstName',NEW.`FirstName`,'LastName',NEW.`LastName`,
                     'WorkshopID',NEW.`WorkshopID`,'EmploymentStatus',NEW.`EmploymentStatus`));
END$$

CREATE TRIGGER `trg_mec_ad_audit` AFTER DELETE ON `Mechanic` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Mechanic', 'DELETE', CAST(OLD.`MechanicID` AS CHAR),
        JSON_OBJECT('MechanicID',OLD.`MechanicID`,'FirstName',OLD.`FirstName`,'LastName',OLD.`LastName`,
                     'WorkshopID',OLD.`WorkshopID`,'EmploymentStatus',OLD.`EmploymentStatus`),
        NULL);
END$$
DELIMITER ;

-- MechanicCertification 
DROP TRIGGER IF EXISTS `trg_mc_ai_audit`;
DROP TRIGGER IF EXISTS `trg_mc_au_audit`;
DROP TRIGGER IF EXISTS `trg_mc_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_mc_ai_audit` AFTER INSERT ON `MechanicCertification` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('MechanicCertification', 'INSERT', CAST(NEW.`MecCertID` AS CHAR), NULL,
        JSON_OBJECT('MecCertID',NEW.`MecCertID`,'MechanicID',NEW.`MechanicID`,'MecCertTypeID',NEW.`MecCertTypeID`,
                     'IssueDate',NEW.`IssueDate`,'ExpireDate',NEW.`ExpireDate`));
END$$

CREATE TRIGGER `trg_mc_au_audit` AFTER UPDATE ON `MechanicCertification` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('MechanicCertification', 'UPDATE', CAST(NEW.`MecCertID` AS CHAR),
        JSON_OBJECT('MecCertID',OLD.`MecCertID`,'MechanicID',OLD.`MechanicID`,'MecCertTypeID',OLD.`MecCertTypeID`,
                     'IssueDate',OLD.`IssueDate`,'ExpireDate',OLD.`ExpireDate`),
        JSON_OBJECT('MecCertID',NEW.`MecCertID`,'MechanicID',NEW.`MechanicID`,'MecCertTypeID',NEW.`MecCertTypeID`,
                     'IssueDate',NEW.`IssueDate`,'ExpireDate',NEW.`ExpireDate`));
END$$

CREATE TRIGGER `trg_mc_ad_audit` AFTER DELETE ON `MechanicCertification` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('MechanicCertification', 'DELETE', CAST(OLD.`MecCertID` AS CHAR),
        JSON_OBJECT('MecCertID',OLD.`MecCertID`,'MechanicID',OLD.`MechanicID`,'MecCertTypeID',OLD.`MecCertTypeID`,
                     'IssueDate',OLD.`IssueDate`,'ExpireDate',OLD.`ExpireDate`),
        NULL);
END$$
DELIMITER ;

-- ActivityType 
DROP TRIGGER IF EXISTS `trg_aty_ai_audit`;
DROP TRIGGER IF EXISTS `trg_aty_au_audit`;
DROP TRIGGER IF EXISTS `trg_aty_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_aty_ai_audit` AFTER INSERT ON `ActivityType` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('ActivityType', 'INSERT', CAST(NEW.`ActivityTypeID` AS CHAR), NULL,
        JSON_OBJECT('ActivityTypeID',NEW.`ActivityTypeID`,'Name',NEW.`Name`,'MecCertTypeID',NEW.`MecCertTypeID`));
END$$

CREATE TRIGGER `trg_aty_au_audit` AFTER UPDATE ON `ActivityType` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('ActivityType', 'UPDATE', CAST(NEW.`ActivityTypeID` AS CHAR),
        JSON_OBJECT('ActivityTypeID',OLD.`ActivityTypeID`,'Name',OLD.`Name`,'MecCertTypeID',OLD.`MecCertTypeID`),
        JSON_OBJECT('ActivityTypeID',NEW.`ActivityTypeID`,'Name',NEW.`Name`,'MecCertTypeID',NEW.`MecCertTypeID`));
END$$

CREATE TRIGGER `trg_aty_ad_audit` AFTER DELETE ON `ActivityType` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('ActivityType', 'DELETE', CAST(OLD.`ActivityTypeID` AS CHAR),
        JSON_OBJECT('ActivityTypeID',OLD.`ActivityTypeID`,'Name',OLD.`Name`,'MecCertTypeID',OLD.`MecCertTypeID`),
        NULL);
END$$
DELIMITER ;

-- PredictiveAlert 
DROP TRIGGER IF EXISTS `trg_pa_ai_audit`;
DROP TRIGGER IF EXISTS `trg_pa_au_audit`;
DROP TRIGGER IF EXISTS `trg_pa_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_pa_ai_audit` AFTER INSERT ON `PredictiveAlert` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('PredictiveAlert', 'INSERT', CAST(NEW.`AlertID` AS CHAR), NULL,
        JSON_OBJECT('AlertID',NEW.`AlertID`,'VehicleID',NEW.`VehicleID`,'AlertType',NEW.`AlertType`,'Severity',NEW.`Severity`,
                     'GeneratedAt',NEW.`GeneratedAt`,'Status',NEW.`Status`,'ResolvedAt',NEW.`ResolvedAt`));
END$$

CREATE TRIGGER `trg_pa_au_audit` AFTER UPDATE ON `PredictiveAlert` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('PredictiveAlert', 'UPDATE', CAST(NEW.`AlertID` AS CHAR),
        JSON_OBJECT('AlertID',OLD.`AlertID`,'VehicleID',OLD.`VehicleID`,'AlertType',OLD.`AlertType`,'Severity',OLD.`Severity`,
                     'GeneratedAt',OLD.`GeneratedAt`,'Status',OLD.`Status`,'ResolvedAt',OLD.`ResolvedAt`),
        JSON_OBJECT('AlertID',NEW.`AlertID`,'VehicleID',NEW.`VehicleID`,'AlertType',NEW.`AlertType`,'Severity',NEW.`Severity`,
                     'GeneratedAt',NEW.`GeneratedAt`,'Status',NEW.`Status`,'ResolvedAt',NEW.`ResolvedAt`));
END$$

CREATE TRIGGER `trg_pa_ad_audit` AFTER DELETE ON `PredictiveAlert` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('PredictiveAlert', 'DELETE', CAST(OLD.`AlertID` AS CHAR),
        JSON_OBJECT('AlertID',OLD.`AlertID`,'VehicleID',OLD.`VehicleID`,'AlertType',OLD.`AlertType`,'Severity',OLD.`Severity`,
                     'GeneratedAt',OLD.`GeneratedAt`,'Status',OLD.`Status`,'ResolvedAt',OLD.`ResolvedAt`),
        NULL);
END$$
DELIMITER ;

-- MaintenanceJobs 
DROP TRIGGER IF EXISTS `trg_mj_ai_audit`;
DROP TRIGGER IF EXISTS `trg_mj_au_audit`;
DROP TRIGGER IF EXISTS `trg_mj_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_mj_ai_audit` AFTER INSERT ON `MaintenanceJobs` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('MaintenanceJobs', 'INSERT', CAST(NEW.`JobID` AS CHAR), NULL,
        JSON_OBJECT('JobID',NEW.`JobID`,'VehicleID',NEW.`VehicleID`,'WorkshopID',NEW.`WorkshopID`,'DateOpened',NEW.`DateOpened`,
                     'DateClosed',NEW.`DateClosed`,'OverallDowntime',NEW.`OverallDowntime`,'TotalCost',NEW.`TotalCost`,'AlertID',NEW.`AlertID`));
END$$

CREATE TRIGGER `trg_mj_au_audit` AFTER UPDATE ON `MaintenanceJobs` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('MaintenanceJobs', 'UPDATE', CAST(NEW.`JobID` AS CHAR),
        JSON_OBJECT('JobID',OLD.`JobID`,'VehicleID',OLD.`VehicleID`,'WorkshopID',OLD.`WorkshopID`,'DateOpened',OLD.`DateOpened`,
                     'DateClosed',OLD.`DateClosed`,'OverallDowntime',OLD.`OverallDowntime`,'TotalCost',OLD.`TotalCost`,'AlertID',OLD.`AlertID`),
        JSON_OBJECT('JobID',NEW.`JobID`,'VehicleID',NEW.`VehicleID`,'WorkshopID',NEW.`WorkshopID`,'DateOpened',NEW.`DateOpened`,
                     'DateClosed',NEW.`DateClosed`,'OverallDowntime',NEW.`OverallDowntime`,'TotalCost',NEW.`TotalCost`,'AlertID',NEW.`AlertID`));
END$$

CREATE TRIGGER `trg_mj_ad_audit` AFTER DELETE ON `MaintenanceJobs` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('MaintenanceJobs', 'DELETE', CAST(OLD.`JobID` AS CHAR),
        JSON_OBJECT('JobID',OLD.`JobID`,'VehicleID',OLD.`VehicleID`,'WorkshopID',OLD.`WorkshopID`,'DateOpened',OLD.`DateOpened`,
                     'DateClosed',OLD.`DateClosed`,'OverallDowntime',OLD.`OverallDowntime`,'TotalCost',OLD.`TotalCost`,'AlertID',OLD.`AlertID`),
        NULL);
END$$
DELIMITER ;

-- MaintenanceActivity 
DROP TRIGGER IF EXISTS `trg_ma_ai_audit`;
DROP TRIGGER IF EXISTS `trg_ma_au_audit`;
DROP TRIGGER IF EXISTS `trg_ma_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_ma_ai_audit` AFTER INSERT ON `MaintenanceActivity` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('MaintenanceActivity', 'INSERT', CAST(NEW.`ActivityID` AS CHAR), NULL,
        JSON_OBJECT('ActivityID',NEW.`ActivityID`,'JobID',NEW.`JobID`,'ActivityTypeID',NEW.`ActivityTypeID`,
                     'DiagnosticResult',NEW.`DiagnosticResult`,'IsRepeatFault',NEW.`IsRepeatFault`,
                     'StartedAt',NEW.`StartedAt`,'CompleteAt',NEW.`CompleteAt`));
END$$

CREATE TRIGGER `trg_ma_au_audit` AFTER UPDATE ON `MaintenanceActivity` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('MaintenanceActivity', 'UPDATE', CAST(NEW.`ActivityID` AS CHAR),
        JSON_OBJECT('ActivityID',OLD.`ActivityID`,'JobID',OLD.`JobID`,'ActivityTypeID',OLD.`ActivityTypeID`,
                     'DiagnosticResult',OLD.`DiagnosticResult`,'IsRepeatFault',OLD.`IsRepeatFault`,
                     'StartedAt',OLD.`StartedAt`,'CompleteAt',OLD.`CompleteAt`),
        JSON_OBJECT('ActivityID',NEW.`ActivityID`,'JobID',NEW.`JobID`,'ActivityTypeID',NEW.`ActivityTypeID`,
                     'DiagnosticResult',NEW.`DiagnosticResult`,'IsRepeatFault',NEW.`IsRepeatFault`,
                     'StartedAt',NEW.`StartedAt`,'CompleteAt',NEW.`CompleteAt`));
END$$

CREATE TRIGGER `trg_ma_ad_audit` AFTER DELETE ON `MaintenanceActivity` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('MaintenanceActivity', 'DELETE', CAST(OLD.`ActivityID` AS CHAR),
        JSON_OBJECT('ActivityID',OLD.`ActivityID`,'JobID',OLD.`JobID`,'ActivityTypeID',OLD.`ActivityTypeID`,
                     'DiagnosticResult',OLD.`DiagnosticResult`,'IsRepeatFault',OLD.`IsRepeatFault`,
                     'StartedAt',OLD.`StartedAt`,'CompleteAt',OLD.`CompleteAt`),
        NULL);
END$$
DELIMITER ;

-- ActivityMechanic (composite PK: ActivityID, MechanicID) 
DROP TRIGGER IF EXISTS `trg_am_ai_audit`;
DROP TRIGGER IF EXISTS `trg_am_au_audit`;
DROP TRIGGER IF EXISTS `trg_am_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_am_ai_audit` AFTER INSERT ON `ActivityMechanic` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('ActivityMechanic', 'INSERT', CONCAT(NEW.`ActivityID`,'-',NEW.`MechanicID`), NULL,
        JSON_OBJECT('ActivityID',NEW.`ActivityID`,'MechanicID',NEW.`MechanicID`,'LabourHours',NEW.`LabourHours`));
END$$

CREATE TRIGGER `trg_am_au_audit` AFTER UPDATE ON `ActivityMechanic` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('ActivityMechanic', 'UPDATE', CONCAT(NEW.`ActivityID`,'-',NEW.`MechanicID`),
        JSON_OBJECT('ActivityID',OLD.`ActivityID`,'MechanicID',OLD.`MechanicID`,'LabourHours',OLD.`LabourHours`),
        JSON_OBJECT('ActivityID',NEW.`ActivityID`,'MechanicID',NEW.`MechanicID`,'LabourHours',NEW.`LabourHours`));
END$$

CREATE TRIGGER `trg_am_ad_audit` AFTER DELETE ON `ActivityMechanic` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('ActivityMechanic', 'DELETE', CONCAT(OLD.`ActivityID`,'-',OLD.`MechanicID`),
        JSON_OBJECT('ActivityID',OLD.`ActivityID`,'MechanicID',OLD.`MechanicID`,'LabourHours',OLD.`LabourHours`),
        NULL);
END$$
DELIMITER ;

-- Part 
DROP TRIGGER IF EXISTS `trg_pt_ai_audit`;
DROP TRIGGER IF EXISTS `trg_pt_au_audit`;
DROP TRIGGER IF EXISTS `trg_pt_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_pt_ai_audit` AFTER INSERT ON `Part` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Part', 'INSERT', CAST(NEW.`PartID` AS CHAR), NULL,
        JSON_OBJECT('PartID',NEW.`PartID`,'PartNumber',NEW.`PartNumber`,'Description',NEW.`Description`,
                     'UnitPrice',NEW.`UnitPrice`,'QuantityInStock',NEW.`QuantityInStock`,'ReorderThreshold',NEW.`ReorderThreshold`));
END$$

CREATE TRIGGER `trg_pt_au_audit` AFTER UPDATE ON `Part` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Part', 'UPDATE', CAST(NEW.`PartID` AS CHAR),
        JSON_OBJECT('PartID',OLD.`PartID`,'PartNumber',OLD.`PartNumber`,'Description',OLD.`Description`,
                     'UnitPrice',OLD.`UnitPrice`,'QuantityInStock',OLD.`QuantityInStock`,'ReorderThreshold',OLD.`ReorderThreshold`),
        JSON_OBJECT('PartID',NEW.`PartID`,'PartNumber',NEW.`PartNumber`,'Description',NEW.`Description`,
                     'UnitPrice',NEW.`UnitPrice`,'QuantityInStock',NEW.`QuantityInStock`,'ReorderThreshold',NEW.`ReorderThreshold`));
END$$

CREATE TRIGGER `trg_pt_ad_audit` AFTER DELETE ON `Part` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Part', 'DELETE', CAST(OLD.`PartID` AS CHAR),
        JSON_OBJECT('PartID',OLD.`PartID`,'PartNumber',OLD.`PartNumber`,'Description',OLD.`Description`,
                     'UnitPrice',OLD.`UnitPrice`,'QuantityInStock',OLD.`QuantityInStock`,'ReorderThreshold',OLD.`ReorderThreshold`),
        NULL);
END$$
DELIMITER ;

-- Supplier 
DROP TRIGGER IF EXISTS `trg_sup_ai_audit`;
DROP TRIGGER IF EXISTS `trg_sup_au_audit`;
DROP TRIGGER IF EXISTS `trg_sup_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_sup_ai_audit` AFTER INSERT ON `Supplier` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Supplier', 'INSERT', CAST(NEW.`SupplierID` AS CHAR), NULL,
        JSON_OBJECT('SupplierID',NEW.`SupplierID`,'Name',NEW.`Name`,'ContactEmail',NEW.`ContactEmail`,'LeadTimeDays',NEW.`LeadTimeDays`));
END$$

CREATE TRIGGER `trg_sup_au_audit` AFTER UPDATE ON `Supplier` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Supplier', 'UPDATE', CAST(NEW.`SupplierID` AS CHAR),
        JSON_OBJECT('SupplierID',OLD.`SupplierID`,'Name',OLD.`Name`,'ContactEmail',OLD.`ContactEmail`,'LeadTimeDays',OLD.`LeadTimeDays`),
        JSON_OBJECT('SupplierID',NEW.`SupplierID`,'Name',NEW.`Name`,'ContactEmail',NEW.`ContactEmail`,'LeadTimeDays',NEW.`LeadTimeDays`));
END$$

CREATE TRIGGER `trg_sup_ad_audit` AFTER DELETE ON `Supplier` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Supplier', 'DELETE', CAST(OLD.`SupplierID` AS CHAR),
        JSON_OBJECT('SupplierID',OLD.`SupplierID`,'Name',OLD.`Name`,'ContactEmail',OLD.`ContactEmail`,'LeadTimeDays',OLD.`LeadTimeDays`),
        NULL);
END$$
DELIMITER ;

-- SupplyPart (composite PK: PartID, SupplierID) 
DROP TRIGGER IF EXISTS `trg_sp_ai_audit`;
DROP TRIGGER IF EXISTS `trg_sp_au_audit`;
DROP TRIGGER IF EXISTS `trg_sp_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_sp_ai_audit` AFTER INSERT ON `SupplyPart` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('SupplyPart', 'INSERT', CONCAT(NEW.`PartID`,'-',NEW.`SupplierID`), NULL,
        JSON_OBJECT('PartID',NEW.`PartID`,'SupplierID',NEW.`SupplierID`,'UnitCost',NEW.`UnitCost`,'IsPrimary',NEW.`IsPrimary`));
END$$

CREATE TRIGGER `trg_sp_au_audit` AFTER UPDATE ON `SupplyPart` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('SupplyPart', 'UPDATE', CONCAT(NEW.`PartID`,'-',NEW.`SupplierID`),
        JSON_OBJECT('PartID',OLD.`PartID`,'SupplierID',OLD.`SupplierID`,'UnitCost',OLD.`UnitCost`,'IsPrimary',OLD.`IsPrimary`),
        JSON_OBJECT('PartID',NEW.`PartID`,'SupplierID',NEW.`SupplierID`,'UnitCost',NEW.`UnitCost`,'IsPrimary',NEW.`IsPrimary`));
END$$

CREATE TRIGGER `trg_sp_ad_audit` AFTER DELETE ON `SupplyPart` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('SupplyPart', 'DELETE', CONCAT(OLD.`PartID`,'-',OLD.`SupplierID`),
        JSON_OBJECT('PartID',OLD.`PartID`,'SupplierID',OLD.`SupplierID`,'UnitCost',OLD.`UnitCost`,'IsPrimary',OLD.`IsPrimary`),
        NULL);
END$$
DELIMITER ;

-- ActivityPart (composite PK: ActivityID, PartID) 
DROP TRIGGER IF EXISTS `trg_ap_ai_audit`;
DROP TRIGGER IF EXISTS `trg_ap_au_audit`;
DROP TRIGGER IF EXISTS `trg_ap_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_ap_ai_audit` AFTER INSERT ON `ActivityPart` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('ActivityPart', 'INSERT', CONCAT(NEW.`ActivityID`,'-',NEW.`PartID`), NULL,
        JSON_OBJECT('ActivityID',NEW.`ActivityID`,'PartID',NEW.`PartID`,'QuantityUsed',NEW.`QuantityUsed`,'UnitPriceAtTime',NEW.`UnitPriceAtTime`));
END$$

CREATE TRIGGER `trg_ap_au_audit` AFTER UPDATE ON `ActivityPart` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('ActivityPart', 'UPDATE', CONCAT(NEW.`ActivityID`,'-',NEW.`PartID`),
        JSON_OBJECT('ActivityID',OLD.`ActivityID`,'PartID',OLD.`PartID`,'QuantityUsed',OLD.`QuantityUsed`,'UnitPriceAtTime',OLD.`UnitPriceAtTime`),
        JSON_OBJECT('ActivityID',NEW.`ActivityID`,'PartID',NEW.`PartID`,'QuantityUsed',NEW.`QuantityUsed`,'UnitPriceAtTime',NEW.`UnitPriceAtTime`));
END$$

CREATE TRIGGER `trg_ap_ad_audit` AFTER DELETE ON `ActivityPart` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('ActivityPart', 'DELETE', CONCAT(OLD.`ActivityID`,'-',OLD.`PartID`),
        JSON_OBJECT('ActivityID',OLD.`ActivityID`,'PartID',OLD.`PartID`,'QuantityUsed',OLD.`QuantityUsed`,'UnitPriceAtTime',OLD.`UnitPriceAtTime`),
        NULL);
END$$
DELIMITER ;

-- WarrantyClaim 
DROP TRIGGER IF EXISTS `trg_wc_ai_audit`;
DROP TRIGGER IF EXISTS `trg_wc_au_audit`;
DROP TRIGGER IF EXISTS `trg_wc_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_wc_ai_audit` AFTER INSERT ON `WarrantyClaim` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('WarrantyClaim', 'INSERT', CAST(NEW.`ClaimID` AS CHAR), NULL,
        JSON_OBJECT('ClaimID',NEW.`ClaimID`,'ActivityID',NEW.`ActivityID`,'WarrantyType',NEW.`WarrantyType`,
                     'Status',NEW.`Status`,'ClaimDate',NEW.`ClaimDate`));
END$$

CREATE TRIGGER `trg_wc_au_audit` AFTER UPDATE ON `WarrantyClaim` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('WarrantyClaim', 'UPDATE', CAST(NEW.`ClaimID` AS CHAR),
        JSON_OBJECT('ClaimID',OLD.`ClaimID`,'ActivityID',OLD.`ActivityID`,'WarrantyType',OLD.`WarrantyType`,
                     'Status',OLD.`Status`,'ClaimDate',OLD.`ClaimDate`),
        JSON_OBJECT('ClaimID',NEW.`ClaimID`,'ActivityID',NEW.`ActivityID`,'WarrantyType',NEW.`WarrantyType`,
                     'Status',NEW.`Status`,'ClaimDate',NEW.`ClaimDate`));
END$$

CREATE TRIGGER `trg_wc_ad_audit` AFTER DELETE ON `WarrantyClaim` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('WarrantyClaim', 'DELETE', CAST(OLD.`ClaimID` AS CHAR),
        JSON_OBJECT('ClaimID',OLD.`ClaimID`,'ActivityID',OLD.`ActivityID`,'WarrantyType',OLD.`WarrantyType`,
                     'Status',OLD.`Status`,'ClaimDate',OLD.`ClaimDate`),
        NULL);
END$$
DELIMITER ;

-- WarrantyClaimPart (composite PK: ClaimID, PartID; no non-PK columns -> INSERT/DELETE only)
DROP TRIGGER IF EXISTS `trg_wcp_ai_audit`;
DROP TRIGGER IF EXISTS `trg_wcp_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_wcp_ai_audit` AFTER INSERT ON `WarrantyClaimPart` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('WarrantyClaimPart', 'INSERT', CONCAT(NEW.`ClaimID`,'-',NEW.`PartID`), NULL,
        JSON_OBJECT('ClaimID',NEW.`ClaimID`,'PartID',NEW.`PartID`));
END$$

CREATE TRIGGER `trg_wcp_ad_audit` AFTER DELETE ON `WarrantyClaimPart` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('WarrantyClaimPart', 'DELETE', CONCAT(OLD.`ClaimID`,'-',OLD.`PartID`),
        JSON_OBJECT('ClaimID',OLD.`ClaimID`,'PartID',OLD.`PartID`),
        NULL);
END$$
DELIMITER ;



-- Role
DROP TRIGGER IF EXISTS `trg_rl_ai_audit`;
DROP TRIGGER IF EXISTS `trg_rl_au_audit`;
DROP TRIGGER IF EXISTS `trg_rl_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_rl_ai_audit` AFTER INSERT ON `Role` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Role', 'INSERT', CAST(NEW.`RoleID` AS CHAR), NULL,
        JSON_OBJECT('RoleID',NEW.`RoleID`,'RoleName',NEW.`RoleName`));
END$$

CREATE TRIGGER `trg_rl_au_audit` AFTER UPDATE ON `Role` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Role', 'UPDATE', CAST(NEW.`RoleID` AS CHAR),
        JSON_OBJECT('RoleID',OLD.`RoleID`,'RoleName',OLD.`RoleName`),
        JSON_OBJECT('RoleID',NEW.`RoleID`,'RoleName',NEW.`RoleName`));
END$$

CREATE TRIGGER `trg_rl_ad_audit` AFTER DELETE ON `Role` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Role', 'DELETE', CAST(OLD.`RoleID` AS CHAR),
        JSON_OBJECT('RoleID',OLD.`RoleID`,'RoleName',OLD.`RoleName`),
        NULL);
END$$
DELIMITER ;

-- Permission 
DROP TRIGGER IF EXISTS `trg_perm_ai_audit`;
DROP TRIGGER IF EXISTS `trg_perm_au_audit`;
DROP TRIGGER IF EXISTS `trg_perm_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_perm_ai_audit` AFTER INSERT ON `Permission` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Permission', 'INSERT', CAST(NEW.`PermissionID` AS CHAR), NULL,
        JSON_OBJECT('PermissionID',NEW.`PermissionID`,'TableName',NEW.`TableName`,'Action',NEW.`Action`,'Description',NEW.`Description`));
END$$

CREATE TRIGGER `trg_perm_au_audit` AFTER UPDATE ON `Permission` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Permission', 'UPDATE', CAST(NEW.`PermissionID` AS CHAR),
        JSON_OBJECT('PermissionID',OLD.`PermissionID`,'TableName',OLD.`TableName`,'Action',OLD.`Action`,'Description',OLD.`Description`),
        JSON_OBJECT('PermissionID',NEW.`PermissionID`,'TableName',NEW.`TableName`,'Action',NEW.`Action`,'Description',NEW.`Description`));
END$$

CREATE TRIGGER `trg_perm_ad_audit` AFTER DELETE ON `Permission` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('Permission', 'DELETE', CAST(OLD.`PermissionID` AS CHAR),
        JSON_OBJECT('PermissionID',OLD.`PermissionID`,'TableName',OLD.`TableName`,'Action',OLD.`Action`,'Description',OLD.`Description`),
        NULL);
END$$
DELIMITER ;


DROP TRIGGER IF EXISTS `trg_ua_ai_audit`;
DROP TRIGGER IF EXISTS `trg_ua_au_audit`;
DROP TRIGGER IF EXISTS `trg_ua_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_ua_ai_audit` AFTER INSERT ON `UserAccount` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('UserAccount', 'INSERT', CAST(NEW.`UserID` AS CHAR), NULL,
        JSON_OBJECT('UserID',NEW.`UserID`,'Username',NEW.`Username`,'PasswordHash','***REDACTED***',
                     'IsActive',NEW.`IsActive`,'DriverID',NEW.`DriverID`,'MechanicID',NEW.`MechanicID`,'DepotID',NEW.`DepotID`));
END$$

CREATE TRIGGER `trg_ua_au_audit` AFTER UPDATE ON `UserAccount` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('UserAccount', 'UPDATE', CAST(NEW.`UserID` AS CHAR),
        JSON_OBJECT('UserID',OLD.`UserID`,'Username',OLD.`Username`,
                     'PasswordHash', IF(OLD.`PasswordHash` <=> NEW.`PasswordHash`, '***REDACTED***', '***REDACTED-OLD***'),
                     'IsActive',OLD.`IsActive`,'DriverID',OLD.`DriverID`,'MechanicID',OLD.`MechanicID`,'DepotID',OLD.`DepotID`),
        JSON_OBJECT('UserID',NEW.`UserID`,'Username',NEW.`Username`,
                     'PasswordHash', IF(OLD.`PasswordHash` <=> NEW.`PasswordHash`, '***REDACTED***', '***REDACTED-NEW***'),
                     'IsActive',NEW.`IsActive`,'DriverID',NEW.`DriverID`,'MechanicID',NEW.`MechanicID`,'DepotID',NEW.`DepotID`));
END$$

CREATE TRIGGER `trg_ua_ad_audit` AFTER DELETE ON `UserAccount` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('UserAccount', 'DELETE', CAST(OLD.`UserID` AS CHAR),
        JSON_OBJECT('UserID',OLD.`UserID`,'Username',OLD.`Username`,'PasswordHash','***REDACTED***',
                     'IsActive',OLD.`IsActive`,'DriverID',OLD.`DriverID`,'MechanicID',OLD.`MechanicID`,'DepotID',OLD.`DepotID`),
        NULL);
END$$
DELIMITER ;

-- UserRole (composite PK: UserID, RoleID) 
DROP TRIGGER IF EXISTS `trg_ur_ai_audit`;
DROP TRIGGER IF EXISTS `trg_ur_au_audit`;
DROP TRIGGER IF EXISTS `trg_ur_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_ur_ai_audit` AFTER INSERT ON `UserRole` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('UserRole', 'INSERT', CONCAT(NEW.`UserID`,'-',NEW.`RoleID`), NULL,
        JSON_OBJECT('UserID',NEW.`UserID`,'RoleID',NEW.`RoleID`,'GrantedDate',NEW.`GrantedDate`));
END$$

CREATE TRIGGER `trg_ur_au_audit` AFTER UPDATE ON `UserRole` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('UserRole', 'UPDATE', CONCAT(NEW.`UserID`,'-',NEW.`RoleID`),
        JSON_OBJECT('UserID',OLD.`UserID`,'RoleID',OLD.`RoleID`,'GrantedDate',OLD.`GrantedDate`),
        JSON_OBJECT('UserID',NEW.`UserID`,'RoleID',NEW.`RoleID`,'GrantedDate',NEW.`GrantedDate`));
END$$

CREATE TRIGGER `trg_ur_ad_audit` AFTER DELETE ON `UserRole` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('UserRole', 'DELETE', CONCAT(OLD.`UserID`,'-',OLD.`RoleID`),
        JSON_OBJECT('UserID',OLD.`UserID`,'RoleID',OLD.`RoleID`,'GrantedDate',OLD.`GrantedDate`),
        NULL);
END$$
DELIMITER ;

-- RolePermission (composite PK: RoleID, PermissionID; no non-PK columns -> INSERT/DELETE only)
DROP TRIGGER IF EXISTS `trg_rp_ai_audit`;
DROP TRIGGER IF EXISTS `trg_rp_ad_audit`;

DELIMITER $$
CREATE TRIGGER `trg_rp_ai_audit` AFTER INSERT ON `RolePermission` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('RolePermission', 'INSERT', CONCAT(NEW.`RoleID`,'-',NEW.`PermissionID`), NULL,
        JSON_OBJECT('RoleID',NEW.`RoleID`,'PermissionID',NEW.`PermissionID`));
END$$

CREATE TRIGGER `trg_rp_ad_audit` AFTER DELETE ON `RolePermission` FOR EACH ROW
BEGIN
    CALL sp_write_audit_log('RolePermission', 'DELETE', CONCAT(OLD.`RoleID`,'-',OLD.`PermissionID`),
        JSON_OBJECT('RoleID',OLD.`RoleID`,'PermissionID',OLD.`PermissionID`),
        NULL);
END$$
DELIMITER ;



