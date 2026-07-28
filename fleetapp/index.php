<?php
require __DIR__ . '/includes/db.php';
require __DIR__ . '/includes/tables.php';
require __DIR__ . '/includes/functions.php';

$pageTitle = 'Dashboard';

/** Helper function to return a single scalar integer count from SQL. */
function count1(PDO $pdo, string $sql): int {
    return (int)$pdo->query($sql)->fetchColumn();
}

$kpis = [
    ['label' => 'Active Vehicles', 'value' => count1($pdo, "SELECT COUNT(*) FROM Vehicles WHERE OperationalStatus IN ('Active','Available')")],
    ['label' => 'Vehicles Under Maintenance', 'value' => count1($pdo, "SELECT COUNT(*) FROM Vehicles WHERE OperationalStatus = 'Under Maintenance'"), 'warn' => true],
    ['label' => 'Active Drivers', 'value' => count1($pdo, "SELECT COUNT(*) FROM Drivers WHERE EmploymentStatus = 'Active'")],
    ['label' => 'Safety Events Pending Review', 'value' => count1($pdo, "SELECT COUNT(*) FROM SafetyEvents WHERE ReviewStatus IN ('Pending','In Review')"), 'warn' => true],
    ['label' => 'Open Maintenance Jobs', 'value' => count1($pdo, "SELECT COUNT(*) FROM MaintenanceJobs WHERE DateClosed IS NULL")],
    ['label' => 'Unresolved Predictive Alerts', 'value' => count1($pdo, "SELECT COUNT(*) FROM PredictiveAlert WHERE Status != 'Resolved'"), 'warn' => true],
];

require __DIR__ . '/includes/layout_top.php';
?>

<h1>Fleet overview</h1>
<p class="page-sub">Snapshot across depots in Ha Noi, Da Nang, Ho Chi Minh City and Can Tho.</p>

<div class="kpi-grid">
  <?php foreach ($kpis as $k): ?>
    <div class="kpi <?= !empty($k['warn']) && $k['value'] > 0 ? 'warn' : '' ?>">
      <div class="num"><?= $k['value'] ?></div>
      <div class="lbl"><?= e($k['label']) ?></div>
    </div>
  <?php endforeach; ?>
</div>

<?php foreach ($TABLE_GROUPS as $group): ?>
  <h2><?= e($group) ?></h2>
  <div class="group-tiles">
    <?php foreach ($TABLES as $tName => $meta): if ($meta['group'] !== $group) continue;
      $count = count1($pdo, "SELECT COUNT(*) FROM `$tName`");
    ?>
      <a class="group-tile" href="list.php?table=<?= urlencode($tName) ?>">
        <div class="g-title"><?= e($meta['label']) ?></div>
        <div class="g-count"><?= $count ?> record<?= $count === 1 ? '' : 's' ?></div>
      </a>
    <?php endforeach; ?>
  </div>
<?php endforeach; ?>

<?php require __DIR__ . '/includes/layout_bottom.php'; ?>