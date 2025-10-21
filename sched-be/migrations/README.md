# Database Migrations

Este diretório contém as migrations SQL para o banco de dados de produção.

## Bug Reports System Migration

**Arquivo**: `add_bug_reports_system.sql`
**Data**: 2025-10-21

### O que adiciona:

1. **Novos Enums**:
   - `Platform`: WINDOWS, LINUX, MACOS, ANDROID, IOS, WEB
   - `BugStatus`: OPEN, IN_PROGRESS, RESOLVED, CLOSED

2. **Novas Tabelas**:
   - `BugReport`: Relatórios de bugs com título, descrição, status, likes
   - `BugAttachment`: Anexos (imagens, vídeos) dos bugs
   - `BugComment`: Sistema de comentários nos bugs
   - `BugLike`: Sistema de likes nos bugs

3. **Novos Tipos de Notificação**:
   - `BUG_REPORT_CREATED`: Notifica ADMINs quando bug é criado
   - `BUG_REPORT_RESOLVED`: Notifica reporter quando bug é resolvido

### Como aplicar na VPS de Produção:

#### Opção 1: Via psql (Recomendado)

```bash
# 1. SSH na VPS
ssh user@your-vps-ip

# 2. Navegue até o diretório do projeto
cd /path/to/tcs-sched/sched-be

# 3. Faça pull das últimas mudanças
git pull origin main

# 4. Aplique a migration
psql -U seu_usuario_postgres -d tcs_scheduler -f migrations/add_bug_reports_system.sql
```

#### Opção 2: Via Docker (se estiver usando Docker)

```bash
# 1. SSH na VPS
ssh user@your-vps-ip

# 2. Navegue até o diretório do projeto
cd /path/to/tcs-sched/sched-be

# 3. Faça pull das últimas mudanças
git pull origin main

# 4. Aplique a migration via Docker
docker exec -i postgres_container psql -U seu_usuario -d tcs_scheduler < migrations/add_bug_reports_system.sql
```

#### Opção 3: Copiar e Executar SQL Diretamente

Se você tiver acesso a um cliente PostgreSQL (pgAdmin, DBeaver, etc.):

1. Abra o arquivo `migrations/add_bug_reports_system.sql`
2. Copie todo o conteúdo
3. Execute no seu cliente PostgreSQL conectado ao banco `tcs_scheduler`

### Verificar se a migration foi aplicada com sucesso:

```sql
-- Verificar se as tabelas foram criadas
SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_name IN ('BugReport', 'BugComment', 'BugAttachment', 'BugLike');

-- Verificar se os enums foram criados
SELECT typname
FROM pg_type
WHERE typname IN ('Platform', 'BugStatus');

-- Contar registros (deve ser 0 após migration)
SELECT
  (SELECT COUNT(*) FROM "BugReport") as bug_reports,
  (SELECT COUNT(*) FROM "BugComment") as comments,
  (SELECT COUNT(*) FROM "BugAttachment") as attachments,
  (SELECT COUNT(*) FROM "BugLike") as likes;
```

### Rollback (em caso de problemas):

```sql
-- ATENÇÃO: Isso vai deletar todas as tabelas de Bug Reports!
-- Use apenas se algo deu errado e você quer reverter

DROP TABLE IF EXISTS "BugLike" CASCADE;
DROP TABLE IF EXISTS "BugComment" CASCADE;
DROP TABLE IF EXISTS "BugAttachment" CASCADE;
DROP TABLE IF EXISTS "BugReport" CASCADE;
DROP TYPE IF EXISTS "BugStatus";
DROP TYPE IF EXISTS "Platform";

-- Nota: As variantes de NotificationType não podem ser removidas facilmente
-- mas não causarão problemas se permanecerem
```

### Após aplicar a migration:

1. **Reinicie o backend**: O Prisma Client precisa ser regenerado
   ```bash
   cd /path/to/tcs-sched/sched-be
   bun install  # Regenera Prisma Client
   pm2 restart tcs-scheduler-backend  # ou seu comando de restart
   ```

2. **Verifique os logs**: Certifique-se de que não há erros ao iniciar
   ```bash
   pm2 logs tcs-scheduler-backend
   ```

3. **Teste a API**:
   ```bash
   # Health check
   curl https://your-domain.com/health

   # Test bug reports endpoint (requer autenticação)
   curl https://your-domain.com/api/bug-reports \
     -H "Authorization: Bearer YOUR_TOKEN"
   ```

## Notas Importantes:

- ⚠️ **Backup**: Sempre faça backup do banco de dados antes de aplicar migrations em produção
- ⚠️ **Downtime**: Esta migration é segura e não requer downtime (apenas adiciona tabelas)
- ⚠️ **Permissões**: Certifique-se de que o usuário PostgreSQL tem permissões para criar tabelas e enums
- ✅ **Idempotência**: A migration usa `IF NOT EXISTS` onde possível, mas ainda é recomendado aplicar apenas uma vez

## Suporte:

Em caso de problemas, verifique:
1. Logs do PostgreSQL: `/var/log/postgresql/`
2. Logs do backend: `pm2 logs` ou `journalctl -u your-service`
3. Versão do PostgreSQL: Requer PostgreSQL 12+
