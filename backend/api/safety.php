<?php
/**
 * Safety Ops API
 *
 * GET  ?resource=kpis
 * GET  ?resource=events[&severity=High,Critical][&review=1]
 * GET  ?resource=review_queue
 * GET  ?resource=scores[&period=YYYY-MM]
 * GET  ?resource=coaching[&outcome=Pending]
 * GET  ?resource=drivers   (status + score for suspend/reactivate panel)
 *
 * POST ?resource=events            { body: event fields }
 * PUT  ?resource=events&id=N       { body: { ReviewStatus } }
 * PUT  ?resource=coaching&id=N     { body: { Outcome, CompleteDate } }
 * PUT  ?resource=driver_status&id=N { body: { EmploymentStatus } }
 *
 * POST ?resource=coaching          { body: coaching fields }
 */

require __DIR__ . '/_bootstrap.php';

$method   = $_SERVER['REQUEST_METHOD'];
$resource = $_GET['resource'] ?? '';
$id       = isset($_GET['id']) ? (int)$_GET['id'] : null;

// ── KPIs ─────────────────────────────────────────────────────────────
if ($resource === 'kpis') {
    requirePermission('SafetyEvents', 'SELECT');
    $period = date('Y-m'); // current month
    jsonOk([
        'criticalThisMonth' => (int)$pdo->prepare("SELECT COUNT(*) FROM SafetyEvents WHERE Severity='Critical' AND DATE_FORMAT(Timestamp,'%Y-%m')=:p")
            ->execute([':p'=>$period]) ? $pdo->query("SELECT COUNT(*) FROM SafetyEvents WHERE Severity='Critical' AND DATE_FORMAT(Timestamp,'%Y-%m')='$period'")->fetchColumn() : 0,
        'pendingReview'   => (int)$pdo->query("SELECT COUNT(*) FROM SafetyEvents WHERE ReviewStatus IN ('Pending','In Review')")->fetchColumn(),
        'pendingCoaching' => (int)$pdo->query("SELECT COUNT(*) FROM CoachingRecord WHERE Outcome='Pending'")->fetchColumn(),
        'suspendedDrivers'=> (int)$pdo->query("SELECT COUNT(*) FROM Drivers WHERE EmploymentStatus='Suspended'")->fetchColumn(),
        'driversFlagged'  => (int)$pdo->query("SELECT COUNT(*) FROM DriverSafetyScore WHERE CoachingRequired=1 AND ScorePeriod=DATE_FORMAT(NOW(),'%Y-%m')")->fetchColumn(),
    ]);
}

// ── SAFETY EVENTS ─────────────────────────────────────────────────────
if ($resource === 'events') {
    requirePermission('SafetyEvents', 'SELECT');
    if ($method === 'GET') {
        $where = ['1=1'];
        $params = [];
        if (!empty($_GET['severity'])) {
            $sevs = array_map('trim', explode(',', $_GET['severity']));
            $phs  = implode(',', array_map(fn($i) => ":s$i", array_keys($sevs)));
            $where[] = "se.Severity IN ($phs)";
            foreach ($sevs as $i => $s) $params[":s$i"] = $s;
        }
        if (!empty($_GET['review'])) {
            $where[] = "se.ReviewRequired = 1";
        }
        $w = implode(' AND ', $where);
        $stmt = $pdo->prepare("
            SELECT se.EventID, se.Timestamp,
                   CONCAT(d.FirstName,' ',d.LastName) AS DriverName,
                   v.RegistrationNumber AS Vehicle,
                   et.Name AS EventType, se.Severity,
                   dep.Name AS DepotName,
                   se.ReviewRequired, se.ReviewStatus
            FROM SafetyEvents se
            JOIN Drivers d  ON d.DriverID=se.DriverID
            JOIN Vehicles v ON v.VehicleID=se.VehicleID
            JOIN SafetyEventsType et ON et.EventsTypeID=se.EventsTypeID
            JOIN Depots dep ON dep.DepotID=se.DepotID
            WHERE $w
            ORDER BY se.Timestamp DESC
        ");
        $stmt->execute($params);
        jsonOk($stmt->fetchAll());
    }
    if ($method === 'POST') {
        requirePermission('SafetyEvents', 'INSERT');
        $b = readBody();
        // Auto-set ReviewRequired for High/Critical
        $reviewRequired = in_array($b['Severity']??'Low', ['High','Critical']) ? 1 : 0;
        $reviewStatus   = $reviewRequired ? 'Pending' : 'Not Required';
        $pdo->prepare("INSERT INTO SafetyEvents
            (Timestamp,VehicleID,DriverID,EventsTypeID,Severity,DepotID,
             Odometer,ReviewRequired,ReviewStatus)
            VALUES (:ts,:v,:d,:et,:sev,:dep,:odo,:rr,:rs)")->execute([
            ':ts'=>$b['Timestamp'],':v'=>$b['VehicleID'],':d'=>$b['DriverID'],
            ':et'=>$b['EventsTypeID'],':sev'=>$b['Severity'],':dep'=>$b['DepotID'],
            ':odo'=>$b['Odometer']??0,':rr'=>$reviewRequired,':rs'=>$reviewStatus,
        ]);
        jsonOk(['id' => (int)$pdo->lastInsertId()]);
    }
    if ($method === 'PUT' && $id) {
        requirePermission('SafetyEvents', 'UPDATE');
        $b = readBody();
        if (isset($b['ReviewStatus'])) {
            $pdo->prepare("UPDATE SafetyEvents SET ReviewStatus=:rs WHERE EventID=:id")
                ->execute([':rs'=>$b['ReviewStatus'],':id'=>$id]);
            jsonOk(['updated' => $id]);
        }
        jsonErr('Nothing to update.');
    }
    jsonErr('Bad request');
}

// ── REVIEW QUEUE ──────────────────────────────────────────────────────
if ($resource === 'review_queue') {
    requirePermission('SafetyEvents', 'SELECT');
    $rows = $pdo->query("
        SELECT se.EventID, se.Timestamp,
               CONCAT(d.FirstName,' ',d.LastName) AS DriverName,
               v.RegistrationNumber AS Vehicle,
               et.Name AS EventType, se.Severity, se.ReviewStatus
        FROM SafetyEvents se
        JOIN Drivers d ON d.DriverID=se.DriverID
        JOIN Vehicles v ON v.VehicleID=se.VehicleID
        JOIN SafetyEventsType et ON et.EventsTypeID=se.EventsTypeID
        WHERE se.ReviewRequired=1 AND se.ReviewStatus NOT IN ('Completed','Not Required')
        ORDER BY se.Severity DESC, se.Timestamp DESC
    ")->fetchAll();
    jsonOk($rows);
}

// ── DRIVER SAFETY SCORES ──────────────────────────────────────────────
if ($resource === 'scores') {
    requirePermission('DriverSafetyScore', 'SELECT');
    $period = $_GET['period'] ?? date('Y-m');
    $stmt = $pdo->prepare("
        SELECT dss.ScoreID, CONCAT(d.FirstName,' ',d.LastName) AS DriverName,
               dss.ScorePeriod, dss.BaseScore, dss.DeductedPoints, dss.FinalScore,
               dss.CoachingRequired, dss.Suspended,
               dss.LowCount, dss.MediumCount, dss.HighCount, dss.CriticalCount
        FROM DriverSafetyScore dss
        JOIN Drivers d ON d.DriverID=dss.DriverID
        WHERE dss.ScorePeriod=:p
        ORDER BY dss.FinalScore ASC
    ");
    $stmt->execute([':p'=>$period]);
    jsonOk($stmt->fetchAll());
}

// ── COACHING RECORDS ──────────────────────────────────────────────────
if ($resource === 'coaching') {
    requirePermission('CoachingRecord', 'SELECT');
    if ($method === 'GET') {
        $where = '1=1';
        $params = [];
        if (!empty($_GET['outcome'])) {
            $where .= ' AND cr.Outcome=:out';
            $params[':out'] = $_GET['outcome'];
        }
        $stmt = $pdo->prepare("
            SELECT cr.CoachingID, CONCAT(d.FirstName,' ',d.LastName) AS DriverName,
                   cr.Reason, cr.RecordType, cr.ScheduledDate, cr.CompleteDate, cr.Outcome
            FROM CoachingRecord cr
            JOIN Drivers d ON d.DriverID=cr.DriverID
            WHERE $where
            ORDER BY cr.ScheduledDate DESC
        ");
        $stmt->execute($params);
        jsonOk($stmt->fetchAll());
    }
    if ($method === 'POST') {
        requirePermission('CoachingRecord', 'INSERT');
        $b = readBody();
        $pdo->prepare("INSERT INTO CoachingRecord
            (DriverID,Reason,ScheduledDate,CompleteDate,Outcome,RecordType,EventID,ScoreID)
            VALUES (:d,:r,:sd,:cd,:o,:rt,:ev,:sc)")->execute([
            ':d'=>$b['DriverID'],':r'=>$b['Reason'],':sd'=>$b['ScheduledDate'],
            ':cd'=>$b['CompleteDate']??null,':o'=>$b['Outcome']??'Pending',
            ':rt'=>$b['RecordType']??'Other',':ev'=>$b['EventID']??null,':sc'=>$b['ScoreID']??null,
        ]);
        jsonOk(['id' => (int)$pdo->lastInsertId()]);
    }
    if ($method === 'PUT' && $id) {
        requirePermission('CoachingRecord', 'UPDATE');
        $b = readBody();
        $pdo->prepare("UPDATE CoachingRecord SET Outcome=:o, CompleteDate=:cd WHERE CoachingID=:id")
            ->execute([':o'=>$b['Outcome'],':cd'=>$b['CompleteDate']??null,':id'=>$id]);
        jsonOk(['updated' => $id]);
    }
    jsonErr('Bad request');
}

// ── DRIVER STATUS (suspend/reactivate) ────────────────────────────────
if ($resource === 'drivers') {
    requirePermission('Drivers', 'SELECT');
    if ($method === 'GET') {
        $rows = $pdo->query("
            SELECT dr.DriverID, CONCAT(dr.FirstName,' ',dr.LastName) AS DriverName,
                   dep.Name AS DepotName, dr.EmploymentStatus,
                   COALESCE(s.FinalScore, 100) AS SafetyScore
            FROM Drivers dr
            JOIN Depots dep ON dep.DepotID=dr.DepotID
            LEFT JOIN (
                SELECT DriverID, FinalScore, ROW_NUMBER() OVER (PARTITION BY DriverID ORDER BY ScorePeriod DESC) rn
                FROM DriverSafetyScore
            ) s ON s.DriverID=dr.DriverID AND s.rn=1
            ORDER BY dr.LastName
        ")->fetchAll();
        jsonOk($rows);
    }
    jsonErr('Bad request');
}

if ($resource === 'driver_status') {
    requirePermission('Drivers', 'UPDATE');
    if ($method === 'PUT' && $id) {
        $b = readBody();
        $allowed = ['Active','Inactive','Suspended','Terminated'];
        if (!in_array($b['EmploymentStatus']??'', $allowed, true)) jsonErr('Invalid status.');
        $pdo->prepare("UPDATE Drivers SET EmploymentStatus=:s WHERE DriverID=:id")
            ->execute([':s'=>$b['EmploymentStatus'],':id'=>$id]);
        jsonOk(['updated' => $id]);
    }
    jsonErr('Bad request');
}

// ── LOOKUP DATA (for forms) ───────────────────────────────────────────
if ($resource === 'lookup') {
    $type = $_GET['type'] ?? '';
    if ($type === 'event_types') {
        jsonOk($pdo->query("SELECT EventsTypeID, Name, DefaultSeverity FROM SafetyEventsType ORDER BY Name")->fetchAll());
    }
    if ($type === 'vehicles') {
        jsonOk($pdo->query("SELECT VehicleID, RegistrationNumber FROM Vehicles ORDER BY RegistrationNumber")->fetchAll());
    }
    if ($type === 'depots') {
        jsonOk($pdo->query("SELECT DepotID, Name FROM Depots ORDER BY Name")->fetchAll());
    }
    if ($type === 'score_periods') {
        jsonOk($pdo->query("SELECT DISTINCT ScorePeriod FROM DriverSafetyScore ORDER BY ScorePeriod DESC LIMIT 12")->fetchAll());
    }
    jsonErr('Unknown lookup type.');
}

jsonErr("Unknown resource: $resource");
