USE `smart_fleet_management`;

-- =====================================================================
-- PART C — ROW-LEVEL ACCESS VIA VIEWS
-- =====================================================================
-- MySQL has no native row-level security. Views filtered by
-- CURRENT_USER() give per-row control WHEN people connect with their own
-- MySQL accounts. (If your app uses one shared connection, the app must
-- enforce these rules instead — see UserAccount linkage.)
-- Assumes UserAccount.Username == the MySQL login name.

-- ---- Drivers: OWN READS --------------------------------------------
CREATE OR REPLACE VIEW `v_my_safety_events` AS
SELECT se.EventID, se.Timestamp, se.VehicleID, se.EventsTypeID,
       se.Severity, se.DepotID, se.Odometer, se.ReviewStatus
FROM `SafetyEvents` se
JOIN `UserAccount` ua ON ua.DriverID = se.DriverID
WHERE ua.Username = SUBSTRING_INDEX(CURRENT_USER(), '@', 1);

CREATE OR REPLACE VIEW `v_my_safety_scores` AS
SELECT dss.ScorePeriod, dss.BaseScore, dss.DeductedPoints, dss.FinalScore,
       dss.CoachingRequired, dss.Suspended
FROM `DriverSafetyScore` dss
JOIN `UserAccount` ua ON ua.DriverID = dss.DriverID
WHERE ua.Username = SUBSTRING_INDEX(CURRENT_USER(), '@', 1);

-- F6: drivers can check their own certification/licence expiries
CREATE OR REPLACE VIEW `v_my_certifications` AS
SELECT dc.DriverCertID, ct.Name AS Certification, dc.IssueDate, dc.ExpireDate
FROM `DriverCertifications` dc
JOIN `CertificationType` ct ON ct.CertTypeID = dc.CertTypeID
JOIN `UserAccount` ua       ON ua.DriverID = dc.DriverID
WHERE ua.Username = SUBSTRING_INDEX(CURRENT_USER(), '@', 1);

GRANT SELECT ON `smart_fleet_management`.`v_my_safety_events`  TO 'sf_driver';
GRANT SELECT ON `smart_fleet_management`.`v_my_safety_scores`  TO 'sf_driver';
GRANT SELECT ON `smart_fleet_management`.`v_my_certifications` TO 'sf_driver';

-- ---- Mechanics: OWN WRITES (F2) ------------------------------------
-- Reads stay broad (granted on base tables above); only writes are
-- funnelled through these filtered views.

CREATE OR REPLACE VIEW `v_my_labour` AS
SELECT am.ActivityID, am.MechanicID, am.LabourHours
FROM `ActivityMechanic` am
JOIN `UserAccount` ua ON ua.MechanicID = am.MechanicID
WHERE ua.Username = SUBSTRING_INDEX(CURRENT_USER(), '@', 1)
WITH CHECK OPTION;

CREATE OR REPLACE VIEW `v_my_activities` AS
SELECT ma.ActivityID, ma.JobID, ma.DiagnosticResult, ma.IsRepeatFault,
       ma.StartedAt, ma.CompleteAt
FROM `MaintenanceActivity` ma
JOIN `ActivityMechanic` am ON am.ActivityID = ma.ActivityID
JOIN `UserAccount` ua      ON ua.MechanicID = am.MechanicID
WHERE ua.Username = SUBSTRING_INDEX(CURRENT_USER(), '@', 1);

GRANT SELECT, UPDATE (`LabourHours`)
      ON `smart_fleet_management`.`v_my_labour` TO 'sf_mechanic';
GRANT SELECT, UPDATE (`DiagnosticResult`, `IsRepeatFault`, `StartedAt`, `CompleteAt`)
      ON `smart_fleet_management`.`v_my_activities` TO 'sf_mechanic';

-- =====================================================================
-- Verification:
--   SHOW GRANTS FOR 'sf_safety_ops';
--   SHOW GRANTS FOR 'sam_safety'@'%' USING 'sf_safety_ops';
-- =====================================================================

