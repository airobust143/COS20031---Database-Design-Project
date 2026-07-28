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
$dbPass = ''; // <-- Set your MySQL password here if you have one.
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