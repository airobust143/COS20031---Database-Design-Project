<?php
session_start();

// --- Authentication Check ---
// All pages except login.php require an authenticated user.
$isLoginPage = basename($_SERVER['SCRIPT_NAME']) === 'login.php';
if (!isset($_SESSION['user_id']) && !$isLoginPage) {
    // If not logged in and not on the login page, redirect to login.
    header('Location: login.php');
    exit;
}

define('ASSET_BASE', rtrim(dirname($_SERVER['SCRIPT_NAME']), '/\\') . '/');

// --- MySQL Connection ---
// Default for a local XAMPP/LAMPP server is user 'root' with no password.
$dbHost = 'localhost';
$dbName = 'smart_fleet_management';
$dbUser = 'root';
$dbPass = '';
$dbCharset = 'utf8mb4';

$dsn = "mysql:host=$dbHost;dbname=$dbName;charset=$dbCharset";

$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];

try {
    $pdo = new PDO($dsn, $dbUser, $dbPass, $options);
} catch (PDOException $e) {
    die('Database connection failed: ' . htmlspecialchars($e->getMessage()));
}

// --- Application Bootstrap ---

// Load core application files
require_once __DIR__ . '/tables.php';
require_once __DIR__ . '/functions.php';

/**
 * Checks if the currently logged-in user has a specific permission.
 * @param string $table The name of the table.
 * @param string $action The action to check (e.g., 'SELECT', 'INSERT', 'UPDATE', 'DELETE').
 * @return bool True if the user has the permission, false otherwise.
 */
function hasPermission(string $table, string $action): bool {
    if (!isset($_SESSION['permissions'])) {
        return false; // Should not happen for a logged-in user.
    }
    // Check for specific permission (e.g., 'UPDATE') or a wildcard 'ALL' permission.
    $userPerms = $_SESSION['permissions'][$table] ?? [];
    return in_array($action, $userPerms) || in_array('ALL', $userPerms);
}

// Build a reverse map from alias to table name for URL shortening.
// This ensures table names are not exposed in URLs.
$TABLE_ALIASES_REVERSE = [];
foreach ($TABLES as $tableName => $meta) {
    if (isset($meta['alias'])) {
        if (isset($TABLE_ALIASES_REVERSE[$meta['alias']])) {
            // This is a developer error, a duplicate alias.
            die("FATAL: Duplicate table alias '{$meta['alias']}' defined in tables.php.");
        }
        $TABLE_ALIASES_REVERSE[$meta['alias']] = $tableName;
    } else {
        // For robust security, we require all tables to have an alias.
        die("FATAL: Table '{$tableName}' is missing an 'alias' key in includes/tables.php.");
    }
}