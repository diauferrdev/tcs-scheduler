# Guia de Migration para Produção

## ⚠️ ATENÇÃO: LEIA COMPLETAMENTE ANTES DE EXECUTAR

Este guia é para aplicar as mudanças de schema do banco de dados em **PRODUÇÃO**.

## Mudanças a serem aplicadas:

1. **BugComment** - Adicionados campos:
   - `deviceInfo` (Json, nullable) - Informações do dispositivo quando o comentário foi criado
   - Relação com `BugCommentAttachment` (1-para-muitos)

2. **BugCommentAttachment** (NOVA TABELA) - Anexos em comentários:
   - `id` (String, PK)
   - `commentId` (String, FK para BugComment)
   - `fileUrl` (String)
   - `fileName` (String)
   - `fileSize` (Int)
   - `fileType` (String)
   - `createdAt` (DateTime)

## Pré-requisitos:

1. ✅ Backup completo do banco de dados
2. ✅ Janela de manutenção programada
3. ✅ Acesso SSH ao servidor de produção
4. ✅ Credenciais do banco de dados de produção

## Passos para Produção:

### 1. Fazer Backup do Banco

```bash
# No servidor de produção
pg_dump -h <HOST> -U <USER> -d tcs_scheduler > backup_before_comment_attachments_$(date +%Y%m%d_%H%M%S).sql
```

### 2. Testar a Migration em Staging (Recomendado)

```bash
# No ambiente de staging
cd /path/to/sched-be
bunx prisma db push --accept-data-loss
```

### 3. Aplicar em Produção

**Opção A: Usando Prisma Migrate (Recomendado)**

```bash
# No servidor de produção
cd /path/to/sched-be
bunx prisma migrate deploy
```

**Opção B: Usando DB Push (Mais rápido, sem histórico)**

```bash
cd /path/to/sched-be
bunx prisma db push --accept-data-loss
```

### 4. Verificar Aplicação

```bash
# Verificar se as tabelas foram criadas
psql -h <HOST> -U <USER> -d tcs_scheduler -c "\d BugCommentAttachment"
psql -h <HOST> -U <USER> -d tcs_scheduler -c "\d+ BugComment"
```

### 5. Reiniciar Servidor Backend

```bash
# Reiniciar o servidor backend para aplicar novo schema Prisma
pm2 restart backend
# ou
systemctl restart your-backend-service
```

## Rollback (Se necessário):

Se algo der errado:

```bash
# Restaurar backup
psql -h <HOST> -U <USER> -d tcs_scheduler < backup_before_comment_attachments_YYYYMMDD_HHMMSS.sql

# Reverter código
git revert <commit-hash>
pm2 restart backend
```

## Verificação Pós-Deploy:

1. ✅ Testar criação de comentário
2. ✅ Verificar que comentários antigos continuam funcionando
3. ✅ Monitorar logs por erros
4. ✅ Verificar WebSocket real-time

## Notas Importantes:

- ⚠️ A migration adiciona campos NULLABLE, não deve quebrar dados existentes
- ⚠️ Comentários antigos não terão deviceInfo nem attachments (ok)
- ⚠️ A funcionalidade de upload de anexos precisa do backend atualizado
- ✅ É uma operação SAFE - apenas adiciona campos novos

## Contato de Emergência:

Se houver problemas:
1. Fazer rollback imediatamente
2. Verificar logs: `pm2 logs backend --lines 100`
3. Restaurar backup se necessário
