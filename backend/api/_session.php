<?php
/**
 * Start the SmartFleet PHP session with a cookie name that cannot collide
 * with other PHP applications (or another local PHP server) on localhost.
 */

function startSmartFleetSession(): void
{
    if (session_status() === PHP_SESSION_ACTIVE) {
        return;
    }

    // Cookies are scoped by host, not port. During development Apache and the
    // PHP built-in server can both run on localhost under different OS users.
    // Including the backend port prevents one server from receiving a session
    // ID whose file was created by (and is unreadable to) the other server.
    $serverPort = preg_replace('/\D/', '', (string) ($_SERVER['SERVER_PORT'] ?? ''));
    session_name('SMARTFLEETCOS20031SESSID' . $serverPort);

    $isHttps = !empty($_SERVER['HTTPS']) && $_SERVER['HTTPS'] !== 'off';
    session_set_cookie_params([
        'lifetime' => 0,
        'path' => '/',
        'secure' => $isHttps,
        'httponly' => true,
        'samesite' => 'Lax',
    ]);
    ini_set('session.use_strict_mode', '1');

    if (!session_start()) {
        error_log('SmartFleet could not start the PHP session.');
        http_response_code(500);
        echo json_encode([
            'ok' => false,
            'error' => 'The server could not start your session. Please try again.',
        ]);
        exit;
    }
}
