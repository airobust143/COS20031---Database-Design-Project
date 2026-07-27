<?php
require __DIR__ . '/includes/db.php';
require __DIR__ . '/includes/tables.php';
require __DIR__ . '/includes/functions.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die('Method not allowed.');
}

$table = $_POST['table'] ?? '';
if (!isset($TABLES[$table])) {
    http_response_code(404);
    die('Unknown table.');
}
$meta = $TABLES[$table];
$pkCols = explode(',', $meta['pk']);
$pkValues = [];
foreach ($pkCols as $c) { $pkValues[$c] = $_POST[$c] ?? null; }

$error = null;
try {
    $where = pkWhereClause($pkValues);
    $stmt = $pdo->prepare("DELETE FROM `$table` WHERE $where");
    $stmt->execute($pkValues);
} catch (PDOException $e) {
    $error = $e->getMessage();
}

if ($error) {
    // Referential integrity or other failure — send back with a friendly message via session-less query string
    header('Location: list.php?table=' . urlencode($table) . '&delerror=' . urlencode('This record is referenced by other data and cannot be deleted while those links exist.'));
    exit;
}

header('Location: list.php?table=' . urlencode($table) . '&deleted=1');
exit;
