<?php
// Database connection (SQLite demo database)

define('ASSET_BASE', rtrim(dirname($_SERVER['SCRIPT_NAME']), '/\\') . '/');

// To point this app at a real MySQL server instead, swap the DSN below, e.g.:
//   new PDO('mysql:host=localhost;dbname=smart_fleet_management;charset=utf8mb4', $user, $pass)

$dbPath = __DIR__ . '/../db/fleet.sqlite';

if (!file_exists($dbPath)) {
    die('Database file not found at: ' . htmlspecialchars($dbPath));
}

try {
    $pdo = new PDO('sqlite:' . $dbPath);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
    $pdo->exec('PRAGMA foreign_keys = ON');
} catch (PDOException $e) {
    die('Database connection failed: ' . htmlspecialchars($e->getMessage()));
}