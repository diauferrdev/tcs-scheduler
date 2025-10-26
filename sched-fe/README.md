# TCS PacePort Scheduler - Flutter Multiplatform

Clone do frontend do TCS PacePort Scheduler usando Flutter para rodar em **Web, Desktop (Windows/Linux/macOS), Android e iOS** com o mesmo código.

## 🚀 Características

- ✅ **Multiplataforma**: Único código para todas as plataformas
- ✅ **Autenticação**: Sistema completo com session cookies
- ✅ **Theme Toggle**: Dark/Light mode (TCS Black & White design)
- ✅ **Responsive**: Layout adaptativo para mobile e desktop
- ✅ **AppLayout**: Sidebar (desktop) + Bottom Navigation (mobile)
- ✅ **State Management**: Provider
- ✅ **Routing**: go_router com proteção de rotas
- ✅ **API Integration**: Cliente HTTP pronto para o backend em localhost:7777

## 📁 Estrutura do Projeto

```
lib/
├── main.dart                      # Entry point
├── router.dart                    # Configuração de rotas
├── config/
│   └── api_config.dart           # Configuração da API
├── models/
│   └── user.dart                 # Modelo de usuário
├── providers/
│   ├── auth_provider.dart        # Estado de autenticação
│   └── theme_provider.dart       # Estado do tema
├── services/
│   └── api_service.dart          # Cliente HTTP
├── screens/
│   ├── login_screen.dart         # ✅ Login funcional
│   ├── dashboard_screen.dart     # 🚧 Placeholder
│   ├── calendar_screen.dart      # 🚧 Placeholder
│   ├── invitations_screen.dart   # 🚧 Placeholder
│   ├── users_screen.dart         # 🚧 Placeholder
│   └── activity_logs_screen.dart # 🚧 Placeholder
└── widgets/
    └── app_layout.dart           # Layout padrão com header/sidebar/bottom nav
```

## 🎯 Rotas Implementadas

| Rota | Tela | Acesso |
|------|------|--------|
| `/login` | Login | Público |
| `/dashboard` | Dashboard | ADMIN, MANAGER |
| `/calendar` | Bookings | ADMIN, MANAGER |
| `/invitations` | Invitations | ADMIN, MANAGER |
| `/users` | Users | ADMIN apenas |
| `/activity-logs` | Activity Logs | ADMIN apenas |

## 🛠️ Setup e Instalação

### Pré-requisitos

- Flutter 3.35+ instalado
- Backend rodando em `http://localhost:7777`

### Instalação

```bash
# Instalar dependências
flutter pub get

# Verificar se está tudo OK
flutter doctor
```

## 🚀 Como Rodar

### Web

```bash
# Rodar em modo dev (sem navegador, acesse http://localhost:8080)
flutter run -d web-server --web-port=8080

# OU com Chrome/Chromium
export CHROME_EXECUTABLE=/usr/bin/chromium-browser
flutter run -d chrome

# Build para produção
flutter build web
```

### Linux Desktop

```bash
# Rodar
flutter run -d linux

# Build
flutter build linux

# Executar build
./build/linux/x64/release/bundle/flutter_multiplatform_app
```

### Windows Desktop

```bash
flutter build windows
```

### Android

```bash
# Debug
flutter run -d <device-id>

# Release APK
flutter build apk

# Release App Bundle
flutter build appbundle
```

### iOS (requer macOS)

```bash
flutter build ios
```

## 🌐 Acessando a Aplicação Web

**Desenvolvimento (recomendado):**
```bash
flutter run -d web-server --web-port=8080
# Acesse: http://localhost:8080
```

**Após compilar com `flutter build web`:**

1. **Servidor Flutter:**
```bash
flutter run -d web-server --web-port=8080
```

2. **Acessar diretamente do Windows:**
```
\\wsl.localhost\Ubuntu\home\di\tcs\scheduler\flutter_multiplatform_app\build\web\index.html
```

## 🔐 Credenciais de Teste

As credenciais são as mesmas do backend:

- **Admin:** `admin@tcs.com` / `TCSPacePort2024!`
- **Manager:** `manager@tcs.com` / `Manager2024!`

## 🎨 Design System

### Cores

**Dark Mode (padrão):**
- Background: `#000000` (Black)
- Cards: `#18181B` (zinc-900)
- Borders: `#27272A` (zinc-800)
- Text: `#FFFFFF` (White)
- Inputs: `#09090B` (zinc-950)

**Light Mode:**
- Background: `#F9FAFB` (gray-50)
- Cards: `#FFFFFF` (White)
- Borders: `#E5E7EB` (gray-200)
- Text: `#000000` (Black)
- Inputs: `#F9FAFB` (gray-50)

### Componentes

- **Buttons**: Invertidos (branco no dark, preto no light)
- **Active Items**: Background invertido com escala 1.02
- **Border Radius**: 8px (inputs/cards), 12px (nav items)

## 📦 Dependências Principais

```yaml
dependencies:
  flutter_svg: ^2.0.10+1       # SVG support para logos
  google_fonts: ^6.2.1         # Fontes
  provider: ^6.1.2             # State management
  go_router: ^15.1.0           # Routing
  http: ^1.2.2                 # HTTP client
  shared_preferences: ^2.3.3   # Local storage
  flutter_form_builder: ^10.2.0 # Forms
```

## 🔄 API Integration

O app está configurado para se conectar ao backend em:
- **Default:** `http://localhost:7777`
- **Customizado:** Use variável de ambiente `API_URL`

```bash
flutter run -d chrome --dart-define=API_URL=https://your-backend.com
```

### Endpoints Utilizados

- `POST /api/auth/login` - Login
- `POST /api/auth/logout` - Logout
- `GET /api/auth/me` - Verificar sessão

## ⚙️ Configurações

### Mudar URL da API

Edite `lib/config/api_config.dart`:

```dart
static const String baseUrl = String.fromEnvironment(
  'API_URL',
  defaultValue: 'http://localhost:7777',  // <-- Altere aqui
);
```

### Mudar Tema Padrão

Edite `lib/providers/theme_provider.dart`:

```dart
ThemeMode _themeMode = ThemeMode.dark;  // ou ThemeMode.light
```

## 🐛 Debug

```bash
# Ver logs detalhados
flutter run -d linux --verbose

# Limpar build cache
flutter clean && flutter pub get

# Verificar problemas
flutter doctor -v
```

## 📝 TODO (Próximos Passos)

- [ ] Clonar UI detalhada do Dashboard
- [ ] Clonar UI detalhada do Calendar (com bookings)
- [ ] Clonar UI detalhada de Invitations
- [ ] Clonar UI detalhada de Users
- [ ] Clonar UI detalhada de Activity Logs
- [ ] Adicionar páginas públicas (GuestBooking, Badges)
- [ ] Integrar com todas as APIs do backend
- [ ] Adicionar validações de formulários
- [ ] Implementar toast/snackbar notifications
- [ ] Adicionar loading states
- [ ] Implementar error handling completo

## 📄 Licença

Projeto interno TCS.

---

**Desenvolvido com Flutter** 💙
