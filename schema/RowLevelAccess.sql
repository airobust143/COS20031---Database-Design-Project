USE `smart_fleet_management`;

-- =====================================================================
-- PART C — ROW-LEVEL ACCESS FOR DRIVERS (MySQL has no native RLS)
-- =====================================================================
-- A driver should see ONLY their own rows. We expose views that filter by
-- the MySQL account name, then grant the driver role SELECT on the views
-- (never on the base tables). Assumes UserAccount.Username matches the
-- MySQL login (adjust the join to your own convention).

CREATE OR REPLACE VIEW `v_my_safety_events` AS
SELECT se.*
FROM `SafetyEvents` se
JOIN `Drivers` d      ON d.DriverID = se.DriverID
JOIN `UserAccount` ua ON ua.DriverID = d.DriverID
WHERE ua.Username = SUBSTRING_INDEX(CURRENT_USER(), '@', 1);

CREATE OR REPLACE VIEW `v_my_safety_scores` AS
SELECT dss.*
FROM `DriverSafetyScore` dss
JOIN `UserAccount` ua ON ua.DriverID = dss.DriverID
WHERE ua.Username = SUBSTRING_INDEX(CURRENT_USER(), '@', 1);

GRANT SELECT ON `smart_fleet_management`.`v_my_safety_events` TO 'sf_driver';
GRANT SELECT ON `smart_fleet_management`.`v_my_safety_scores` TO 'sf_driver';

-- =====================================================================
-- Useful inspection commands
--   SHOW GRANTS FOR 'sf_safety_ops';
--   SHOW GRANTS FOR 'sam_safety'@'%' USING 'sf_safety_ops';
--   SELECT * FROM information_schema.role_table_grants
--     WHERE grantee LIKE '%sf_%';
-- =====================================================================
