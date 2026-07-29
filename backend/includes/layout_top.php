<?php
// Expects: $pageTitle (string), $TABLES, $TABLE_GROUPS available
$currentAlias = $_GET['t'] ?? null;
$currentTable = $TABLE_ALIASES_REVERSE[$currentAlias] ?? null;
?>
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title><?= e($pageTitle ?? 'Smart Fleet Management') ?></title>
<link rel="stylesheet" href="<?= ASSET_BASE ?>assets/style.css">
</head>
<body>
<div class="app">
  <aside class="sidebar">
    <div class="brand">
      <span class="brand-mark">🚚</span>
      <div>
        <div class="brand-title">Smart Fleet</div>
        <div class="brand-sub">Management Console</div>
      </div>
    </div>
    <nav>
      <a class="nav-home <?= $currentTable === null && basename($_SERVER['SCRIPT_NAME']) === 'index.php' ? 'active' : '' ?>" href="index.php">📊 Dashboard</a>
      <?php foreach ($TABLE_GROUPS as $group): ?>
        <div class="nav-group"><?= e($group) ?></div>
        <?php foreach ($TABLES as $tName => $navMeta): if (($navMeta['group'] ?? '') !== $group || !isset($navMeta['alias'])) continue; ?>
          <a class="<?= $currentTable === $tName ? 'active' : '' ?>" href="list.php?t=<?= urlencode($navMeta['alias']) ?>">
            <?= e($navMeta['label']) ?>
          </a>
        <?php endforeach; ?>
      <?php endforeach; ?>
    </nav>
  </aside>
  <main class="content">
