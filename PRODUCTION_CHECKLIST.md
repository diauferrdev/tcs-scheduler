# ✅ Checklist de Produção - TCS PacePort Scheduler

## Antes de fazer deploy na VPS

### 1. Configuração do Backend

- [ ] Criar arquivo `.env` com variáveis de produção
  ```bash
  cp /var/www/scheduler/sched-be/.env.production.example /var/www/scheduler/sched-be/.env
  nano /var/www/scheduler/sched-be/.env
  ```

- [ ] Gerar JWT_SECRET seguro
  ```bash
  openssl rand -base64 32
  ```

- [ ] Configurar URLs de produção no `.env`:
  - `FRONTEND_URL=https://seu-dominio.com`
  - `BACKEND_URL=https://api.seu-dominio.com`

- [ ] Configurar credenciais do banco de dados

- [ ] Configurar Resend API Key ou SMTP

- [ ] Configurar Firebase credentials (Firebase Console → Project Settings → Service Accounts)

### 2. Configuração do Frontend

- [ ] Atualizar `lib/config/api_config.dart`:
  ```dart
  static const String baseUrl = 'https://api.seu-dominio.com';
  ```

- [ ] Verificar configuração de notificações push (Firebase)
  - Arquivo `web/firebase-messaging-sw.js`
  - Arquivo `web/firebase-config.js`

### 3. Banco de Dados

- [ ] PostgreSQL instalado na VPS
- [ ] Banco de dados criado
- [ ] Usuário do banco criado com permissões
- [ ] Migrations executadas: `bun run prisma migrate deploy`
- [ ] Seed executado (criar admin): `bun run prisma db seed`

### 4. Domínio e DNS

- [ ] Domínio principal apontando para o IP da VPS
  - `A record` para `seu-dominio.com` → `IP_DA_VPS`
  - `A record` para `www.seu-dominio.com` → `IP_DA_VPS`

- [ ] Subdomínio API configurado
  - `A record` para `api.seu-dominio.com` → `IP_DA_VPS`

### 5. Servidor (Nginx)

- [ ] Nginx instalado
- [ ] Configuração do site criada em `/etc/nginx/sites-available/scheduler`
- [ ] Symlink criado em `/etc/nginx/sites-enabled/`
- [ ] Teste de configuração: `sudo nginx -t`
- [ ] Nginx recarregado: `sudo systemctl reload nginx`

### 6. SSL/HTTPS

- [ ] Certbot instalado
- [ ] Certificados SSL gerados
  ```bash
  sudo certbot --nginx -d seu-dominio.com -d www.seu-dominio.com -d api.seu-dominio.com
  ```
- [ ] Renovação automática configurada (cron do certbot)

### 7. Process Manager (PM2)

- [ ] PM2 instalado globalmente
- [ ] Backend rodando no PM2: `pm2 start bun --name scheduler-api -- run start`
- [ ] PM2 configurado para iniciar no boot: `pm2 startup && pm2 save`

### 8. Segurança

- [ ] Firewall (UFW) configurado
  ```bash
  sudo ufw allow 22    # SSH
  sudo ufw allow 80    # HTTP
  sudo ufw allow 443   # HTTPS
  sudo ufw enable
  ```

- [ ] PostgreSQL configurado para aceitar apenas conexões locais

- [ ] `.env` com permissões restritas: `chmod 600 .env`

- [ ] Usuário não-root criado para rodar aplicação

- [ ] Fail2ban instalado (opcional mas recomendado)

### 9. Backup

- [ ] Script de backup criado em `/usr/local/bin/backup-scheduler`
- [ ] Cron job configurado para backup diário
- [ ] Testado restauração de backup

### 10. Monitoramento

- [ ] PM2 monitorando o processo: `pm2 monit`
- [ ] Logs acessíveis: `pm2 logs scheduler-api`
- [ ] Health check endpoint funciona: `https://api.seu-dominio.com/health`

### 11. Testes Finais

- [ ] Backend responde no health check
  ```bash
  curl https://api.seu-dominio.com/health
  ```

- [ ] Frontend carrega corretamente em `https://seu-dominio.com`

- [ ] Login funciona

- [ ] Criação de booking funciona

- [ ] Notificações funcionam (se configurado)

- [ ] WebSocket conecta: verificar console do navegador

- [ ] Dashboard carrega com dados

- [ ] Permissões de ADMIN/MANAGER/USER funcionam corretamente

## Comandos Úteis Pós-Deploy

### Ver status dos serviços
```bash
pm2 status
sudo systemctl status nginx
sudo systemctl status postgresql
```

### Ver logs
```bash
pm2 logs scheduler-api
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

### Reiniciar serviços
```bash
pm2 restart scheduler-api
sudo systemctl reload nginx
sudo systemctl restart postgresql
```

### Update rápido
```bash
sudo update-scheduler
```

## URLs Finais de Produção

- **Frontend**: https://seu-dominio.com
- **API**: https://api.seu-dominio.com
- **Health Check**: https://api.seu-dominio.com/health
- **WebSocket**: wss://api.seu-dominio.com/ws

## Troubleshooting Rápido

### Backend não responde
1. `pm2 logs scheduler-api` - verificar erros
2. `pm2 restart scheduler-api`
3. Verificar `.env` está correto
4. Verificar banco de dados está rodando

### Frontend 404 ou não carrega
1. Verificar build existe: `ls -la /var/www/scheduler/tcs_pace_scheduler/build/web`
2. Verificar permissões: `sudo chown -R www-data:www-data build/web`
3. Verificar Nginx config: `sudo nginx -t`

### Erro CORS
1. Verificar FRONTEND_URL no `.env` do backend
2. Verificar configuração CORS em `sched-be/src/index.ts`

### SSL não funciona
1. `sudo certbot certificates` - verificar certificados
2. `sudo certbot renew --dry-run` - testar renovação
3. Verificar portas 80 e 443 abertas no firewall
