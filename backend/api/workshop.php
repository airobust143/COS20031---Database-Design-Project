<?php
/**
 * Workshop Manager API
 *
 * GET  ?resource=kpis
 * GET  ?resource=jobs[&status=Open]
 * GET  ?resource=alerts[&status=New]
 * GET  ?resource=parts
 * GET  ?resource=suppliers
 * GET  ?resource=warranty
 * GET  ?resource=mechanics
 *
 * POST ?resource=jobs               { body: job fields }
 * PUT  ?resource=jobs&id=N          { body: changed fields }
 * DELETE ?resource=jobs&id=N
 *
 * PUT  ?resource=alerts&id=N        { body: { Status } }
 * PUT  ?resource=parts&id=N         { body: part fields }
 * POST ?resource=parts              { body: part fields }
 * DELETE ?resource=parts&id=N
 * POST ?resource=suppliers          { body: supplier fields }
 * PUT  ?resource=suppliers&id=N
 * DELETE ?resource=suppliers&id=N
 * POST ?resource=warranty           { body: claim fields }
 * PUT  ?resource=warranty&id=N      { body: { Status } }
 * POST ?resource=mechanics          { body: mechanic fields }
 * PUT  ?resource=mechanics&id=N
 * PUT  ?resource=mechanic_cert&id=N { mechanic cert add/update }
 */

require __DIR__ . '/_bootstrap.php';

$method   = $_SERVER['REQUEST_METHOD'];
$resource = $_GET['resource'] ?? '';
$id       = isset($_GET['id']) ? (int)$_GET['id'] : null;

// ── KPIs ─────────────────────────────────────────────────────────────
if ($resource === 'kpis') {
    requirePermission('MaintenanceJobs', 'SELECT');
    jsonOk([
        'openJobs'      => (int)$pdo->query("SELECT COUNT(*) FROM MaintenanceJobs WHERE DateClosed IS NULL")->fetchColumn(),
        'inProgress'    => (int)$pdo->query("SELECT COUNT(*) FROM MaintenanceJobs mj WHERE DateClosed IS NULL AND EXISTS(SELECT 1 FROM MaintenanceActivity ma WHERE ma.JobID=mj.JobID AND ma.StartedAt IS NOT NULL)")->fetchColumn(),
        'newAlerts'     => (int)$pdo->query("SELECT COUNT(*) FROM PredictiveAlert WHERE Status='New'")->fetchColumn(),
        'lowStock'      => (int)$pdo->query("SELECT COUNT(*) FROM Part WHERE QuantityInStock <= ReorderThreshold")->fetchColumn(),
        'pendingClaims' => (int)$pdo->query("SELECT COUNT(*) FROM WarrantyClaim WHERE Status='Submitted'")->fetchColumn(),
        'activeMechanics'=> (int)$pdo->query("SELECT COUNT(*) FROM Mechanic WHERE EmploymentStatus='Active'")->fetchColumn(),
        'totalCost'     => (float)$pdo->query("SELECT COALESCE(SUM(TotalCost),0) FROM MaintenanceJobs")->fetchColumn(),
    ]);
}

// ── JOBS ─────────────────────────────────────────────────────────────
if ($resource === 'jobs') {
    requirePermission('MaintenanceJobs', 'SELECT');
    if ($method === 'GET') {
        $where = ['1=1']; $params = [];
        if (!empty($_GET['status'])) {
            if ($_GET['status'] === 'Open')       $where[] = "mj.DateClosed IS NULL AND NOT EXISTS(SELECT 1 FROM MaintenanceActivity ma WHERE ma.JobID=mj.JobID AND ma.StartedAt IS NOT NULL)";
            elseif ($_GET['status'] === 'In Progress') $where[] = "mj.DateClosed IS NULL AND EXISTS(SELECT 1 FROM MaintenanceActivity ma WHERE ma.JobID=mj.JobID AND ma.StartedAt IS NOT NULL)";
            elseif ($_GET['status'] === 'Closed') $where[] = "mj.DateClosed IS NOT NULL";
        }
        $w = implode(' AND ', $where);
        $rows = $pdo->query("
            SELECT mj.JobID, v.RegistrationNumber, CONCAT(v.Manufacturer,' ',v.Model) AS VehicleModel,
                   ws.Name AS WorkshopName, mj.DateOpened, mj.DateClosed,
                   mj.OverallDowntime, mj.TotalCost, mj.AlertID,
                   CASE WHEN mj.DateClosed IS NOT NULL THEN 'Closed'
                        WHEN EXISTS(SELECT 1 FROM MaintenanceActivity ma WHERE ma.JobID=mj.JobID AND ma.StartedAt IS NOT NULL) THEN 'In Progress'
                        ELSE 'Open' END AS Status
            FROM MaintenanceJobs mj
            JOIN Vehicles v ON v.VehicleID=mj.VehicleID
            JOIN Workshop ws ON ws.WorkshopID=mj.WorkshopID
            WHERE $w
            ORDER BY mj.DateOpened DESC
        ")->fetchAll();
        jsonOk($rows);
    }
    if ($method === 'POST') {
        requirePermission('MaintenanceJobs', 'INSERT');
        $b = readBody();
        $pdo->prepare("INSERT INTO MaintenanceJobs
            (VehicleID,WorkshopID,DateOpened,DateClosed,OverallDowntime,TotalCost,AlertID)
            VALUES (:v,:ws,:do,:dc,:od,:tc,:al)")->execute([
            ':v'=>$b['VehicleID'],':ws'=>$b['WorkshopID'],':do'=>$b['DateOpened'],
            ':dc'=>$b['DateClosed']??null,':od'=>$b['OverallDowntime']??null,
            ':tc'=>$b['TotalCost']??0,':al'=>$b['AlertID']??null,
        ]);
        jsonOk(['id' => (int)$pdo->lastInsertId()]);
    }
    if ($method === 'PUT' && $id) {
        requirePermission('MaintenanceJobs', 'UPDATE');
        $b = readBody();
        $pdo->prepare("UPDATE MaintenanceJobs SET VehicleID=:v,WorkshopID=:ws,
            DateOpened=:do,DateClosed=:dc,OverallDowntime=:od,TotalCost=:tc,AlertID=:al
            WHERE JobID=:id")->execute([
            ':v'=>$b['VehicleID'],':ws'=>$b['WorkshopID'],':do'=>$b['DateOpened'],
            ':dc'=>$b['DateClosed']??null,':od'=>$b['OverallDowntime']??null,
            ':tc'=>$b['TotalCost']??0,':al'=>$b['AlertID']??null,':id'=>$id,
        ]);
        jsonOk(['updated' => $id]);
    }
    if ($method === 'DELETE' && $id) {
        requirePermission('MaintenanceJobs', 'DELETE');
        try {
            $pdo->prepare("DELETE FROM MaintenanceJobs WHERE JobID=:id")->execute([':id'=>$id]);
            jsonOk(['deleted' => $id]);
        } catch (PDOException $e) {
            jsonErr('Cannot delete: job has activities.', 409);
        }
    }
    jsonErr('Bad request');
}

// ── PREDICTIVE ALERTS ─────────────────────────────────────────────────
if ($resource === 'alerts') {
    requirePermission('PredictiveAlert', 'SELECT');
    if ($method === 'GET') {
        $where = '1=1'; $params = [];
        if (!empty($_GET['status'])) { $where .= ' AND pa.Status=:st'; $params[':st']=$_GET['status']; }
        $stmt = $pdo->prepare("
            SELECT pa.AlertID, v.RegistrationNumber AS Vehicle, pa.AlertType,
                   pa.Severity, pa.GeneratedAt, pa.Status, pa.ResolvedAt
            FROM PredictiveAlert pa
            JOIN Vehicles v ON v.VehicleID=pa.VehicleID
            WHERE $where ORDER BY pa.GeneratedAt DESC
        ");
        $stmt->execute($params);
        jsonOk($stmt->fetchAll());
    }
    if ($method === 'PUT' && $id) {
        requirePermission('PredictiveAlert', 'UPDATE');
        $b = readBody();
        $resolved = ($b['Status'] === 'Resolved') ? date('Y-m-d H:i:s') : null;
        $pdo->prepare("UPDATE PredictiveAlert SET Status=:s,ResolvedAt=:r WHERE AlertID=:id")
            ->execute([':s'=>$b['Status'],':r'=>$resolved,':id'=>$id]);
        jsonOk(['updated' => $id]);
    }
    jsonErr('Bad request');
}

// ── PARTS ────────────────────────────────────────────────────────────
if ($resource === 'parts') {
    requirePermission('Part', 'SELECT');
    if ($method === 'GET') {
        $lowOnly = !empty($_GET['low_stock']);
        $where = $lowOnly ? 'WHERE QuantityInStock <= ReorderThreshold' : '';
        jsonOk($pdo->query("SELECT * FROM Part $where ORDER BY PartNumber")->fetchAll());
    }
    if ($method === 'POST') {
        requirePermission('Part', 'INSERT');
        $b = readBody();
        $pdo->prepare("INSERT INTO Part (PartNumber,Description,UnitPrice,QuantityInStock,ReorderThreshold)
            VALUES (:pn,:d,:up,:qty,:rt)")->execute([
            ':pn'=>$b['PartNumber'],':d'=>$b['Description']??'',':up'=>$b['UnitPrice'],
            ':qty'=>$b['QuantityInStock']??0,':rt'=>$b['ReorderThreshold']??0,
        ]);
        jsonOk(['id' => (int)$pdo->lastInsertId()]);
    }
    if ($method === 'PUT' && $id) {
        requirePermission('Part', 'UPDATE');
        $b = readBody();
        $pdo->prepare("UPDATE Part SET PartNumber=:pn,Description=:d,UnitPrice=:up,
            QuantityInStock=:qty,ReorderThreshold=:rt WHERE PartID=:id")->execute([
            ':pn'=>$b['PartNumber'],':d'=>$b['Description']??'',':up'=>$b['UnitPrice'],
            ':qty'=>$b['QuantityInStock']??0,':rt'=>$b['ReorderThreshold']??0,':id'=>$id,
        ]);
        jsonOk(['updated' => $id]);
    }
    if ($method === 'DELETE' && $id) {
        requirePermission('Part', 'DELETE');
        try {
            $pdo->prepare("DELETE FROM Part WHERE PartID=:id")->execute([':id'=>$id]);
            jsonOk(['deleted' => $id]);
        } catch (PDOException $e) {
            jsonErr('Part is used in activities or warranty claims.', 409);
        }
    }
    jsonErr('Bad request');
}

// ── SUPPLIERS ────────────────────────────────────────────────────────
if ($resource === 'suppliers') {
    requirePermission('Supplier', 'SELECT');
    if ($method === 'GET') {
        jsonOk($pdo->query("SELECT * FROM Supplier ORDER BY Name")->fetchAll());
    }
    if ($method === 'POST') {
        requirePermission('Supplier', 'INSERT');
        $b = readBody();
        $pdo->prepare("INSERT INTO Supplier (Name,ContactInfo,LeadTimeDays) VALUES (:n,:c,:l)")
            ->execute([':n'=>$b['Name'],':c'=>$b['ContactInfo']??null,':l'=>$b['LeadTimeDays']??0]);
        jsonOk(['id' => (int)$pdo->lastInsertId()]);
    }
    if ($method === 'PUT' && $id) {
        requirePermission('Supplier', 'UPDATE');
        $b = readBody();
        $pdo->prepare("UPDATE Supplier SET Name=:n,ContactInfo=:c,LeadTimeDays=:l WHERE SupplierID=:id")
            ->execute([':n'=>$b['Name'],':c'=>$b['ContactInfo']??null,':l'=>$b['LeadTimeDays']??0,':id'=>$id]);
        jsonOk(['updated' => $id]);
    }
    if ($method === 'DELETE' && $id) {
        requirePermission('Supplier', 'DELETE');
        $pdo->prepare("DELETE FROM Supplier WHERE SupplierID=:id")->execute([':id'=>$id]);
        jsonOk(['deleted' => $id]);
    }
    jsonErr('Bad request');
}

// ── WARRANTY CLAIMS ──────────────────────────────────────────────────
if ($resource === 'warranty') {
    requirePermission('WarrantyClaim', 'SELECT');
    if ($method === 'GET') {
        $where = '1=1'; $params = [];
        if (!empty($_GET['status'])) { $where .= ' AND wc.Status=:st'; $params[':st']=$_GET['status']; }
        $stmt = $pdo->prepare("
            SELECT wc.ClaimID, wc.ActivityID,
                   CONCAT('JOB-',LPAD(mj.JobID,4,'0')) AS JobRef,
                   wc.WarrantyType, wc.Status, wc.ClaimDate
            FROM WarrantyClaim wc
            JOIN MaintenanceActivity ma ON ma.ActivityID=wc.ActivityID
            JOIN MaintenanceJobs mj     ON mj.JobID=ma.JobID
            WHERE $where ORDER BY wc.ClaimDate DESC
        ");
        $stmt->execute($params);
        jsonOk($stmt->fetchAll());
    }
    if ($method === 'POST') {
        requirePermission('WarrantyClaim', 'INSERT');
        $b = readBody();
        $pdo->prepare("INSERT INTO WarrantyClaim (ActivityID,WarrantyType,Status,ClaimDate)
            VALUES (:a,:wt,:s,:cd)")->execute([
            ':a'=>$b['ActivityID'],':wt'=>$b['WarrantyType'],
            ':s'=>$b['Status']??'Submitted',':cd'=>$b['ClaimDate']??date('Y-m-d'),
        ]);
        jsonOk(['id' => (int)$pdo->lastInsertId()]);
    }
    if ($method === 'PUT' && $id) {
        requirePermission('WarrantyClaim', 'UPDATE');
        $b = readBody();
        $pdo->prepare("UPDATE WarrantyClaim SET Status=:s WHERE ClaimID=:id")
            ->execute([':s'=>$b['Status'],':id'=>$id]);
        jsonOk(['updated' => $id]);
    }
    jsonErr('Bad request');
}

// ── MECHANICS (roster) ───────────────────────────────────────────────
if ($resource === 'mechanics') {
    requirePermission('Mechanic', 'SELECT');
    if ($method === 'GET') {
        $rows = $pdo->query("
            SELECT m.MechanicID, m.FirstName, m.LastName, m.EmploymentStatus,
                   w.Name AS WorkshopName,
                   GROUP_CONCAT(mct.Name ORDER BY mct.Name SEPARATOR '||') AS Certifications
            FROM Mechanic m
            JOIN Workshop w ON w.WorkshopID=m.WorkshopID
            LEFT JOIN MechanicCertification mc ON mc.MechanicID=m.MechanicID
                   AND (mc.ExpireDate IS NULL OR mc.ExpireDate >= CURDATE())
            LEFT JOIN MechanicCertType mct ON mct.MecCertTypeID=mc.MecCertTypeID
            GROUP BY m.MechanicID, m.FirstName, m.LastName, m.EmploymentStatus, w.Name
            ORDER BY m.LastName
        ")->fetchAll();
        foreach ($rows as &$r) {
            $r['CertList'] = $r['Certifications'] ? explode('||', $r['Certifications']) : [];
            unset($r['Certifications']);
        }
        jsonOk($rows);
    }
    if ($method === 'POST') {
        requirePermission('Mechanic', 'INSERT');
        $b = readBody();
        $pdo->prepare("INSERT INTO Mechanic (FirstName,LastName,WorkshopID,EmploymentStatus)
            VALUES (:fn,:ln,:ws,:es)")->execute([
            ':fn'=>$b['FirstName'],':ln'=>$b['LastName'],
            ':ws'=>$b['WorkshopID'],':es'=>$b['EmploymentStatus']??'Active',
        ]);
        jsonOk(['id' => (int)$pdo->lastInsertId()]);
    }
    if ($method === 'PUT' && $id) {
        requirePermission('Mechanic', 'UPDATE');
        $b = readBody();
        $pdo->prepare("UPDATE Mechanic SET FirstName=:fn,LastName=:ln,
            WorkshopID=:ws,EmploymentStatus=:es WHERE MechanicID=:id")->execute([
            ':fn'=>$b['FirstName'],':ln'=>$b['LastName'],
            ':ws'=>$b['WorkshopID'],':es'=>$b['EmploymentStatus'],':id'=>$id,
        ]);
        jsonOk(['updated' => $id]);
    }
    jsonErr('Bad request');
}

// ── LOOKUP ───────────────────────────────────────────────────────────
if ($resource === 'lookup') {
    $type = $_GET['type'] ?? '';
    if ($type === 'vehicles')   jsonOk($pdo->query("SELECT VehicleID, RegistrationNumber FROM Vehicles ORDER BY RegistrationNumber")->fetchAll());
    if ($type === 'workshops')  jsonOk($pdo->query("SELECT WorkshopID, Name FROM Workshop ORDER BY Name")->fetchAll());
    if ($type === 'activities') jsonOk($pdo->query("SELECT ma.ActivityID, mj.JobID, at.Name AS ActivityType FROM MaintenanceActivity ma JOIN MaintenanceJobs mj ON mj.JobID=ma.JobID JOIN ActivityType at ON at.ActivityTypeID=ma.ActivityTypeID ORDER BY ma.ActivityID DESC LIMIT 100")->fetchAll());
    if ($type === 'cert_types') jsonOk($pdo->query("SELECT MecCertTypeID, Name FROM MechanicCertType ORDER BY Name")->fetchAll());
    jsonErr('Unknown lookup type.');
}

jsonErr("Unknown resource: $resource");
