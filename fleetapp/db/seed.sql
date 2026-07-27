PRAGMA foreign_keys = ON;

-- Depots
INSERT INTO Depots (City, Address, Name, ContactPhone) VALUES
('Ha Noi', '12 Lang Ha, Dong Da', 'Ha Noi Central', '024-3822-1100'),
('Da Nang', '45 Nguyen Van Linh', 'Da Nang Depot', '0236-3899-200'),
('Ho Chi Minh City', '88 Cach Mang Thang Tam, D3', 'HCMC South', '028-3930-4400'),
('Can Tho', '19 30 Thang 4', 'Can Tho Depot', '0292-3812-300');

-- Vehicle categories
INSERT INTO VehiclesCategory (CategoryName) VALUES
('Delivery Van'), ('Refrigerated Truck'), ('Electric Van'), ('Service Vehicle'), ('Heavy Transport Truck');

-- Certification types (driver)
INSERT INTO CertificationType (Name, Expire) VALUES
('Standard Licence', 1),
('Heavy Vehicle Licence', 1),
('Refrigerated Transport Certification', 1),
('EV Certification', 1),
('Hazardous Goods Certification', 1);

-- Vehicle certification matrix
INSERT INTO VehicleCertRequirement (CategoryID, CertTypeID) VALUES
(1,1),
(2,1),(2,2),(2,3),
(3,1),(3,4),
(4,1),
(5,2),(5,5);

-- Safety event types
INSERT INTO SafetyEventsType (Name, DefaultSeverity) VALUES
('Harsh Braking','Low'),
('Rapid Acceleration','Low'),
('Excessive Speeding','High'),
('Sharp Cornering','Medium'),
('Excessive Idling','Low'),
('Fatigue Warning','High'),
('Seatbelt Violation','Medium'),
('Phone Distraction Alert','Medium');

-- Mechanic certification types
INSERT INTO MechanicCertType (Name, Expire) VALUES
('Standard Vehicle Mechanic Licence', 1),
('EV Technician Certification', 1),
('Refrigeration Systems Certification', 1),
('Heavy Vehicle Mechanic Licence', 1);

-- Activity types
INSERT INTO ActivityType (Name, MecCertTypeID) VALUES
('Routine Inspection', 1),
('Preventative Servicing', 1),
('Diagnostic Testing', 1),
('Emergency Repair', 1),
('Component Replacement', 1),
('EV Battery / Electrical Repair', 2),
('Refrigeration System Repair', 3),
('Heavy Vehicle Repair', 4),
('Brake Service', 1),
('Tyre Replacement', 1);

-- Vehicles
INSERT INTO Vehicles (RegistrationNumber, CategoryID, Model, Manufacturer, YearOfManufacture, CurrentOdometerReading, DepotID, OperationalStatus) VALUES
('29A-123.45', 1, 'Canter', 'Mitsubishi Fuso', '2021', 45310, 1, 'Active'),
('51C-789.01', 2, 'NPR', 'Isuzu', '2020', 112480, 3, 'Under Maintenance'),
('43E-456.78', 3, 'eCanter', 'Mitsubishi Fuso', '2023', 12300, 2, 'Available'),
('92B-101.22', 4, 'Hilux', 'Toyota', '2019', 88210, 4, 'Available'),
('29H-556.10', 5, 'FH16', 'Volvo', '2018', 210500, 1, 'Awaiting Inspection');

-- Drivers
INSERT INTO Drivers (FirstName, LastName, ContactInformation, DepotID, LicenceType, LicenceExpiryDate, EmploymentStatus, EmergencyContactDetails) VALUES
('Van An', 'Nguyen', '0912-345-678', 1, 'B2', '2027-02-14', 'Active', 'Nguyen Thi Hoa - 0987-654-321'),
('Thi Bich', 'Tran', '0934-567-890', 3, 'C', '2028-05-20', 'Active', 'Tran Van Hai - 0977-111-222'),
('Quoc Minh', 'Le', '0977-888-999', 1, 'B2', '2027-06-21', 'Active', 'Le Thi Mai - 0966-333-444'),
('Duc Long', 'Pham', '0988-222-333', 4, 'C', '2026-11-18', 'Active', 'Pham Van Tam - 0955-777-888');

-- Driver certifications
INSERT INTO DriverCertifications (DriverID, CertTypeID, IssueDate, ExpireDate) VALUES
(1, 1, '2023-02-14', '2025-02-14'),
(1, 4, '2023-04-30', '2025-04-30'),
(2, 2, '2023-12-08', '2025-12-08'),
(2, 3, '2024-05-01', '2026-05-01'),
(3, 1, '2024-06-21', '2026-06-21'),
(4, 5, '2024-11-18', '2026-11-18');

-- Vehicle assignments
INSERT INTO VehicleAssignments (VehicleID, DriverID, StartDate, EndDate, IsPermanent, DepotID) VALUES
(1, 1, '2024-01-10', NULL, 1, 1),
(3, 1, '2024-06-01', NULL, 0, 2),
(2, 2, '2023-09-01', NULL, 1, 3),
(4, 4, '2023-03-15', NULL, 1, 4);

-- Driver safety scores
INSERT INTO DriverSafetyScore (DriverID, ScorePeriod, BaseScore, DeductedPoints, FinalScore, CoachingRequired, Suspended, LowCount, MediumCount, HighCount, CriticalCount) VALUES
(1, '2024-05', 100, 32, 68, 1, 0, 2, 0, 2, 0),
(2, '2024-05', 100, 20, 80, 0, 1, 0, 1, 0, 1),
(3, '2024-05', 100, 2, 98, 0, 0, 1, 0, 0, 0);

-- Safety events (from the example log in the brief)
INSERT INTO SafetyEvents (Timestamp, VehicleID, DriverID, EventsTypeID, Severity, DepotID, Odometer, ReviewRequired, ReviewStatus) VALUES
('2024-05-10 08:14:00', 1, 1, 1, 'Low', 1, 45100, 0, 'Not Required'),
('2024-05-10 09:30:00', 1, 1, 3, 'High', 1, 45140, 1, 'Pending'),
('2024-05-11 11:00:00', 2, 2, 4, 'Medium', 3, 112050, 0, 'Not Required'),
('2024-05-12 14:20:00', 3, 1, 6, 'High', 2, 12300, 1, 'Pending'),
('2024-05-13 07:42:00', 1, 3, 5, 'Low', 1, 45310, 0, 'Not Required'),
('2024-05-13 18:05:00', 2, 2, 3, 'Critical', 3, 112480, 1, 'In Review');

-- Coaching records
INSERT INTO CoachingRecord (DriverID, Reason, ScheduledDate, CompleteDate, Outcome, RecordType, EventID, ScoreID) VALUES
(1, 'Monthly safety score at 68 - below 75 threshold', '2024-06-05', NULL, 'Pending', 'Low Safety Score', NULL, 1),
(2, 'Critical speeding event recorded', '2024-05-20', '2024-05-22', 'Passed', 'Critical Event', 6, 2);

-- Workshops (one per depot)
INSERT INTO Workshop (DepotID, Name, NumBays, Contacts) VALUES
(1, 'Ha Noi Central Workshop', 4, 'workshop.hn@fleet.vn'),
(2, 'Da Nang Workshop', 2, 'workshop.dn@fleet.vn'),
(3, 'HCMC South Workshop', 5, 'workshop.hcmc@fleet.vn'),
(4, 'Can Tho Workshop', 2, 'workshop.ct@fleet.vn');

-- Mechanics
INSERT INTO Mechanic (FirstName, LastName, WorkshopID, EmploymentStatus) VALUES
('Van Duc', 'Hoang', 1, 'Active'),
('Thi Lan', 'Pham', 1, 'Active'),
('Thi Mai', 'Nguyen', 3, 'Active'),
('Quoc Bao', 'Tran', 3, 'Active');

-- Mechanic certifications
INSERT INTO MechanicCertification (MechanicID, MecCertTypeID, IssueDate, ExpireDate) VALUES
(1, 1, '2022-01-10', '2026-01-10'),
(2, 1, '2022-03-15', '2026-03-15'),
(3, 1, '2021-07-01', '2025-07-01'),
(4, 3, '2023-02-01', '2027-02-01');

-- Predictive alerts
INSERT INTO PredictiveAlert (VehicleID, AlertType, Severity, GeneratedAt, Status, ResolvedAt) VALUES
(1, 'Brake Wear Warning', 'Medium', '2024-05-11 22:00:00', 'Scheduled', NULL),
(2, 'Cooling System Anomaly', 'High', '2024-05-13 20:00:00', 'Escalated', NULL);

-- Maintenance jobs (from the brief's example job table)
INSERT INTO MaintenanceJobs (VehicleID, WorkshopID, DateOpened, DateClosed, OverallDowntime, TotalCost, AlertID) VALUES
(1, 1, '2024-05-12 09:00:00', '2024-05-13 03:00:00', 18, 1800000, 1),
(2, 3, '2024-05-14 08:00:00', '2024-05-14 14:00:00', 6, 3610000, 2);

-- Maintenance activities (from the brief's example activity table)
INSERT INTO MaintenanceActivity (JobID, ActivityTypeID, DiagnosticResult, IsRepeatFault, StartedAt, CompleteAt) VALUES
(1, 9, 'Pads worn below 3mm', 0, '2024-05-12 09:15:00', '2024-05-12 11:45:00'),
(1, 10, 'Worn unevenly - possible alignment issue', 1, '2024-05-12 12:00:00', '2024-05-12 13:00:00'),
(2, 2, 'OK', 0, '2024-05-14 08:10:00', '2024-05-14 09:40:00'),
(2, 7, 'Belt cracked - 3rd replacement this year', 1, '2024-05-14 09:45:00', '2024-05-14 13:30:00');

-- Activity-Mechanic assignments
INSERT INTO ActivityMechanic (ActivityID, MechanicID, LabourHours) VALUES
(1, 1, 2.5),
(1, 2, 2.5),
(2, 1, 1.0),
(3, 3, 1.5),
(4, 4, 2.0);

-- Warranty claims
INSERT INTO WarrantyClaim (ActivityID, WarrantyType, Status, ClaimDate) VALUES
(4, 'Supplier', 'Submitted', '2024-05-14');

-- Parts
INSERT INTO Part (PartNumber, Description, UnitPrice) VALUES
('BRK-PAD-001', 'Front brake pad set', 450000),
('TYR-STD-205', '205/75R16 tyre', 1800000),
('BELT-RF-014', 'Refrigeration compressor belt', 620000);

-- Suppliers
INSERT INTO Supplier (Name, ContactInfo, LeadTimeDays) VALUES
('Viet Auto Parts Co.', 'sales@vietautoparts.vn', 3),
('Mekong Fleet Supplies', 'contact@mekongsupplies.vn', 5);

-- Supplier-Part links
INSERT INTO SupplyPart (PartID, SupplierID, UnitCost, IsPrimary) VALUES
(1, 1, 400000, 1),
(1, 2, 420000, 0),
(2, 1, 1700000, 1),
(3, 2, 590000, 1);

-- Activity parts consumed
INSERT INTO ActivityPart (ActivityID, PartID, QuantityUsed, UnitPriceAtTime) VALUES
(1, 1, 1, 450000),
(2, 2, 4, 1800000),
(4, 3, 1, 620000);

-- Warranty claim parts
INSERT INTO WarrantyClaimPart (ClaimID, PartID) VALUES
(1, 3);

-- Roles
INSERT INTO Role (RoleName) VALUES ('Fleet Safety Officer'), ('Workshop Manager'), ('Admin'), ('Driver'), ('Mechanic');

-- Permissions
INSERT INTO Permission (TableName, Action) VALUES
('SafetyEvents', 'ALL'),
('MaintenanceJobs', 'ALL'),
('Vehicles', 'SELECT');

-- Role-Permission
INSERT INTO RolePermission (RoleID, PermissionID) VALUES
(1, 1), (2, 2), (3, 1), (3, 2), (3, 3);

-- User accounts
INSERT INTO UserAccount (Username, PasswordHash, IsActive, DriverID, MechanicID, DepotID) VALUES
('admin', '$2y$10$abcdefghijklmnopqrstuv', 1, NULL, NULL, NULL),
('van.an', '$2y$10$abcdefghijklmnopqrstuv', 1, 1, NULL, 1),
('hoang.duc', '$2y$10$abcdefghijklmnopqrstuv', 1, NULL, 1, 1);

-- User roles
INSERT INTO UserRole (UserID, RoleID, GrantedDate) VALUES
(1, 3, '2023-01-01'),
(2, 4, '2023-01-10'),
(3, 5, '2023-01-10');

-- Vehicle depot history
INSERT INTO VehiclesDepotHistory (VehicleID, DepotID, MovedFrom, MovedTo) VALUES
(3, 1, '2023-01-01 00:00:00', '2024-06-01 00:00:00'),
(3, 2, '2024-06-01 00:00:00', NULL);
