<?php
require __DIR__ . '/includes/db.php';

$alias = $_GET['t'] ?? '';
$table = $TABLE_ALIASES_REVERSE[$alias] ?? null;
if ($table === null || !isset($TABLES[$table])) {
    http_response_code(404); die('Unknown resource.');
}

// --- Authorization Check ---
if (!hasPermission($table, 'SELECT')) {
    http_response_code(403);
    die('Forbidden: You do not have permission to view this resource.');
}

$meta = $TABLES[$table];
$pkCols = explode(',', $meta['pk']);
$isComposite = count($pkCols) > 1;

// Preload FK label maps for any FK columns on this table
$fkMaps = [];
foreach ($meta['columns'] as $col) {
    if ($col['type'] === 'fk') {
        $fkMaps[$col['name']] = fkOptions($pdo, $TABLES, $col['fk_table']);
    }
}

// Simple keyword search across non-fk text-ish columns
$q = trim($_GET['q'] ?? '');
$where = '';
$params = [];
if ($q !== '') {
    $searchable = array_filter($meta['columns'], fn($c) => in_array($c['type'], ['text', 'textarea']));
    if ($searchable) {
        $likes = [];
        foreach ($searchable as $c) {
            $likes[] = "`{$c['name']}` LIKE :q";
        }
        $where = 'WHERE ' . implode(' OR ', $likes);
        $params[':q'] = '%' . $q . '%';
    }
}

$sql = "SELECT * FROM `$table` $where ORDER BY {$meta['order_by']}";
$stmt = $pdo->prepare($sql);
$stmt->execute($params);
$rows = $stmt->fetchAll();

$listColumns = array_filter($meta['columns'], fn($c) => $c['list'] ?? true);

$pageTitle = $meta['label'];
require __DIR__ . '/includes/layout_top.php';
?>

<?php if (isset($_GET['saved'])): ?>
  <div class="alert alert-success">Record saved successfully.</div>
<?php elseif (isset($_GET['deleted'])): ?>
  <div class="alert alert-success">Record deleted.</div>
<?php elseif (isset($_GET['delerror'])): ?>
  <div class="alert alert-error"><?= e($_GET['delerror']) ?></div>
<?php endif; ?>

<div class="topbar">
  <div>
    <h1><?= e($meta['label']) ?></h1>
    <p class="page-sub"><?= count($rows) ?> record<?= count($rows) === 1 ? '' : 's' ?><?= $q !== '' ? ' matching “' . e($q) . '”' : '' ?></p>
  </div>
  <div style="display:flex; gap:10px;">
    <form method="get" style="display:flex; gap:6px;">
      <input type="hidden" name="t" value="<?= e($alias) ?>">
      <input type="text" name="q" placeholder="Search…" value="<?= e($q) ?>" style="width:200px;">
      <button class="btn btn-outline" type="submit">Search</button>
    </form>
    <?php if ($table !== 'UserAccount' && hasPermission($table, 'INSERT')): ?>
      <a class="btn btn-amber" href="form.php?t=<?= urlencode($alias) ?>">+ Add new</a>
    <?php endif; ?>
  </div>
</div>

<?php if (!$rows): ?>
  <div class="empty-state card">
    <div class="big">🗂️</div>
    <p><?= $q !== '' ? 'No records match your search.' : 'No records yet.' ?></p>
    <?php if ($table === 'UserAccount'): ?>
      <?php if (hasPermission('UserAccount', 'INSERT') && hasPermission('UserRole', 'INSERT')): ?>
        <a class="btn btn-amber" href="create_account.php">+ Create the first account</a>
      <?php endif; ?>
    <?php elseif (hasPermission($table, 'INSERT')): ?>
      <a class="btn btn-amber" href="form.php?t=<?= urlencode($alias) ?>">+ Add the first record</a>
    <?php endif; ?>
  </div>
<?php else: ?>
<div style="overflow-x:auto;">
<table>
  <thead>
    <tr>
      <?php foreach ($listColumns as $col): ?>
        <th><?= e($col['label']) ?></th>
      <?php endforeach; ?>
      <th></th>
    </tr>
  </thead>
  <tbody>
    <?php foreach ($rows as $row):
        $pkVals = [];
        foreach ($pkCols as $c) { $pkVals[$c] = $row[$c]; }
        $qsPk = http_build_query($pkVals);
    ?>
      <tr>
        <?php foreach ($listColumns as $col):
            $val = $row[$col['name']] ?? null;
        ?>
          <td>
            <?php if ($col['type'] === 'fk'): ?>
              <?= e($fkMaps[$col['name']][$val] ?? ($val !== null ? '#' . $val : '—')) ?>
            <?php elseif ($col['type'] === 'select' && $val): ?>
              <span class="badge badge-<?= e(str_replace(' ', '-', $val)) ?>"><?= e($val) ?></span>
            <?php elseif (in_array($col['name'], $pkCols) && !$isComposite): ?>
              <span class="id-cell">#<?= e($val) ?></span>
            <?php else: ?>
              <?= formatValue($val, $col) ?>
            <?php endif; ?>
          </td>
        <?php endforeach; ?>
        <td class="actions-cell">
          <?php if (hasPermission($table, 'UPDATE')): ?>
            <a class="btn btn-outline btn-sm" href="form.php?t=<?= urlencode($alias) ?>&<?= $qsPk ?>">Edit</a>
          <?php endif; ?>
          <?php if (hasPermission($table, 'DELETE')): ?>
            <form class="inline" method="post" action="delete.php" onsubmit="return confirm('Delete this record? This cannot be undone.');">
              <input type="hidden" name="t" value="<?= e($alias) ?>">
              <?php foreach ($pkVals as $c => $v): ?>
                <input type="hidden" name="<?= e($c) ?>" value="<?= e($v) ?>">
              <?php endforeach; ?>
              <button class="btn btn-danger btn-sm" type="submit">Delete</button>
            </form>
          <?php endif; ?>
        </td>
      </tr>
    <?php endforeach; ?>
  </tbody>
</table>
</div>
<?php endif; ?>

<?php require __DIR__ . '/includes/layout_bottom.php'; ?>
