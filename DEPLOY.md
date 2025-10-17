# 🚀 Guia de Deploy - TCS PacePort Scheduler

## Pré-requisitos na VPS

```bash
# 1. Instale Node.js/Bun
curl -fsSL https://bun.sh/install | bash

# 2. Instale PostgreSQL 15+
sudo apt update
sudo apt install postgresql postgresql-contrib

# 3. Instale Nginx
sudo apt install nginx

# 4. Instale Certbot (SSL)
sudo apt install certbot python3-certbot-nginx
```

## 📦 Deploy do Backend

### 1. Clone o repositório na VPS
```bash
cd /var/www
git clone <seu-repositorio> scheduler
cd scheduler/sched-be
```

### 2. Configure o ambiente
```bash
# Copie e configure o .env
cp .env.example .env
nano .env
```

**Arquivo .env de produção:**
```env
# Database
DATABASE_URL="postgresql://usuario:senha@localhost:5432/tcs_scheduler_prod"

# Server
PORT=7777
NODE_ENV=production

# URLs (IMPORTANTE: use seu domínio)
FRONTEND_URL=https://seu-dominio.com
BACKEND_URL=https://api.seu-dominio.com

# Auth
JWT_SECRET=<gere-uma-chave-segura>

# Email (Resend ou Nodemailer)
RESEND_API_KEY=<sua-chave-resend>

# Firebase (notificações push)
FIREBASE_PROJECT_ID=<seu-project-id>
FIREBASE_PRIVATE_KEY=<sua-private-key>
FIREBASE_CLIENT_EMAIL=<seu-client-email>
```

### 3. Setup do banco de dados
```bash
# Entre no PostgreSQL
sudo -u postgres psql

# Dentro do psql:
CREATE DATABASE tcs_scheduler_prod;
CREATE USER seu_usuario WITH PASSWORD 'sua_senha_segura';
GRANT ALL PRIVILEGES ON DATABASE tcs_scheduler_prod TO seu_usuario;
\q

# Execute as migrations
bun install
bun run prisma migrate deploy
bun run prisma generate

# Seed inicial (cria usuário admin)
bun run prisma db seed
```

### 4. Instale e configure PM2
```bash
bun add -g pm2

# Inicie o backend
pm2 start bun --name "scheduler-api" -- run start

# Configure para iniciar no boot
pm2 startup
pm2 save
```

## 🌐 Deploy do Frontend (Flutter Web)

### 1. Build de produção
```bash
cd /var/www/scheduler/tcs_pace_scheduler

# Configure a URL da API
nano lib/services/api_service.dart
# Altere baseUrl para: https://api.seu-dominio.com

# Faça o build
flutter build web --release --web-renderer canvaskit
```

O build será gerado em: `build/web/`

### 2. Configure o Nginx

Crie o arquivo de configuração:
```bash
sudo nano /etc/nginx/sites-available/scheduler
```

**Conteúdo do arquivo:**
```nginx
# Backend API
server {
    listen 80;
    server_name api.seu-dominio.com;

    location / {
        proxy_pass http://localhost:7777;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }

    # WebSocket support
    location /ws {
        proxy_pass http://localhost:7777/ws;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}

# Frontend
server {
    listen 80;
    server_name seu-dominio.com www.seu-dominio.com;

    root /var/www/scheduler/tcs_pace_scheduler/build/web;
    index index.html;

    location / {
        try_files $uri $uri/ /index.html;
    }

    # Cache estático
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # Compressão
    gzip on;
    gzip_vary on;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/javascript application/xml+rss application/json;
}
```

### 3. Ative o site
```bash
sudo ln -s /etc/nginx/sites-available/scheduler /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl reload nginx
```

### 4. Configure SSL (Certbot)
```bash
sudo certbot --nginx -d seu-dominio.com -d www.seu-dominio.com -d api.seu-dominio.com
```

## 🔄 Script de Update Rápido

Crie um script para facilitar updates futuros:

```bash
sudo nano /usr/local/bin/update-scheduler
```

**Conteúdo:**
```bash
#!/bin/bash
set -e

echo "🔄 Atualizando TCS Scheduler..."

cd /var/www/scheduler

# Pull latest changes
git pull origin main

# Update backend
echo "📦 Atualizando backend..."
cd sched-be
bun install
bun run prisma migrate deploy
bun run prisma generate
pm2 restart scheduler-api

# Update frontend
echo "🌐 Atualizando frontend..."
cd ../tcs_pace_scheduler
flutter build web --release --web-renderer canvaskit

echo "✅ Deploy concluído!"
echo "Backend: https://api.seu-dominio.com/health"
echo "Frontend: https://seu-dominio.com"
```

Torne executável:
```bash
sudo chmod +x /usr/local/bin/update-scheduler
```

## 🔍 Verificação de Saúde

### Backend
```bash
curl https://api.seu-dominio.com/health
```

Resposta esperada:
```json
{
  "status": "ok",
  "timestamp": "2025-10-16T...",
  "services": {
    "api": "ok",
    "websocket": "native",
    "connections": 0
  }
}
```

### Frontend
Acesse: `https://seu-dominio.com`

## 📊 Monitoramento

```bash
# Ver logs do backend
pm2 logs scheduler-api

# Ver status
pm2 status

# Ver logs do Nginx
sudo tail -f /var/log/nginx/error.log
sudo tail -f /var/log/nginx/access.log
```

## 🔐 Segurança

1. **Firewall:**
```bash
sudo ufw allow 22      # SSH
sudo ufw allow 80      # HTTP
sudo ufw allow 443     # HTTPS
sudo ufw enable
```

2. **PostgreSQL:**
```bash
sudo nano /etc/postgresql/15/main/pg_hba.conf
# Garanta que apenas localhost pode conectar
```

3. **Backup automático:**
```bash
sudo nano /usr/local/bin/backup-scheduler
```

```bash
#!/bin/bash
BACKUP_DIR="/var/backups/scheduler"
DATE=$(date +%Y%m%d_%H%M%S)

mkdir -p $BACKUP_DIR

# Backup do banco
pg_dump -U seu_usuario tcs_scheduler_prod | gzip > $BACKUP_DIR/db_$DATE.sql.gz

# Backup dos uploads (se houver)
tar -czf $BACKUP_DIR/uploads_$DATE.tar.gz /var/www/scheduler/sched-be/uploads

# Manter apenas últimos 7 dias
find $BACKUP_DIR -type f -mtime +7 -delete

echo "Backup concluído: $DATE"
```

Configure cron:
```bash
sudo crontab -e
# Adicione: 0 2 * * * /usr/local/bin/backup-scheduler
```

## 🚨 Troubleshooting

### Backend não inicia
```bash
pm2 logs scheduler-api --lines 50
# Verifique DATABASE_URL, FIREBASE credentials
```

### Frontend não carrega
```bash
# Verifique permissões
sudo chown -R www-data:www-data /var/www/scheduler/tcs_pace_scheduler/build/web

# Teste Nginx
sudo nginx -t
```

### Erro CORS
Verifique em `sched-be/src/index.ts` que FRONTEND_URL está correto

## 📝 Checklist Final

- [ ] PostgreSQL instalado e rodando
- [ ] Banco de dados criado e migrations aplicadas
- [ ] .env configurado com URLs de produção
- [ ] Backend rodando no PM2
- [ ] Flutter build gerado
- [ ] Nginx configurado
- [ ] SSL configurado com Certbot
- [ ] Firewall configurado
- [ ] Backup automático configurado
- [ ] Logs funcionando
- [ ] Health check responde OK

## 🎯 URLs Finais

- **Frontend**: https://seu-dominio.com
- **API**: https://api.seu-dominio.com
- **Health**: https://api.seu-dominio.com/health
- **WebSocket**: wss://api.seu-dominio.com/ws

---

**Suporte**: Para atualizações futuras, apenas execute: `sudo update-scheduler`
