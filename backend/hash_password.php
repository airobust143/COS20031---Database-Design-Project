<?php
/**
 * Password Hashing Utility
 *
 * Use this script from the command line to generate a secure password hash
 * for the UserAccount table.
 *
 * Usage:
 *   php hash_password.php your_password_here
 *
 * Example:
 *   php hash_password.php my-secure-password123
 *   > $2y$10$P... (a long hash string will be printed)
 *
 * Copy the resulting hash and paste it into the PasswordHash column
 * in your database for a user.
 */
if (php_sapi_name() !== 'cli') { die('This script must be run from the command line.'); }

if (isset($argv[1])) {
    echo password_hash($argv[1], PASSWORD_DEFAULT);
    echo "\n";
} else {
    echo "Usage: php " . basename(__FILE__) . " <password_to_hash>\n";
}