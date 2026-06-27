-- Drop tables (CASCADE clears dependent objects)
DROP TABLE IF EXISTS ActivityMechanic        CASCADE;
DROP TABLE IF EXISTS MaintenanceActivity     CASCADE;
DROP TABLE IF EXISTS MaintenanceJobs         CASCADE;
DROP TABLE IF EXISTS PredictiveAlert         CASCADE;
DROP TABLE IF EXISTS SafetyEvents            CASCADE;
DROP TABLE IF EXISTS SafetyEventsType        CASCADE;
DROP TABLE IF EXISTS DriverSafetyScore       CASCADE;
DROP TABLE IF EXISTS CoachingRecord          CASCADE;
DROP TABLE IF EXISTS DriverCertifications    CASCADE;
DROP TABLE IF EXISTS VehicleCertRequirement  CASCADE;
DROP TABLE IF EXISTS CertificationType       CASCADE;
DROP TABLE IF EXISTS VehicleAssignments      CASCADE;
DROP TABLE IF EXISTS Drivers                 CASCADE;
DROP TABLE IF EXISTS Vehicles                CASCADE;
DROP TABLE IF EXISTS ActivityType            CASCADE;
DROP TABLE IF EXISTS MechanicCertification   CASCADE;
DROP TABLE IF EXISTS MechanicCertType        CASCADE;
DROP TABLE IF EXISTS Mechanic                CASCADE;
DROP TABLE IF EXISTS Workshop                CASCADE;
DROP TABLE IF EXISTS Depots                  CASCADE;

-- Drop ENUM types (must come after the tables that use them)
DROP TYPE IF EXISTS vehicle_category_enum    CASCADE;
DROP TYPE IF EXISTS operational_status_enum  CASCADE;
DROP TYPE IF EXISTS severity_enum            CASCADE;

CREATE TYPE vehicle_category_enum AS ENUM (
    'Delivery Van',
    'Refrigerated Truck',
    'Electric Van',
    'Service Vehicle',
    'Heavy Transport Truck'
);

CREATE TYPE operational_status_enum AS ENUM (
    'Active',
    'Available',
    'Under Maintenance',
    'Awaiting Inspection',
    'Out of Service',
    'Retired'
);

CREATE TYPE severity_enum AS ENUM (
    'Low',
    'Medium',
    'High',
    'Critical'
);


-- CORE FLEET DOMAIN

CREATE TABLE Depots (
    DepotID        SERIAL       PRIMARY KEY,
    City           VARCHAR(100) NOT NULL,
    Address        VARCHAR(255) NOT NULL,
    Name           VARCHAR(150) NOT NULL,
    ContactPhone   VARCHAR(30)
);

CREATE TABLE Vehicles (
    VehicleID              SERIAL                  PRIMARY KEY,
    RegistrationNumber     VARCHAR(20)             NOT NULL UNIQUE,
    VehicleCategory        vehicle_category_enum   NOT NULL,
    Model                  VARCHAR(100),
    Manufacturer           VARCHAR(100),
    YearOfManufacture      INT                     CHECK (YearOfManufacture BETWEEN 1950 AND 2100),
    CurrentOdometerReading INT                     DEFAULT 0 CHECK (CurrentOdometerReading >= 0),
    DepotID                INT                     NOT NULL,
    OperationalStatus      operational_status_enum NOT NULL DEFAULT 'Active',
    CONSTRAINT fk_vehicles_depot
        FOREIGN KEY (DepotID) REFERENCES Depots(DepotID)
);


-- WORKSHOPS & PEOPLE DOMAIN

CREATE TABLE Workshop (
    WorkshopID   SERIAL       PRIMARY KEY,
    DepotID      INT          NOT NULL,
    Name         VARCHAR(150) NOT NULL,
    NumBays      INT          CHECK (NumBays >= 0),
    Contacts     VARCHAR(255),
    CONSTRAINT fk_workshop_depot
        FOREIGN KEY (DepotID) REFERENCES Depots(DepotID)
);

CREATE TABLE Mechanic (
    MechanicID        SERIAL       PRIMARY KEY,
    FirstName         VARCHAR(80)  NOT NULL,
    LastName          VARCHAR(80)  NOT NULL,
    WorkshopID        INT          NOT NULL,
    EmploymentStatus  VARCHAR(30)  NOT NULL DEFAULT 'Active',
    CONSTRAINT fk_mechanic_workshop
        FOREIGN KEY (WorkshopID) REFERENCES Workshop(WorkshopID)
);

CREATE TABLE MechanicCertType (
    MecCertTypeID  SERIAL       PRIMARY KEY,
    Name           VARCHAR(150) NOT NULL UNIQUE,
    Expire         BOOLEAN      NOT NULL DEFAULT TRUE
);

CREATE TABLE MechanicCertification (
    MecCertID      SERIAL  PRIMARY KEY,
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


-- DRIVERS, CERTIFICATIONS & SAFETY DOMAIN

CREATE TABLE Drivers (
    DriverID                 SERIAL       PRIMARY KEY,
    FirstName                VARCHAR(80)  NOT NULL,
    LastName                 VARCHAR(80)  NOT NULL,
    ContactInformation       VARCHAR(255),
    DepotID                  INT          NOT NULL,
    LicenceType              VARCHAR(50)  NOT NULL,
    LicenceExpiryDate        DATE         NOT NULL,
    EmploymentStatus         VARCHAR(30)  NOT NULL DEFAULT 'Active',
    EmergencyContactDetails  VARCHAR(255),
    CONSTRAINT fk_drivers_depot
        FOREIGN KEY (DepotID) REFERENCES Depots(DepotID)
);

CREATE TABLE VehicleAssignments (
    AssignmentID  SERIAL  PRIMARY KEY,
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
    CertTypeID  SERIAL       PRIMARY KEY,
    Name        VARCHAR(150) NOT NULL UNIQUE,
    Expire      BOOLEAN      NOT NULL DEFAULT TRUE
);

-- Defines which certifications each vehicle category requires
CREATE TABLE VehicleCertRequirement (
    ReqID        SERIAL                 PRIMARY KEY,
    VehicleType  vehicle_category_enum  NOT NULL,
    CertTypeID   INT                    NOT NULL,
    CONSTRAINT fk_vcr_certtype FOREIGN KEY (CertTypeID) REFERENCES CertificationType(CertTypeID),
    CONSTRAINT uq_vcr UNIQUE (VehicleType, CertTypeID)
);

CREATE TABLE DriverCertifications (
    DriverCertID  SERIAL PRIMARY KEY,
    DriverID      INT    NOT NULL,
    CertTypeID    INT    NOT NULL,
    IssueDate     DATE   NOT NULL,
    ExpireDate    DATE,
    CONSTRAINT fk_dc_driver   FOREIGN KEY (DriverID)   REFERENCES Drivers(DriverID),
    CONSTRAINT fk_dc_certtype FOREIGN KEY (CertTypeID) REFERENCES CertificationType(CertTypeID),
    CONSTRAINT chk_dc_dates   CHECK (ExpireDate IS NULL OR ExpireDate >= IssueDate)
);

CREATE TABLE CoachingRecord (
    CoachingID     SERIAL       PRIMARY KEY,
    DriverID       INT          NOT NULL,
    Reason         VARCHAR(255),
    ScheduledDate  DATE         NOT NULL,
    CompleteDate   DATE,
    Outcome        VARCHAR(255),
    CONSTRAINT fk_cr_driver FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID)
);

CREATE TABLE DriverSafetyScore (
    ScoreID          SERIAL  PRIMARY KEY,
    DriverID         INT     NOT NULL,
    BaseScore        INT     NOT NULL DEFAULT 100,
    DeductedPoints   INT     NOT NULL DEFAULT 0,
    FinalScore       INT     NOT NULL,
    CoachingRequired BOOLEAN NOT NULL DEFAULT FALSE,
    Suspended        BOOLEAN NOT NULL DEFAULT FALSE,
    CONSTRAINT fk_dss_driver FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID)
);

CREATE TABLE SafetyEventsType (
    EventsTypeID    SERIAL         PRIMARY KEY,
    Name            VARCHAR(100)   NOT NULL UNIQUE,
    DefaultSeverity severity_enum  NOT NULL
);

CREATE TABLE SafetyEvents (
    EventID        SERIAL         PRIMARY KEY,
    Timestamp      TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    VehicleID      INT            NOT NULL,
    DriverID       INT            NOT NULL,
    EventsTypeID   INT            NOT NULL,
    Severity       severity_enum  NOT NULL,
    DepotID        INT            NOT NULL,
    Odometer       INT            CHECK (Odometer >= 0),
    ReviewRequired BOOLEAN        NOT NULL DEFAULT FALSE,
    ReviewStatus   VARCHAR(30),
    CONSTRAINT fk_se_vehicle   FOREIGN KEY (VehicleID)    REFERENCES Vehicles(VehicleID),
    CONSTRAINT fk_se_driver    FOREIGN KEY (DriverID)     REFERENCES Drivers(DriverID),
    CONSTRAINT fk_se_eventtype FOREIGN KEY (EventsTypeID) REFERENCES SafetyEventsType(EventsTypeID),
    CONSTRAINT fk_se_depot     FOREIGN KEY (DepotID)      REFERENCES Depots(DepotID)
);


-- MAINTENANCE DOMAIN

CREATE TABLE PredictiveAlert (
    AlertID      SERIAL         PRIMARY KEY,
    VehicleID    INT            NOT NULL,
    AlertType    VARCHAR(100)   NOT NULL,
    Severity     severity_enum  NOT NULL,
    GeneratedAt  TIMESTAMP      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Status       VARCHAR(30)    NOT NULL DEFAULT 'Open',
    ResolvedAt   TIMESTAMP,
    CONSTRAINT fk_pa_vehicle FOREIGN KEY (VehicleID) REFERENCES Vehicles(VehicleID)
);

CREATE TABLE MaintenanceJobs (
    JobID            SERIAL  PRIMARY KEY,
    VehicleID        INT     NOT NULL,
    WorkshopID       INT     NOT NULL,
    DateOpened       DATE    NOT NULL,
    DateClosed       DATE,
    OverallDowntime  INT,                       -- in hours or minutes per business rule
    TotalCost        NUMERIC(12,2) DEFAULT 0,
    AlertID          INT,                       -- optional: job triggered by an alert
    CONSTRAINT fk_mj_vehicle  FOREIGN KEY (VehicleID)  REFERENCES Vehicles(VehicleID),
    CONSTRAINT fk_mj_workshop FOREIGN KEY (WorkshopID) REFERENCES Workshop(WorkshopID),
    CONSTRAINT fk_mj_alert    FOREIGN KEY (AlertID)    REFERENCES PredictiveAlert(AlertID),
    CONSTRAINT chk_mj_dates   CHECK (DateClosed IS NULL OR DateClosed >= DateOpened)
);

CREATE TABLE ActivityType (
    ActivityTypeID  SERIAL       PRIMARY KEY,
    Name            VARCHAR(150) NOT NULL UNIQUE,
    MecCertTypeID   INT          NOT NULL,      -- required mechanic certification
    CONSTRAINT fk_at_certtype
        FOREIGN KEY (MecCertTypeID) REFERENCES MechanicCertType(MecCertTypeID)
);

CREATE TABLE MaintenanceActivity (
    ActivityID         SERIAL    PRIMARY KEY,
    JobID              INT       NOT NULL,
    ActivityType       INT       NOT NULL,      -- FK to ActivityType.ActivityTypeID
    DiagnosticResult   TEXT,
    IsRepeatFault      BOOLEAN   NOT NULL DEFAULT FALSE,
    WarrantyIndicator  BOOLEAN   NOT NULL DEFAULT FALSE,
    StartedAt          TIMESTAMP,
    CompleteAt         TIMESTAMP,
    CONSTRAINT fk_ma_job  FOREIGN KEY (JobID)        REFERENCES MaintenanceJobs(JobID),
    CONSTRAINT fk_ma_type FOREIGN KEY (ActivityType) REFERENCES ActivityType(ActivityTypeID),
    CONSTRAINT chk_ma_times
        CHECK (CompleteAt IS NULL OR StartedAt IS NULL OR CompleteAt >= StartedAt)
);

-- Junction: which mechanics worked on which activity (and for how long)
CREATE TABLE ActivityMechanic (
    AssignmentID  SERIAL        PRIMARY KEY,
    ActivityID    INT           NOT NULL,
    MechanicID    INT           NOT NULL,
    LabourHours   NUMERIC(6,2)  NOT NULL DEFAULT 0 CHECK (LabourHours >= 0),
    CONSTRAINT fk_am_activity FOREIGN KEY (ActivityID) REFERENCES MaintenanceActivity(ActivityID),
    CONSTRAINT fk_am_mechanic FOREIGN KEY (MechanicID) REFERENCES Mechanic(MechanicID),
    CONSTRAINT uq_am UNIQUE (ActivityID, MechanicID)
);


-- Helpful indexes for common lookups
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