# ngrok - Múltiplas Contas

## Comandos Rápidos

### Backend (porta 7777)
```bash
ngrok start backend --config ~/.config/ngrok/ngrok-backend.yml
```

### Frontend (porta 3000)
```bash
ngrok start frontend --config ~/.config/ngrok/ngrok-frontend.yml
```

### Alternativa (sem nome de tunnel)
```bash
# Backend
ngrok http 7777 --config ~/.config/ngrok/ngrok-backend.yml

# Frontend
ngrok http 3000 --config ~/.config/ngrok/ngrok-frontend.yml
```

## Configs Disponíveis

- `~/.config/ngrok/ngrok.yml` - Conta padrão
- `~/.config/ngrok/ngrok-backend.yml` - Conta backend
- `~/.config/ngrok/ngrok-frontend.yml` - Conta frontend

Cada arquivo tem um `authtoken` diferente para contas ngrok diferentes.
