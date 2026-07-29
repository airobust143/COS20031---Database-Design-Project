-- =====================================================================
-- Smart Fleet Management Database — REFERENCE / SEED DATA
-- COS20031 Group 4 — MySQL 8.0 / MariaDB 10.4+
-- File 6 of 7. Requires files 01–05 to have all been run.
-- =====================================================================
-- Populates lookup tables so the schema and triggers are immediately
-- testable. All values are taken directly from the project brief and
-- the ERD (Vehicle Certification Matrix, Event Penalties, Required
-- Mechanic Certification table) — nothing here is invented.
-- =====================================================================

USE `smart_fleet_management`;

-- ---------------------------------------------------------------------
-- Depots (placeholder addresses/contacts — replace with real data)
-- ---------------------------------------------------------------------
INSERT INTO `Depots` (`City`, `Address`, `Name`, `ContactPhone`) VALUES
    ('Ha Noi',           '123 Nguyen Trai, Thanh Xuan',        'Ha Noi Central',   '024-1111-2222'),
    ('Ho Chi Minh City', '45 Vo Van Kiet, District 5',         'HCMC South',       '028-3333-4444'),
    ('Da Nang',          '78 Nguyen Van Linh, Thanh Khe',      'Da Nang Depot',    '0236-555-666'),
    ('Can Tho',          '12 30 Thang 4, Ninh Kieu',           'Can Tho Depot',    '0292-777-888');

-- ---------------------------------------------------------------------
-- Workshop (one per depot — Workshop.DepotID is UNIQUE)
-- ---------------------------------------------------------------------
INSERT INTO `Workshop` (`DepotID`, `Name`, `NumBays`, `Contacts`)
SELECT `DepotID`, CONCAT(`Name`, ' Workshop'), 4, `ContactPhone`
FROM `Depots`;

-- ---------------------------------------------------------------------
-- VehiclesCategory (exact names from the Vehicle Certification Matrix)
-- ---------------------------------------------------------------------
INSERT INTO `VehiclesCategory` (`CategoryName`) VALUES
    ('Delivery Van'),
    ('Refrigerated Truck'),
    ('Electric Van'),
    ('Service Vehicle'),
    ('Heavy Transport Truck');

-- ---------------------------------------------------------------------
-- CertificationType (the five columns of the Vehicle Certification
-- Matrix — driver-held certifications)
-- ---------------------------------------------------------------------
INSERT INTO `CertificationType` (`Name`, `Expire`) VALUES
    ('Standard Licence',                    TRUE),
    ('Heavy Vehicle Licence',               TRUE),
    ('Refrigerated Transport Certification', TRUE),
    ('EV Certification',                    TRUE),
    ('Hazardous Goods Certification',       TRUE);

-- ---------------------------------------------------------------------
-- VehicleCertRequirement — the Vehicle Certification Matrix itself.
-- "To drive the following vehicles you need ALL the certifications
-- as follows":
--   Delivery Van          -> Standard Licence
--   Refrigerated Truck    -> Standard Licence, Heavy Vehicle Licence,
--                             Refrigerated Transport Certification
--   Electric Van          -> Standard Licence, EV Certification
--   Service Vehicle       -> Standard Licence
--   Heavy Transport Truck -> Heavy Vehicle Licence,
--                             Hazardous Goods Certification
-- ---------------------------------------------------------------------
INSERT INTO `VehicleCertRequirement` (`CategoryID`, `CertTypeID`)
SELECT vc.`CategoryID`, ct.`CertTypeID`
FROM `VehiclesCategory` vc
JOIN `CertificationType` ct
WHERE (vc.`CategoryName` = 'Delivery Van'          AND ct.`Name` = 'Standard Licence')
   OR (vc.`CategoryName` = 'Refrigerated Truck'     AND ct.`Name` IN ('Standard Licence','Heavy Vehicle Licence','Refrigerated Transport Certification'))
   OR (vc.`CategoryName` = 'Electric Van'           AND ct.`Name` IN ('Standard Licence','EV Certification'))
   OR (vc.`CategoryName` = 'Service Vehicle'        AND ct.`Name` = 'Standard Licence')
   OR (vc.`CategoryName` = 'Heavy Transport Truck'  AND ct.`Name` IN ('Heavy Vehicle Licence','Hazardous Goods Certification'));

-- ---------------------------------------------------------------------
-- SafetyEventsType — DefaultSeverity is a typical/starting value only;
-- the brief's own example log shows the same event type recorded at
-- different severities on different occasions, so SafetyEvents.Severity
-- is always what actually gets stored per event.
-- ---------------------------------------------------------------------
INSERT INTO `SafetyEventsType` (`Name`, `DefaultSeverity`) VALUES
    ('Harsh Braking',        'Low'),
    ('Rapid Acceleration',   'Low'),
    ('Excessive Speeding',   'High'),
    ('Sharp Cornering',      'Medium'),
    ('Excessive Idling',     'Low'),
    ('Fatigue Warning',      'High'),
    ('Seatbelt Violation',   'Medium'),
    ('Phone Distraction Alert', 'High');

-- ---------------------------------------------------------------------
-- EventPenalty — exact values from the brief's "Event Penalties" table
-- ---------------------------------------------------------------------
INSERT INTO `EventPenalty` (`Severity`, `PointsDeducted`, `Description`) VALUES
    ('Low',      -2,  NULL),
    ('Medium',   -5,  NULL),
    ('High',     -10, 'Also applied automatically: any Critical event in the month adds a further -10'),
    ('Critical', -20, NULL);

-- ---------------------------------------------------------------------
-- MechanicCertType
-- ---------------------------------------------------------------------
INSERT INTO `MechanicCertType` (`Name`, `Expire`) VALUES
    ('Standard Vehicle Mechanic Licence',   TRUE),
    ('EV Technician Certification',         TRUE),
    ('Refrigeration Systems Certification', TRUE),
    ('Heavy Vehicle Mechanic Licence',      TRUE);

-- ---------------------------------------------------------------------
-- ActivityType — exact mapping from the brief's "Required Mechanic
-- Certification" table
-- ---------------------------------------------------------------------
INSERT INTO `ActivityType` (`Name`, `MecCertTypeID`)
SELECT a.name, mct.`MecCertTypeID`
FROM (
    SELECT 'Routine Inspection' AS name, 'Standard Vehicle Mechanic Licence' AS cert
    UNION ALL SELECT 'Preventative Servicing',        'Standard Vehicle Mechanic Licence'
    UNION ALL SELECT 'Diagnostic Testing',             'Standard Vehicle Mechanic Licence'
    UNION ALL SELECT 'Emergency Repair',                'Standard Vehicle Mechanic Licence'
    UNION ALL SELECT 'Component Replacement',           'Standard Vehicle Mechanic Licence'
    UNION ALL SELECT 'EV Battery / Electrical Repair',  'EV Technician Certification'
    UNION ALL SELECT 'Refrigeration System Repair',     'Refrigeration Systems Certification'
    UNION ALL SELECT 'Heavy Vehicle Repair',            'Heavy Vehicle Mechanic Licence'
) a
JOIN `MechanicCertType` mct ON mct.`Name` = a.cert;

-- =====================================================================
-- End of 06_seed_reference_data.sql
-- =====================================================================
