SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS ActivityMechanic;
DROP TABLE IF EXISTS MaintenanceActivity;
DROP TABLE IF EXISTS MaintenanceJobs;
DROP TABLE IF EXISTS PredictiveAlert;
DROP TABLE IF EXISTS SafetyEvents;
DROP TABLE IF EXISTS SafetyEventsType;
DROP TABLE IF EXISTS DriverSafetyScore;
DROP TABLE IF EXISTS CoachingRecord;
DROP TABLE IF EXISTS DriverCertifications;
DROP TABLE IF EXISTS VehicleCertRequirement;
DROP TABLE IF EXISTS CertificationType;
DROP TABLE IF EXISTS VehicleAssignments;
DROP TABLE IF EXISTS Drivers;
DROP TABLE IF EXISTS Vehicles;
DROP TABLE IF EXISTS ActivityType;
DROP TABLE IF EXISTS MechanicCertification;
DROP TABLE IF EXISTS MechanicCertType;
DROP TABLE IF EXISTS Mechanic;
DROP TABLE IF EXISTS Workshop;
DROP TABLE IF EXISTS Depots;

SET FOREIGN_KEY_CHECKS = 1;


-- =====================================================================
-- 1. CORE FLEET DOMAIN
-- =====================================================================

CREATE TABLE Depots (
    DepotID        INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    City           VARCHAR(100) NOT NULL,
    Address        VARCHAR(255) NOT NULL,
    Name           VARCHAR(150) NOT NULL,
    ContactPhone   VARCHAR(30)
);

CREATE TABLE Vehicles (
    VehicleID              INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    RegistrationNumber     VARCHAR(20)  NOT NULL UNIQUE,
    VehicleCategory        ENUM(
        'Delivery Van',
        'Refrigerated Truck',
        'Electric Van',
        'Service Vehicle',
        'Heavy Transport Truck'
    ) NOT NULL,
    Model                  VARCHAR(100),
    Manufacturer           VARCHAR(100),
    YearOfManufacture      INT          CHECK (YearOfManufacture BETWEEN 1950 AND 2100),
    CurrentOdometerReading INT          DEFAULT 0 CHECK (CurrentOdometerReading >= 0),
    DepotID                INT          NOT NULL,
    OperationalStatus      ENUM(
        'Active',
        'Available',
        'Under Maintenance',
        'Awaiting Inspection',
        'Out of Service',
        'Retired'
    ) NOT NULL DEFAULT 'Active',
    CONSTRAINT fk_vehicles_depot
        FOREIGN KEY (DepotID) REFERENCES Depots(DepotID)
);


-- =====================================================================
-- 2. WORKSHOPS & PEOPLE DOMAIN
-- =====================================================================

CREATE TABLE Workshop (
    WorkshopID   INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    DepotID      INT          NOT NULL,
    Name         VARCHAR(150) NOT NULL,
    NumBays      INT          CHECK (NumBays >= 0),
    Contacts     VARCHAR(255),
    CONSTRAINT fk_workshop_depot
        FOREIGN KEY (DepotID) REFERENCES Depots(DepotID)
);

CREATE TABLE Mechanic (
    MechanicID        INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    FirstName         VARCHAR(80)  NOT NULL,
    LastName          VARCHAR(80)  NOT NULL,
    WorkshopID        INT          NOT NULL,
    EmploymentStatus  ENUM('Active','On Leave','Suspended','Terminated') NOT NULL DEFAULT 'Active',
    CONSTRAINT fk_mechanic_workshop
        FOREIGN KEY (WorkshopID) REFERENCES Workshop(WorkshopID)
);

CREATE TABLE MechanicCertType (
    MecCertTypeID  INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    Name           ENUM(
        'Standard Vehicle Mechanic Licence',
        'EV Technician Certification',
        'Refrigeration Systems Certification',
        'Heavy Vehicle Mechanic Licence'
    ) NOT NULL UNIQUE,
    Expire         BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE MechanicCertification (
    MecCertID      INT     NOT NULL AUTO_INCREMENT PRIMARY KEY,
    MechanicID     INT     NOT NULL,
    MecCertTypeID  INT     NOT NULL,
    IssueDate      DATE    NOT NULL,
    ExpireDate     DATE,
    CONSTRAINT fk_mc_mechanic
        FOREIGN KEY (MechanicID)    REFERENCES Mechanic(MechanicID),
    CONSTRAINT fk_mc_certtype
        FOREIGN KEY (MecCertTypeID) REFERENCES MechanicCertType(MecCertTypeID),
    CONSTRAINT chk_mc_dates CHECK (ExpireDate IS NULL OR ExpireDate >= IssueDate)
);


-- =====================================================================
-- 3. DRIVERS, CERTIFICATIONS & SAFETY DOMAIN
-- =====================================================================

CREATE TABLE Drivers (
    DriverID                 INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    FirstName                VARCHAR(80)  NOT NULL,
    LastName                 VARCHAR(80)  NOT NULL,
    ContactInformation       VARCHAR(255),
    DepotID                  INT          NOT NULL,
    LicenceType              ENUM('Standard Licence','Heavy Vehicle Licence') NOT NULL,
    LicenceExpiryDate        DATE         NOT NULL,
    EmploymentStatus         ENUM('Active','On Leave','Suspended','Terminated') NOT NULL DEFAULT 'Active',
    EmergencyContactDetails  VARCHAR(255),
    CONSTRAINT fk_drivers_depot
        FOREIGN KEY (DepotID) REFERENCES Depots(DepotID)
);

CREATE TABLE VehicleAssignments (
    AssignmentID  INT     NOT NULL AUTO_INCREMENT PRIMARY KEY,
    VehicleID     INT     NOT NULL,
    DriverID      INT     NOT NULL,
    StartDate     DATE    NOT NULL,
    EndDate       DATE,
    AssignedDepot INT,
    IsPermanent   BOOLEAN NOT NULL DEFAULT FALSE,
    DepotID       INT     NOT NULL,
    CONSTRAINT fk_va_vehicle  FOREIGN KEY (VehicleID)     REFERENCES Vehicles(VehicleID),
    CONSTRAINT fk_va_driver   FOREIGN KEY (DriverID)      REFERENCES Drivers(DriverID),
    CONSTRAINT fk_va_depot    FOREIGN KEY (DepotID)       REFERENCES Depots(DepotID),
    CONSTRAINT fk_va_adepot   FOREIGN KEY (AssignedDepot) REFERENCES Depots(DepotID),
    CONSTRAINT chk_va_dates   CHECK (EndDate IS NULL OR EndDate >= StartDate)
);

CREATE TABLE CertificationType (
    CertTypeID  INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    Name        ENUM(
        'Standard Licence',
        'Heavy Vehicle Licence',
        'Refrigerated Transport Certification',
        'EV Certification',
        'Hazardous Goods Certification'
    ) NOT NULL UNIQUE,
    Expire      BOOLEAN      NOT NULL DEFAULT TRUE
);

-- Defines which certifications each vehicle category requires
CREATE TABLE VehicleCertRequirement (
    ReqID        INT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    VehicleType  ENUM(
        'Delivery Van',
        'Refrigerated Truck',
        'Electric Van',
        'Service Vehicle',
        'Heavy Transport Truck'
    ) NOT NULL,
    CertTypeID   INT NOT NULL,
    CONSTRAINT fk_vcr_certtype FOREIGN KEY (CertTypeID) REFERENCES CertificationType(CertTypeID),
    CONSTRAINT uq_vcr UNIQUE (VehicleType, CertTypeID)
);

CREATE TABLE DriverCertifications (
    DriverCertID  INT  NOT NULL AUTO_INCREMENT PRIMARY KEY,
    DriverID      INT  NOT NULL,
    CertTypeID    INT  NOT NULL,
    IssueDate     DATE NOT NULL,
    ExpireDate    DATE,
    CONSTRAINT fk_dc_driver   FOREIGN KEY (DriverID)   REFERENCES Drivers(DriverID),
    CONSTRAINT fk_dc_certtype FOREIGN KEY (CertTypeID) REFERENCES CertificationType(CertTypeID),
    CONSTRAINT chk_dc_dates   CHECK (ExpireDate IS NULL OR ExpireDate >= IssueDate)
);

CREATE TABLE CoachingRecord (
    CoachingID     INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    DriverID       INT          NOT NULL,
    Reason         VARCHAR(255),
    ScheduledDate  DATE         NOT NULL,
    CompleteDate   DATE,
    Outcome        VARCHAR(255),
    CONSTRAINT fk_cr_driver FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID)
);

CREATE TABLE DriverSafetyScore (
    ScoreID          INT     NOT NULL AUTO_INCREMENT PRIMARY KEY,
    DriverID         INT     NOT NULL,
    BaseScore        INT     NOT NULL DEFAULT 100,
    DeductedPoints   INT     NOT NULL DEFAULT 0,
    FinalScore       INT     NOT NULL,
    CoachingRequired BOOLEAN NOT NULL DEFAULT FALSE,
    Suspended        BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_dss_driver FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID)
);

CREATE TABLE SafetyEventsType (
    EventsTypeID    INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    Name            ENUM(
        'Harsh Braking',
        'Rapid Acceleration',
        'Excessive Speeding',
        'Sharp Cornering',
        'Excessive Idling',
        'Fatigue Warning',
        'Seatbelt Violation',
        'Phone Distraction Alert'
    ) NOT NULL UNIQUE,
    DefaultSeverity ENUM('Low','Medium','High','Critical') NOT NULL
);

CREATE TABLE SafetyEvents (
    EventID        INT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    Timestamp      TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    VehicleID      INT       NOT NULL,
    DriverID       INT       NOT NULL,
    EventsTypeID   INT       NOT NULL,
    Severity       ENUM('Low','Medium','High','Critical') NOT NULL,
    DepotID        INT       NOT NULL,
    Odometer       INT       CHECK (Odometer >= 0),
    ReviewRequired BOOLEAN   NOT NULL DEFAULT FALSE,
    ReviewStatus   ENUM('Pending','In Review','Resolved','Dismissed'),
    CONSTRAINT fk_se_vehicle   FOREIGN KEY (VehicleID)    REFERENCES Vehicles(VehicleID),
    CONSTRAINT fk_se_driver    FOREIGN KEY (DriverID)     REFERENCES Drivers(DriverID),
    CONSTRAINT fk_se_eventtype FOREIGN KEY (EventsTypeID) REFERENCES SafetyEventsType(EventsTypeID),
    CONSTRAINT fk_se_depot     FOREIGN KEY (DepotID)      REFERENCES Depots(DepotID)
);


-- =====================================================================
-- 4. MAINTENANCE DOMAIN
-- =====================================================================

CREATE TABLE PredictiveAlert (
    AlertID      INT          NOT NULL AUTO_INCREMENT PRIMARY KEY,
    VehicleID    INT          NOT NULL,
    AlertType    VARCHAR(100) NOT NULL,
    Severity     ENUM('Low','Medium','High','Critical') NOT NULL,
    GeneratedAt  TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Status       ENUM('Open','Acknowledged','In Progress','Resolved','Dismissed') NOT NULL DEFAULT 'Open',
    ResolvedAt   TIMESTAMP    NULL,
    CONSTRAINT fk_pa_vehicle FOREIGN KEY (VehicleID) REFERENCES Vehicles(VehicleID)
);

CREATE TABLE MaintenanceJobs (
    JobID            INT  NOT NULL AUTO_INCREMENT PRIMARY KEY,
    VehicleID        INT  NOT NULL,
    WorkshopID       INT  NOT NULL,
    DateOpened       DATE NOT NULL,
    DateClosed       DATE,
    OverallDowntime  INT,
    TotalCost        DECIMAL(12,2) DEFAULT 0,
    AlertID          INT,
    CONSTRAINT fk_mj_vehicle  FOREIGN KEY (VehicleID)  REFERENCES Vehicles(VehicleID),
    CONSTRAINT fk_mj_workshop FOREIGN KEY (WorkshopID) REFERENCES Workshop(WorkshopID),
    CONSTRAINT fk_mj_alert    FOREIGN KEY (AlertID)    REFERENCES PredictiveAlert(AlertID),
    CONSTRAINT chk_mj_dates   CHECK (DateClosed IS NULL OR DateClosed >= DateOpened)
);

CREATE TABLE MaintenanceActivity (
    ActivityID         INT       NOT NULL AUTO_INCREMENT PRIMARY KEY,
    JobID              INT       NOT NULL,
    ActivityType       ENUM(
        'Routine Inspection',
        'Preventative Servicing',
        'Diagnostic Testing',
        'Emergency Repair',
        'Component Replacement',
        'EV Battery / Electrical Repair',
        'Refrigeration System Repair',
        'Heavy Vehicle Repair'
    ) NOT NULL,
    DiagnosticResult   TEXT,
    IsRepeatFault      BOOLEAN   NOT NULL DEFAULT FALSE,
    WarrantyIndicator  BOOLEAN   NOT NULL DEFAULT FALSE,
    StartedAt          TIMESTAMP NULL,
    CompleteAt         TIMESTAMP NULL,
    CONSTRAINT fk_ma_job  FOREIGN KEY (JobID) REFERENCES MaintenanceJobs(JobID),
    CONSTRAINT chk_ma_times
        CHECK (CompleteAt IS NULL OR StartedAt IS NULL OR CompleteAt >= StartedAt)
);

-- Junction: which mechanics worked on which activity (and for how long)
CREATE TABLE ActivityMechanic (
    AssignmentID  INT           NOT NULL AUTO_INCREMENT PRIMARY KEY,
    ActivityID    INT           NOT NULL,
    MechanicID    INT           NOT NULL,
    LabourHours   DECIMAL(6,2)  NOT NULL DEFAULT 0 CHECK (LabourHours >= 0),
    CONSTRAINT fk_am_activity FOREIGN KEY (ActivityID) REFERENCES MaintenanceActivity(ActivityID),
    CONSTRAINT fk_am_mechanic FOREIGN KEY (MechanicID) REFERENCES Mechanic(MechanicID),
    CONSTRAINT uq_am UNIQUE (ActivityID, MechanicID)
);


-- =====================================================================
-- Helpful indexes for common lookups
-- =====================================================================
CREATE INDEX idx_vehicles_depot          ON Vehicles(DepotID);
CREATE INDEX idx_vehicles_status         ON Vehicles(OperationalStatus);
CREATE INDEX idx_drivers_depot           ON Drivers(DepotID);
CREATE INDEX idx_va_vehicle              ON VehicleAssignments(VehicleID);
CREATE INDEX idx_va_driver               ON VehicleAssignments(DriverID);
CREATE INDEX idx_dc_driver               ON DriverCertifications(DriverID);
CREATE INDEX idx_se_vehicle_ts           ON SafetyEvents(VehicleID, Timestamp);
CREATE INDEX idx_se_driver_ts            ON SafetyEvents(DriverID,  Timestamp);
CREATE INDEX idx_pa_vehicle_status       ON PredictiveAlert(VehicleID, Status);
CREATE INDEX idx_mj_vehicle              ON MaintenanceJobs(VehicleID);
CREATE INDEX idx_mj_workshop             ON MaintenanceJobs(WorkshopID);
CREATE INDEX idx_ma_job                  ON MaintenanceActivity(JobID);
CREATE INDEX idx_am_mechanic             ON ActivityMechanic(MechanicID);
CREATE INDEX idx_mc_mechanic             ON MechanicCertification(MechanicID);