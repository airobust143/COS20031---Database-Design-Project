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

require_once __DIR__ . '/_session.php';
startSmartFleetSession();

// ── DB connection ─────────────────────────────────────────────────────
require_once __DIR__ . '/../config/database.php';

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

// Activity-log actor context (read by schema/09_activity_log.sql triggers)
$pdo->prepare('SET @sf_actor_id = ?, @sf_actor_username = ?, @sf_actor_role = ?, @sf_client_ip = ?, @sf_request_id = UUID()')
    ->execute([
        $_SESSION['user_id'] ?? null,
        $_SESSION['username'] ?? null,
        $_SESSION['role'] ?? null,
        $_SERVER['REMOTE_ADDR'] ?? null,
    ]);

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
    $permission = callProcedure(
        $GLOBALS['pdo'],
        'CALL sp_check_user_permission(:user_id, :table_name, :action_name)',
        [
            ':user_id' => $_SESSION['user_id'],
            ':table_name' => $table,
            ':action_name' => $action,
        ]
    )[0][0]['HasPermission'] ?? 0;
    if (!hasPermission($table, $action) || !(int)$permission) {
        jsonErr("Forbidden: no $action permission on $table.", 403);
    }
}

/** Read a trimmed optional query-string value and enforce a safe length. */
function queryOptionalString(string $name, int $maxLength = 100): ?string {
    if (!isset($_GET[$name]) || !is_string($_GET[$name])) return null;
    $value = trim($_GET[$name]);
    if ($value === '') return null;
    if (strlen($value) > $maxLength) jsonErr("Query parameter '$name' is too long.", 422);
    return $value;
}

/** Read an optional positive integer query-string value. */
function queryOptionalPositiveInt(string $name): ?int {
    $value = queryOptionalString($name, 20);
    if ($value === null) return null;
    $validated = filter_var($value, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
    if ($validated === false) jsonErr("Query parameter '$name' must be a positive integer.", 422);
    return (int)$validated;
}

/** Read an optional integer constrained to an inclusive range. */
function queryOptionalBoundedInt(string $name, int $min, int $max): ?int {
    $value = queryOptionalString($name, 20);
    if ($value === null) return null;
    $validated = filter_var($value, FILTER_VALIDATE_INT);
    if ($validated === false || $validated < $min || $validated > $max) {
        jsonErr("Query parameter '$name' must be between $min and $max.", 422);
    }
    return (int)$validated;
}

/** Read an optional value from a fixed allow-list. */
function queryOptionalEnum(string $name, array $allowed): ?string {
    $value = queryOptionalString($name);
    if ($value !== null && !in_array($value, $allowed, true)) {
        jsonErr("Query parameter '$name' has an invalid value.", 422);
    }
    return $value;
}

/** Read and validate an optional ISO YYYY-MM-DD date. */
function queryOptionalDate(string $name): ?string {
    $value = queryOptionalString($name, 10);
    if ($value === null) return null;
    $date = DateTimeImmutable::createFromFormat('!Y-m-d', $value);
    if (!$date || $date->format('Y-m-d') !== $value) {
        jsonErr("Query parameter '$name' must use YYYY-MM-DD format.", 422);
    }
    return $value;
}

/** Read a query-string boolean expressed as 1/0 or true/false. */
function queryBoolean(string $name, bool $default = false): bool {
    if (!isset($_GET[$name])) return $default;
    $value = filter_var($_GET[$name], FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE);
    if ($value === null) jsonErr("Query parameter '$name' must be a boolean.", 422);
    return $value;
}

/** Execute a read-only procedure and consume every result set. */
function callProcedure(PDO $pdo, string $sql, array $parameters = []): array {
    $stmt = $pdo->prepare($sql);
    $stmt->execute($parameters);
    $resultSets = [];
    do {
        if ($stmt->columnCount() > 0) {
            $resultSets[] = $stmt->fetchAll(PDO::FETCH_ASSOC);
        }
    } while ($stmt->nextRowset());
    $stmt->closeCursor();
    return $resultSets;
}

// ── Read JSON body ────────────────────────────────────────────────────
function readBody(): array {
    $raw = file_get_contents('php://input');
    if (!$raw) return $_POST;
    $decoded = json_decode($raw, true);
    return is_array($decoded) ? $decoded : $_POST;
}
