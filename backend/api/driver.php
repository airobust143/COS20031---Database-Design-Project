<?php
/**
 * Driver API — read-only, own data only
 *
 * GET  ?resource=my_profile
 * GET  ?resource=my_events
 * GET  ?resource=my_scores
 * GET  ?resource=my_certifications
 * GET  ?resource=kpis
 */

require __DIR__ . '/_bootstrap.php';

$resource = $_GET['resource'] ?? '';

if ($_SERVER['REQUEST_METHOD'] !== 'GET') jsonErr('Read-only endpoint.', 405);

$driverId = (int)($SESSION_USER['driver_id'] ?? 0);
if (!$driverId) jsonErr('This account is not linked to a driver record.', 403);

// ── KPIs ─────────────────────────────────────────────────────────────
if ($resource === 'kpis') {
    requirePermission('DriverSafetyScore', 'SELECT');
    $score = $pdo->prepare("SELECT FinalScore,CoachingRequired,Suspended FROM DriverSafetyScore WHERE DriverID=:d ORDER BY ScorePeriod DESC LIMIT 1");
    $score->execute([':d'=>$driverId]);
    $latest = $score->fetch() ?: ['FinalScore'=>100,'CoachingRequired'=>0,'Suspended'=>0];

    $expiring = $pdo->prepare("SELECT COUNT(*) FROM DriverCertifications WHERE DriverID=:d AND ExpireDate BETWEEN CURDATE() AND DATE_ADD(CURDATE(),INTERVAL 60 DAY)");
    $expiring->execute([':d'=>$driverId]);

    $expired = $pdo->prepare("SELECT COUNT(*) FROM DriverCertifications WHERE DriverID=:d AND ExpireDate < CURDATE()");
    $expired->execute([':d'=>$driverId]);

    $eventCount = $pdo->prepare("SELECT COUNT(*) FROM SafetyEvents WHERE DriverID=:d AND Timestamp >= DATE_SUB(NOW(), INTERVAL 3 MONTH)");
    $eventCount->execute([':d'=>$driverId]);

    $dr = $pdo->prepare("SELECT CONCAT(FirstName,' ',LastName) AS FullName, EmploymentStatus, LicenceType, LicenceExpiryDate FROM Drivers WHERE DriverID=:d");
    $dr->execute([':d'=>$driverId]);
    $driverInfo = $dr->fetch();

    jsonOk([
        'name'             => $driverInfo['FullName'] ?? $_SESSION['username'],
        'status'           => $driverInfo['EmploymentStatus'] ?? 'Active',
        'licenceType'      => $driverInfo['LicenceType'] ?? '—',
        'licenceExpiry'    => $driverInfo['LicenceExpiryDate'] ?? '—',
        'latestScore'      => (int)$latest['FinalScore'],
        'coachingRequired' => (bool)$latest['CoachingRequired'],
        'suspended'        => (bool)$latest['Suspended'],
        'expiringSoon'     => (int)$expiring->fetchColumn(),
        'expiredCerts'     => (int)$expired->fetchColumn(),
        'recentEvents'     => (int)$eventCount->fetchColumn(),
    ]);
}

// ── MY PROFILE ───────────────────────────────────────────────────────
if ($resource === 'my_profile') {
    requirePermission('Drivers', 'SELECT');
    $stmt = $pdo->prepare("
        SELECT dr.DriverID, dr.FirstName, dr.LastName, dr.ContactInformation,
               dr.LicenceType, dr.LicenceExpiryDate, dr.EmploymentStatus,
               dep.Name AS DepotName
        FROM Drivers dr
        JOIN Depots dep ON dep.DepotID=dr.DepotID
        WHERE dr.DriverID=:d
    ");
    $stmt->execute([':d'=>$driverId]);
    jsonOk($stmt->fetch());
}

// ── MY SAFETY EVENTS ─────────────────────────────────────────────────
if ($resource === 'my_events') {
    requirePermission('SafetyEvents', 'SELECT');
    $stmt = $pdo->prepare("
        SELECT se.EventID, se.Timestamp,
               et.Name AS EventType, se.Severity,
               v.RegistrationNumber AS Vehicle,
               se.ReviewStatus
        FROM SafetyEvents se
        JOIN SafetyEventsType et ON et.EventsTypeID=se.EventsTypeID
        JOIN Vehicles v          ON v.VehicleID=se.VehicleID
        WHERE se.DriverID=:d
        ORDER BY se.Timestamp DESC
    ");
    $stmt->execute([':d'=>$driverId]);
    jsonOk($stmt->fetchAll());
}

// ── MY SAFETY SCORES ─────────────────────────────────────────────────
if ($resource === 'my_scores') {
    requirePermission('DriverSafetyScore', 'SELECT');
    $stmt = $pdo->prepare("
        SELECT ScorePeriod, BaseScore, DeductedPoints, FinalScore,
               CoachingRequired, Suspended,
               LowCount, MediumCount, HighCount, CriticalCount
        FROM DriverSafetyScore
        WHERE DriverID=:d
        ORDER BY ScorePeriod DESC
        LIMIT 12
    ");
    $stmt->execute([':d'=>$driverId]);
    jsonOk($stmt->fetchAll());
}

// ── MY CERTIFICATIONS ────────────────────────────────────────────────
if ($resource === 'my_certifications') {
    requirePermission('DriverCertifications', 'SELECT');
    $stmt = $pdo->prepare("
        SELECT dc.DriverCertID, ct.Name AS CertType,
               dc.IssueDate, dc.ExpireDate
        FROM DriverCertifications dc
        JOIN CertificationType ct ON ct.CertTypeID=dc.CertTypeID
        WHERE dc.DriverID=:d
        ORDER BY dc.ExpireDate IS NULL DESC, dc.ExpireDate ASC
    ");
    $stmt->execute([':d'=>$driverId]);
    jsonOk($stmt->fetchAll());
}

jsonErr("Unknown resource: $resource");
