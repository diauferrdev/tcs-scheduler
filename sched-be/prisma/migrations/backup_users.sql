-- Backup users before migration
CREATE TABLE IF NOT EXISTS users_backup AS
SELECT * FROM "User";
