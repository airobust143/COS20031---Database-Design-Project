-- =====================================================================
-- Smart Fleet Management — SEED DATA (MariaDB 10.4 / XAMPP)
-- Run after table creation (01–05) and before 06_procedures_triggers.sql.
--
-- Data is drawn from the project brief: the four depots, the vehicle
-- certification matrix, the example driver certifications, the example
-- safety event log (E091-E096), and jobs M1021 / M1022 with their
-- activity breakdown.
--
-- Explicit IDs are used so foreign keys are predictable and the script
-- is re-runnable after a DELETE. Run as root (or anna_admin).
--
-- In addition to the hand-written demonstration rows, this script creates
-- 500 deterministic synthetic rows in the scalable business tables.
-- Depots, their one-to-one Workshops, lookups, user-account and RBAC tables
-- intentionally remain small.
-- =====================================================================

USE `smart_fleet_management`;

SET FOREIGN_KEY_CHECKS = 0;
DELETE FROM `UserRole`;
DELETE FROM `UserAccount`;
DELETE FROM `WarrantyClaimParts`;
DELETE FROM `WarrantyClaim`;
DELETE FROM `ActivityMechanic`;
DELETE FROM `ActivityPart`;
DELETE FROM `MaintenanceActivity`;
DELETE FROM `MaintenanceJobs`;
DELETE FROM `PredictiveAlert`;
DELETE FROM `SupplyPart`;
DELETE FROM `Part`;
DELETE FROM `Supplier`;
DELETE FROM `MechanicCertification`;
DELETE FROM `Mechanic`;
DELETE FROM `Workshop`;
DELETE FROM `CoachingRecord`;
DELETE FROM `SafetyEvents`;
DELETE FROM `DriverSafetyScore`;
DELETE FROM `DriverCertifications`;
DELETE FROM `VehicleAssignments`;
DELETE FROM `VehicleCertRequirement`;
DELETE FROM `VehiclesDepotHistory`;
DELETE FROM `Vehicles`;
DELETE FROM `Drivers`;
DELETE FROM `ActivityType`;
DELETE FROM `MechanicCertType`;
DELETE FROM `EventPenalty`;
DELETE FROM `SafetyEventsType`;
DELETE FROM `CertificationType`;
DELETE FROM `VehiclesCategory`;
DELETE FROM `Depots`;
SET FOREIGN_KEY_CHECKS = 1;


-- =====================================================================
-- LOOKUPS
-- =====================================================================

INSERT INTO `Depots` (`DepotID`,`City`,`Address`,`Name`,`ContactPhone`) VALUES
 (1,'Ha Noi','12 Pham Van Dong, Bac Tu Liem','Ha Noi Depot','024-3831-0011'),
 (2,'Da Nang','88 Nguyen Van Linh, Hai Chau','Da Nang Depot','0236-3822-0022'),
 (3,'Ho Chi Minh City','215 Dien Bien Phu, Binh Thanh','HCMC Depot','028-3899-0033'),
 (4,'Can Tho','45 Nguyen Van Cu, Ninh Kieu','Can Tho Depot','0292-3877-0044');

INSERT INTO `VehiclesCategory` (`CategoryID`,`CategoryName`) VALUES
 (1,'Delivery Van'),
 (2,'Refrigerated Truck'),
 (3,'Electric Van'),
 (4,'Service Vehicle'),
 (5,'Heavy Transport Truck');

INSERT INTO `CertificationType` (`CertTypeID`,`Name`,`Expire`) VALUES
 (1,'Standard Licence',TRUE),
 (2,'Heavy Vehicle Licence',TRUE),
 (3,'Refrigerated Transport Certification',TRUE),
 (4,'EV Certification',TRUE),
 (5,'Hazardous Goods Certification',TRUE);

-- Vehicle Certification Matrix (brief p.4): ALL listed certs required
INSERT INTO `VehicleCertRequirement` (`CategoryID`,`CertTypeID`) VALUES
 (1,1),                    -- Delivery Van        : Standard
 (2,1),(2,2),(2,3),        -- Refrigerated Truck  : Standard + Heavy + Refrigerated
 (3,1),(3,4),              -- Electric Van        : Standard + EV
 (4,1),                    -- Service Vehicle     : Standard
 (5,2),(5,5);              -- Heavy Transport     : Heavy + Hazardous Goods

INSERT INTO `SafetyEventsType` (`EventsTypeID`,`Name`,`DefaultSeverity`) VALUES
 (1,'Harsh Braking','Low'),
 (2,'Rapid Acceleration','Low'),
 (3,'Excessive Speeding','High'),
 (4,'Sharp Cornering','Medium'),
 (5,'Excessive Idling','Low'),
 (6,'Fatigue Warning','High'),
 (7,'Seatbelt Violation','Medium'),
 (8,'Phone Distraction Alert','High');

INSERT INTO `EventPenalty` (`Severity`,`PointsDeducted`,`Description`) VALUES
 ('Low',      -2,'Minor event'),
 ('Medium',   -5,'Moderate event'),
 ('High',    -10,'Serious event requiring review'),
 ('Critical',-20,'Critical event requiring immediate intervention');

INSERT INTO `MechanicCertType` (`MecCertTypeID`,`Name`,`Expire`) VALUES
 (1,'Standard Vehicle Mechanic Licence',TRUE),
 (2,'EV Technician Certification',TRUE),
 (3,'Refrigeration Systems Certification',TRUE),
 (4,'Heavy Vehicle Mechanic Licence',TRUE);

-- Activity Type -> Required Mechanic Certification (brief p.11)
INSERT INTO `ActivityType` (`ActivityTypeID`,`Name`,`MecCertTypeID`) VALUES
 (1,'Routine Inspection',1),
 (2,'Preventative Servicing',1),
 (3,'Diagnostic Testing',1),
 (4,'Emergency Repair',1),
 (5,'Component Replacement',1),
 (6,'EV Battery / Electrical Repair',2),
 (7,'Refrigeration System Repair',3),
 (8,'Heavy Vehicle Repair',4);


-- =====================================================================
-- CORE FLEET
-- =====================================================================

INSERT INTO `Vehicles`
 (`VehicleID`,`RegistrationNumber`,`CategoryID`,`Model`,`Manufacturer`,
  `YearOfManufacture`,`CurrentOdometerReading`,`DepotID`,`OperationalStatus`) VALUES
 (1,'29A-123.45',1,'Transit 350','Ford',      2021, 45310,1,'Active'),
 (2,'51C-789.01',2,'Canter FE85','Mitsubishi',2020,112480,3,'Under Maintenance'),
 (3,'43E-456.78',3,'eVito','Mercedes-Benz',   2022, 12300,2,'Active'),
 (4,'65B-222.10',5,'FM 440','Volvo',          2019,201750,4,'Available'),
 (5,'29D-901.22',4,'Hilux','Toyota',          2023,  8900,1,'Available');

INSERT INTO `VehiclesDepotHistory` (`VehicleID`,`DepotID`,`MovedFrom`,`MovedTo`) VALUES
 (1,1,'2021-03-01 08:00:00',NULL),
 (2,3,'2020-07-15 08:00:00',NULL),
 (3,1,'2022-01-10 08:00:00','2024-04-30 17:00:00'),
 (3,2,'2024-05-01 08:00:00',NULL),
 (4,4,'2019-11-20 08:00:00',NULL),
 (5,1,'2023-06-05 08:00:00',NULL);

INSERT INTO `Drivers`
 (`DriverID`,`FirstName`,`LastName`,`ContactInformation`,`DepotID`,
  `LicenceType`,`LicenceExpiryDate`,`EmploymentStatus`,`EmergencyContactDetails`) VALUES
 (1,'Nguyen Van','An',  'an.nguyen@fleet.vn / 0901-112-233', 1,'B2','2027-02-14','Active',  'Nguyen Thi Hoa 0902-334-455'),
 (2,'Tran Thi','Bich',  'bich.tran@fleet.vn / 0903-204-506', 3,'C', '2026-12-08','Inactive','Tran Van Nam 0904-556-677'),
 (3,'Le Quoc','Minh',   'minh.le@fleet.vn / 0905-331-442',   1,'B2','2028-06-21','Active',  'Le Thi Mai 0906-778-889'),
 (4,'Pham Duc','Long',  'long.pham@fleet.vn / 0907-417-528', 4,'C', '2027-11-18','Active',  'Pham Van Hung 0908-990-001');
-- NOTE: driver 2 is Inactive — the brief's rule that a Critical event
-- makes a driver unassignable until review/training is complete.

-- Driver certifications (brief p.5) plus renewals, so the full history
-- is retained and some rows are expired while others are current.
INSERT INTO `DriverCertifications`
 (`DriverCertID`,`DriverID`,`CertTypeID`,`IssueDate`,`ExpireDate`) VALUES
 (1,1,1,'2023-02-15','2025-02-14'),   -- An: Standard  (EXPIRED)
 (2,1,4,'2023-05-01','2025-04-30'),   -- An: EV        (EXPIRED)
 (3,1,1,'2025-02-15','2027-02-14'),   -- An: Standard renewed (current)
 (4,1,4,'2025-05-01','2027-04-30'),   -- An: EV renewed       (current)
 (5,2,2,'2023-12-09','2025-12-08'),   -- Bich: Heavy Vehicle  (EXPIRED)
 (6,2,3,'2024-05-02','2026-05-01'),   -- Bich: Refrigerated   (EXPIRED)
 (7,3,1,'2024-06-22','2026-06-21'),   -- Minh: Standard       (EXPIRED)
 (8,4,5,'2024-11-19','2026-11-18'),   -- Long: Hazardous      (current)
 (9,4,2,'2024-11-19','2027-11-18');   -- Long: Heavy Vehicle  (current)

INSERT INTO `VehicleAssignments`
 (`AssignmentID`,`VehicleID`,`DriverID`,`StartDate`,`EndDate`,`IsPermanent`,`DepotID`) VALUES
 (1,1,1,'2024-01-15',NULL,        TRUE, 1),
 (2,2,2,'2024-02-01','2024-05-13',FALSE,3),
 (3,3,1,'2024-05-01','2024-05-12',FALSE,2),
 (4,1,3,'2024-05-13',NULL,        FALSE,1),
 (5,4,4,'2024-03-10',NULL,        TRUE, 4);


-- =====================================================================
-- SAFETY (example event log, brief p.8)
-- =====================================================================

INSERT INTO `SafetyEvents`
 (`EventID`,`Timestamp`,`VehicleID`,`DriverID`,`EventsTypeID`,`Severity`,
  `DepotID`,`Odometer`,`ReviewRequired`,`ReviewStatus`) VALUES
 (91,'2024-05-10 08:14:00',1,1,1,'Low',     1, 45100,FALSE,'Not Required'),
 (92,'2024-05-10 09:30:00',1,1,3,'High',    1, 45140,TRUE, 'Completed'),
 (93,'2024-05-11 11:00:00',2,2,4,'Medium',  3,112050,FALSE,'Not Required'),
 (94,'2024-05-12 14:20:00',3,1,6,'High',    2, 12300,TRUE, 'In Review'),
 (95,'2024-05-13 07:42:00',1,3,5,'Low',     1, 45310,FALSE,'Not Required'),
 (96,'2024-05-13 18:05:00',2,2,3,'Critical',3,112480,TRUE, 'Pending');
-- High/Critical events automatically require review (brief p.6).

-- Monthly scores for 2024-05, calculated with the Event Penalties table:
--   An   : Low -2, High -10, High -10                  = 100-22 = 78
--   Bich : Medium -5, Critical -20, +critical-event -10= 100-35 = 65  -> coaching
--   Minh : Low -2                                       = 100-2  = 98
INSERT INTO `DriverSafetyScore`
 (`ScoreID`,`DriverID`,`ScorePeriod`,`BaseScore`,`DeductedPoints`,`FinalScore`,
  `CoachingRequired`,`Suspended`,`LowCount`,`MediumCount`,`HighCount`,`CriticalCount`) VALUES
 (1,1,'2024-05',100,22,78,FALSE,FALSE,1,0,2,0),
 (2,2,'2024-05',100,35,65,TRUE, FALSE,0,1,0,1),
 (3,3,'2024-05',100, 2,98,FALSE,FALSE,1,0,0,0);

INSERT INTO `CoachingRecord`
 (`CoachingID`,`DriverID`,`Reason`,`ScheduledDate`,`CompleteDate`,`Outcome`,
  `RecordType`,`EventID`,`ScoreID`) VALUES
 (1,2,'Critical speeding event on 13 May 2024','2024-05-20','2024-05-27','Passed','Critical Event',96,NULL),
 (2,2,'Monthly safety score of 65 (below 75 threshold)','2024-06-03',NULL,'Pending','Low Safety Score',NULL,2);


-- =====================================================================
-- WORKSHOPS & MECHANICS (one workshop per depot, brief p.11)
-- =====================================================================

INSERT INTO `Workshop` (`WorkshopID`,`DepotID`,`Name`,`NumBays`,`Contacts`) VALUES
 (1,1,'Ha Noi Central Workshop',6,'workshop.hanoi@fleet.vn'),
 (2,2,'Da Nang Workshop',      4,'workshop.danang@fleet.vn'),
 (3,3,'HCMC South Workshop',   8,'workshop.hcmc@fleet.vn'),
 (4,4,'Can Tho Workshop',      3,'workshop.cantho@fleet.vn');

INSERT INTO `Mechanic`
 (`MechanicID`,`FirstName`,`LastName`,`WorkshopID`,`EmploymentStatus`) VALUES
 (7, 'Nguyen Thi','Mai', 3,'Active'),   -- ME-07
 (9, 'Tran Quoc','Bao',  3,'Active'),   -- ME-09
 (12,'Hoang Van','Duc',  1,'Active'),   -- ME-12  <- mike_mech
 (15,'Pham Thi','Lan',   1,'Active');   -- ME-15

INSERT INTO `MechanicCertification`
 (`MecCertID`,`MechanicID`,`MecCertTypeID`,`IssueDate`,`ExpireDate`) VALUES
 (1,7, 1,'2023-01-10','2027-01-09'),
 (2,9, 1,'2023-03-15','2027-03-14'),
 (3,9, 3,'2023-03-15','2027-03-14'),   -- Bao: refrigeration
 (4,12,1,'2022-08-01','2026-07-31'),
 (5,12,4,'2022-08-01','2026-07-31'),   -- Duc: heavy vehicle
 (6,15,1,'2024-02-20','2028-02-19'),
 (7,15,2,'2024-02-20','2028-02-19');   -- Lan: EV technician


-- =====================================================================
-- MAINTENANCE (jobs M1021 / M1022, brief pp.9-10)
-- =====================================================================

INSERT INTO `PredictiveAlert`
 (`AlertID`,`VehicleID`,`AlertType`,`Severity`,`GeneratedAt`,`Status`,`ResolvedAt`) VALUES
 (1,1,'Brake Wear Warning','High','2024-05-11 16:40:00','Resolved','2024-05-13 03:00:00'),
 (2,2,'Cooling System Anomaly','Medium','2024-05-13 20:15:00','Resolved','2024-05-14 14:00:00'),
 (3,4,'Tyre Pressure Irregularity','Low','2024-05-20 07:05:00','Acknowledged',NULL),
 (4,3,'Battery Degradation','Medium','2024-06-02 09:30:00','Scheduled',NULL);

INSERT INTO `MaintenanceJobs`
 (`JobID`,`VehicleID`,`WorkshopID`,`DateOpened`,`DateClosed`,
  `OverallDowntime`,`TotalCost`,`AlertID`) VALUES
 (1021,1,1,'2024-05-12 09:00:00','2024-05-13 03:00:00',18.00,1800000.00,1),
 (1022,2,3,'2024-05-14 08:00:00','2024-05-14 14:00:00', 6.00,3610000.00,2);

INSERT INTO `MaintenanceActivity`
 (`ActivityID`,`JobID`,`ActivityTypeID`,`DiagnosticResult`,`IsRepeatFault`,
  `StartedAt`,`CompleteAt`) VALUES
 (1,1021,5,'Pads worn below 3mm',FALSE,'2024-05-12 09:30:00','2024-05-12 12:00:00'),
 (2,1021,5,'Worn unevenly - possible alignment issue',TRUE,'2024-05-12 13:00:00','2024-05-12 14:00:00'),
 (3,1022,2,'OK',FALSE,'2024-05-14 08:15:00','2024-05-14 09:45:00'),
 (4,1022,7,'Belt cracked - 3rd replacement this year',TRUE,'2024-05-14 10:00:00','2024-05-14 12:00:00');

-- Activity 1 has TWO mechanics — the brief's "some activities require
-- several mechanics working together" case, and the scenario where a
-- shared DiagnosticResult can be overwritten by either of them.
INSERT INTO `ActivityMechanic` (`ActivityID`,`MechanicID`,`LabourHours`) VALUES
 (1,12,2.50),
 (1,15,2.50),
 (2,12,1.00),
 (3,7, 1.50),
 (4,9, 2.00);


-- =====================================================================
-- DETERMINISTIC BULK DATA
-- 500 additional rows are generated for each scalable business table.
-- Synthetic records are distributed across the four real depots and their
-- one-to-one workshops instead of generating artificial locations.
-- IDs start at 1001 (or 10001 for high-volume event/job entities) so the
-- project-brief examples above keep their original, easy-to-demo IDs.
-- =====================================================================

DROP TEMPORARY TABLE IF EXISTS `_seed_numbers`;
CREATE TEMPORARY TABLE `_seed_numbers` (
    `n` INT UNSIGNED NOT NULL,
    PRIMARY KEY (`n`)
) ENGINE=MEMORY;

INSERT INTO `_seed_numbers` (`n`)
SELECT hundreds.d * 100 + tens.d * 10 + ones.d + 1
FROM
    (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) ones
CROSS JOIN
    (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4
     UNION ALL SELECT 5 UNION ALL SELECT 6 UNION ALL SELECT 7 UNION ALL SELECT 8 UNION ALL SELECT 9) tens
CROSS JOIN
    (SELECT 0 d UNION ALL SELECT 1 UNION ALL SELECT 2 UNION ALL SELECT 3 UNION ALL SELECT 4) hundreds;

-- Fleet vehicles --------------------------------------------------------------
INSERT INTO `Vehicles`
 (`VehicleID`,`RegistrationNumber`,`CategoryID`,`Model`,`Manufacturer`,
  `YearOfManufacture`,`CurrentOdometerReading`,`DepotID`,`OperationalStatus`)
SELECT 1000+n,
       CONCAT('SF-', LPAD(n,6,'0')),
       1,
       CONCAT('FleetVan-', 1 + MOD(n,20)),
       ELT(1 + MOD(n-1,5),'Ford','Toyota','Hyundai','Mercedes-Benz','Isuzu'),
       2018 + MOD(n,8),
       10000 + n * 125,
       1+MOD(n-1,4),
       IF(MOD(n,2)=0,'Available','Active')
FROM `_seed_numbers`;

INSERT INTO `VehiclesDepotHistory`
 (`HistoryID`,`VehicleID`,`DepotID`,`MovedFrom`,`MovedTo`)
SELECT 10000+n, 1000+n, 1+MOD(n-1,4),
       DATE_ADD('2020-01-01 08:00:00', INTERVAL MOD(n,1460) DAY),
       NULL
FROM `_seed_numbers`;

-- Drivers, credentials, assignments and safety -------------------------------
INSERT INTO `Drivers`
 (`DriverID`,`FirstName`,`LastName`,`ContactInformation`,`DepotID`,
  `LicenceType`,`LicenceExpiryDate`,`EmploymentStatus`,`EmergencyContactDetails`)
SELECT 1000+n,
       CONCAT('Driver', LPAD(n,3,'0')),
       CONCAT('Synthetic', LPAD(n,3,'0')),
       CONCAT('driver', LPAD(n,3,'0'), '@fleet.example / 08', LPAD(n,8,'0')),
       1+MOD(n-1,4),
       'B2',
       '2035-12-31',
       'Active',
       CONCAT('Emergency contact 07', LPAD(n,8,'0'))
FROM `_seed_numbers`;

INSERT INTO `DriverCertifications`
 (`DriverCertID`,`DriverID`,`CertTypeID`,`IssueDate`,`ExpireDate`)
SELECT 10000+n, 1000+n, 1, '2024-01-01', '2035-12-31'
FROM `_seed_numbers`;

INSERT INTO `VehicleAssignments`
 (`AssignmentID`,`VehicleID`,`DriverID`,`StartDate`,`EndDate`,`IsPermanent`,`DepotID`)
SELECT 10000+n, 1000+n, 1000+n,
       DATE_ADD('2024-01-01', INTERVAL MOD(n,365) DAY),
       NULL,
       MOD(n,2),
       1+MOD(n-1,4)
FROM `_seed_numbers`;

INSERT INTO `DriverSafetyScore`
 (`ScoreID`,`DriverID`,`ScorePeriod`,`BaseScore`,`DeductedPoints`,`FinalScore`,
  `CoachingRequired`,`Suspended`,`LowCount`,`MediumCount`,`HighCount`,`CriticalCount`)
SELECT 10000+n,
       1000+n,
       '2024-01',
       100,
       MOD(n*7,45),
       100-MOD(n*7,45),
       (100-MOD(n*7,45) <= 75),
       FALSE,
       MOD(n,5), MOD(n,4), MOD(n,3), 0
FROM `_seed_numbers`;

INSERT INTO `SafetyEvents`
 (`EventID`,`Timestamp`,`VehicleID`,`DriverID`,`EventsTypeID`,`Severity`,
  `DepotID`,`Odometer`,`ReviewRequired`,`ReviewStatus`)
SELECT 10000+n,
       DATE_ADD(DATE_ADD('2025-01-01 06:00:00', INTERVAL MOD(n,365) DAY),
                INTERVAL MOD(n,16) HOUR),
       1000+n,
       1000+n,
       1+MOD(n-1,8),
       ELT(1+MOD(n-1,4),'Low','Medium','High','Critical'),
       1+MOD(n-1,4),
       10000+n*125,
       (MOD(n-1,4) >= 2),
       IF(MOD(n-1,4) >= 2,'Pending','Not Required')
FROM `_seed_numbers`;

INSERT INTO `CoachingRecord`
 (`CoachingID`,`DriverID`,`Reason`,`ScheduledDate`,`CompleteDate`,`Outcome`,
  `RecordType`,`EventID`,`ScoreID`)
SELECT 10000+n,
       1000+n,
       CONCAT('Synthetic coaching review for safety event ', 10000+n),
       DATE_ADD('2025-01-08', INTERVAL MOD(n,365) DAY),
       IF(MOD(n,3)=0, DATE_ADD('2025-01-15', INTERVAL MOD(n,365) DAY), NULL),
       IF(MOD(n,3)=0,'Passed','Pending'),
       IF(MOD(n,4)=0,'Critical Event','Other'),
       10000+n,
       NULL
FROM `_seed_numbers`;

-- Workshops and mechanics -----------------------------------------------------
INSERT INTO `Mechanic`
 (`MechanicID`,`FirstName`,`LastName`,`WorkshopID`,`EmploymentStatus`)
SELECT 1000+n,
       CONCAT('Mechanic', LPAD(n,3,'0')),
       CONCAT('Synthetic', LPAD(n,3,'0')),
       1+MOD(n-1,4),
       'Active'
FROM `_seed_numbers`;

INSERT INTO `MechanicCertification`
 (`MecCertID`,`MechanicID`,`MecCertTypeID`,`IssueDate`,`ExpireDate`)
SELECT 10000+n, 1000+n, 1, '2024-01-01', '2035-12-31'
FROM `_seed_numbers`;

-- Alerts, jobs and workshop activity -----------------------------------------
INSERT INTO `PredictiveAlert`
 (`AlertID`,`VehicleID`,`AlertType`,`Severity`,`GeneratedAt`,`Status`,`ResolvedAt`)
SELECT 10000+n,
       1000+n,
       ELT(1+MOD(n-1,7),
           'Brake Wear Warning','Engine Overheating Risk','Battery Degradation',
           'Oil Quality Deterioration','Transmission Fault Warning',
           'Cooling System Anomaly','Tyre Pressure Irregularity'),
       ELT(1+MOD(n-1,4),'Low','Medium','High','Critical'),
       DATE_ADD('2025-02-01 07:00:00', INTERVAL MOD(n,300) DAY),
       ELT(1+MOD(n-1,4),'New','Acknowledged','Scheduled','Resolved'),
       IF(MOD(n-1,4)=3,
          DATE_ADD('2025-02-03 12:00:00', INTERVAL MOD(n,300) DAY),
          NULL)
FROM `_seed_numbers`;

INSERT INTO `MaintenanceJobs`
 (`JobID`,`VehicleID`,`WorkshopID`,`DateOpened`,`DateClosed`,
  `OverallDowntime`,`TotalCost`,`AlertID`)
SELECT 10000+n,
       1000+n,
       1+MOD(n-1,4),
       DATE_ADD('2025-02-02 08:00:00', INTERVAL MOD(n,300) DAY),
       DATE_ADD(DATE_ADD('2025-02-02 08:00:00', INTERVAL MOD(n,300) DAY),
                INTERVAL (2+MOD(n,12)) HOUR),
       2+MOD(n,12),
       500000+MOD(n*137000,9500000),
       10000+n
FROM `_seed_numbers`;

INSERT INTO `MaintenanceActivity`
 (`ActivityID`,`JobID`,`ActivityTypeID`,`DiagnosticResult`,`IsRepeatFault`,
  `StartedAt`,`CompleteAt`)
SELECT 10000+n,
       10000+n,
       1,
       CONCAT('Synthetic inspection result ', LPAD(n,3,'0')),
       (MOD(n,10)=0),
       DATE_ADD('2025-02-02 09:00:00', INTERVAL MOD(n,300) DAY),
       DATE_ADD('2025-02-02 11:00:00', INTERVAL MOD(n,300) DAY)
FROM `_seed_numbers`;

INSERT INTO `ActivityMechanic` (`ActivityID`,`MechanicID`,`LabourHours`)
SELECT 10000+n, 1000+n, 2+MOD(n,8)/2
FROM `_seed_numbers`;

-- Parts, suppliers, usage and warranties -------------------------------------
INSERT INTO `Part`
 (`PartID`,`PartNumber`,`Description`,`UnitPrice`,`QuantityInStock`,`ReorderThreshold`)
SELECT 1000+n,
       CONCAT('SFP-', LPAD(n,6,'0')),
       CONCAT('Synthetic fleet service part ', LPAD(n,3,'0')),
       50000+MOD(n*17000,2000000),
       25+MOD(n,176),
       10+MOD(n,20)
FROM `_seed_numbers`;

INSERT INTO `Supplier` (`SupplierID`,`Name`,`ContactInfo`,`LeadTimeDays`)
SELECT 1000+n,
       CONCAT('Synthetic Parts Supplier ', LPAD(n,3,'0')),
       CONCAT('supplier', LPAD(n,3,'0'), '@parts.example / 06', LPAD(n,8,'0')),
       1+MOD(n,30)
FROM `_seed_numbers`;

INSERT INTO `SupplyPart` (`PartID`,`SupplierID`,`UnitCost`,`IsPrimary`)
SELECT 1000+n,
       1000+n,
       40000+MOD(n*13000,1500000),
       TRUE
FROM `_seed_numbers`;

INSERT INTO `ActivityPart`
 (`ActivityID`,`PartID`,`QuantityUsed`,`UnitPriceAtTime`)
SELECT 10000+n,
       1000+n,
       1+MOD(n,5),
       50000+MOD(n*17000,2000000)
FROM `_seed_numbers`;

INSERT INTO `WarrantyClaim`
 (`ClaimID`,`ActivityID`,`WarrantyType`,`Status`,`ClaimDate`)
SELECT 10000+n,
       10000+n,
       IF(MOD(n,2)=0,'Manufacturer','Supplier'),
       ELT(1+MOD(n-1,4),'Submitted','Approved','Rejected','Completed'),
       DATE_ADD('2025-02-03', INTERVAL MOD(n,300) DAY)
FROM `_seed_numbers`;

INSERT INTO `WarrantyClaimParts` (`ClaimID`,`PartID`)
SELECT 10000+n, 1000+n
FROM `_seed_numbers`;

DROP TEMPORARY TABLE `_seed_numbers`;


-- =====================================================================
-- USER ACCOUNTS  (link database logins to people)
-- =====================================================================
-- PasswordHash values are placeholders. A real application stores a
-- bcrypt/argon2 hash here; these strings are for structure only.
-- Username MUST match the MariaDB login name for the Part C views to work.

INSERT INTO `UserAccount`
 (`UserID`,`Username`,`PasswordHash`,`IsActive`,`DriverID`,`MechanicID`,`DepotID`) VALUES
 (1,'anna_admin', '$2y$10$placeholder_admin_hash', TRUE,NULL,NULL,NULL),
 (2,'sam_safety', '$2y$10$placeholder_safety_hash',TRUE,NULL,NULL,1),
 (3,'wendy_wshop','$2y$10$placeholder_wshop_hash', TRUE,NULL,NULL,1),
 (4,'mike_mech',  '$2y$10$placeholder_mech_hash',  TRUE,NULL,12,  1),
 (5,'dan_driver', '$2y$10$placeholder_driver_hash',TRUE,1,   NULL,1);

-- Map users to application-level roles (matched by name, not by ID)
INSERT INTO `UserRole` (`UserID`,`RoleID`,`GrantedDate`)
SELECT u.UserID, r.RoleID, '2024-01-01'
FROM `UserAccount` u JOIN `Role` r
  ON (u.Username='anna_admin'  AND r.RoleName='fleet_admin')
  OR (u.Username='sam_safety'  AND r.RoleName='safety_ops')
  OR (u.Username='wendy_wshop' AND r.RoleName='workshop_mgr')
  OR (u.Username='mike_mech'   AND r.RoleName='mechanic')
  OR (u.Username='dan_driver'  AND r.RoleName='driver');

-- Update the password for the admin user
UPDATE `UserAccount` SET `PasswordHash` = '$2y$10$EMoZXSidOZBe2WFGeek36O4rqR4YiaYfO24O.ab1p9QLqxCOtThHC' WHERE `Username` = 'anna_admin';
UPDATE `UserAccount` SET `PasswordHash` = '$2y$10$5Ev8z8zK0cKMEe.6qoLYme6I8goVk8Ru0bzW98sbVg9k7Gu93l6rC' WHERE `Username` = 'sam_safety';
UPDATE `UserAccount` SET `PasswordHash` = '$2y$10$3X2EUSkoyvtU5Bc47jp15.gkGJ1R5cuoq6so9Ws5ZDNXiyuPObIni' WHERE `Username` = 'wendy_wshop';
UPDATE `UserAccount` SET `PasswordHash` = '$2y$10$opGq4KMR3G6nFLf/3n719efrkFkvngBzxOmL0Pp4FJSoH8N.6FY7S' WHERE `Username` = 'mike_mech';
UPDATE `UserAccount` SET `PasswordHash` = '$2y$10$m3MlZl1.gLdWVZ7CIm2Oju7LnvRuELk3WnKG8aJOdiGx6fXG0pWcS' WHERE `Username` = 'dan_driver';



-- =====================================================================
-- VIEW FIX: CURRENT_USER() -> USER()
-- Views run as SQL SECURITY DEFINER, so CURRENT_USER() returns the view's
-- creator (root), not the person querying. USER() returns the connected
-- client and is what the row filter needs.
-- =====================================================================

CREATE OR REPLACE VIEW `v_my_safety_events` AS
SELECT se.EventID, se.Timestamp, se.VehicleID, se.EventsTypeID,
       se.Severity, se.DepotID, se.Odometer, se.ReviewStatus
FROM `SafetyEvents` se
JOIN `UserAccount` ua ON ua.DriverID = se.DriverID
WHERE ua.Username = SUBSTRING_INDEX(USER(), '@', 1);

CREATE OR REPLACE VIEW `v_my_safety_scores` AS
SELECT dss.ScorePeriod, dss.BaseScore, dss.DeductedPoints, dss.FinalScore,
       dss.CoachingRequired, dss.Suspended
FROM `DriverSafetyScore` dss
JOIN `UserAccount` ua ON ua.DriverID = dss.DriverID
WHERE ua.Username = SUBSTRING_INDEX(USER(), '@', 1);

CREATE OR REPLACE VIEW `v_my_certifications` AS
SELECT dc.DriverCertID, ct.Name AS Certification, dc.IssueDate, dc.ExpireDate
FROM `DriverCertifications` dc
JOIN `CertificationType` ct ON ct.CertTypeID = dc.CertTypeID
JOIN `UserAccount` ua       ON ua.DriverID = dc.DriverID
WHERE ua.Username = SUBSTRING_INDEX(USER(), '@', 1);

CREATE OR REPLACE VIEW `v_my_labour` AS
SELECT am.ActivityID, am.MechanicID, am.LabourHours
FROM `ActivityMechanic` am
JOIN `UserAccount` ua ON ua.MechanicID = am.MechanicID
WHERE ua.Username = SUBSTRING_INDEX(USER(), '@', 1)
WITH CHECK OPTION;

CREATE OR REPLACE VIEW `v_my_activities` AS
SELECT ma.ActivityID, ma.JobID, ma.DiagnosticResult, ma.IsRepeatFault,
       ma.StartedAt, ma.CompleteAt
FROM `MaintenanceActivity` ma
JOIN `ActivityMechanic` am ON am.ActivityID = ma.ActivityID
JOIN `UserAccount` ua      ON ua.MechanicID = am.MechanicID
WHERE ua.Username = SUBSTRING_INDEX(USER(), '@', 1);


-- =====================================================================
-- EXPECTED RESULTS after seeding
--
-- As mike_mech  (MechanicID 12, on activities 1 and 2):
--   SELECT * FROM v_my_activities;   -> 2 rows (ActivityID 1, 2)
--   SELECT * FROM v_my_labour;       -> 2 rows (2.50 and 1.00 hours)
--   SELECT * FROM MaintenanceJobs;   -> 502 rows (broad read allowed)
--   UPDATE MaintenanceActivity ...   -> ERROR 1142 (denied)
--
-- As dan_driver (DriverID 1):
--   SELECT * FROM v_my_safety_events;  -> 3 rows (events 91, 92, 94)
--   SELECT * FROM v_my_safety_scores;  -> 1 row  (2024-05, score 78)
--   SELECT * FROM SafetyEvents;        -> ERROR 1142 (denied)
-- =====================================================================
