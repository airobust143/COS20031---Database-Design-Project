<?php
session_start();

// If user is already logged in, redirect them to the dashboard.
if (isset($_SESSION['user_id'])) {
    header('Location: index.php');
    exit;
}

require_once __DIR__ . '/includes/db.php';

$error = '';
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $username = $_POST['username'] ?? '';
    $password = $_POST['password'] ?? '';

    if (empty($username) || empty($password)) {
        $error = 'Username and password are required.';
    } else {
        $stmt = $pdo->prepare("SELECT UserID, Username, PasswordHash FROM UserAccount WHERE Username = :username AND IsActive = 1");
        $stmt->execute([':username' => $username]);
        $user = $stmt->fetch();

        // Verify user exists and password is correct.
        // NOTE: This requires a real password hash in the database. See hash_password.php.
        if ($user && password_verify($password, $user['PasswordHash'])) {
            // Store user data in session
            $_SESSION['user_id'] = $user['UserID'];
            $_SESSION['username'] = $user['Username'];

            // Load all permissions for the user's roles into the session.
            $permStmt = $pdo->prepare("
                SELECT DISTINCT p.TableName, p.Action
                FROM UserRole ur
                JOIN RolePermission rp ON ur.RoleID = rp.RoleID
                JOIN Permission p ON rp.PermissionID = p.PermissionID
                WHERE ur.UserID = :user_id
            ");
            $permStmt->execute([':user_id' => $user['UserID']]);
            $permissions = [];
            while ($perm = $permStmt->fetch()) {
                $permissions[$perm['TableName']][] = $perm['Action'];
            }
            $_SESSION['permissions'] = $permissions;

            // Regenerate session ID for security
            session_regenerate_id(true);

            header('Location: index.php');
            exit;
        } else {
            // Use a generic error message to avoid leaking user existence.
            $error = 'Invalid username or password.';
        }
    }
}

$pageTitle = 'Login';
?>
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title><?= e($pageTitle) ?> - Smart Fleet Management</title>
    <link rel="stylesheet" href="<?= ASSET_BASE ?>assets/style.css">
    <style>
        body.login-page { background-color: #f4f7f6; display: flex; justify-content: center; align-items: center; min-height: 100vh; margin: 0; }
        .login-container { background: #fff; padding: 2rem 3rem; border-radius: 8px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); width: 100%; max-width: 400px; }
        .login-container h1 { text-align: center; margin-bottom: 0.5rem; }
        .login-container .brand-mark { display: block; text-align: center; font-size: 3rem; margin-bottom: 1rem; }
        .form-group { margin-bottom: 1.5rem; }
        .form-group label { display: block; margin-bottom: 0.5rem; font-weight: 600; }
        .form-group input { width: 100%; padding: 0.75rem; border: 1px solid #ccc; border-radius: 4px; box-sizing: border-box; }
        .login-btn { width: 100%; padding: 0.8rem; border: none; background-color: #ffb100; color: #333; font-size: 1rem; font-weight: bold; border-radius: 4px; cursor: pointer; }
        .login-error { background-color: #ffebee; color: #c62828; padding: 0.75rem; border-radius: 4px; margin-bottom: 1rem; text-align: center; }
        .alert-success { text-align: center; }
    </style>
</head>
<body class="login-page">
    <div class="login-container">
        <span class="brand-mark">🚚</span>
        <h1>Login</h1>

        <?php if (isset($_GET['logged_out'])): ?>
            <div class="alert alert-success">You have been successfully logged out.</div>
        <?php endif; ?>

        <?php if ($error): ?>
            <div class="login-error"><?= e($error) ?></div>
        <?php endif; ?>

        <form method="post" action="login.php">
            <div class="form-group">
                <label for="username">Username</label>
                <input type="text" id="username" name="username" required autofocus>
            </div>
            <div class="form-group">
                <label for="password">Password</label>
                <input type="password" id="password" name="password" required>
            </div>
            <button type="submit" class="login-btn">Login</button>
        </form>
    </div>
</body>
</html>