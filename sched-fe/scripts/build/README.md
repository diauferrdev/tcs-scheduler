# 🚀 Build Scripts - TCS Pace Scheduler

Scripts organizados por plataforma para build e distribuição automatizados.

## 📋 Estrutura

```
scripts/build/
├── android.sh      # Android APK + Firebase App Distribution
├── ios.sh          # iOS IPA (requer macOS)
├── macos.sh        # macOS App (requer macOS)
├── windows.sh      # Windows EXE (Git Bash/WSL)
├── windows.bat     # Windows EXE (CMD nativo)
├── linux.sh        # Linux Binary
├── web.sh          # Web Build
└── BUILD.sh        # Menu interativo multiplataforma
```

---

## 📱 Android (com Firebase App Distribution)

**Script**: `android.sh`

### Features:
- ✅ Build APK com `--split-per-abi` (gera APKs enxutos por arquitetura)
- ✅ Incrementa versão automaticamente
- ✅ Upload automático para Firebase App Distribution
- ✅ Gera 3 APKs otimizados:
  - `arm64-v8a` - Dispositivos modernos 64-bit (recomendado)
  - `armeabi-v7a` - Dispositivos antigos 32-bit
  - `x86_64` - Emuladores e dispositivos x86

### Uso:
```bash
./scripts/build/android.sh
```

### Requisitos:
- Firebase CLI instalado: `npm install -g firebase-tools`
- Autenticado no Firebase: `firebase login`
- Grupo "internal-testers" criado no Firebase Console

### Saída:
- APKs: `build/app/outputs/flutter-apk/`
- Versão incrementada automaticamente
- Upload para Firebase App Distribution

---

## 🍎 iOS

**Script**: `ios.sh`

### Features:
- ✅ Build IPA para iOS
- ✅ Incrementa versão automaticamente
- ✅ Instruções para upload no Firebase App Distribution

### Uso:
```bash
./scripts/build/ios.sh
```

### Requisitos:
- macOS com Xcode instalado
- Certificados de assinatura configurados

### Saída:
- IPA: `build/ios/ipa/tcs_pace_scheduler.ipa`

---

## 🖥️ macOS

**Script**: `macos.sh`

### Features:
- ✅ Build app macOS
- ✅ Incrementa versão automaticamente
- ✅ Gera ZIP para distribuição

### Uso:
```bash
./scripts/build/macos.sh
```

### Requisitos:
- macOS

### Saída:
- App: `build/macos/Build/Products/Release/tcs_pace_scheduler.app`
- ZIP: `build/macos/Build/Products/Release/tcs-pace-scheduler-vX.X.X-buildXX-macos.zip`

---

## 🪟 Windows

**Scripts**:
- `windows.sh` (Git Bash / WSL)
- `windows.bat` (CMD nativo)

### Features:
- ✅ Build executável Windows
- ✅ **Exclui Firebase automaticamente** (C++ SDK incompatível no Windows desktop)
- ✅ Usa `local_notifier` para notificações desktop
- ✅ Incrementa versão automaticamente
- ✅ Gera ZIP para distribuição

### Uso:
```bash
# Git Bash / WSL
./scripts/build/windows.sh

# CMD nativo (Windows)
scripts\build\windows.bat
```

### Requisitos:
- Windows 10 ou superior (build 1809+)
- Windows SDK 10.0.26100.0+
- Visual Studio 2022 com "Desktop development with C++"
- Flutter SDK configurado

### ⚠️ Exclusão Automática do Firebase:

O script exclui automaticamente Firebase do build Windows porque:
- **Problema**: Firebase C++ SDK tem problemas de linking no Windows desktop (33 símbolos não resolvidos)
- **Solução**: Windows usa `local_notifier` para notificações desktop (equivalente nativo)
- **Automático**: Script modifica os arquivos gerados do Flutter:
  - `windows/flutter/generated_plugins.cmake` - Remove firebase_core da lista
  - `windows/flutter/generated_plugin_registrant.cc` - Comenta includes e registros

**Não afeta outras plataformas**: Android, iOS, Web e macOS continuam usando Firebase normalmente.

### Saída:
- Executável: `build/windows/x64/runner/Release/flutter_multiplatform_app.exe`
- ZIP: `build/windows/x64/runner/tcs-pace-scheduler-vX.X.X-buildXX-windows-x64.zip`

### Distribuição:
- **Copiar toda a pasta Release** (contém DLLs e recursos necessários)
- Ou usar o ZIP gerado automaticamente
- Aplicação portável - não requer instalação
- Arquivos necessários:
  - `flutter_multiplatform_app.exe` (executável principal)
  - `flutter_windows.dll` (runtime Flutter)
  - `data/` (recursos da aplicação)
  - `*.dll` (plugins: local_notifier, printing, etc.)

---

## 🐧 Linux

**Script**: `linux.sh`

### Features:
- ✅ Build binário Linux
- ✅ Incrementa versão automaticamente
- ✅ Gera tar.gz para distribuição

### Uso:
```bash
./scripts/build/linux.sh
```

### Requisitos:
- Linux
- Dependências Flutter instaladas

### Saída:
- Binário: `build/linux/x64/release/bundle/tcs_pace_scheduler`
- Archive: `build/linux/x64/release/tcs-pace-scheduler-vX.X.X-buildXX-linux-x64.tar.gz`

---

## 🌐 Web

**Script**: `web.sh`

### Features:
- ✅ Build aplicação web
- ✅ Incrementa versão automaticamente
- ✅ CanvasKit renderer para melhor desempenho
- ✅ Instruções para deploy no Firebase Hosting

### Uso:
```bash
./scripts/build/web.sh
```

### Saída:
- Build: `build/web/`

### Deploy:
```bash
firebase deploy --only hosting
```

---

## 🔧 Como Funcionam os Scripts

Todos os scripts seguem o mesmo fluxo:

1. **Verificação de Versão**
   - Lê versão atual do `pubspec.yaml`
   - Incrementa build number automaticamente
   - Pergunta confirmação antes de continuar

2. **Atualização de Versão**
   - Atualiza `pubspec.yaml` com nova versão

3. **Clean & Dependencies**
   - Executa `flutter clean`
   - Executa `flutter pub get`

4. **Configuração Específica** (Windows)
   - Exclui Firebase automaticamente
   - Modifica arquivos gerados do CMake

5. **Build**
   - Executa build específico da plataforma
   - Modo release otimizado

6. **Distribuição**
   - Android: Upload automático para Firebase App Distribution
   - Outras: Gera arquivos ZIP/tar.gz

7. **Resumo**
   - Mostra informações da build
   - Lista próximos passos

---

## 📦 Firebase App Distribution (Android)

### Setup Inicial:

1. **Instalar Firebase CLI:**
```bash
npm install -g firebase-tools
```

2. **Login:**
```bash
firebase login
```

3. **Criar Grupo de Testers:**
   - Acesse: https://console.firebase.google.com/project/tcs-paceport-scheduler/appdistribution
   - Vá em "Testers & Groups"
   - Crie grupo "internal-testers"
   - Adicione emails dos testers

### App IDs Configurados:

- **Android**: `1:874457674237:android:81596c5009b03f9a9fa994`
- **iOS**: `1:874457674237:ios:705420cf66986a579fa994`
- **Web**: `1:874457674237:web:3178aef43c686e2c9fa994`

---

## 🎯 Workflow Recomendado

### Para Releases Completos:

```bash
# 1. Android (com Firebase Distribution)
./scripts/build/android.sh

# 2. Web (se necessário)
./scripts/build/web.sh
firebase deploy --only hosting

# 3. iOS (se tiver macOS)
./scripts/build/ios.sh

# 4. Desktop (se necessário)
./scripts/build/windows.sh  # ou windows.bat no CMD
./scripts/build/linux.sh
./scripts/build/macos.sh
```

### Para Testes Rápidos (Android):

```bash
./scripts/build/android.sh
# Testers receberão notificação automática do Firebase
```

---

## 🔍 Verificar Versão Atual

```bash
grep "^version:" pubspec.yaml
```

---

## 📝 Notas Importantes

### Android (split-per-abi):
- **arm64-v8a**: Use para a maioria dos dispositivos modernos (95%+ do mercado)
- **armeabi-v7a**: Para compatibilidade com dispositivos antigos
- **x86_64**: Para emuladores e tablets x86 específicos

### Windows (Firebase Exclusion):
- **Problema Técnico**: Firebase C++ SDK não compila no Windows devido a erros de linking
- **Solução Automática**: Script exclui Firebase e usa alternativas nativas:
  - `local_notifier` para notificações desktop
  - Firebase funciona normalmente em Android, iOS, web, macOS
- **Processo Transparente**: Usuário não precisa fazer nada manualmente

### Versioning:
- Formato: `MAJOR.MINOR.PATCH+BUILD`
- Exemplo: `1.0.1+3`
  - `1.0.1` = Version name (aparece para usuários)
  - `3` = Build number (interno, usado para updates)

### Firebase Distribution:
- Testers recebem email automático
- Link de download expira em X dias (configurável)
- Pode adicionar release notes personalizadas

---

## 🐛 Troubleshooting

### "Firebase CLI not found"
```bash
npm install -g firebase-tools
```

### "Not logged in to Firebase"
```bash
firebase login
```

### "Permission denied"
```bash
chmod +x scripts/build/*.sh
```

### "APK upload failed"
- Verifique se grupo "internal-testers" existe no Firebase Console
- Verifique se você tem permissões no projeto Firebase
- Tente fazer login novamente: `firebase logout && firebase login`

### Windows: "CMake Error: No CMAKE_CXX_COMPILER"
- Instale Visual Studio 2022 com "Desktop development with C++"
- Instale Windows SDK (10.0.26100.0 ou superior)

### Windows: "Firebase linking errors"
- **Normal!** O script exclui Firebase automaticamente
- Firebase não é suportado no Windows desktop
- Use `local_notifier` (já configurado automaticamente)

---

## 📞 Suporte

Para problemas ou dúvidas:
1. Verifique logs de erro no terminal
2. Consulte documentação do Firebase: https://firebase.google.com/docs/app-distribution
3. Execute `flutter doctor` para verificar ambiente

---

**Última atualização**: 2024-10-17
**Mantido por**: TCS Development Team
