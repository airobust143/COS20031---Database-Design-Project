
-- Login attempt tracking for brute-force protection

USE `smart_fleet_management`;

CREATE TABLE IF NOT EXISTS `login_attempts` (
    `id`         INT UNSIGNED    NOT NULL AUTO_INCREMENT,
    `ip`         VARCHAR(45)     NOT NULL COMMENT 'IPv4 or IPv6 address',
    `attempted_at` DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4
  COMMENT='Tracks failed login attempts per IP for rate-limiting.';


