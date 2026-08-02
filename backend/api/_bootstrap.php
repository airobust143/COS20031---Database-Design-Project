<?php
/**
 * Shared bootstrap for all JSON API endpoints.
 * Starts session, connects DB, loads helpers, enforces auth.
 * Include at the top of every api/*.php endpoint.
 *
 * Provides: $pdo, hasPermission(), jsonOk(), jsonErr(), $SESSION_USER
 */

header('Content-Type: application/json; charset=utf-8');
// Allow Vite dev-server (port 5173/5174) to call the PHP API (port 80/XAMPP)
$origin = $_SERVER['HTTP_ORIGIN'] ?? '';
$allowed = ['http://localhost:5173', 'http://127.0.0.1:5173', 'http://localhost:5174', 'http://127.0.0.1:5174'];
if (in_array($origin, $allowed, true)) {
    header("Access-Control-Allow-Origin: $origin");
    header('Access-Control-Allow-Credentials: true');
    header('Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS');
    header('Access-Control-Allow-Headers: Content-Type, X-Requested-With');
}
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') { http_response_code(204); exit; }

session_start();

// ── DB connection ─────────────────────────────────────────────────────
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
    echo json_encode(['ok' => false, 'error' => 'Database unavailable: ' . $e->getMessage()]);
    exit;
}

// ── Auth guard ────────────────────────────────────────────────────────
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'error' => 'Not authenticated.']);
    exit;
}

$SESSION_USER = [
    'id'         => $_SESSION['user_id'],
    'username'   => $_SESSION['username'],
    'role'       => $_SESSION['role'],
    'driver_id'  => $_SESSION['driver_id']  ?? null,
    'mechanic_id'=> $_SESSION['mechanic_id'] ?? null,
    'depot_id'   => $_SESSION['depot_id']   ?? null,
    'permissions'=> $_SESSION['permissions'] ?? [],
];

// ── Permission helper ─────────────────────────────────────────────────
function hasPermission(string $table, string $action): bool {
    $perms = $_SESSION['permissions'][$table] ?? [];
    return in_array($action, $perms, true) || in_array('ALL', $perms, true);
}

// ── Response helpers ──────────────────────────────────────────────────
function jsonOk(mixed $data): never {
    echo json_encode(['ok' => true, 'data' => $data]);
    exit;
}

function jsonErr(string $msg, int $code = 400): never {
    http_response_code($code);
    echo json_encode(['ok' => false, 'error' => $msg]);
    exit;
}

function requirePermission(string $table, string $action): void {
    if (!hasPermission($table, $action)) {
        jsonErr("Forbidden: no $action permission on $table.", 403);
    }
}

// ── Read JSON body ────────────────────────────────────────────────────
function readBody(): array {
    $raw = file_get_contents('php://input');
    if (!$raw) return $_POST;
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : $_POST;
}
