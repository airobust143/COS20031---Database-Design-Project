<?php

/** Build a human-readable label for a row given one or more label columns. */
function buildRowLabel(array $row, $fkLabel): string
{
    if (is_array($fkLabel)) {
        return implode(' ', array_map(fn($c) => $row[$c] ?? '', $fkLabel));
    }
    return (string)($row[$fkLabel] ?? '');
}

/** Fetch [pkValue => displayLabel] options for a FK dropdown. */
function fkOptions(PDO $pdo, array $TABLES, string $fkTable): array
{
    if (!isset($TABLES[$fkTable])) {
        return [];
    }
    
    $meta = $TABLES[$fkTable];
    $pkCols = explode(',', $meta['pk']);
    $orderBy = $meta['order_by'] ?? $pkCols[0];
    
    $stmt = $pdo->query("SELECT * FROM `$fkTable` ORDER BY $orderBy");
    $options = [];
    
    foreach ($stmt->fetchAll() as $row) {
        // Handle both single and composite primary keys for option values
        $pkVals = array_map(fn($col) => $row[$col] ?? '', $pkCols);
        $pkValue = implode('-', $pkVals);
        
        $label = $pkValue . ' — ' . guessLabel($row, $meta);
        $options[$pkValue] = $label;
    }
    return $options;
}

/** Guess a reasonable display label for a row of a given table's metadata. */
function guessLabel(array $row, array $meta): string
{
    // Prefer common "name-like" columns if present
    foreach (['Name', 'RegistrationNumber', 'Username', 'RoleName', 'PartNumber', 'CategoryName', 'JobID', 'EventID', 'ScorePeriod', 'ClaimID', 'ActivityID', 'AlertType'] as $col) {
        if (isset($row[$col]) && $row[$col] !== '') return (string)$row[$col];
    }
    if (isset($row['FirstName']) || isset($row['LastName'])) {
        return trim(($row['FirstName'] ?? '') . ' ' . ($row['LastName'] ?? ''));
    }
    // Fallback: first non-pk scalar column
    $pkCols = explode(',', $meta['pk']);
    foreach ($row as $k => $v) {
        if (!in_array($k, $pkCols, true) && !is_array($v) && $v !== null && $v !== '') {
            return (string)$v;
        }
    }
    return 'Record #' . implode('-', array_map(fn($c) => $row[$c] ?? '', $pkCols));
}

/** Format a cell value for display in the list view. */
function formatValue($value, array $col): string
{
    if ($value === null || $value === '') return '<span class="muted">—</span>';
    if ($col['type'] === 'bool') return $value ? '✅' : '—';
    return e((string)$value);
}

/** Parse the (possibly composite) primary key from a query string like "id" or "a=1&b=2". */
function pkFromRequest(array $params, $pkDef): array
{
    $pkCols = explode(',', $pkDef);
    $vals = [];
    foreach ($pkCols as $c) {
        $vals[$c] = $params[$c] ?? null;
    }
    return $vals;
}

/** Build "WHERE col1 = :pk_col1 AND col2 = :pk_col2" from a pk value map. */
function pkWhereClause(array $pkValues): string
{
    $parts = [];
    foreach (array_keys($pkValues) as $c) {
        $parts[] = "`$c` = :pk_$c";
    }
    return implode(' AND ', $parts);
}

/** Escape string for HTML context securely. */
function e($s): string { 
    return htmlspecialchars((string)$s, ENT_QUOTES, 'UTF-8'); 
}