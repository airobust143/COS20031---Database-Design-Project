<?php
// Database connection (SQLite demo database)

define('ASSET_BASE', rtrim(dirname($_SERVER['SCRIPT_NAME']), '/\\') . '/');

// To point this app at a real MySQL server instead, swap the DSN below, e.g.:
//   new PDO('mysql:host=localhost;dbname=smart_fleet_management;charset=utf8mb4', $user, $pass)

// --- MySQL Connection ---
// Replace with your MySQL server details.
// Default for a local XAMPP/LAMPP server is user 'root' with no password.
$dbHost = 'localhost';
$dbName = 'smart_fleet_management';
$dbUser = 'root';
$dbPass = 'ha431'; // <-- Set your MySQL password here if you have one.
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