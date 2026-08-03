<?php
/**
 * Shared database configuration.
 * Include this file in any script that needs DB access.
 * Provides: $pdo (PDO connection object)
 */

// Database credentials
$dbHost    = 'localhost';
$dbName    = 'smart_fleet_management';
$dbUser    = 'root';
$dbPass    = '';
$dbCharset = 'utf8mb4';

// PDO options for secure, consistent behavior
$options = [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
    PDO::ATTR_EMULATE_PREPARES   => false,
];

// Create PDO connection
try {
    $pdo = new PDO(
        "mysql:host=$dbHost;dbname=$dbName;charset=$dbCharset",
        $dbUser,
        $dbPass,
        $options
    );
} catch (PDOException $e) {
    // Don't expose detailed error messages in production
    if (php_sapi_name() === 'cli') {
        die('Database connection failed: ' . $e->getMessage() . "\n");
    }
    
    // For API endpoints (JSON responses)
    if (isset($_SERVER['HTTP_ACCEPT']) && strpos($_SERVER['HTTP_ACCEPT'], 'application/json') !== false) {
        http_response_code(503);
        header('Content-Type: application/json; charset=utf-8');
        echo json_encode(['ok' => false, 'error' => 'Database unavailable']);
        exit;
    }
    
    // For traditional PHP pages (HTML responses)
    die('Database connection failed. Please contact support.');
}
