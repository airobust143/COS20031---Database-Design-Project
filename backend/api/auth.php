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

// Start the shared app session without the protected-endpoint auth guard.
require_once __DIR__ . '/_session.php';
startSmartFleetSession();

// Load shared database configuration
require_once __DIR__ . '/../config/database.php';

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

    if (strlen($password) > 72) {
        // Reject before DB lookup — bcrypt silently truncates at 72 bytes,
        // so a 100-char password and its 72-char prefix would verify identically.
        http_response_code(400);
        echo json_encode(['ok' => false, 'error' => 'Password must be 72 characters or fewer.']);
        exit;
    }

    // ── Brute-force rate limiting ─────────────────────────────────────
    // Track by client IP: max 5 failures in a 15-minute window.
    // The window is sliding — each check looks at the last 15 minutes.
    define('LOGIN_MAX_ATTEMPTS',  5);
    define('LOGIN_WINDOW_SECONDS', 15 * 60);

    $ip = $_SERVER['HTTP_X_FORWARDED_FOR']
        ?? $_SERVER['REMOTE_ADDR']
        ?? '0.0.0.0';
    // X-Forwarded-For can be a comma-separated list; take the first (client) IP.
    $ip = trim(explode(',', $ip)[0]);
    // Normalise and cap to the column length.
    $ip = substr(filter_var($ip, FILTER_VALIDATE_IP) ?: '0.0.0.0', 0, 45);

    // Purge stale rows older than the window to keep the table small.
    $pdo->prepare("DELETE FROM login_attempts WHERE attempted_at < DATE_SUB(NOW(), INTERVAL :w SECOND)")
        ->execute([':w' => LOGIN_WINDOW_SECONDS]);

    // Count recent failures for this IP.
    $countStmt = $pdo->prepare(
        "SELECT COUNT(*) FROM login_attempts
         WHERE ip = :ip AND attempted_at >= DATE_SUB(NOW(), INTERVAL :w SECOND)"
    );
    $countStmt->execute([':ip' => $ip, ':w' => LOGIN_WINDOW_SECONDS]);
    $recentFailures = (int) $countStmt->fetchColumn();

    if ($recentFailures >= LOGIN_MAX_ATTEMPTS) {
        http_response_code(429);
        echo json_encode(['ok' => false, 'error' => 'Too many failed attempts. Please wait 15 minutes and try again.']);
        exit;
    }
    // ─────────────────────────────────────────────────────────────────

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

    // Always run password_verify even when no user is found so that both
    // the "wrong username" and "wrong password" paths take the same amount
    // of time (bcrypt cost). Without this, a missing user returns instantly
    // because the short-circuit &&  skips the hash, leaking which usernames exist.
    $hashToCheck = $user ? $user['PasswordHash'] : '$2y$10$dummyhashfortimingnobodycanloginwiththis00000000000000000';
    $passwordOk  = password_verify($password, $hashToCheck);

    if (!$user || !$passwordOk) {
        // Record this failure for rate-limiting.
        $pdo->prepare("INSERT INTO login_attempts (ip) VALUES (:ip)")
            ->execute([':ip' => $ip]);

        http_response_code(401);
        echo json_encode(['ok' => false, 'error' => 'Invalid username or password.']);
        exit;
    }

    // Successful login — clear this IP's failure history.
    $pdo->prepare("DELETE FROM login_attempts WHERE ip = :ip")
        ->execute([':ip' => $ip]);

    // Transparently upgrade the stored hash if PASSWORD_DEFAULT's algorithm
    // or cost factor has changed since this account was last authenticated.
    if (password_needs_rehash($user['PasswordHash'], PASSWORD_DEFAULT)) {
        $newHash = password_hash($password, PASSWORD_DEFAULT);
        $pdo->prepare("UPDATE UserAccount SET PasswordHash = :h WHERE UserID = :id")
            ->execute([':h' => $newHash, ':id' => $user['UserID']]);
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
