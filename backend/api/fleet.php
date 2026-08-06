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

function resolveVehicleModel(PDO $pdo, string $model, string $manufacturer): int {
    $stmt = $pdo->prepare(
        'INSERT INTO VehicleModel (ModelName, Manufacturer) VALUES (:model, :manufacturer) '
        . 'ON DUPLICATE KEY UPDATE ModelID = LAST_INSERT_ID(ModelID)'
    );
    $stmt->execute([':model' => trim($model), ':manufacturer' => trim($manufacturer)]);
    return (int) $pdo->lastInsertId();
}

// -- KPIs -- //
if ($resource === 'kpis') {
    requirePermission('Vehicles', 'SELECT');
    $summaryRows = callProcedure($pdo, 'CALL sp_fleet_summary_counts()')[0] ?? [];
    $summary = [];
    foreach ($summaryRows as $row) {
        $summary[$row['MetricType']][$row['Category']] = (int)$row['Count'];
    }
    $vehicleStatus = $summary['VehiclesByStatus'] ?? [];
    $driverStatus = $summary['DriversByStatus'] ?? [];
    $jobStatus = $summary['MaintenanceJobs'] ?? [];
    jsonOk([
        'totalVehicles'   => array_sum($vehicleStatus),
        'operational'     => (int)($vehicleStatus['Active'] ?? 0) + (int)($vehicleStatus['Available'] ?? 0),
        'underMaint'      => (int)($vehicleStatus['Under Maintenance'] ?? 0),
        'totalDrivers'    => array_sum($driverStatus),
        'activeDrivers'   => (int)($driverStatus['Active'] ?? 0),
        'totalMechanics'  => (int)$pdo->query("SELECT COUNT(*) FROM Mechanic")->fetchColumn(),
        'activeMechanics' => (int)$pdo->query("SELECT COUNT(*) FROM Mechanic WHERE EmploymentStatus='Active'")->fetchColumn(),
        'totalDepots'     => (int)$pdo->query("SELECT COUNT(*) FROM Depots")->fetchColumn(),
        'openJobs'        => (int)($jobStatus['Open'] ?? 0) + (int)($jobStatus['In Progress'] ?? 0),
        'activeAssignments' => (int)($summary['ActiveAssignments']['Current'] ?? 0),
    ]);
}

// -- VEHICLES -- //
if ($resource === 'vehicles') {
    requirePermission('Vehicles', 'SELECT');
    if ($method === 'GET') {
        $stmt = $pdo->prepare('CALL sp_search_vehicles(:status, NULL, NULL, :search, NULL)');
        $stmt->execute([
            ':status' => ($_GET['status'] ?? '') ?: null,
            ':search' => ($_GET['filter'] ?? '') ?: null,
        ]);
        $rows = $stmt->fetchAll();
        $stmt->closeCursor();
        jsonOk($rows);
    }
    if ($method === 'POST') {
        requirePermission('Vehicles', 'INSERT');
        $b = readBody();
        $modelId = resolveVehicleModel($pdo, $b['Model'], $b['Manufacturer']);
        $stmt = $pdo->prepare("INSERT INTO Vehicles
            (RegistrationNumber,CategoryID,ModelID,YearOfManufacture,
            CurrentOdometerReading,DepotID,OperationalStatus)
            VALUES (:reg,:cat,:modelId,:yr,:odo,:depot,:status)");
        $stmt->execute([
            ':reg'=>$b['RegistrationNumber'],':cat'=>$b['CategoryID'],
            ':modelId'=>$modelId,
            ':yr'=>$b['YearOfManufacture'],':odo'=>$b['CurrentOdometerReading']??0,
            ':depot'=>$b['DepotID'],':status'=>$b['OperationalStatus']??'Available',
        ]);
        jsonOk(['id' => (int)$pdo->lastInsertId()]);
    }
    if ($method === 'PUT' && $id) {
        requirePermission('Vehicles', 'UPDATE');
        $b = readBody();
        $modelId = resolveVehicleModel($pdo, $b['Model'], $b['Manufacturer']);
        $pdo->prepare("UPDATE Vehicles SET
            RegistrationNumber=:reg, CategoryID=:cat, ModelID=:modelId,
            YearOfManufacture=:yr, CurrentOdometerReading=:odo, DepotID=:depot,
            OperationalStatus=:status
            WHERE VehicleID=:id")->execute([
            ':reg'=>$b['RegistrationNumber'],':cat'=>$b['CategoryID'],
            ':modelId'=>$modelId,
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
        $pdo->prepare("INSERT INTO Depots (Name,StreetAddress,District,City,ContactPhone) VALUES (:name,:street,:district,:city,:ph)")
            ->execute([
                ':name'=>$b['Name'], ':street'=>$b['StreetAddress'], ':district'=>$b['District'],
                ':city'=>$b['City'], ':ph'=>$b['ContactPhone']??null,
            ]);
        jsonOk(['id' => (int)$pdo->lastInsertId()]);
    }
    if ($method === 'PUT' && $id) {
        requirePermission('Depots', 'UPDATE');
        $b = readBody();
        $pdo->prepare("UPDATE Depots SET Name=:name,StreetAddress=:street,District=:district,City=:city,ContactPhone=:ph WHERE DepotID=:id")
            ->execute([
                ':name'=>$b['Name'], ':street'=>$b['StreetAddress'], ':district'=>$b['District'],
                ':city'=>$b['City'], ':ph'=>$b['ContactPhone']??null, ':id'=>$id,
            ]);
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
        $stmt = $pdo->prepare('CALL sp_vehicle_assignment_history(NULL, NULL, :limit)');
        $stmt->execute([':limit' => 500]);
        $rows = $stmt->fetchAll();
        $stmt->closeCursor();
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
        $stmt = $pdo->prepare('CALL sp_list_users_by_role(NULL)');
        $stmt->execute();
        $rows = $stmt->fetchAll();
        $stmt->closeCursor();
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
        SELECT mj.JobID, v.RegistrationNumber, CONCAT(vm.Manufacturer,' ',vm.ModelName) AS VehicleModel,
               w.Name AS WorkshopName, mj.DateOpened, mj.DateClosed,
               mj.TotalCost, mj.AlertID,
               CASE WHEN mj.DateClosed IS NOT NULL THEN 'Closed'
                    WHEN EXISTS(SELECT 1 FROM MaintenanceActivity ma WHERE ma.JobID=mj.JobID AND ma.StartedAt IS NOT NULL) THEN 'In Progress'
                    ELSE 'Open'
               END AS Status
        FROM MaintenanceJobs mj
        JOIN Vehicles v ON v.VehicleID=mj.VehicleID
        JOIN VehicleModel vm ON vm.ModelID=v.ModelID
        JOIN Workshop w ON w.WorkshopID=mj.WorkshopID
        ORDER BY mj.DateOpened DESC LIMIT 10
    ")->fetchAll();
    jsonOk($rows);
}

// -- VEHICLE STATUS BREAKDOWN -- //
if ($resource === 'vehicle_status_breakdown') {
    requirePermission('Vehicles', 'SELECT');
    $summaryRows = callProcedure($pdo, 'CALL sp_fleet_summary_counts()')[0] ?? [];
    $rows = array_map(
        fn(array $row) => ['status' => $row['Category'], 'count' => (int)$row['Count']],
        array_values(array_filter($summaryRows, fn(array $row) => $row['MetricType'] === 'VehiclesByStatus'))
    );
    jsonOk($rows);
}

// -- PROCEDURE-BASED FLEET DETAIL AND WORK QUEUES -- //
if ($resource === 'vehicle_profile' && $method === 'GET' && $id) {
    requirePermission('Vehicles', 'SELECT');
    jsonOk(callProcedure($pdo, 'CALL sp_get_vehicle_profile(:vehicle_id)', [':vehicle_id' => $id]));
}

if ($resource === 'available_vehicles' && $method === 'GET') {
    requirePermission('Vehicles', 'SELECT');
    $depotId = !empty($_GET['depot_id']) ? (int)$_GET['depot_id'] : null;
    $categoryId = !empty($_GET['category_id']) ? (int)$_GET['category_id'] : null;
    jsonOk(callProcedure($pdo, 'CALL sp_list_available_vehicles(:depot_id, :category_id)', [
        ':depot_id' => $depotId,
        ':category_id' => $categoryId,
    ])[0] ?? []);
}

if ($resource === 'maintenance_due' && $method === 'GET') {
    requirePermission('MaintenanceJobs', 'SELECT');
    $odometer = max(1, min(100000, (int)($_GET['odometer_threshold'] ?? 10000)));
    $days = max(1, min(3650, (int)($_GET['days_threshold'] ?? 180)));
    jsonOk(callProcedure($pdo, 'CALL sp_vehicles_due_maintenance(:odometer, :days)', [
        ':odometer' => $odometer,
        ':days' => $days,
    ])[0] ?? []);
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
