# Firebase App Distribution - Setup Completo

## 🎯 Objetivo
Obter links de download do Firebase App Distribution para Android, iOS, macOS e atualizar o backend.

---

## 📱 Passo 1: Build Android (APK)

### 1.1 Build Release APK
```bash
cd /home/di/tcs/scheduler/flutter_multiplatform_app

# Build APK de produção
flutter build apk --release

# APK estará em:
# build/app/outputs/flutter-apk/app-release.apk
```

### 1.2 Upload para Firebase App Distribution

```bash
# Instalar Firebase CLI (se ainda não tiver)
npm install -g firebase-tools

# Login no Firebase
firebase login

# Upload do APK
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:YOUR_PROJECT_NUMBER:android:YOUR_APP_ID \
  --groups "internal-testers" \
  --release-notes "Versão 1.0.0 - Release inicial com push notifications"
```

### 1.3 Obter o Link Android

Após o upload, o Firebase CLI vai mostrar algo assim:

```
✅ Upload successful!

View this release in the Firebase console:
https://console.firebase.google.com/project/tcs-paceport-scheduler/appdistribution/app/android:com.tcs.scheduler/releases/...

Distribution link: https://appdistribution.firebase.dev/i/abc123def456
```

**⭐ Copie o link que começa com `https://appdistribution.firebase.dev/i/...`**

---

## 🍎 Passo 2: Build iOS (IPA)

### 2.1 Build Release IPA (precisa macOS)

```bash
# Build iOS Archive
flutter build ipa --release

# IPA estará em:
# build/ios/ipa/flutter_multiplatform_app.ipa
```

### 2.2 Upload para Firebase App Distribution

```bash
firebase appdistribution:distribute \
  build/ios/ipa/flutter_multiplatform_app.ipa \
  --app 1:YOUR_PROJECT_NUMBER:ios:YOUR_APP_ID \
  --groups "internal-testers" \
  --release-notes "Versão 1.0.0 - Release inicial com push notifications"
```

### 2.3 Obter o Link iOS

Copie o link gerado: `https://appdistribution.firebase.dev/i/xyz789abc123`

---

## 🖥️ Passo 3: Build macOS (DMG)

### 3.1 Build Release macOS (precisa macOS)

```bash
# Build macOS app
flutter build macos --release

# App estará em:
# build/macos/Build/Products/Release/flutter_multiplatform_app.app
```

### 3.2 Upload para Firebase App Distribution

```bash
# Criar ZIP do app
cd build/macos/Build/Products/Release
zip -r flutter_multiplatform_app.zip flutter_multiplatform_app.app
cd -

firebase appdistribution:distribute \
  build/macos/Build/Products/Release/flutter_multiplatform_app.zip \
  --app 1:YOUR_PROJECT_NUMBER:ios:YOUR_MACOS_APP_ID \
  --groups "internal-testers" \
  --release-notes "Versão 1.0.0 - Release inicial"
```

### 3.3 Obter o Link macOS

Copie o link gerado: `https://appdistribution.firebase.dev/i/macos123abc456`

---

## 🪟 Passo 4: Windows e Linux (GitHub Releases)

Para Windows e Linux, use GitHub Releases ao invés de Firebase:

### 4.1 Build Windows

```bash
flutter build windows --release

# EXE estará em:
# build/windows/x64/runner/Release/
```

### 4.2 Build Linux

```bash
flutter build linux --release

# Binário estará em:
# build/linux/x64/release/bundle/
```

### 4.3 Criar Release no GitHub

```bash
# Criar tag
git tag -a v1.0.0 -m "Release v1.0.0"
git push origin v1.0.0

# Fazer upload dos builds no GitHub Releases:
# https://github.com/seu-usuario/tcs-scheduler/releases/new
```

O link ficará algo como:
- Windows: `https://github.com/seu-org/tcs-scheduler/releases/download/v1.0.0/windows.zip`
- Linux: `https://github.com/seu-org/tcs-scheduler/releases/download/v1.0.0/linux.tar.gz`

---

## 🔧 Passo 5: Encontrar seu App ID do Firebase

### Via Firebase Console (Fácil):

1. Acesse: https://console.firebase.google.com/project/tcs-paceport-scheduler/settings/general
2. Role até "Seus apps"
3. Você verá algo assim:

**Android:**
```
App ID: 1:123456789012:android:abcdef123456
```

**iOS:**
```
App ID: 1:123456789012:ios:fedcba654321
```

### Via Linha de Comando:

```bash
# Listar projetos
firebase projects:list

# Ver apps do projeto
firebase apps:list --project tcs-paceport-scheduler
```

Saída exemplo:
```
┌───────────────────┬─────────────────────────────────────┬─────────────────────┐
│ Display Name      │ App ID                              │ Platform            │
├───────────────────┼─────────────────────────────────────┼─────────────────────┤
│ TCS Pace Schedule │ 1:123456789012:android:abc123       │ ANDROID             │
│ TCS Pace Schedule │ 1:123456789012:ios:def456           │ IOS                 │
│ TCS Pace Schedule │ 1:123456789012:web:ghi789           │ WEB                 │
└───────────────────┴─────────────────────────────────────┴─────────────────────┘
```

---

## ⚡ Passo 6: Atualizar Backend com os Links

Agora que você tem todos os links, atualize o arquivo:

**`sched-be/src/routes/version.ts`**

```typescript
app.get('/current', (c) => {
  return c.json({
    version: '1.0.0',
    buildNumber: 1,
    minVersion: '1.0.0',
    forceUpdate: false,

    downloadUrl: {
      // Cole os links que você obteve acima ⬇️
      android: 'https://appdistribution.firebase.dev/i/abc123def456', // ← Seu link Android
      ios: 'https://appdistribution.firebase.dev/i/xyz789abc123',     // ← Seu link iOS
      web: '',                                                         // ← Web não precisa
      macos: 'https://appdistribution.firebase.dev/i/macos123abc456', // ← Seu link macOS
      windows: 'https://github.com/seu-org/tcs-scheduler/releases/download/v1.0.0/windows.zip',
      linux: 'https://github.com/seu-org/tcs-scheduler/releases/download/v1.0.0/linux.tar.gz',
    },

    releaseNotes: {
      'pt-BR': 'Versão 1.0.0 - Release inicial com notificações push e sistema de agendamento completo.',
      'en': 'Version 1.0.0 - Initial release with push notifications and complete scheduling system.',
    },

    releaseDate: '2024-10-12T10:00:00Z',
    critical: false,
  });
});
```

---

## 🧪 Passo 7: Testar Auto-Update

### Cenário 1: Update Opcional
1. **App instalado:** versão 1.0.0
2. **Backend retorna:** versão 1.0.1, forceUpdate: false
3. **Resultado:** Dialog com "Depois" e "Atualizar Agora"

### Cenário 2: Update Forçado
1. **App instalado:** versão 1.0.0
2. **Backend retorna:** versão 1.0.1, forceUpdate: true
3. **Resultado:** Dialog sem "Depois", usuário DEVE atualizar

### Cenário 3: Versão Mínima (BLOQUEIO)
1. **App instalado:** versão 0.9.0
2. **Backend retorna:** minVersion: 1.0.0
3. **Resultado:** UI bloqueada, não pode usar app até atualizar

---

## 📋 Checklist Completo

- [ ] Instalou Firebase CLI: `npm install -g firebase-tools`
- [ ] Fez login: `firebase login`
- [ ] Obteve App ID do Android no Firebase Console
- [ ] Fez build Android: `flutter build apk --release`
- [ ] Upload Android para Firebase App Distribution
- [ ] Copiou link Android: `https://appdistribution.firebase.dev/i/...`
- [ ] Obteve App ID do iOS no Firebase Console
- [ ] Fez build iOS: `flutter build ipa --release` (se tiver macOS)
- [ ] Upload iOS para Firebase App Distribution
- [ ] Copiou link iOS: `https://appdistribution.firebase.dev/i/...`
- [ ] Atualizou `sched-be/src/routes/version.ts` com os links
- [ ] Reiniciou backend: `cd sched-be && bun run dev`
- [ ] Testou update opcional (aumentar version para 1.0.1)
- [ ] Testou update forçado (forceUpdate: true)
- [ ] Testou bloqueio (minVersion: 1.0.1, app em 1.0.0)

---

## 🚀 Comandos Rápidos (Resumo)

```bash
# 1. Build Android
flutter build apk --release

# 2. Upload Android
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:YOUR_PROJECT_NUMBER:android:YOUR_APP_ID \
  --groups "internal-testers"

# 3. Copiar link e atualizar sched-be/src/routes/version.ts

# 4. Reiniciar backend
cd ../sched-be && bun run dev
```

---

## ❓ Troubleshooting

### "App ID não encontrado"
- Verifique se registrou o app no Firebase Console
- Use `firebase apps:list --project tcs-paceport-scheduler`

### "Permission denied"
- Execute `firebase login` novamente
- Verifique se sua conta tem permissão no projeto Firebase

### "Build failed"
- Android: verifique `android/key.properties` (se assinar APK)
- iOS: precisa macOS + Xcode configurado
- Rode `flutter doctor` para verificar ambiente

---

## 🎉 Pronto!

Agora seu sistema de auto-update está 100% funcional! O app vai:

1. ✅ Verificar versão 5 segundos após login
2. ✅ Mostrar dialog de update se disponível
3. ✅ Bloquear UI se versão desatualizada
4. ✅ Abrir Firebase App Distribution ao clicar "Atualizar"
5. ✅ Funcionar em TODAS as plataformas
