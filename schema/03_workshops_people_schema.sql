-- =====================================================================
-- Smart Fleet Management Database — WORKSHOPS & PEOPLE DOMAIN
-- COS20031 Group 4 — MySQL 8.0 / MariaDB 10.4+
-- File 3 of 7. Requires 01_core_fleet_schema.sql (Depots) to have run.
-- =====================================================================
-- Tables: Workshop, MechanicCertType, Mechanic, MechanicCertification
-- =====================================================================

USE `smart_fleet_management`;
SET FOREIGN_KEY_CHECKS = 0;

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

SET FOREIGN_KEY_CHECKS = 1;

-- =====================================================================
-- End of 03_workshops_people_schema.sql
-- =====================================================================
