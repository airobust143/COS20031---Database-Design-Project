<?php
require __DIR__ . '/includes/db.php';

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    die('Method not allowed.');
}

$alias = $_POST['t'] ?? '';
$table = $TABLE_ALIASES_REVERSE[$alias] ?? null;
if ($table === null || !isset($TABLES[$table])) {
    http_response_code(404);
    die('Unknown resource.');
}
$meta = $TABLES[$table];
$pkCols = explode(',', $meta['pk']);
$pkValues = [];
foreach ($pkCols as $c) { $pkValues[$c] = $_POST[$c] ?? null; }

$error = null;
try {
    $where = pkWhereClause($pkValues);
    $bind = [];
    foreach ($pkValues as $c => $v) {
        $bind[':pk_' . $c] = $v;
    }
    $stmt = $pdo->prepare("DELETE FROM `$table` WHERE $where");
    $stmt->execute($bind);
} catch (PDOException $e) {
    $error = $e->getMessage();
}

if ($error) {
    // Referential integrity or other failure — send back with a friendly message via session-less query string
    header('Location: list.php?t=' . urlencode($alias) . '&delerror=' . urlencode('This record is referenced by other data and cannot be deleted while those links exist.'));
    exit;
}

header('Location: list.php?t=' . urlencode($alias) . '&deleted=1');
exit;
