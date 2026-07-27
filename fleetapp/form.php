<?php
require __DIR__ . '/includes/db.php';
require __DIR__ . '/includes/tables.php';
require __DIR__ . '/includes/functions.php';

$table = $_GET['table'] ?? $_POST['table'] ?? '';
if (!isset($TABLES[$table])) {
    http_response_code(404);
    die('Unknown table.');
}
$meta = $TABLES[$table];
$pkCols = explode(',', $meta['pk']);
$isComposite = count($pkCols) > 1;

// DETERMINE EDIT STATE FROM A SINGLE SOURCE OF TRUTH
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    if ($isComposite) {
        $isEdit = isset($_POST['__is_edit']) && $_POST['__is_edit'] === '1';
    } else {
        $isEdit = !empty($_POST['__pk']);
    }
} else {
    $pkFromGet = pkFromRequest($_GET, $meta['pk']);
    $isEdit = !in_array(null, $pkFromGet, true) && !in_array('', $pkFromGet, true);
}

$errors = [];
$values = [];

// Preload FK option lists
$fkOptionsByCol = [];
foreach ($meta['columns'] as $col) {
    if ($col['type'] === 'fk') {
        $fkOptionsByCol[$col['name']] = fkOptions($pdo, $TABLES, $col['fk_table']);
    }
}

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    foreach ($meta['columns'] as $col) {
        $name = $col['name'];
        $raw = $_POST[$name] ?? null;
        if ($col['type'] === 'bool') {
            $values[$name] = isset($_POST[$name]) ? 1 : 0;
            continue;
        }
        if ($raw === '') { $raw = null; }
        $values[$name] = $raw;
        if (($col['required'] ?? false) && ($raw === null)) {
            $errors[] = "{$col['label']} is required.";
        }
    }

    // Determine Primary Key values
    if ($isComposite) {
        $pkValues = [];
        foreach ($pkCols as $c) { 
            $pkValues[$c] = $_POST['__orig_' . $c] ?? $values[$c] ?? null; 
        }
    } else {
        $pkValues = [$pkCols[0] => $_POST['__pk'] ?? null];
    }

    if (!$errors) {
        try {
            if ($isEdit) {
                $setParts = [];
                $bind = [];
                foreach ($meta['columns'] as $col) {
                    $colName = $col['name'];
                    
                    // DO NOT include primary key columns in the SET clause during UPDATE
                    if (in_array($colName, $pkCols, true) || ($col['part_of_pk'] ?? false)) {
                        continue;
                    }
                    
                    $setParts[] = "`{$colName}` = :{$colName}";
                    $bind[':' . $colName] = $values[$colName];
                }

                // Skip UPDATE query if table contains only primary key columns
                if (empty($setParts)) {
                    header('Location: list.php?table=' . urlencode($table) . '&saved=1');
                    exit;
                }

                $whereParts = [];
                foreach ($pkValues as $c => $v) {
                    $whereParts[] = "`$c` = :pk_$c";
                    $bind[':pk_' . $c] = $v;
                }
                $sql = "UPDATE `$table` SET " . implode(', ', $setParts) . " WHERE " . implode(' AND ', $whereParts);
                $stmt = $pdo->prepare($sql);
                $stmt->execute($bind);
            } else {
                $insertCols = array_map(fn($c) => $c['name'], $meta['columns']);
                $placeholders = array_map(fn($c) => ':' . $c, $insertCols);
                $bind = [];
                foreach ($insertCols as $c) { $bind[':' . $c] = $values[$c]; }
                $sql = "INSERT INTO `$table` (`" . implode('`, `', $insertCols) . "`) VALUES (" . implode(', ', $placeholders) . ")";
                $stmt = $pdo->prepare($sql);
                $stmt->execute($bind);
            }
            header('Location: list.php?table=' . urlencode($table) . '&saved=1');
            exit;
        } catch (PDOException $e) {
            $errors[] = 'Could not save: ' . $e->getMessage();
        }
    }
} elseif ($isEdit) {
    $pkFromGet = pkFromRequest($_GET, $meta['pk']);
    $where = pkWhereClause($pkFromGet);
    $stmt = $pdo->prepare("SELECT * FROM `$table` WHERE $where");
    $stmt->execute($pkFromGet);
    $row = $stmt->fetch();
    if (!$row) {
        die('Record not found.');
    }
    foreach ($meta['columns'] as $col) {
        $values[$col['name']] = $row[$col['name']];
    }
    $pkValues = $pkFromGet;
} else {
    foreach ($meta['columns'] as $col) {
        $values[$col['name']] = $col['type'] === 'bool' ? 0 : '';
    }
    $pkValues = [];
}

$pageTitle = ($isEdit ? 'Edit' : 'Add') . ' — ' . $meta['label'];
$ASSET_BASE = '';
require __DIR__ . '/includes/layout_top.php';
?>

<h1><?= $isEdit ? 'Edit' : 'Add new' ?> — <?= e($meta['label']) ?></h1>
<p class="page-sub"><a href="list.php?table=<?= urlencode($table) ?>">&larr; Back to <?= e($meta['label']) ?></a></p>

<?php if ($errors): ?>
  <div class="alert alert-error">
    <?php foreach ($errors as $err): ?><div><?= e($err) ?></div><?php endforeach; ?>
  </div>
<?php endif; ?>

<div class="card">
<form method="post" action="form.php">
  <input type="hidden" name="table" value="<?= e($table) ?>">
  <?php if ($isComposite): ?>
    <input type="hidden" name="__is_edit" value="<?= $isEdit ? '1' : '0' ?>">
    <?php foreach ($pkValues as $c => $v): ?>
      <input type="hidden" name="__orig_<?= e($c) ?>" value="<?= e($v) ?>">
    <?php endforeach; ?>
  <?php elseif ($isEdit): ?>
    <input type="hidden" name="__pk" value="<?= e($pkValues[$pkCols[0]] ?? '') ?>">
  <?php endif; ?>

  <div class="form-grid">
    <?php foreach ($meta['columns'] as $col):
        $name = $col['name'];
        $val = $values[$name] ?? '';
        $lockPk = $isEdit && (in_array($name, $pkCols, true) || ($col['part_of_pk'] ?? false));
        $wide = in_array($col['type'], ['textarea']);
    ?>
      <div class="<?= $wide ? 'full' : '' ?>">
        <label for="f_<?= e($name) ?>"><?= e($col['label']) ?><?= ($col['required'] ?? false) ? ' *' : '' ?></label>

        <?php if ($col['type'] === 'fk'): ?>
          <select id="f_<?= e($name) ?>" name="<?= e($name) ?>" <?= $lockPk ? 'disabled' : '' ?> <?= ($col['required'] ?? false) ? 'required' : '' ?>>
            <option value="">— Select <?= e($col['label']) ?> —</option>
            <?php foreach ($fkOptionsByCol[$name] as $optVal => $optLabel): ?>
              <option value="<?= e($optVal) ?>" <?= (string)$val === (string)$optVal ? 'selected' : '' ?>><?= e($optLabel) ?></option>
            <?php endforeach; ?>
          </select>
          <?php if ($lockPk): ?><input type="hidden" name="<?= e($name) ?>" value="<?= e($val) ?>"><?php endif; ?>

        <?php elseif ($col['type'] === 'select'): ?>
          <select id="f_<?= e($name) ?>" name="<?= e($name) ?>" <?= ($col['required'] ?? false) ? 'required' : '' ?>>
            <option value="">— Select —</option>
            <?php foreach ($col['options'] as $opt): ?>
              <option value="<?= e($opt) ?>" <?= (string)$val === (string)$opt ? 'selected' : '' ?>><?= e($opt) ?></option>
            <?php endforeach; ?>
          </select>

        <?php elseif ($col['type'] === 'bool'): ?>
          <div class="checkbox-row">
            <input type="checkbox" id="f_<?= e($name) ?>" name="<?= e($name) ?>" value="1" <?= $val ? 'checked' : '' ?>>
            <span class="muted">Yes</span>
          </div>

        <?php elseif ($col['type'] === 'textarea'): ?>
          <textarea id="f_<?= e($name) ?>" name="<?= e($name) ?>" <?= ($col['required'] ?? false) ? 'required' : '' ?>><?= e($val) ?></textarea>

        <?php elseif ($col['type'] === 'date'): ?>
          <input type="date" id="f_<?= e($name) ?>" name="<?= e($name) ?>" value="<?= e($val) ?>" <?= ($col['required'] ?? false) ? 'required' : '' ?>>

        <?php elseif ($col['type'] === 'datetime'): ?>
          <input type="text" id="f_<?= e($name) ?>" name="<?= e($name) ?>" placeholder="YYYY-MM-DD HH:MM:SS" value="<?= e($val) ?>" <?= ($col['required'] ?? false) ? 'required' : '' ?>>

        <?php elseif ($col['type'] === 'int'): ?>
          <input type="number" step="1" id="f_<?= e($name) ?>" name="<?= e($name) ?>" value="<?= e($val) ?>" <?= ($col['required'] ?? false) ? 'required' : '' ?> <?= $lockPk ? 'readonly' : '' ?>>

        <?php elseif ($col['type'] === 'decimal'): ?>
          <input type="number" step="0.01" id="f_<?= e($name) ?>" name="<?= e($name) ?>" value="<?= e($val) ?>" <?= ($col['required'] ?? false) ? 'required' : '' ?>>

        <?php else: ?>
          <input type="text" id="f_<?= e($name) ?>" name="<?= e($name) ?>" value="<?= e($val) ?>" <?= ($col['required'] ?? false) ? 'required' : '' ?> <?= $lockPk ? 'readonly' : '' ?>>
        <?php endif; ?>
      </div>
    <?php endforeach; ?>
  </div>

  <div class="form-actions">
    <button class="btn btn-amber" type="submit"><?= $isEdit ? 'Save changes' : 'Add record' ?></button>
    <a class="btn btn-outline" href="list.php?table=<?= urlencode($table) ?>">Cancel</a>
  </div>
</form>
</div>

<?php require __DIR__ . '/includes/layout_bottom.php'; ?>