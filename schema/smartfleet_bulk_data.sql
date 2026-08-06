-- ============================================================================
-- SMART FLEET MANAGEMENT - BULK PERFORMANCE TEST DATA
-- Target: MariaDB 10.4+ (XAMPP / phpMyAdmin)
--
-- Run this file manually from phpMyAdmin AFTER the normal schema, meaningful
-- seed data, procedures/triggers, indexes, and RBAC scripts have been loaded.
-- This file is intentionally NOT part of schema/run_all.js.
--
-- Adds approximately 500 coherent rows to each high-growth operational table.
-- Small lookup/configuration tables are reused instead of being inflated.
-- Only 25 suppliers are added because suppliers are comparatively low-volume.
-- User accounts, roles, permissions, login attempts, and audit rows are omitted.
--
-- Every generated natural value uses the "BULK" / "LoadTest" marker. Re-running
-- the script is safe: each INSERT checks for its previously generated row.
-- ============================================================================

USE `smart_fleet_management`;
SET NAMES utf8mb4;

-- MariaDB's SEQUENCE storage engine supplies seq_1_to_500. It is enabled by
-- default in MariaDB 10.4 and avoids a stored loop or 500 literal VALUES rows.
START TRANSACTION;

-- Cache stable row numbers for the existing depots and workshops. This avoids
-- assuming their auto-increment IDs are contiguous.
DROP TEMPORARY TABLE IF EXISTS `_bulk_depots`;
CREATE TEMPORARY TABLE `_bulk_depots` AS
SELECT ROW_NUMBER() OVER (ORDER BY `DepotID`) AS `seq_no`, `DepotID`
FROM `Depots`;

DROP TEMPORARY TABLE IF EXISTS `_bulk_workshops`;
CREATE TEMPORARY TABLE `_bulk_workshops` AS
SELECT ROW_NUMBER() OVER (ORDER BY `WorkshopID`) AS `seq_no`, `WorkshopID`
FROM `Workshop`;

SET @bulk_depot_count = (SELECT COUNT(*) FROM `_bulk_depots`);
SET @bulk_workshop_count = (SELECT COUNT(*) FROM `_bulk_workshops`);

-- --------------------------------------------------------------------------
-- 1. Core people and fleet: 500 drivers, vehicles, histories and assignments
-- --------------------------------------------------------------------------

INSERT INTO `Drivers`
    (`FirstName`, `LastName`, `ContactPhoneNumber`, `DepotID`, `LicenceType`,
     `LicenceExpiryDate`, `EmploymentStatus`, `EmergencyContactPhone`)
SELECT
    CONCAT('BulkDriver', LPAD(s.seq, 6, '0')),
    'LoadTest',
    CONCAT('+8491', LPAD(s.seq, 6, '0')),
    d.`DepotID`,
    'B2',
    '2035-12-31',
    'Active',
    CONCAT('+8492', LPAD(s.seq, 6, '0'))
FROM seq_1_to_500 AS s
JOIN `_bulk_depots` AS d
  ON d.`seq_no` = 1 + MOD(s.seq - 1, @bulk_depot_count)
WHERE NOT EXISTS (
    SELECT 1
    FROM `Drivers` AS existing
    WHERE existing.`FirstName` = CONCAT('BulkDriver', LPAD(s.seq, 6, '0'))
      AND existing.`LastName` = 'LoadTest'
);

-- One current Standard Licence per generated driver. Delivery Vans require this
-- certification, so the assignment eligibility trigger remains fully enabled.
INSERT INTO `DriverCertifications`
    (`DriverID`, `CertTypeID`, `IssueDate`, `ExpireDate`)
SELECT
    d.`DriverID`, ct.`CertTypeID`, '2023-01-01', '2035-12-31'
FROM seq_1_to_500 AS s
JOIN `Drivers` AS d
  ON d.`FirstName` = CONCAT('BulkDriver', LPAD(s.seq, 6, '0'))
 AND d.`LastName` = 'LoadTest'
JOIN `CertificationType` AS ct
  ON ct.`Name` = 'Standard Licence'
WHERE NOT EXISTS (
    SELECT 1
    FROM `DriverCertifications` AS existing
    WHERE existing.`DriverID` = d.`DriverID`
      AND existing.`CertTypeID` = ct.`CertTypeID`
      AND existing.`IssueDate` = '2023-01-01'
);

INSERT INTO `Vehicles`
    (`RegistrationNumber`, `CategoryID`, `ModelID`, `YearOfManufacture`,
     `CurrentOdometerReading`, `DepotID`, `OperationalStatus`)
SELECT
    CONCAT('BULK-', LPAD(s.seq, 6, '0')),
    vc.`CategoryID`,
    vm.`ModelID`,
    2017 + MOD(s.seq, 9),
    10000 + (s.seq * 337),
    d.`DepotID`,
    'Available'
FROM seq_1_to_500 AS s
JOIN `_bulk_depots` AS d
  ON d.`seq_no` = 1 + MOD(s.seq - 1, @bulk_depot_count)
JOIN `VehiclesCategory` AS vc
  ON vc.`CategoryName` = 'Delivery Van'
JOIN `VehicleModel` AS vm
  ON vm.`Manufacturer` = 'Ford' AND vm.`ModelName` = 'Transit 350'
WHERE NOT EXISTS (
    SELECT 1
    FROM `Vehicles` AS existing
    WHERE existing.`RegistrationNumber` = CONCAT('BULK-', LPAD(s.seq, 6, '0'))
);

INSERT INTO `VehiclesDepotHistory`
    (`VehicleID`, `DepotID`, `MovedFrom`, `MovedTo`)
SELECT
    v.`VehicleID`,
    v.`DepotID`,
    TIMESTAMP('2023-01-01 08:00:00') + INTERVAL s.seq DAY,
    NULL
FROM seq_1_to_500 AS s
JOIN `Vehicles` AS v
  ON v.`RegistrationNumber` = CONCAT('BULK-', LPAD(s.seq, 6, '0'))
WHERE NOT EXISTS (
    SELECT 1
    FROM `VehiclesDepotHistory` AS existing
    WHERE existing.`VehicleID` = v.`VehicleID`
      AND existing.`MovedFrom` = TIMESTAMP('2023-01-01 08:00:00') + INTERVAL s.seq DAY
);

-- Historical, non-overlapping one-to-one assignments. These are inserted before
-- safety events and maintenance jobs can change current driver/vehicle status.
INSERT INTO `VehicleAssignments`
    (`VehicleID`, `DriverID`, `StartDate`, `EndDate`, `IsPermanent`, `DepotID`)
SELECT
    v.`VehicleID`,
    d.`DriverID`,
    DATE('2023-01-01') + INTERVAL s.seq DAY,
    DATE('2023-01-02') + INTERVAL s.seq DAY,
    FALSE,
    v.`DepotID`
FROM seq_1_to_500 AS s
JOIN `Vehicles` AS v
  ON v.`RegistrationNumber` = CONCAT('BULK-', LPAD(s.seq, 6, '0'))
JOIN `Drivers` AS d
  ON d.`FirstName` = CONCAT('BulkDriver', LPAD(s.seq, 6, '0'))
 AND d.`LastName` = 'LoadTest'
WHERE NOT EXISTS (
    SELECT 1
    FROM `VehicleAssignments` AS existing
    WHERE existing.`VehicleID` = v.`VehicleID`
      AND existing.`DriverID` = d.`DriverID`
      AND existing.`StartDate` = DATE('2023-01-01') + INTERVAL s.seq DAY
);

-- --------------------------------------------------------------------------
-- 2. Safety: 500 events, 500 auto-generated scores, 500 coaching records
-- --------------------------------------------------------------------------

-- Each generated driver receives one event. The existing SafetyEvents trigger
-- creates/recalculates one DriverSafetyScore row for that driver's event month.
-- Critical severity is deliberately excluded so the trigger does not inactivate
-- bulk drivers or add extra automatic coaching rows beyond the requested 500.
INSERT INTO `SafetyEvents`
    (`Timestamp`, `VehicleID`, `DriverID`, `EventsTypeID`, `Severity`,
     `DepotID`, `Odometer`, `ReviewRequired`, `ReviewStatus`)
SELECT
    TIMESTAMP('2024-01-01 07:00:00') + INTERVAL s.seq DAY,
    v.`VehicleID`,
    d.`DriverID`,
    et.`EventsTypeID`,
    CASE MOD(s.seq, 3)
        WHEN 0 THEN 'Low'
        WHEN 1 THEN 'Medium'
        ELSE 'High'
    END,
    v.`DepotID`,
    10000 + (s.seq * 337),
    FALSE,
    'Not Required'
FROM seq_1_to_500 AS s
JOIN `Vehicles` AS v
  ON v.`RegistrationNumber` = CONCAT('BULK-', LPAD(s.seq, 6, '0'))
JOIN `Drivers` AS d
  ON d.`FirstName` = CONCAT('BulkDriver', LPAD(s.seq, 6, '0'))
 AND d.`LastName` = 'LoadTest'
JOIN `SafetyEventsType` AS et
  ON et.`Name` = CASE MOD(s.seq, 3)
      WHEN 0 THEN 'Harsh Braking'
      WHEN 1 THEN 'Sharp Cornering'
      ELSE 'Excessive Speeding'
  END
WHERE NOT EXISTS (
    SELECT 1
    FROM `SafetyEvents` AS existing
    WHERE existing.`VehicleID` = v.`VehicleID`
      AND existing.`DriverID` = d.`DriverID`
      AND existing.`Timestamp` = TIMESTAMP('2024-01-01 07:00:00') + INTERVAL s.seq DAY
);

INSERT INTO `CoachingRecord`
    (`DriverID`, `Reason`, `ScheduledDate`, `CompleteDate`, `Outcome`,
     `RecordType`, `EventID`, `ScoreID`)
SELECT
    d.`DriverID`,
    CONCAT('Bulk load coaching record ', LPAD(s.seq, 6, '0')),
    DATE('2025-06-01') + INTERVAL MOD(s.seq, 180) DAY,
    CASE
        WHEN MOD(s.seq, 4) = 0 THEN NULL
        ELSE DATE('2025-06-08') + INTERVAL MOD(s.seq, 180) DAY
    END,
    CASE MOD(s.seq, 4)
        WHEN 0 THEN 'Pending'
        WHEN 1 THEN 'Passed'
        WHEN 2 THEN 'Failed'
        ELSE 'Cancelled'
    END,
    'Other',
    NULL,
    NULL
FROM seq_1_to_500 AS s
JOIN `Drivers` AS d
  ON d.`FirstName` = CONCAT('BulkDriver', LPAD(s.seq, 6, '0'))
 AND d.`LastName` = 'LoadTest'
WHERE NOT EXISTS (
    SELECT 1
    FROM `CoachingRecord` AS existing
    WHERE existing.`Reason` = CONCAT('Bulk load coaching record ', LPAD(s.seq, 6, '0'))
);

-- --------------------------------------------------------------------------
-- 3. Workshop people: 500 mechanics and current certifications
-- --------------------------------------------------------------------------

INSERT INTO `Mechanic`
    (`FirstName`, `LastName`, `WorkshopID`, `EmploymentStatus`)
SELECT
    CONCAT('BulkMechanic', LPAD(s.seq, 6, '0')),
    'LoadTest',
    w.`WorkshopID`,
    'Active'
FROM seq_1_to_500 AS s
JOIN `_bulk_workshops` AS w
  ON w.`seq_no` = 1 + MOD(s.seq - 1, @bulk_workshop_count)
WHERE NOT EXISTS (
    SELECT 1
    FROM `Mechanic` AS existing
    WHERE existing.`FirstName` = CONCAT('BulkMechanic', LPAD(s.seq, 6, '0'))
      AND existing.`LastName` = 'LoadTest'
);

INSERT INTO `MechanicCertification`
    (`MechanicID`, `MecCertTypeID`, `IssueDate`, `ExpireDate`)
SELECT
    m.`MechanicID`, mct.`MecCertTypeID`, '2023-01-01', '2035-12-31'
FROM seq_1_to_500 AS s
JOIN `Mechanic` AS m
  ON m.`FirstName` = CONCAT('BulkMechanic', LPAD(s.seq, 6, '0'))
 AND m.`LastName` = 'LoadTest'
JOIN `MechanicCertType` AS mct
  ON mct.`Name` = 'Standard Vehicle Mechanic Licence'
WHERE NOT EXISTS (
    SELECT 1
    FROM `MechanicCertification` AS existing
    WHERE existing.`MechanicID` = m.`MechanicID`
      AND existing.`MecCertTypeID` = mct.`MecCertTypeID`
      AND existing.`IssueDate` = '2023-01-01'
);

-- --------------------------------------------------------------------------
-- 4. Parts and supply: 500 parts, 25 suppliers, 500 supplier links
-- --------------------------------------------------------------------------

INSERT INTO `Part`
    (`PartNumber`, `Description`, `UnitPrice`, `QuantityInStock`, `ReorderThreshold`)
SELECT
    CONCAT('BULK-P-', LPAD(s.seq, 6, '0')),
    CONCAT('Bulk performance-test part ', LPAD(s.seq, 6, '0')),
    50000 + (s.seq * 1250),
    1000 + MOD(s.seq, 200),
    50 + MOD(s.seq, 25)
FROM seq_1_to_500 AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM `Part` AS existing
    WHERE existing.`PartNumber` = CONCAT('BULK-P-', LPAD(s.seq, 6, '0'))
);

INSERT INTO `Supplier`
    (`Name`, `ContactEmail`, `LeadTimeDays`)
SELECT
    CONCAT('Bulk Supplier ', LPAD(s.seq, 3, '0')),
    CONCAT('bulk-supplier-', LPAD(s.seq, 3, '0'), '@example.test'),
    1 + MOD(s.seq, 14)
FROM seq_1_to_25 AS s
WHERE NOT EXISTS (
    SELECT 1
    FROM `Supplier` AS existing
    WHERE existing.`Name` = CONCAT('Bulk Supplier ', LPAD(s.seq, 3, '0'))
);

INSERT INTO `SupplyPart`
    (`PartID`, `SupplierID`, `UnitCost`, `IsPrimary`)
SELECT
    p.`PartID`,
    supplier.`SupplierID`,
    ROUND(p.`UnitPrice` * 0.72, 2),
    TRUE
FROM seq_1_to_500 AS s
JOIN `Part` AS p
  ON p.`PartNumber` = CONCAT('BULK-P-', LPAD(s.seq, 6, '0'))
JOIN `Supplier` AS supplier
  ON supplier.`Name` = CONCAT('Bulk Supplier ', LPAD(1 + MOD(s.seq - 1, 25), 3, '0'))
WHERE NOT EXISTS (
    SELECT 1
    FROM `SupplyPart` AS existing
    WHERE existing.`PartID` = p.`PartID`
      AND existing.`SupplierID` = supplier.`SupplierID`
);

-- --------------------------------------------------------------------------
-- 5. Maintenance: 500 alerts, jobs, activities, labour and part-usage rows
-- --------------------------------------------------------------------------

INSERT INTO `PredictiveAlert`
    (`VehicleID`, `AlertType`, `Severity`, `GeneratedAt`, `Status`, `ResolvedAt`)
SELECT
    v.`VehicleID`,
    CASE MOD(s.seq, 8)
        WHEN 0 THEN 'Brake Wear Warning'
        WHEN 1 THEN 'Engine Overheating Risk'
        WHEN 2 THEN 'Battery Degradation'
        WHEN 3 THEN 'Oil Quality Deterioration'
        WHEN 4 THEN 'Transmission Fault Warning'
        WHEN 5 THEN 'Cooling System Anomaly'
        WHEN 6 THEN 'Tyre Pressure Irregularity'
        ELSE 'Other'
    END,
    CASE MOD(s.seq, 4)
        WHEN 0 THEN 'Low'
        WHEN 1 THEN 'Medium'
        WHEN 2 THEN 'High'
        ELSE 'Critical'
    END,
    TIMESTAMP('2024-05-31 07:00:00') + INTERVAL s.seq DAY,
    'Acknowledged',
    NULL
FROM seq_1_to_500 AS s
JOIN `Vehicles` AS v
  ON v.`RegistrationNumber` = CONCAT('BULK-', LPAD(s.seq, 6, '0'))
WHERE NOT EXISTS (
    SELECT 1
    FROM `PredictiveAlert` AS existing
    WHERE existing.`VehicleID` = v.`VehicleID`
      AND existing.`GeneratedAt` = TIMESTAMP('2024-05-31 07:00:00') + INTERVAL s.seq DAY
);

-- Stage job input before INSERT. The MaintenanceJobs trigger updates Vehicles
-- and PredictiveAlert, and MariaDB does not allow a trigger to update a table
-- that the invoking INSERT ... SELECT is simultaneously reading.
DROP TEMPORARY TABLE IF EXISTS `_bulk_jobs`;
CREATE TEMPORARY TABLE `_bulk_jobs` AS
SELECT
    s.seq AS `bulk_seq`,
    v.`VehicleID`,
    w.`WorkshopID`,
    TIMESTAMP('2024-06-01 08:00:00') + INTERVAL s.seq DAY AS `DateOpened`,
    CASE
        WHEN MOD(s.seq, 5) = 0 THEN NULL
        ELSE TIMESTAMP('2024-06-01 08:00:00') + INTERVAL s.seq DAY
             + INTERVAL (2 + MOD(s.seq, 10)) HOUR
    END AS `DateClosed`,
    CASE WHEN MOD(s.seq, 5) = 0 THEN NULL ELSE 2 + MOD(s.seq, 10) END AS `OverallDowntime`,
    CASE WHEN MOD(s.seq, 5) = 0 THEN 0 ELSE 250000 + (s.seq * 15000) END AS `TotalCost`,
    pa.`AlertID`
FROM seq_1_to_500 AS s
JOIN `Vehicles` AS v
  ON v.`RegistrationNumber` = CONCAT('BULK-', LPAD(s.seq, 6, '0'))
JOIN `Workshop` AS w
  ON w.`DepotID` = v.`DepotID`
JOIN `PredictiveAlert` AS pa
  ON pa.`VehicleID` = v.`VehicleID`
 AND pa.`GeneratedAt` = TIMESTAMP('2024-05-31 07:00:00') + INTERVAL s.seq DAY
WHERE NOT EXISTS (
    SELECT 1
    FROM `MaintenanceJobs` AS existing
    WHERE existing.`VehicleID` = v.`VehicleID`
      AND existing.`DateOpened` = TIMESTAMP('2024-06-01 08:00:00') + INTERVAL s.seq DAY
);

INSERT INTO `MaintenanceJobs`
    (`VehicleID`, `WorkshopID`, `DateOpened`, `DateClosed`,
     `OverallDowntime`, `TotalCost`, `AlertID`)
SELECT
    `VehicleID`, `WorkshopID`, `DateOpened`, `DateClosed`,
    `OverallDowntime`, `TotalCost`, `AlertID`
FROM `_bulk_jobs`;

INSERT INTO `MaintenanceActivity`
    (`JobID`, `ActivityTypeID`, `DiagnosticResult`, `IsRepeatFault`,
     `StartedAt`, `CompleteAt`)
SELECT
    mj.`JobID`,
    atp.`ActivityTypeID`,
    CONCAT('Bulk diagnostic result ', LPAD(s.seq, 6, '0')),
    MOD(s.seq, 10) = 0,
    mj.`DateOpened` + INTERVAL 30 MINUTE,
    CASE
        WHEN mj.`DateClosed` IS NULL THEN NULL
        ELSE mj.`DateOpened` + INTERVAL (1 + MOD(s.seq, 5)) HOUR
    END
FROM seq_1_to_500 AS s
JOIN `Vehicles` AS v
  ON v.`RegistrationNumber` = CONCAT('BULK-', LPAD(s.seq, 6, '0'))
JOIN `MaintenanceJobs` AS mj
  ON mj.`VehicleID` = v.`VehicleID`
 AND mj.`DateOpened` = TIMESTAMP('2024-06-01 08:00:00') + INTERVAL s.seq DAY
JOIN `ActivityType` AS atp
  ON atp.`Name` = 'Routine Inspection'
WHERE NOT EXISTS (
    SELECT 1
    FROM `MaintenanceActivity` AS existing
    WHERE existing.`JobID` = mj.`JobID`
      AND existing.`DiagnosticResult` = CONCAT('Bulk diagnostic result ', LPAD(s.seq, 6, '0'))
);

-- The certification trigger validates every row against the Routine Inspection
-- activity's required Standard Vehicle Mechanic Licence.
INSERT INTO `ActivityMechanic`
    (`ActivityID`, `MechanicID`, `LabourHours`)
SELECT
    ma.`ActivityID`,
    m.`MechanicID`,
    1.00 + (MOD(s.seq, 8) * 0.50)
FROM seq_1_to_500 AS s
JOIN `MaintenanceActivity` AS ma
  ON ma.`DiagnosticResult` = CONCAT('Bulk diagnostic result ', LPAD(s.seq, 6, '0'))
JOIN `Mechanic` AS m
  ON m.`FirstName` = CONCAT('BulkMechanic', LPAD(s.seq, 6, '0'))
 AND m.`LastName` = 'LoadTest'
WHERE NOT EXISTS (
    SELECT 1
    FROM `ActivityMechanic` AS existing
    WHERE existing.`ActivityID` = ma.`ActivityID`
      AND existing.`MechanicID` = m.`MechanicID`
);

-- ActivityPart's stock trigger deducts this quantity from each generated part.
-- Stage the price and IDs first because that trigger updates Part stock.
DROP TEMPORARY TABLE IF EXISTS `_bulk_activity_parts`;
CREATE TEMPORARY TABLE `_bulk_activity_parts` AS
SELECT
    ma.`ActivityID`,
    p.`PartID`,
    1 + MOD(s.seq, 5) AS `QuantityUsed`,
    p.`UnitPrice` AS `UnitPriceAtTime`
FROM seq_1_to_500 AS s
JOIN `MaintenanceActivity` AS ma
  ON ma.`DiagnosticResult` = CONCAT('Bulk diagnostic result ', LPAD(s.seq, 6, '0'))
JOIN `Part` AS p
  ON p.`PartNumber` = CONCAT('BULK-P-', LPAD(s.seq, 6, '0'))
WHERE NOT EXISTS (
    SELECT 1
    FROM `ActivityPart` AS existing
    WHERE existing.`ActivityID` = ma.`ActivityID`
      AND existing.`PartID` = p.`PartID`
);

INSERT INTO `ActivityPart`
    (`ActivityID`, `PartID`, `QuantityUsed`, `UnitPriceAtTime`)
SELECT
    `ActivityID`, `PartID`, `QuantityUsed`, `UnitPriceAtTime`
FROM `_bulk_activity_parts`;

-- --------------------------------------------------------------------------
-- 6. Warranty: 500 claims and 500 claim/part links
-- --------------------------------------------------------------------------

INSERT INTO `WarrantyClaim`
    (`ActivityID`, `WarrantyType`, `Status`, `ClaimDate`)
SELECT
    ma.`ActivityID`,
    CASE WHEN MOD(s.seq, 2) = 0 THEN 'Manufacturer' ELSE 'Supplier' END,
    CASE MOD(s.seq, 4)
        WHEN 0 THEN 'Submitted'
        WHEN 1 THEN 'Approved'
        WHEN 2 THEN 'Rejected'
        ELSE 'Completed'
    END,
    DATE('2024-06-02') + INTERVAL s.seq DAY
FROM seq_1_to_500 AS s
JOIN `MaintenanceActivity` AS ma
  ON ma.`DiagnosticResult` = CONCAT('Bulk diagnostic result ', LPAD(s.seq, 6, '0'))
WHERE NOT EXISTS (
    SELECT 1
    FROM `WarrantyClaim` AS existing
    WHERE existing.`ActivityID` = ma.`ActivityID`
      AND existing.`ClaimDate` = DATE('2024-06-02') + INTERVAL s.seq DAY
);

INSERT INTO `WarrantyClaimPart`
    (`ClaimID`, `PartID`)
SELECT
    wc.`ClaimID`,
    p.`PartID`
FROM seq_1_to_500 AS s
JOIN `MaintenanceActivity` AS ma
  ON ma.`DiagnosticResult` = CONCAT('Bulk diagnostic result ', LPAD(s.seq, 6, '0'))
JOIN `WarrantyClaim` AS wc
  ON wc.`ActivityID` = ma.`ActivityID`
 AND wc.`ClaimDate` = DATE('2024-06-02') + INTERVAL s.seq DAY
JOIN `Part` AS p
  ON p.`PartNumber` = CONCAT('BULK-P-', LPAD(s.seq, 6, '0'))
WHERE NOT EXISTS (
    SELECT 1
    FROM `WarrantyClaimPart` AS existing
    WHERE existing.`ClaimID` = wc.`ClaimID`
      AND existing.`PartID` = p.`PartID`
);

COMMIT;

DROP TEMPORARY TABLE IF EXISTS `_bulk_depots`;
DROP TEMPORARY TABLE IF EXISTS `_bulk_workshops`;
DROP TEMPORARY TABLE IF EXISTS `_bulk_jobs`;
DROP TEMPORARY TABLE IF EXISTS `_bulk_activity_parts`;

-- Refresh optimizer statistics so EXPLAIN/ANALYZE can make decisions using the
-- newly loaded row distribution.
ANALYZE TABLE
    `Vehicles`, `VehiclesDepotHistory`, `VehicleAssignments`,
    `Drivers`, `DriverCertifications`, `DriverSafetyScore`, `SafetyEvents`,
    `CoachingRecord`, `Mechanic`, `MechanicCertification`, `PredictiveAlert`,
    `MaintenanceJobs`, `MaintenanceActivity`, `ActivityMechanic`, `Part`,
    `SupplyPart`, `ActivityPart`, `WarrantyClaim`, `WarrantyClaimPart`;

-- Final totals include the original meaningful seed rows plus the bulk rows.
SELECT 'Vehicles' AS `table_name`, COUNT(*) AS `total_rows` FROM `Vehicles`
UNION ALL SELECT 'VehiclesDepotHistory', COUNT(*) FROM `VehiclesDepotHistory`
UNION ALL SELECT 'VehicleAssignments', COUNT(*) FROM `VehicleAssignments`
UNION ALL SELECT 'Drivers', COUNT(*) FROM `Drivers`
UNION ALL SELECT 'DriverCertifications', COUNT(*) FROM `DriverCertifications`
UNION ALL SELECT 'DriverSafetyScore', COUNT(*) FROM `DriverSafetyScore`
UNION ALL SELECT 'SafetyEvents', COUNT(*) FROM `SafetyEvents`
UNION ALL SELECT 'CoachingRecord', COUNT(*) FROM `CoachingRecord`
UNION ALL SELECT 'Mechanic', COUNT(*) FROM `Mechanic`
UNION ALL SELECT 'MechanicCertification', COUNT(*) FROM `MechanicCertification`
UNION ALL SELECT 'Part', COUNT(*) FROM `Part`
UNION ALL SELECT 'Supplier', COUNT(*) FROM `Supplier`
UNION ALL SELECT 'SupplyPart', COUNT(*) FROM `SupplyPart`
UNION ALL SELECT 'PredictiveAlert', COUNT(*) FROM `PredictiveAlert`
UNION ALL SELECT 'MaintenanceJobs', COUNT(*) FROM `MaintenanceJobs`
UNION ALL SELECT 'MaintenanceActivity', COUNT(*) FROM `MaintenanceActivity`
UNION ALL SELECT 'ActivityMechanic', COUNT(*) FROM `ActivityMechanic`
UNION ALL SELECT 'ActivityPart', COUNT(*) FROM `ActivityPart`
UNION ALL SELECT 'WarrantyClaim', COUNT(*) FROM `WarrantyClaim`
UNION ALL SELECT 'WarrantyClaimPart', COUNT(*) FROM `WarrantyClaimPart`;

-- ============================================================================
-- End of smartfleet_bulk_data.sql
-- ============================================================================
