<?php
require __DIR__ . '/includes/db.php';

// --- Authorization Check ---
// Creating an account touches both UserAccount and UserRole, so require
// INSERT permission on both — currently only fleet_admin has this combination.
if (!hasPermission('UserAccount', 'INSERT') || !hasPermission('UserRole', 'INSERT')) {
    http_response_code(403);
    die('Forbidden: You do not have permission to create new user accounts.');
}

$errors = [];
$values = [
    'Username'   => '',
    'Password'   => '',
    'IsActive'   => 1,
    'DriverID'   => '',
    'MechanicID' => '',
    'DepotID'    => '',
];
$selectedRoleId = '';

// Load reference data for the form.
$roles = $pdo->query("SELECT RoleID, RoleName FROM Role ORDER BY RoleName")->fetchAll();
$driverOptions = fkOptions($pdo, $TABLES, 'Drivers');
$mechanicOptions = fkOptions($pdo, $TABLES, 'Mechanic');
$depotOptions = fkOptions($pdo, $TABLES, 'Depots');

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $values['Username']   = trim($_POST['Username'] ?? '');
    $values['Password']   = (string)($_POST['Password'] ?? '');
    $confirmPassword      = (string)($_POST['ConfirmPassword'] ?? '');
    $values['IsActive']   = isset($_POST['IsActive']) ? 1 : 0;
    $values['DriverID']   = $_POST['DriverID'] ?? '';
    $values['MechanicID'] = $_POST['MechanicID'] ?? '';
    $values['DepotID']    = $_POST['DepotID'] ?? '';
    $selectedRoleId       = $_POST['RoleID'] ?? '';

    // --- Validation ---
    if ($values['Username'] === '') {
        $errors[] = 'Username is required.';
    } elseif (!preg_match('/^[A-Za-z0-9_.]{3,50}$/', $values['Username'])) {
        $errors[] = 'Username must be 3–50 characters and may only contain letters, numbers, dots, and underscores.';
    }

    if ($values['Password'] === '') {
        $errors[] = 'Password is required.';
    } elseif (strlen($values['Password']) < 8) {
        $errors[] = 'Password must be at least 8 characters.';
    } elseif ($values['Password'] !== $confirmPassword) {
        $errors[] = 'Password and confirmation do not match.';
    }

    if ($selectedRoleId === '') {
        $errors[] = 'Select a role to grant.';
    } else {
        $validRoleIds = array_column($roles, 'RoleID');
        if (!in_array((int)$selectedRoleId, $validRoleIds, true)) {
            $errors[] = 'The selected role is invalid.';
        }
    }

    if (!$errors && $values['Username'] !== '') {
        $dupStmt = $pdo->prepare('SELECT 1 FROM UserAccount WHERE Username = :u');
        $dupStmt->execute([':u' => $values['Username']]);
        if ($dupStmt->fetch()) {
            $errors[] = 'That username is already taken.';
        }
    }

    if (!$errors) {
        try {
            $pdo->beginTransaction();

            $passwordHash = password_hash($values['Password'], PASSWORD_DEFAULT);

            $insertStmt = $pdo->prepare("
                INSERT INTO UserAccount (Username, PasswordHash, IsActive, DriverID, MechanicID, DepotID)
                VALUES (:username, :hash, :active, :driver, :mechanic, :depot)
            ");
            $insertStmt->execute([
                ':username' => $values['Username'],
                ':hash'     => $passwordHash,
                ':active'   => $values['IsActive'],
                ':driver'   => $values['DriverID'] !== '' ? $values['DriverID'] : null,
                ':mechanic' => $values['MechanicID'] !== '' ? $values['MechanicID'] : null,
                ':depot'    => $values['DepotID'] !== '' ? $values['DepotID'] : null,
            ]);
            $newUserId = (int)$pdo->lastInsertId();

            $roleStmt = $pdo->prepare("
                INSERT INTO UserRole (UserID, RoleID, GrantedDate) VALUES (:uid, :rid, CURRENT_DATE)
            ");
            $roleStmt->execute([':uid' => $newUserId, ':rid' => (int)$selectedRoleId]);

            $pdo->commit();

            header('Location: list.php?t=' . urlencode($TABLES['UserAccount']['alias']) . '&saved=1');
            exit;
        } catch (PDOException $e) {
            $pdo->rollBack();
            $errors[] = 'Could not create account: ' . $e->getMessage();
        }
    }
}

$pageTitle = 'Create Account & Grant Roles';
require __DIR__ . '/includes/layout_top.php';
?>

<h1>Create a new account &amp; grant roles</h1>
<p class="page-sub">Available to accounts with INSERT permission on User Accounts and User ↔ Roles. This creates a login and assigns its roles in one step.</p>

<?php if ($errors): ?>
  <div class="alert alert-error">
    <?php foreach ($errors as $err): ?><div><?= e($err) ?></div><?php endforeach; ?>
  </div>
<?php endif; ?>

<div class="card">
<form method="post" action="create_account.php">
  <div class="form-grid">
    <div>
      <label for="f_username">Username *</label>
      <input type="text" id="f_username" name="Username" value="<?= e($values['Username']) ?>" required autofocus>
    </div>

    <div>
      <label for="f_active">Active?</label>
      <div class="checkbox-row">
        <input type="checkbox" id="f_active" name="IsActive" value="1" <?= $values['IsActive'] ? 'checked' : '' ?>>
        <span class="muted">Account can log in immediately</span>
      </div>
    </div>

    <div>
      <label for="f_password">Password *</label>
      <input type="password" id="f_password" name="Password" required minlength="8" autocomplete="new-password">
    </div>

    <div>
      <label for="f_confirm">Confirm password *</label>
      <input type="password" id="f_confirm" name="ConfirmPassword" required minlength="8" autocomplete="new-password">
    </div>

    <div>
      <label for="f_driver">Linked Driver</label>
      <select id="f_driver" name="DriverID">
        <option value="">— None —</option>
        <?php foreach ($driverOptions as $optVal => $optLabel): ?>
          <option value="<?= e($optVal) ?>" <?= (string)$values['DriverID'] === (string)$optVal ? 'selected' : '' ?>><?= e($optLabel) ?></option>
        <?php endforeach; ?>
      </select>
    </div>

    <div>
      <label for="f_mechanic">Linked Mechanic</label>
      <select id="f_mechanic" name="MechanicID">
        <option value="">— None —</option>
        <?php foreach ($mechanicOptions as $optVal => $optLabel): ?>
          <option value="<?= e($optVal) ?>" <?= (string)$values['MechanicID'] === (string)$optVal ? 'selected' : '' ?>><?= e($optLabel) ?></option>
        <?php endforeach; ?>
      </select>
    </div>

    <div>
      <label for="f_depot">Depot</label>
      <select id="f_depot" name="DepotID">
        <option value="">— None —</option>
        <?php foreach ($depotOptions as $optVal => $optLabel): ?>
          <option value="<?= e($optVal) ?>" <?= (string)$values['DepotID'] === (string)$optVal ? 'selected' : '' ?>><?= e($optLabel) ?></option>
        <?php endforeach; ?>
      </select>
    </div>

    <div>
      <label for="f_role">Role *</label>
      <select id="f_role" name="RoleID" required>
        <option value="">— Select role —</option>
        <?php foreach ($roles as $role): ?>
          <option value="<?= (int)$role['RoleID'] ?>" <?= (string)$selectedRoleId === (string)$role['RoleID'] ? 'selected' : '' ?>><?= e($role['RoleName']) ?></option>
        <?php endforeach; ?>
      </select>
    </div>
  </div>

  <div class="form-actions">
    <button class="btn btn-amber" type="submit">Create account</button>
    <a class="btn btn-outline" href="list.php?t=<?= urlencode($TABLES['UserAccount']['alias']) ?>">Cancel</a>
  </div>
</form>
</div>

<?php require __DIR__ . '/includes/layout_bottom.php'; ?>