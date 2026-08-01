#!/usr/bin/env node
// Usage: node run_all.js <mysql_user> [mysql_password] [mysql_host]
// Example: node run_all.js root ha431
//          node run_all.js root ha431 localhost

import { createConnection } from 'mysql2/promise';
import { readFileSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import { execFileSync } from 'child_process';

const __dirname = dirname(fileURLToPath(import.meta.url));

const [,, user = 'root', password = '', host = 'localhost'] = process.argv;

const files = [
    '01_core_fleet_schema.sql',
    '02_driver_safety_schema.sql',
    '03_workshops_people_schema.sql',
    '04_maintenance_schema.sql',
    '05_user_role_schema.sql',
    'smartfleet_seed_quick_data.sql',
    '06_procedures_triggers.sql',
    'smartfleet_rbac.sql',
];

// Locate mysql executable
const mysqlPath = process.platform === 'win32'
    ? 'C:\\Program Files\\MySQL\\MySQL Server 8.0\\bin\\mysql.exe'
    : 'mysql';

/**
 * Split a SQL file into individual statements, handling DELIMITER $$ blocks
 * (used for stored procedures/triggers) that mysql2 can't process natively.
 */
function splitStatements(sql) {
    const statements = [];
    let delimiter = ';';
    // Escape delimiter for use in regex
    const escapeRegex = (s) => s.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');

    // Remove /* */ block comments and -- line comments to avoid false matches
    // but keep the line structure intact
    const lines = sql.split('\n');
    let buffer = '';

    for (let i = 0; i < lines.length; i++) {
        const line = lines[i];

        // DELIMITER directive
        const delimMatch = line.match(/^\s*DELIMITER\s+(\S+)\s*$/i);
        if (delimMatch) {
            // flush any pending buffer
            const pending = buffer.trim();
            if (pending) { statements.push(pending); buffer = ''; }
            delimiter = delimMatch[1];
            continue;
        }

        buffer += line + '\n';

        // Check if buffer ends with the current delimiter
        const trimmed = buffer.trimEnd();
        const esc = escapeRegex(delimiter);
        if (new RegExp(esc + '\\s*$').test(trimmed)) {
            // Strip the delimiter off the end
            const stmt = trimmed.slice(0, trimmed.lastIndexOf(delimiter)).trim();
            if (stmt) statements.push(stmt);
            buffer = '';
        }
    }

    const leftover = buffer.trim();
    if (leftover) statements.push(leftover);

    // Filter out empty strings and pure comment blocks
    return statements.filter(s => s.replace(/--[^\n]*/g, '').trim().length > 0);
}

const conn = await createConnection({
    host,
    user,
    password,
    multipleStatements: false,
});

for (const file of files) {
    const filePath = join(__dirname, file);
    process.stdout.write(`>> Running ${file} ... `);
    try {
        // For seed file, use mysql CLI directly (handles complex multi-line INSERTs better)
        if (file === 'smartfleet_seed_quick_data.sql') {
            const args = ['-u', user, '-h', host];
            if (password) args.push(`-p${password}`);
            execFileSync(mysqlPath, args, {
                input: readFileSync(filePath, 'utf8'),
                stdio: ['pipe', 'pipe', 'pipe'],
            });
        } else {
            const sql = readFileSync(filePath, 'utf8');
            const statements = splitStatements(sql);
            for (const stmt of statements) {
                await conn.query(stmt);
            }
        }
        console.log('done');
    } catch (err) {
        console.log('FAILED');
        console.error(`   Error in ${file}: ${err.message || err.stderr?.toString() || err}`);
        await conn.end();
        process.exit(1);
    }
}

await conn.end();
console.log("\n>> Done. Database 'smart_fleet_management' is ready.");
