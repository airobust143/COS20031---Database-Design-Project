USE smart_fleet_management;

CREATE INDEX idx_vehicles_status
ON Vehicles (OperationalStatus);

CREATE INDEX idx_vdh_vehicle_dates
ON VehiclesDepotHistory (VehicleID, MovedFrom, MovedTo);

CREATE INDEX idx_va_vehicle_dates
ON VehicleAssignments (VehicleID, StartDate, EndDate);

CREATE INDEX idx_va_driver_dates
ON VehicleAssignments (DriverID, StartDate, EndDate);

CREATE INDEX idx_drivers_status
ON Drivers (EmploymentStatus);

CREATE INDEX idx_dc_driver_cert_dates
ON DriverCertifications
    (DriverID, CertTypeID, IssueDate, ExpireDate);

CREATE INDEX idx_se_driver_time
ON SafetyEvents (DriverID, Timestamp);

CREATE INDEX idx_se_vehicle_time
ON SafetyEvents (VehicleID, Timestamp);

CREATE INDEX idx_se_severity
ON SafetyEvents (Severity);

CREATE INDEX idx_cr_driver_outcome_date
ON CoachingRecord (DriverID, Outcome, ScheduledDate);

CREATE INDEX idx_mc_mechanic_cert_dates
ON MechanicCertification
    (MechanicID, MecCertTypeID, IssueDate, ExpireDate);

CREATE INDEX idx_pa_status_generated
ON PredictiveAlert (Status, GeneratedAt);

CREATE INDEX idx_mj_vehicle_closed
ON MaintenanceJobs (VehicleID, DateClosed);

CREATE INDEX idx_mj_workshop_closed
ON MaintenanceJobs (WorkshopID, DateClosed);

CREATE INDEX idx_mj_workshop_opened_closed
ON MaintenanceJobs (WorkshopID, DateOpened, DateClosed);

CREATE INDEX idx_ma_job_dates
ON MaintenanceActivity (JobID, StartedAt, CompleteAt);

CREATE INDEX idx_ma_complete
ON MaintenanceActivity (CompleteAt);

CREATE INDEX idx_part_stock
ON Part (QuantityInStock);

CREATE INDEX idx_sp_part_primary
ON SupplyPart (PartID, IsPrimary);

CREATE INDEX idx_la_ip_time
ON login_attempts (ip, attempted_at);