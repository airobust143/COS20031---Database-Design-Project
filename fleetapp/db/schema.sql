-- =====================================================================
-- Smart Fleet Management Database — SQLite build
-- Converted from the MySQL 8.0 physical schema (COS20031 Group 4)
-- for use as a self-contained demo database behind the PHP admin GUI.
--
-- Conversion notes:
--   * INT UNSIGNED AUTO_INCREMENT -> INTEGER PRIMARY KEY AUTOINCREMENT
--   * ENUM(...)                   -> TEXT + CHECK (...) constraint
--   * BOOLEAN                     -> INTEGER (0/1)
--   * DATE / DATETIME / YEAR      -> TEXT (ISO 8601 strings)
--   * DECIMAL(p,s)                -> NUMERIC
--   * MySQL-only clauses (ENGINE, CHARSET, COMMENT) removed
--   * Foreign key actions preserved (RESTRICT / SET NULL / CASCADE)
-- =====================================================================

PRAGMA foreign_keys = ON;

-- =====================================================================
-- DOMAIN: CORE FLEET
-- =====================================================================

CREATE TABLE Depots (
    DepotID      INTEGER PRIMARY KEY AUTOINCREMENT,
    City         TEXT NOT NULL,
    Address      TEXT NOT NULL,
    Name         TEXT NOT NULL UNIQUE,
    ContactPhone TEXT
);

CREATE TABLE VehiclesCategory (
    CategoryID   INTEGER PRIMARY KEY AUTOINCREMENT,
    CategoryName TEXT NOT NULL UNIQUE
);

CREATE TABLE CertificationType (
    CertTypeID INTEGER PRIMARY KEY AUTOINCREMENT,
    Name       TEXT NOT NULL UNIQUE,
    Expire     INTEGER NOT NULL DEFAULT 1 CHECK (Expire IN (0,1))
);

CREATE TABLE SafetyEventsType (
    EventsTypeID    INTEGER PRIMARY KEY AUTOINCREMENT,
    Name            TEXT NOT NULL UNIQUE,
    DefaultSeverity TEXT NOT NULL CHECK (DefaultSeverity IN ('Low','Medium','High','Critical'))
);

CREATE TABLE MechanicCertType (
    MecCertTypeID INTEGER PRIMARY KEY AUTOINCREMENT,
    Name          TEXT NOT NULL UNIQUE,
    Expire        INTEGER NOT NULL DEFAULT 1 CHECK (Expire IN (0,1))
);

CREATE TABLE ActivityType (
    ActivityTypeID INTEGER PRIMARY KEY AUTOINCREMENT,
    Name           TEXT NOT NULL UNIQUE,
    MecCertTypeID  INTEGER NOT NULL,
    FOREIGN KEY (MecCertTypeID) REFERENCES MechanicCertType(MecCertTypeID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Vehicles (
    VehicleID              INTEGER PRIMARY KEY AUTOINCREMENT,
    RegistrationNumber     TEXT NOT NULL UNIQUE,
    CategoryID             INTEGER NOT NULL,
    Model                  TEXT NOT NULL,
    Manufacturer           TEXT NOT NULL,
    YearOfManufacture      TEXT NOT NULL,
    CurrentOdometerReading INTEGER NOT NULL DEFAULT 0,
    DepotID                INTEGER NOT NULL,
    OperationalStatus      TEXT NOT NULL DEFAULT 'Available'
        CHECK (OperationalStatus IN ('Active','Available','Under Maintenance','Awaiting Inspection','Out of Service','Retired')),
    FOREIGN KEY (CategoryID) REFERENCES VehiclesCategory(CategoryID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (DepotID) REFERENCES Depots(DepotID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE VehiclesDepotHistory (
    HistoryID  INTEGER PRIMARY KEY AUTOINCREMENT,
    VehicleID  INTEGER NOT NULL,
    DepotID    INTEGER NOT NULL,
    MovedFrom  TEXT NOT NULL,
    MovedTo    TEXT,
    CHECK (MovedTo IS NULL OR MovedTo >= MovedFrom),
    FOREIGN KEY (VehicleID) REFERENCES Vehicles(VehicleID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (DepotID) REFERENCES Depots(DepotID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Drivers (
    DriverID                 INTEGER PRIMARY KEY AUTOINCREMENT,
    FirstName                TEXT NOT NULL,
    LastName                 TEXT NOT NULL,
    ContactInformation       TEXT,
    DepotID                  INTEGER NOT NULL,
    LicenceType              TEXT NOT NULL,
    LicenceExpiryDate        TEXT NOT NULL,
    EmploymentStatus         TEXT NOT NULL DEFAULT 'Active'
        CHECK (EmploymentStatus IN ('Active','Inactive','Suspended','Terminated')),
    EmergencyContactDetails  TEXT,
    FOREIGN KEY (DepotID) REFERENCES Depots(DepotID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE VehicleAssignments (
    AssignmentID INTEGER PRIMARY KEY AUTOINCREMENT,
    VehicleID    INTEGER NOT NULL,
    DriverID     INTEGER NOT NULL,
    StartDate    TEXT NOT NULL,
    EndDate      TEXT,
    IsPermanent  INTEGER NOT NULL DEFAULT 0 CHECK (IsPermanent IN (0,1)),
    DepotID      INTEGER NOT NULL,
    CHECK (EndDate IS NULL OR EndDate >= StartDate),
    FOREIGN KEY (VehicleID) REFERENCES Vehicles(VehicleID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (DepotID) REFERENCES Depots(DepotID) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- =====================================================================
-- DOMAIN: DRIVER & SAFETY
-- =====================================================================

CREATE TABLE DriverCertifications (
    DriverCertID INTEGER PRIMARY KEY AUTOINCREMENT,
    DriverID     INTEGER NOT NULL,
    CertTypeID   INTEGER NOT NULL,
    IssueDate    TEXT NOT NULL,
    ExpireDate   TEXT,
    CHECK (ExpireDate IS NULL OR ExpireDate >= IssueDate),
    FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (CertTypeID) REFERENCES CertificationType(CertTypeID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE VehicleCertRequirement (
    ReqID      INTEGER PRIMARY KEY AUTOINCREMENT,
    CategoryID INTEGER NOT NULL,
    CertTypeID INTEGER NOT NULL,
    UNIQUE (CategoryID, CertTypeID),
    FOREIGN KEY (CategoryID) REFERENCES VehiclesCategory(CategoryID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (CertTypeID) REFERENCES CertificationType(CertTypeID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE DriverSafetyScore (
    ScoreID          INTEGER PRIMARY KEY AUTOINCREMENT,
    DriverID         INTEGER NOT NULL,
    ScorePeriod      TEXT NOT NULL,
    BaseScore        INTEGER NOT NULL DEFAULT 100,
    DeductedPoints   INTEGER NOT NULL DEFAULT 0,
    FinalScore       INTEGER NOT NULL DEFAULT 100,
    CoachingRequired INTEGER NOT NULL DEFAULT 0 CHECK (CoachingRequired IN (0,1)),
    Suspended        INTEGER NOT NULL DEFAULT 0 CHECK (Suspended IN (0,1)),
    LowCount         INTEGER NOT NULL DEFAULT 0,
    MediumCount      INTEGER NOT NULL DEFAULT 0,
    HighCount        INTEGER NOT NULL DEFAULT 0,
    CriticalCount    INTEGER NOT NULL DEFAULT 0,
    UNIQUE (DriverID, ScorePeriod),
    FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE SafetyEvents (
    EventID       INTEGER PRIMARY KEY AUTOINCREMENT,
    Timestamp     TEXT NOT NULL,
    VehicleID     INTEGER NOT NULL,
    DriverID      INTEGER NOT NULL,
    EventsTypeID  INTEGER NOT NULL,
    Severity      TEXT NOT NULL CHECK (Severity IN ('Low','Medium','High','Critical')),
    DepotID       INTEGER NOT NULL,
    Odometer      INTEGER NOT NULL,
    ReviewRequired INTEGER NOT NULL DEFAULT 0 CHECK (ReviewRequired IN (0,1)),
    ReviewStatus  TEXT NOT NULL DEFAULT 'Not Required'
        CHECK (ReviewStatus IN ('Not Required','Pending','In Review','Completed')),
    FOREIGN KEY (VehicleID) REFERENCES Vehicles(VehicleID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (EventsTypeID) REFERENCES SafetyEventsType(EventsTypeID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (DepotID) REFERENCES Depots(DepotID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE CoachingRecord (
    CoachingID    INTEGER PRIMARY KEY AUTOINCREMENT,
    DriverID      INTEGER NOT NULL,
    Reason        TEXT NOT NULL,
    ScheduledDate TEXT NOT NULL,
    CompleteDate  TEXT,
    Outcome       TEXT NOT NULL DEFAULT 'Pending' CHECK (Outcome IN ('Pending','Passed','Failed','Cancelled')),
    RecordType    TEXT NOT NULL CHECK (RecordType IN ('Low Safety Score','Repeated High-Severity Incidents','Critical Event','Other')),
    EventID       INTEGER,
    ScoreID       INTEGER,
    CHECK (CompleteDate IS NULL OR CompleteDate >= ScheduledDate),
    FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (EventID) REFERENCES SafetyEvents(EventID) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (ScoreID) REFERENCES DriverSafetyScore(ScoreID) ON DELETE SET NULL ON UPDATE CASCADE
);

-- =====================================================================
-- DOMAIN: WORKSHOPS & PEOPLE
-- =====================================================================

CREATE TABLE Workshop (
    WorkshopID INTEGER PRIMARY KEY AUTOINCREMENT,
    DepotID    INTEGER NOT NULL UNIQUE,
    Name       TEXT NOT NULL,
    NumBays    INTEGER NOT NULL DEFAULT 1,
    Contacts   TEXT,
    FOREIGN KEY (DepotID) REFERENCES Depots(DepotID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE Mechanic (
    MechanicID       INTEGER PRIMARY KEY AUTOINCREMENT,
    FirstName        TEXT NOT NULL,
    LastName         TEXT NOT NULL,
    WorkshopID       INTEGER NOT NULL,
    EmploymentStatus TEXT NOT NULL DEFAULT 'Active'
        CHECK (EmploymentStatus IN ('Active','Inactive','Suspended','Terminated')),
    FOREIGN KEY (WorkshopID) REFERENCES Workshop(WorkshopID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE MechanicCertification (
    MecCertID     INTEGER PRIMARY KEY AUTOINCREMENT,
    MechanicID    INTEGER NOT NULL,
    MecCertTypeID INTEGER NOT NULL,
    IssueDate     TEXT NOT NULL,
    ExpireDate    TEXT,
    CHECK (ExpireDate IS NULL OR ExpireDate >= IssueDate),
    FOREIGN KEY (MechanicID) REFERENCES Mechanic(MechanicID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (MecCertTypeID) REFERENCES MechanicCertType(MecCertTypeID) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- =====================================================================
-- DOMAIN: MAINTENANCE
-- =====================================================================

CREATE TABLE PredictiveAlert (
    AlertID     INTEGER PRIMARY KEY AUTOINCREMENT,
    VehicleID   INTEGER NOT NULL,
    AlertType   TEXT NOT NULL CHECK (AlertType IN (
        'Brake Wear Warning','Engine Overheating Risk','Battery Degradation',
        'Oil Quality Deterioration','Transmission Fault Warning',
        'Cooling System Anomaly','Tyre Pressure Irregularity','Other')),
    Severity    TEXT NOT NULL CHECK (Severity IN ('Low','Medium','High','Critical')),
    GeneratedAt TEXT NOT NULL,
    Status      TEXT NOT NULL DEFAULT 'New' CHECK (Status IN ('New','Acknowledged','Scheduled','Escalated','Resolved')),
    ResolvedAt  TEXT,
    CHECK (ResolvedAt IS NULL OR ResolvedAt >= GeneratedAt),
    FOREIGN KEY (VehicleID) REFERENCES Vehicles(VehicleID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE MaintenanceJobs (
    JobID           INTEGER PRIMARY KEY AUTOINCREMENT,
    VehicleID       INTEGER NOT NULL,
    WorkshopID      INTEGER NOT NULL,
    DateOpened      TEXT NOT NULL,
    DateClosed      TEXT,
    OverallDowntime NUMERIC,
    TotalCost       NUMERIC,
    AlertID         INTEGER UNIQUE,
    CHECK (DateClosed IS NULL OR DateClosed >= DateOpened),
    FOREIGN KEY (VehicleID) REFERENCES Vehicles(VehicleID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (WorkshopID) REFERENCES Workshop(WorkshopID) ON DELETE RESTRICT ON UPDATE CASCADE,
    FOREIGN KEY (AlertID) REFERENCES PredictiveAlert(AlertID) ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE MaintenanceActivity (
    ActivityID       INTEGER PRIMARY KEY AUTOINCREMENT,
    JobID            INTEGER NOT NULL,
    ActivityTypeID   INTEGER NOT NULL,
    DiagnosticResult TEXT,
    IsRepeatFault    INTEGER NOT NULL DEFAULT 0 CHECK (IsRepeatFault IN (0,1)),
    StartedAt        TEXT NOT NULL,
    CompleteAt       TEXT,
    CHECK (CompleteAt IS NULL OR CompleteAt >= StartedAt),
    FOREIGN KEY (JobID) REFERENCES MaintenanceJobs(JobID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (ActivityTypeID) REFERENCES ActivityType(ActivityTypeID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE WarrantyClaim (
    ClaimID      INTEGER PRIMARY KEY AUTOINCREMENT,
    ActivityID   INTEGER NOT NULL,
    WarrantyType TEXT NOT NULL CHECK (WarrantyType IN ('Manufacturer','Supplier')),
    Status       TEXT NOT NULL DEFAULT 'Submitted' CHECK (Status IN ('Submitted','Approved','Rejected','Completed')),
    ClaimDate    TEXT NOT NULL,
    FOREIGN KEY (ActivityID) REFERENCES MaintenanceActivity(ActivityID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Part (
    PartID      INTEGER PRIMARY KEY AUTOINCREMENT,
    PartNumber  TEXT NOT NULL UNIQUE,
    Description TEXT,
    UnitPrice   NUMERIC NOT NULL DEFAULT 0.00
);

CREATE TABLE Supplier (
    SupplierID   INTEGER PRIMARY KEY AUTOINCREMENT,
    Name         TEXT NOT NULL,
    ContactInfo  TEXT,
    LeadTimeDays INTEGER
);

CREATE TABLE SupplyPart (
    PartID     INTEGER NOT NULL,
    SupplierID INTEGER NOT NULL,
    UnitCost   NUMERIC NOT NULL,
    IsPrimary  INTEGER NOT NULL DEFAULT 0 CHECK (IsPrimary IN (0,1)),
    PRIMARY KEY (PartID, SupplierID),
    FOREIGN KEY (PartID) REFERENCES Part(PartID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (SupplierID) REFERENCES Supplier(SupplierID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE ActivityPart (
    ActivityID      INTEGER NOT NULL,
    PartID          INTEGER NOT NULL,
    QuantityUsed    INTEGER NOT NULL DEFAULT 1,
    UnitPriceAtTime NUMERIC NOT NULL,
    PRIMARY KEY (ActivityID, PartID),
    FOREIGN KEY (ActivityID) REFERENCES MaintenanceActivity(ActivityID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (PartID) REFERENCES Part(PartID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE WarrantyClaimPart (
    ClaimID INTEGER NOT NULL,
    PartID  INTEGER NOT NULL,
    PRIMARY KEY (ClaimID, PartID),
    FOREIGN KEY (ClaimID) REFERENCES WarrantyClaim(ClaimID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (PartID) REFERENCES Part(PartID) ON DELETE RESTRICT ON UPDATE CASCADE
);

CREATE TABLE ActivityMechanic (
    ActivityID  INTEGER NOT NULL,
    MechanicID  INTEGER NOT NULL,
    LabourHours NUMERIC NOT NULL DEFAULT 0.00,
    PRIMARY KEY (ActivityID, MechanicID),
    FOREIGN KEY (ActivityID) REFERENCES MaintenanceActivity(ActivityID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (MechanicID) REFERENCES Mechanic(MechanicID) ON DELETE RESTRICT ON UPDATE CASCADE
);

-- =====================================================================
-- DOMAIN: USER ROLE
-- =====================================================================

CREATE TABLE UserAccount (
    UserID       INTEGER PRIMARY KEY AUTOINCREMENT,
    Username     TEXT NOT NULL UNIQUE,
    PasswordHash TEXT NOT NULL,
    IsActive     INTEGER NOT NULL DEFAULT 1 CHECK (IsActive IN (0,1)),
    DriverID     INTEGER UNIQUE,
    MechanicID   INTEGER UNIQUE,
    DepotID      INTEGER,
    FOREIGN KEY (DriverID) REFERENCES Drivers(DriverID) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (MechanicID) REFERENCES Mechanic(MechanicID) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (DepotID) REFERENCES Depots(DepotID) ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE TABLE Role (
    RoleID   INTEGER PRIMARY KEY AUTOINCREMENT,
    RoleName TEXT NOT NULL UNIQUE
);

CREATE TABLE Permission (
    PermissionID INTEGER PRIMARY KEY AUTOINCREMENT,
    TableName    TEXT NOT NULL,
    Action       TEXT NOT NULL CHECK (Action IN ('SELECT','INSERT','UPDATE','DELETE','ALL')),
    UNIQUE (TableName, Action)
);

CREATE TABLE UserRole (
    UserID      INTEGER NOT NULL,
    RoleID      INTEGER NOT NULL,
    GrantedDate TEXT NOT NULL,
    PRIMARY KEY (UserID, RoleID),
    FOREIGN KEY (UserID) REFERENCES UserAccount(UserID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (RoleID) REFERENCES Role(RoleID) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE RolePermission (
    RoleID       INTEGER NOT NULL,
    PermissionID INTEGER NOT NULL,
    PRIMARY KEY (RoleID, PermissionID),
    FOREIGN KEY (RoleID) REFERENCES Role(RoleID) ON DELETE CASCADE ON UPDATE CASCADE,
    FOREIGN KEY (PermissionID) REFERENCES Permission(PermissionID) ON DELETE CASCADE ON UPDATE CASCADE
);
