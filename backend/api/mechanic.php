<?php
/**
 * Mechanic API — row-scoped to own assigned activities only
 *
 * GET  ?resource=my_activities   (own assigned activities with job+vehicle context)
 * GET  ?resource=kpis
 * GET  ?resource=lookup&type=activity_types
 *
 * PUT  ?resource=my_activity&id=N   { DiagnosticResult, IsRepeatFault, StartedAt, CompleteAt }
 * PUT  ?resource=my_labour&id=N     { LabourHours }   (id = ActivityID)
 */

require __DIR__ . '/_bootstrap.php';

$method   = $_SERVER['REQUEST_METHOD'];
$resource = $_GET['resource'] ?? '';
$id       = isset($_GET['id']) ? (int)$_GET['id'] : null;

$mechId = (int)($SESSION_USER['mechanic_id'] ?? 0);
if (!$mechId) jsonErr('This account is not linked to a mechanic record.', 403);

// ── KPIs ─────────────────────────────────────────────────────────────
if ($resource === 'kpis') {
    requirePermission('MaintenanceActivity', 'SELECT');
    $stmt = $pdo->prepare("
        SELECT
            COUNT(*)                                               AS total,
            SUM(ma.CompleteAt IS NOT NULL)                         AS completed,
            SUM(ma.StartedAt IS NOT NULL AND ma.CompleteAt IS NULL) AS inProgress,
            SUM(ma.IsRepeatFault)                                  AS repeatFaults,
            COALESCE(SUM(am.LabourHours),0)                        AS totalHours
        FROM MaintenanceActivity ma
        JOIN ActivityMechanic am ON am.ActivityID=ma.ActivityID AND am.MechanicID=:mid
    ");
    $stmt->execute([':mid'=>$mechId]);
    jsonOk($stmt->fetch());
}

// ── MY ACTIVITIES ─────────────────────────────────────────────────────
if ($resource === 'my_activities') {
    requirePermission('MaintenanceActivity', 'SELECT');
    $stmt = $pdo->prepare('CALL sp_get_mechanic_assigned_jobs(:mechanic, FALSE)');
    $stmt->execute([':mechanic' => $mechId]);
    $rows = $stmt->fetchAll();
    $stmt->closeCursor();
    jsonOk($rows);
}

// ── UPDATE OWN ACTIVITY (diagnostic result, repeat fault, timestamps) ─
if ($resource === 'my_activity') {
    requirePermission('MaintenanceActivity', 'UPDATE');
    if ($method === 'PUT' && $id) {
        // Verify this activity belongs to this mechanic
        $check = $pdo->prepare("SELECT 1 FROM ActivityMechanic WHERE ActivityID=:a AND MechanicID=:m");
        $check->execute([':a'=>$id,':m'=>$mechId]);
        if (!$check->fetch()) jsonErr('Forbidden: not your activity.', 403);

        $b = readBody();
        $pdo->prepare("UPDATE MaintenanceActivity SET
            DiagnosticResult=:dr, IsRepeatFault=:rf, StartedAt=:sa, CompleteAt=:ca
            WHERE ActivityID=:id")->execute([
            ':dr'=>$b['DiagnosticResult']??null,
            ':rf'=>isset($b['IsRepeatFault']) ? (int)(bool)$b['IsRepeatFault'] : 0,
            ':sa'=>$b['StartedAt']??null,
            ':ca'=>$b['CompleteAt']??null,
            ':id'=>$id,
        ]);
        jsonOk(['updated' => $id]);
    }
    jsonErr('Bad request');
}

// ── UPDATE OWN LABOUR HOURS ──────────────────────────────────────────
if ($resource === 'my_labour') {
    requirePermission('ActivityMechanic', 'UPDATE');
    if ($method === 'PUT' && $id) {
        $check = $pdo->prepare("SELECT 1 FROM ActivityMechanic WHERE ActivityID=:a AND MechanicID=:m");
        $check->execute([':a'=>$id,':m'=>$mechId]);
        if (!$check->fetch()) jsonErr('Forbidden: not your labour record.', 403);

        $b = readBody();
        $pdo->prepare("UPDATE ActivityMechanic SET LabourHours=:lh WHERE ActivityID=:a AND MechanicID=:m")
            ->execute([':lh'=>$b['LabourHours'],':a'=>$id,':m'=>$mechId]);
        jsonOk(['updated' => $id]);
    }
    jsonErr('Bad request');
}

// ── LOOKUP ───────────────────────────────────────────────────────────
if ($resource === 'lookup') {
    $type = $_GET['type'] ?? '';
    if ($type === 'activity_types') jsonOk($pdo->query("SELECT ActivityTypeID, Name FROM ActivityType ORDER BY Name")->fetchAll());
    jsonErr('Unknown lookup type.');
}

jsonErr("Unknown resource: $resource");
