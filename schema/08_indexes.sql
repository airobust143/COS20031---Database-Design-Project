-- =====================================================================
-- Smart Fleet Management Database — PERFORMANCE INDEXES
-- COS20031 Group 4 — MySQL 8.0 / MariaDB 10.4+
-- File 8 of 8. Run after all tables have been created (01–07).
-- =====================================================================
-- This file contains all non-unique secondary indexes extracted from
-- the table definitions for better maintainability and performance
-- tuning. These indexes support:
--   • Foreign key lookups and JOIN operations
--   • Status/enum filtering queries
--   • Date range queries
--   • Aggregate operations (COUNT, GROUP BY, etc.)
--
-- NOTE: Primary keys and unique constraints remain in their respective
-- table definition files (01–05) as they are part of the logical schema.
-- Only performance-oriented secondary indexes are extracted here.
-- =====================================================================

USE `smart_fleet_management`;

-- =====================================================================
-- CORE FLEET DOMAIN INDEXES
-- =====================================================================

-- Vehicles
ALTER TABLE `Vehicles`
    ADD INDEX `idx_vehicles_status` (`OperationalStatus`);

-- VehiclesDepotHistory
ALTER TABLE `VehiclesDepotHistory`
    ADD INDEX `idx_vdh_vehicle` (`VehicleID`),
    ADD INDEX `idx_vdh_depot` (`DepotID`);

-- VehicleAssignments
ALTER TABLE `VehicleAssignments`
    ADD INDEX `idx_va_vehicle` (`VehicleID`),
    ADD INDEX `idx_va_driver` (`DriverID`),
    ADD INDEX `idx_va_depot` (`DepotID`);

-- =====================================================================
-- DRIVER & SAFETY DOMAIN INDEXES
-- =====================================================================

-- Drivers
ALTER TABLE `Drivers`
    ADD INDEX `idx_drivers_depot` (`DepotID`),
    ADD INDEX `idx_drivers_status` (`EmploymentStatus`),
    ADD INDEX `idx_drivers_licexp` (`LicenceExpiryDate`);

-- DriverCertifications
ALTER TABLE `DriverCertifications`
    ADD INDEX `idx_dc_driver` (`DriverID`),
    ADD INDEX `idx_dc_certtype` (`CertTypeID`),
    ADD INDEX `idx_dc_expire` (`ExpireDate`);

-- SafetyEvents
ALTER TABLE `SafetyEvents`
    ADD INDEX `idx_se_driver` (`DriverID`),
    ADD INDEX `idx_se_vehicle` (`VehicleID`),
    ADD INDEX `idx_se_depot` (`DepotID`),
    ADD INDEX `idx_se_eventstype` (`EventsTypeID`),
    ADD INDEX `idx_se_severity` (`Severity`),
    ADD INDEX `idx_se_timestamp` (`Timestamp`);

-- CoachingRecord
ALTER TABLE `CoachingRecord`
    ADD INDEX `idx_cr_driver` (`DriverID`),
    ADD INDEX `idx_cr_event` (`EventID`),
    ADD INDEX `idx_cr_score` (`ScoreID`);

-- =====================================================================
-- WORKSHOPS & PEOPLE DOMAIN INDEXES
-- =====================================================================

-- Mechanic
ALTER TABLE `Mechanic`
    ADD INDEX `idx_mechanic_workshop` (`WorkshopID`);

-- MechanicCertification
ALTER TABLE `MechanicCertification`
    ADD INDEX `idx_mc_mechanic` (`MechanicID`),
    ADD INDEX `idx_mc_certtype` (`MecCertTypeID`);

-- =====================================================================
-- MAINTENANCE DOMAIN INDEXES
-- =====================================================================

-- PredictiveAlert
ALTER TABLE `PredictiveAlert`
    ADD INDEX `idx_pa_vehicle` (`VehicleID`),
    ADD INDEX `idx_pa_status` (`Status`);

-- MaintenanceJobs
ALTER TABLE `MaintenanceJobs`
    ADD INDEX `idx_mj_vehicle` (`VehicleID`),
    ADD INDEX `idx_mj_workshop` (`WorkshopID`);

-- MaintenanceActivity
ALTER TABLE `MaintenanceActivity`
    ADD INDEX `idx_ma_job` (`JobID`),
    ADD INDEX `idx_ma_activitytype` (`ActivityTypeID`);

-- ActivityMechanic
ALTER TABLE `ActivityMechanic`
    ADD INDEX `idx_am_mechanic` (`MechanicID`);

-- Part
ALTER TABLE `Part`
    ADD INDEX `idx_part_stock` (`QuantityInStock`);

-- SupplyPart
ALTER TABLE `SupplyPart`
    ADD INDEX `idx_sp_supplier` (`SupplierID`);

-- ActivityPart
ALTER TABLE `ActivityPart`
    ADD INDEX `idx_ap_part` (`PartID`);

-- WarrantyClaim
ALTER TABLE `WarrantyClaim`
    ADD INDEX `idx_wc_activity` (`ActivityID`);

-- WarrantyClaimParts
ALTER TABLE `WarrantyClaimParts`
    ADD INDEX `idx_wcp_part` (`PartID`);

-- =====================================================================
-- USER ROLE DOMAIN INDEXES
-- =====================================================================

-- UserAccount
ALTER TABLE `UserAccount`
    ADD INDEX `idx_ua_driver` (`DriverID`),
    ADD INDEX `idx_ua_mechanic` (`MechanicID`),
    ADD INDEX `idx_ua_depot` (`DepotID`);

-- UserRole
ALTER TABLE `UserRole`
    ADD INDEX `idx_ur_role` (`RoleID`);

-- RolePermission
ALTER TABLE `RolePermission`
    ADD INDEX `idx_rp_permission` (`PermissionID`);

-- =====================================================================
-- LOGIN TRACKING INDEXES
-- =====================================================================

-- login_attempts
ALTER TABLE `login_attempts`
    ADD INDEX `idx_la_ip_time` (`ip`, `attempted_at`);

-- =====================================================================
-- End of 08_indexes.sql
-- =====================================================================
