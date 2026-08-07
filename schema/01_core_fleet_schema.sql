-- File 1. Run in numeric order.
-- Tables: Depots, VehiclesCategory, VehicleModel, Vehicles, VehiclesDepotHistory, VehicleAssignments

DROP DATABASE IF EXISTS `smart_fleet_management`;
CREATE DATABASE IF NOT EXISTS `smart_fleet_management` DEFAULT CHARACTER SET utf8mb4 DEFAULT COLLATE utf8mb4_unicode_ci;
USE `smart_fleet_management`;

SET FOREIGN_KEY_CHECKS = 0;


-- Depots

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


-- VehiclesCategory (lookup)

CREATE TABLE `VehiclesCategory` (
    `CategoryID`   INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `CategoryName` VARCHAR(50)     NOT NULL,
    PRIMARY KEY (`CategoryID`),
    UNIQUE KEY `uq_vehiclescategory_name` (`CategoryName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;


-- VehicleModel

CREATE TABLE `VehicleModel` (
    `ModelID`      INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `ModelName`    VARCHAR(100) NOT NULL,
    `Manufacturer` VARCHAR(100) NOT NULL,
    PRIMARY KEY (`ModelID`),
    UNIQUE KEY `uq_vehiclemodel_manufacturer_name` (`Manufacturer`, `ModelName`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Vehicles

CREATE TABLE `Vehicles` (
    `VehicleID`              INT UNSIGNED   NOT NULL AUTO_INCREMENT,
    `RegistrationNumber`     VARCHAR(20)    NOT NULL,
    `CategoryID`             INT UNSIGNED   NOT NULL,
    `ModelID`                INT UNSIGNED   NOT NULL,   
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



-- VehiclesDepotHistory
-- MovedFrom / MovedTo interpreted as the datetime range this vehicle
-- was stationed at DepotID (MovedTo is NULL while still assigned there)

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


-- VehicleAssignments

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


