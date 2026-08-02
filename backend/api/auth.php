<?php
/**
 * POST /api/auth.php?action=login   { username, password }
 * POST /api/auth.php?action=logout
 * GET  /api/auth.php?action=me
 *
 * Returns JSON. Does NOT redirect — the JS frontend handles routing.
 */
header('Content-Type: application/json; charset=utf-8');
header('Access-Control-Allow-Origin: http://localhost:5173');
header('Access-Control-Allow-Credentials: true');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type');

if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

// Bootstrap DB without the redirect guard
session_start();

$dbHost    = 'localhost';
$dbName    = 'smart_fleet_management';
$dbUser    = 'root';
$dbPass    = '';
$dbCharset = 'utf8mb4';

try {
    $pdo = new PDO(
        "mysql:host=$dbHost;dbname=$dbName;charset=$dbCharset",
        $dbUser, $dbPass,
        [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ]
    );
} catch (PDOException $e) {
    http_response_code(503);
    echo json_encode(['ok' => false, 'error' => 'Database unavailable']);
    exit;
}

$action = $_GET['action'] ?? 'me';

// ── GET /api/auth.php?action=me ──────────────────────────────────────
if ($action === 'me') {
    if (!isset($_SESSION['user_id'])) {
        http_response_code(401);
        echo json_encode(['ok' => false, 'error' => 'Not authenticated']);
        exit;
    }
    echo json_encode([
        'ok'   => true,
        'data' => [
            'userId'     => $_SESSION['user_id'],
            'username'   => $_SESSION['username'],
            'role'       => $_SESSION['role'],
            'roleName'   => $_SESSION['role_display'],
            'driverId'   => $_SESSION['driver_id'] ?? null,
            'mechanicId' => $_SESSION['mechanic_id'] ?? null,
            'depotId'    => $_SESSION['depot_id'] ?? null,
        ]
    ]);
    exit;
}

// ── POST /api/auth.php?action=logout ────────────────────────────────
if ($action === 'logout' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $_SESSION = [];
    if (ini_get('session.use_cookies')) {
        $p = session_get_cookie_params();
        setcookie(session_name(), '', time() - 42000,
            $p['path'], $p['domain'], $p['secure'], $p['httponly']);
    }
    session_destroy();
    echo json_encode(['ok' => true]);
    exit;
}

// ── POST /api/auth.php?action=login ─────────────────────────────────
if ($action === 'login' && $_SERVER['REQUEST_METHOD'] === 'POST') {
    $body     = json_decode(file_get_contents('php://input'), true) ?? [];
    $username = trim($body['username'] ?? $_POST['username'] ?? '');
    $password = $body['password'] ?? $_POST['password'] ?? '';

    if ($username === '' || $password === '') {
        http_response_code(400);
        echo json_encode(['ok' => false, 'error' => 'Username and password are required.']);
        exit;
    }

    $stmt = $pdo->prepare("
        SELECT ua.UserID, ua.Username, ua.PasswordHash, ua.DriverID, ua.MechanicID, ua.DepotID,
               r.RoleName
        FROM UserAccount ua
        JOIN UserRole ur ON ur.UserID = ua.UserID
        JOIN Role r      ON r.RoleID  = ur.RoleID
        WHERE ua.Username = :u AND ua.IsActive = 1
        LIMIT 1
    ");
    $stmt->execute([':u' => $username]);
    $user = $stmt->fetch();

    if (!$user || !password_verify($password, $user['PasswordHash'])) {
        http_response_code(401);
        echo json_encode(['ok' => false, 'error' => 'Invalid username or password.']);
        exit;
    }

    // Load all permissions
    $permStmt = $pdo->prepare("
        SELECT DISTINCT p.TableName, p.Action
        FROM UserRole ur
        JOIN RolePermission rp ON ur.RoleID = rp.RoleID
        JOIN Permission p      ON rp.PermissionID = p.PermissionID
        WHERE ur.UserID = :uid
    ");
    $permStmt->execute([':uid' => $user['UserID']]);
    $permissions = [];
    while ($perm = $permStmt->fetch()) {
        $permissions[$perm['TableName']][] = $perm['Action'];
    }

    // Role display names
    $roleDisplayMap = [
        'fleet_admin'  => 'Fleet Admin',
        'safety_ops'   => 'Safety Ops',
        'workshop_mgr' => 'Workshop Manager',
        'mechanic'     => 'Mechanic',
        'driver'       => 'Driver',
    ];

    session_regenerate_id(true);
    $_SESSION['user_id']      = $user['UserID'];
    $_SESSION['username']     = $user['Username'];
    $_SESSION['role']         = $user['RoleName'];
    $_SESSION['role_display'] = $roleDisplayMap[$user['RoleName']] ?? $user['RoleName'];
    $_SESSION['driver_id']    = $user['DriverID'];
    $_SESSION['mechanic_id']  = $user['MechanicID'];
    $_SESSION['depot_id']     = $user['DepotID'];
    $_SESSION['permissions']  = $permissions;

    echo json_encode([
        'ok'   => true,
        'data' => [
            'userId'     => $user['UserID'],
            'username'   => $user['Username'],
            'role'       => $user['RoleName'],
            'roleName'   => $_SESSION['role_display'],
            'driverId'   => $user['DriverID'],
            'mechanicId' => $user['MechanicID'],
            'depotId'    => $user['DepotID'],
        ]
    ]);
    exit;
}

http_response_code(400);
echo json_encode(['ok' => false, 'error' => 'Invalid action.']);
