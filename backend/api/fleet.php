<?php
/**
 * Fleet Admin API — vehicles, depots, assignments, drivers, mechanics, users/roles
 * GET  ?resource=vehicles
 * GET  ?resource=depots
 * GET  ?resource=assignments
 * GET  ?resource=drivers
 * GET  ?resource=mechanics
 * GET  ?resource=users
 * GET  ?resource=kpis
 *
 * POST ?resource=vehicles   { body: vehicle fields }
 * POST ?resource=depots     { body: depot fields }
 * POST ?resource=assignments { body: assignment fields }
 * POST ?resource=drivers    { body: driver fields }
 * POST ?resource=mechanics  { body: mechanic fields }
 * POST ?resource=users      { body: user + role fields }
 *
 * PUT  ?resource=vehicles&id=N    { body: changed fields }
 * PUT  ?resource=depots&id=N      { body: changed fields }
 * PUT  ?resource=assignments&id=N { body: changed fields }
 * PUT  ?resource=drivers&id=N     { body: changed fields }
 * PUT  ?resource=mechanics&id=N   { body: changed fields }
 * PUT  ?resource=users&id=N       { body: changed fields }
 *
 * PUT  ?resource=vehicle_status&id=N { body: { status } }
 *
 * DELETE ?resource=vehicles&id=N
 * DELETE ?resource=depots&id=N
 * DELETE ?resource=drivers&id=N
 * DELETE ?resource=mechanics&id=N
 * DELETE ?resource=users&id=N
 */

require __DIR__ . '/_bootstrap.php';

$method   = $_SERVER['REQUEST_METHOD'];
$resource = $_GET['resource'] ?? '';
$id       = isset($_GET['id']) ? (int)$_GET['id'] : null;

// -- KPIs -- //
if ($resource === 'kpis') {
    requirePermission('Vehicles', 'SELECT');
    jsonOk([
        'totalVehicles'   => (int)$pdo->query("SELECT COUNT(*) FROM Vehicles")->fetchColumn(),
        'operational'     => (int)$pdo->query("SELECT COUNT(*) FROM Vehicles WHERE OperationalStatus IN ('Active','Available')")->fetchColumn(),
        'underMaint'      => (int)$pdo->query("SELECT COUNT(*) FROM Vehicles WHERE OperationalStatus='Under Maintenance'")->fetchColumn(),
        'totalDrivers'    => (int)$pdo->query("SELECT COUNT(*) FROM Drivers")->fetchColumn(),
        'activeDrivers'   => (int)$pdo->query("SELECT COUNT(*) FROM Drivers WHERE EmploymentStatus='Active'")->fetchColumn(),
        'totalMechanics'  => (int)$pdo->query("SELECT COUNT(*) FROM Mechanic")->fetchColumn(),
        'activeMechanics' => (int)$pdo->query("SELECT COUNT(*) FROM Mechanic WHERE EmploymentStatus='Active'")->fetchColumn(),
        'totalDepots'     => (int)$pdo->query("SELECT COUNT(*) FROM Depots")->fetchColumn(),
        'openJobs'        => (int)$pdo->query("SELECT COUNT(*) FROM MaintenanceJobs WHERE DateClosed IS NULL")->fetchColumn(),
        'activeAssignments' => (int)$pdo->query("SELECT COUNT(*) FROM VehicleAssignments WHERE EndDate IS NULL OR EndDate >= CURDATE()")->fetchColumn(),
    ]);
}

// -- VEHICLES -- //
if ($resource === 'vehicles') {
    requirePermission('Vehicles', 'SELECT');
    if ($method === 'GET') {
        $filter = $_GET['filter'] ?? '';
        $status = $_GET['status'] ?? '';
        
        $where = [];
        $params = [];
        if ($filter) {
            $where[] = "(v.RegistrationNumber LIKE :filter OR v.Model LIKE :filter OR v.Manufacturer LIKE :filter OR d.Name LIKE :filter)";
            $params[':filter'] = "%$filter%";
        }
        if ($status) {
            $where[] = "v.OperationalStatus = :status";
            $params[':status'] = $status;
        }
        
        $sql = "
            SELECT v.VehicleID, v.RegistrationNumber, v.CategoryID, v.DepotID, v.Model, v.Manufacturer,
                   v.YearOfManufacture, v.CurrentOdometerReading, v.OperationalStatus,
                   vc.CategoryName, d.Name AS DepotName
            FROM Vehicles v
            JOIN VehiclesCategory vc ON vc.CategoryID = v.CategoryID
            JOIN Depots d ON d.DepotID = v.DepotID
        ";
        if ($where) {
            $sql .= ' WHERE ' . implode(' AND ', $where);
        }
        $sql .= ' ORDER BY v.RegistrationNumber';
        
        $stmt = $pdo->prepare($sql);
        foreach ($params as $k => $v) {
            $stmt->bindValue($k, $v);
        }
        $stmt->execute();
        $rows = $stmt->fetchAll();
        jsonOk($rows);
    }
    if ($method === 'POST') {
        requirePermission('Vehicles', 'INSERT');
        $b = readBody();
        $stmt = $pdo->prepare("INSERT INTO Vehicles
            (RegistrationNumber,CategoryID,Model,Manufacturer,YearOfManufacture,
            CurrentOdometerReading,DepotID,OperationalStatus)
            VALUES (:reg,:cat,:model,:mfr,:yr,:odo,:depot,:status)");
        $stmt->execute([
            ':reg'=>$b['RegistrationNumber'],':cat'=>$b['CategoryID'],
            ':model'=>$b['Model'],':mfr'=>$b['Manufacturer'],
            ':yr'=>$b['YearOfManufacture'],':odo'=>$b['CurrentOdometerReading']??0,
            ':depot'=>$b['DepotID'],':status'=>$b['OperationalStatus']??'Available',
        ]);
        jsonOk(['id' => (int)$pdo->lastInsertId()]);
    }
    if ($method === 'PUT' && $id) {
        requirePermission('Vehicles', 'UPDATE');
        $b = readBody();
        $pdo->prepare("UPDATE Vehicles SET
            RegistrationNumber=:reg, CategoryID=:cat, Model=:model, Manufacturer=:mfr,
            YearOfManufacture=:yr, CurrentOdometerReading=:odo, DepotID=:depot,
            OperationalStatus=:status
            WHERE VehicleID=:id")->execute([
            ':reg'=>$b['RegistrationNumber'],':cat'=>$b['CategoryID'],
            ':model'=>$b['Model'],':mfr'=>$b['Manufacturer'],
            ':yr'=>$b['YearOfManufacture'],':odo'=>$b['CurrentOdometerReading']??0,
            ':depot'=>$b['DepotID'],':status'=>$b['OperationalStatus'],
            ':id'=>$id,
        ]);
        jsonOk(['updated' => $id]);
    }
    if ($method === 'DELETE' && $id) {
        requirePermission('Vehicles', 'DELETE');
        try {
            $pdo->prepare("DELETE FROM Vehicles WHERE VehicleID=:id")->execute([':id'=>$id]);
            jsonOk(['deleted' => $id]);
        } catch (PDOException $e) {
            jsonErr('Cannot delete: vehicle is referenced by other records.', 409);
        }
    }
    jsonErr('Bad request');
}

// -- DEPOTS -- //
if ($resource === 'depots') {
    requirePermission('Depots', 'SELECT');
    if ($method === 'GET') {
        $rows = $pdo->query("
            SELECT d.*,
                   (SELECT COUNT(*) FROM Vehicles v WHERE v.DepotID=d.DepotID) AS VehicleCount,
                   (SELECT COUNT(*) FROM Drivers dr WHERE dr.DepotID=d.DepotID) AS DriverCount
            FROM Depots d
            ORDER BY d.Name
        ")->fetchAll();
        jsonOk($rows);
    }
    if ($method === 'POST') {
        requirePermission('Depots', 'INSERT');
        $b = readBody();
        $pdo->prepare("INSERT INTO Depots (City,Address,Name,ContactPhone) VALUES (:city,:addr,:name,:ph)")
            ->execute([':city'=>$b['City'],':addr'=>$b['Address'],':name'=>$b['Name'],':ph'=>$b['ContactPhone']??null]);
        jsonOk(['id' => (int)$pdo->lastInsertId()]);
    }
    if ($method === 'PUT' && $id) {
        requirePermission('Depots', 'UPDATE');
        $b = readBody();
        $pdo->prepare("UPDATE Depots SET City=:city,Address=:addr,Name=:name,ContactPhone=:ph WHERE DepotID=:id")
            ->execute([':city'=>$b['City'],':addr'=>$b['Address'],':name'=>$b['Name'],':ph'=>$b['ContactPhone']??null,':id'=>$id]);
        jsonOk(['updated' => $id]);
    }
    if ($method === 'DELETE' && $id) {
        requirePermission('Depots', 'DELETE');
        try {
            $pdo->prepare("DELETE FROM Depots WHERE DepotID=:id")->execute([':id'=>$id]);
            jsonOk(['deleted' => $id]);
        } catch (PDOException $e) {
            jsonErr('Cannot delete: depot is referenced by vehicles or drivers.', 409);
        }
    }
    jsonErr('Bad request');
}

// -- ASSIGNMENTS -- //
if ($resource === 'assignments') {
    requirePermission('VehicleAssignments', 'SELECT');
    if ($method === 'GET') {
        $rows = $pdo->query("
            SELECT va.AssignmentID, va.VehicleID, va.DriverID, va.DepotID, v.RegistrationNumber, CONCAT(v.Manufacturer,' ',v.Model) AS VehicleModel,
                   CONCAT(dr.FirstName,' ',dr.LastName) AS DriverName,
                   dep.Name AS DepotName, va.StartDate, va.EndDate, va.IsPermanent
            FROM VehicleAssignments va
            JOIN Vehicles v ON v.VehicleID=va.VehicleID
            JOIN Drivers dr ON dr.DriverID=va.DriverID
            JOIN Depots dep ON dep.DepotID=va.DepotID
            ORDER BY va.StartDate DESC
        ")->fetchAll();
        jsonOk($rows);
    }
    if ($method === 'POST') {
        requirePermission('VehicleAssignments', 'INSERT');
        $b = readBody();
        $pdo->prepare("INSERT INTO VehicleAssignments
            (VehicleID,DriverID,StartDate,EndDate,IsPermanent,DepotID)
            VALUES (:v,:d,:s,:e,:p,:dep)")->execute([
            ':v'=>$b['VehicleID'],':d'=>$b['DriverID'],':s'=>$b['StartDate'],
            ':e'=>$b['EndDate']??null,':p'=>$b['IsPermanent']??0,':dep'=>$b['DepotID'],
        ]);
        jsonOk(['id' => (int)$pdo->lastInsertId()]);
    }
    if ($method === 'PUT' && $id) {
        requirePermission('VehicleAssignments', 'UPDATE');
        $b = readBody();
        $pdo->prepare("UPDATE VehicleAssignments SET
            VehicleID=:v,DriverID=:d,StartDate=:s,EndDate=:e,IsPermanent=:p,DepotID=:dep
            WHERE AssignmentID=:id")->execute([
            ':v'=>$b['VehicleID'],':d'=>$b['DriverID'],':s'=>$b['StartDate'],
            ':e'=>$b['EndDate']??null,':p'=>$b['IsPermanent']??0,':dep'=>$b['DepotID'],':id'=>$id,
        ]);
        jsonOk(['updated' => $id]);
    }
    if ($method === 'DELETE' && $id) {
        requirePermission('VehicleAssignments', 'DELETE');
        $pdo->prepare("DELETE FROM VehicleAssignments WHERE AssignmentID=:id")->execute([':id'=>$id]);
        jsonOk(['deleted' => $id]);
    }
    jsonErr('Bad request');
}

// -- DRIVERS -- //
if ($resource === 'drivers') {
    requirePermission('Drivers', 'SELECT');
    if ($method === 'GET') {
        $rows = $pdo->query("
            SELECT dr.*, d.Name AS DepotName,
                   COALESCE(latest_score.FinalScore, 100) AS SafetyScore
            FROM Drivers dr
            JOIN Depots d ON d.DepotID=dr.DepotID
            LEFT JOIN (
                SELECT DriverID, FinalScore,
                       ROW_NUMBER() OVER (PARTITION BY DriverID ORDER BY ScorePeriod DESC) AS rn
                FROM DriverSafetyScore
            ) latest_score ON latest_score.DriverID=dr.DriverID AND latest_score.rn=1
            ORDER BY dr.LastName
        ")->fetchAll();
        jsonOk($rows);
    }
    if ($method === 'POST') {
        requirePermission('Drivers', 'INSERT');
        $b = readBody();
        $pdo->prepare("INSERT INTO Drivers
            (FirstName,LastName,ContactInformation,DepotID,LicenceType,
            LicenceExpiryDate,EmploymentStatus,EmergencyContactDetails)
            VALUES (:fn,:ln,:ci,:dep,:lt,:led,:es,:ec)")->execute([
            ':fn'=>$b['FirstName'],':ln'=>$b['LastName'],':ci'=>$b['ContactInformation']??null,
            ':dep'=>$b['DepotID'],':lt'=>$b['LicenceType'],':led'=>$b['LicenceExpiryDate'],
            ':es'=>$b['EmploymentStatus']??'Active',':ec'=>$b['EmergencyContactDetails']??null,
        ]);
        jsonOk(['id' => (int)$pdo->lastInsertId()]);
    }
    if ($method === 'PUT' && $id) {
        requirePermission('Drivers', 'UPDATE');
        $b = readBody();
        $pdo->prepare("UPDATE Drivers SET
            FirstName=:fn,LastName=:ln,ContactInformation=:ci,
            DepotID=:dep,LicenceType=:lt,LicenceExpiryDate=:led,
            EmploymentStatus=:es,EmergencyContactDetails=:ec
            WHERE DriverID=:id")->execute([
            ':fn'=>$b['FirstName'],':ln'=>$b['LastName'],':ci'=>$b['ContactInformation']??null,
            ':dep'=>$b['DepotID'],':lt'=>$b['LicenceType'],':led'=>$b['LicenceExpiryDate'],
            ':es'=>$b['EmploymentStatus'],':ec'=>$b['EmergencyContactDetails']??null,':id'=>$id,
        ]);
        jsonOk(['updated' => $id]);
    }
    if ($method === 'DELETE' && $id) {
        requirePermission('Drivers', 'DELETE');
        try {
            $pdo->prepare("DELETE FROM Drivers WHERE DriverID=:id")->execute([':id'=>$id]);
            jsonOk(['deleted' => $id]);
        } catch (PDOException $e) {
            jsonErr('Cannot delete: driver has assignments or safety records.', 409);
        }
    }
    jsonErr('Bad request');
}

// -- MECHANICS -- //
if ($resource === 'mechanics') {
    requirePermission('Mechanic', 'SELECT');
    if ($method === 'GET') {
        $rows = $pdo->query("
            SELECT m.MechanicID, m.FirstName, m.LastName, m.WorkshopID, m.EmploymentStatus,
                   w.Name AS WorkshopName,
                   GROUP_CONCAT(mct.Name ORDER BY mct.Name SEPARATOR '||') AS Certifications
            FROM Mechanic m
            JOIN Workshop w ON w.WorkshopID=m.WorkshopID
            LEFT JOIN MechanicCertification mc ON mc.MechanicID=m.MechanicID
                AND (mc.ExpireDate IS NULL OR mc.ExpireDate >= CURDATE())
            LEFT JOIN MechanicCertType mct ON mct.MecCertTypeID=mc.MecCertTypeID
            GROUP BY m.MechanicID, m.FirstName, m.LastName, m.WorkshopID, m.EmploymentStatus, w.Name
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
        $pdo->prepare("UPDATE Mechanic SET
            FirstName=:fn,LastName=:ln, WorkshopID=:ws,EmploymentStatus=:es
            WHERE MechanicID=:id")->execute([
            ':fn'=>$b['FirstName'],':ln'=>$b['LastName'],
            ':ws'=>$b['WorkshopID'],':es'=>$b['EmploymentStatus'],':id'=>$id,
        ]);
        jsonOk(['updated' => $id]);
    }
    if ($method === 'DELETE' && $id) {
        requirePermission('Mechanic', 'DELETE');
        try {
            $pdo->prepare("DELETE FROM Mechanic WHERE MechanicID=:id")->execute([':id'=>$id]);
            jsonOk(['deleted' => $id]);
        } catch (PDOException $e) {
            jsonErr('Cannot delete: mechanic has assigned activities.', 409);
        }
    }
    jsonErr('Bad request');
}

// -- USERS -- //
if ($resource === 'users') {
    requirePermission('UserAccount', 'SELECT');
    if ($method === 'GET') {
        $rows = $pdo->query("
            SELECT ua.UserID, ua.Username, ua.IsActive,
                   ua.DriverID, ua.MechanicID, ua.DepotID,
                   r.RoleName,
                   CONCAT(d.FirstName,' ',d.LastName) AS LinkedDriver,
                   CONCAT(m.FirstName,' ',m.LastName) AS LinkedMechanic,
                   dep.Name AS DepotName, ur.GrantedDate
            FROM UserAccount ua
            LEFT JOIN UserRole ur  ON ur.UserID  = ua.UserID
            LEFT JOIN Role r       ON r.RoleID   = ur.RoleID
            LEFT JOIN Drivers d    ON d.DriverID  = ua.DriverID
            LEFT JOIN Mechanic m   ON m.MechanicID= ua.MechanicID
            LEFT JOIN Depots dep   ON dep.DepotID  = ua.DepotID
            ORDER BY ua.Username
        ")->fetchAll();
        jsonOk($rows);
    }
    if ($method === 'POST') {
        requirePermission('UserAccount', 'INSERT');
        requirePermission('UserRole', 'INSERT');
        $b = readBody();
        
        $username = trim($b['Username'] ?? '');
        $password = $b['Password'] ?? '';
        $roleId   = isset($b['RoleID']) ? (int)$b['RoleID'] : null;
        
        if ($username === '') jsonErr('Username is required.');
        if (!preg_match('/^[A-Za-z0-9_.]{3,50}$/', $username)) {
            jsonErr('Username must be 3–50 characters and may only contain letters, numbers, dots, and underscores.');
        }
        if ($password === '') jsonErr('Password is required.');
        if (strlen($password) < 8) jsonErr('Password must be at least 8 characters.');
        if (strlen($password) > 72) jsonErr('Password must be 72 characters or fewer (bcrypt limit).');
        if (!$roleId) jsonErr('Role is required.');
        
        $dup = $pdo->prepare('SELECT 1 FROM UserAccount WHERE Username = :u');
        $dup->execute([':u' => $username]);
        if ($dup->fetch()) jsonErr('Username is already taken.', 409);
        
        $roleCheck = $pdo->prepare('SELECT 1 FROM Role WHERE RoleID = :rid');
        $roleCheck->execute([':rid' => $roleId]);
        if (!$roleCheck->fetch()) jsonErr('Invalid role selected.');
        
        try {
            $pdo->beginTransaction();
            $passwordHash = password_hash($password, PASSWORD_DEFAULT);
            $insertUser = $pdo->prepare("
                INSERT INTO UserAccount (Username, PasswordHash, IsActive, DriverID, MechanicID, DepotID)
                VALUES (:username, :hash, :active, :driver, :mechanic, :depot)
            ");
            $insertUser->execute([
                ':username' => $username,
                ':hash' => $passwordHash,
                ':active' => isset($b['IsActive']) ? (int)$b['IsActive'] : 1,
                ':driver' => !empty($b['DriverID']) ? (int)$b['DriverID'] : null,
                ':mechanic' => !empty($b['MechanicID']) ? (int)$b['MechanicID'] : null,
                ':depot' => !empty($b['DepotID']) ? (int)$b['DepotID'] : null,
            ]);
            $userId = (int)$pdo->lastInsertId();
            
            $insertRole = $pdo->prepare("
                INSERT INTO UserRole (UserID, RoleID, GrantedDate)
                VALUES (:uid, :rid, CURRENT_DATE)
            ");
            $insertRole->execute([':uid' => $userId, ':rid' => $roleId]);
            
            $pdo->commit();
            jsonOk(['id' => $userId]);
        } catch (PDOException $e) {
            $pdo->rollBack();
            jsonErr('Could not create account: ' . $e->getMessage(), 500);
        }
    }
    if ($method === 'DELETE' && $id) {
        requirePermission('UserAccount', 'DELETE');
        $pdo->prepare("DELETE FROM UserAccount WHERE UserID=:id")->execute([':id'=>$id]);
        jsonOk(['deleted' => $id]);
    }
    jsonErr('Bad request');
}

// -- JOB SUMMARY (for dashboard recent jobs panel) -- //
if ($resource === 'recent_jobs') {
    requirePermission('MaintenanceJobs', 'SELECT');
    $rows = $pdo->query("
        SELECT mj.JobID, v.RegistrationNumber, CONCAT(v.Manufacturer,' ',v.Model) AS VehicleModel,
               w.Name AS WorkshopName, mj.DateOpened, mj.DateClosed,
               mj.TotalCost, mj.AlertID,
               CASE WHEN mj.DateClosed IS NOT NULL THEN 'Closed'
                    WHEN EXISTS(SELECT 1 FROM MaintenanceActivity ma WHERE ma.JobID=mj.JobID AND ma.StartedAt IS NOT NULL) THEN 'In Progress'
                    ELSE 'Open'
               END AS Status
        FROM MaintenanceJobs mj
        JOIN Vehicles v ON v.VehicleID=mj.VehicleID
        JOIN Workshop w ON w.WorkshopID=mj.WorkshopID
        ORDER BY mj.DateOpened DESC LIMIT 10
    ")->fetchAll();
    jsonOk($rows);
}

// -- VEHICLE STATUS BREAKDOWN -- //
if ($resource === 'vehicle_status_breakdown') {
    requirePermission('Vehicles', 'SELECT');
    $rows = $pdo->query("
        SELECT OperationalStatus AS status, COUNT(*) AS count
        FROM Vehicles
        GROUP BY OperationalStatus
    ")->fetchAll();
    jsonOk($rows);
}

// -- LOOKUP DATA (for dropdowns) -- //
if ($resource === 'lookup') {
    $type = $_GET['type'] ?? '';
    if ($type === 'roles') {
        requirePermission('UserAccount', 'SELECT');
        $rows = $pdo->query("SELECT RoleID, RoleName FROM Role ORDER BY RoleName")->fetchAll();
        jsonOk($rows);
    }
    if ($type === 'drivers_list') {
        requirePermission('Drivers', 'SELECT');
        $rows = $pdo->query("
            SELECT DriverID, CONCAT(FirstName, ' ', LastName) AS DriverName
            FROM Drivers
            ORDER BY LastName, FirstName
        ")->fetchAll();
        jsonOk($rows);
    }
    if ($type === 'mechanics_list') {
        requirePermission('Mechanic', 'SELECT');
        $rows = $pdo->query("
            SELECT MechanicID, CONCAT(FirstName, ' ', LastName) AS MechanicName
            FROM Mechanic
            ORDER BY LastName, FirstName
        ")->fetchAll();
        jsonOk($rows);
    }
    if ($type === 'depots_list') {
        requirePermission('Depots', 'SELECT');
        $rows = $pdo->query("SELECT DepotID, Name FROM Depots ORDER BY Name")->fetchAll();
        jsonOk($rows);
    }
    if ($type === 'vehicle_categories') {
        requirePermission('Vehicles', 'SELECT');
        $rows = $pdo->query("SELECT CategoryID, CategoryName FROM VehiclesCategory ORDER BY CategoryName")->fetchAll();
        jsonOk($rows);
    }
    if ($type === 'workshops_list') {
        requirePermission('Mechanic', 'SELECT');
        $rows = $pdo->query("SELECT WorkshopID, Name FROM Workshop ORDER BY Name")->fetchAll();
        jsonOk($rows);
    }
    if ($type === 'vehicles_list') {
        requirePermission('Vehicles', 'SELECT');
        $rows = $pdo->query("SELECT VehicleID, RegistrationNumber FROM Vehicles ORDER BY RegistrationNumber")->fetchAll();
        jsonOk($rows);
    }
    jsonErr("Unknown lookup type: $type");
}

jsonErr("Unknown resource: $resource");
