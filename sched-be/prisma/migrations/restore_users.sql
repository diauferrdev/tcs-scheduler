-- Restore users after migration
INSERT INTO "User" (id, email, "passwordHash", name, role, "isActive", "createdAt", "updatedAt")
SELECT id, email, "passwordHash", name,
  CASE
    WHEN role = 'GUEST' THEN 'USER'::text::"UserRole"
    ELSE role
  END as role,
  "isActive", "createdAt", "updatedAt"
FROM users_backup
ON CONFLICT (id) DO NOTHING;

-- Drop backup table
DROP TABLE IF EXISTS users_backup;
