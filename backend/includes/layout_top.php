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
    <a href="index.php" class="brand">
      <span class="brand-icon">🚚</span>
      <div>
        <div class="brand-title">Smart Fleet</div>
        <div class="brand-sub">Management Console</div>
      </div>
    </a>
    <div class="user-panel">
      <div class="user-info">
        Logged in as: <strong><?= e($_SESSION['username'] ?? 'N/A') ?></strong>
      </div>
      <a href="logout.php" class="logout-link">Logout &rarr;</a>
    </div>
    <nav>
      <a class="nav-home <?= $currentTable === null && basename($_SERVER['SCRIPT_NAME']) === 'index.php' ? 'active' : '' ?>" href="index.php">📊 Dashboard</a>
      <?php if (hasPermission('UserAccount', 'INSERT') && hasPermission('UserRole', 'INSERT')): ?>
        <a class="nav-home <?= basename($_SERVER['SCRIPT_NAME']) === 'create_account.php' ? 'active' : '' ?>" href="create_account.php">➕ New Account</a>
      <?php endif; ?>
      <?php foreach ($TABLE_GROUPS as $group): ?>
        <div class="nav-group"><?= e($group) ?></div>
        <?php foreach ($TABLES as $tName => $navMeta):
          if (($navMeta['group'] ?? '') !== $group || !isset($navMeta['alias'])) continue;
          if (!hasPermission($tName, 'SELECT')) continue;
        ?>
          <a class="nav-link <?= $currentTable === $tName ? 'active' : '' ?>" href="list.php?t=<?= urlencode($navMeta['alias']) ?>">
            <?= e($navMeta['label']) ?>
          </a>
        <?php endforeach; ?>
      <?php endforeach; ?>
    </nav>
  </aside>
  <main class="content">
