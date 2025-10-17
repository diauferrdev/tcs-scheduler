# Self-Hosted APK Auto-Update (Sem Google Play)

## 🎯 Objetivo
Atualizar o app automaticamente baixando APK do seu servidor (sem Google Play).

---

## ⚠️ Importante

**Riscos:**
- Usuários precisam permitir "Instalar de fontes desconhecidas"
- Não passa por revisão da Google (responsabilidade sua)
- Precisa assinar APK com mesmo certificado sempre

**Use apenas para:**
- Distribuição interna (empresa)
- Beta testing
- Ambientes controlados

---

## 🏗️ Arquitetura

```
┌─────────────────────────────────────┐
│  Flutter App                        │
│  ├─ Verifica versão (backend)       │
│  ├─ Baixa APK (DownloadManager)     │
│  └─ Instala APK (Intent)            │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│  Backend (sched-be)                 │
│  ├─ GET /api/version/current        │
│  └─ GET /api/version/download/apk   │
└─────────────────────────────────────┘
           ↓
┌─────────────────────────────────────┐
│  Arquivo APK hospedado              │
│  /uploads/tcs-pace-scheduler.apk    │
└─────────────────────────────────────┘
```

---

## 📦 Implementação

### 1. Backend - Hospedar APK

```typescript
// sched-be/src/routes/version.ts
import { Hono } from 'hono';
import { readFile } from 'fs/promises';
import path from 'path';

const app = new Hono();

app.get('/current', (c) => {
  return c.json({
    version: '1.0.1',
    buildNumber: 2,
    minVersion: '1.0.0',
    forceUpdate: false,
    apkUrl: 'https://your-domain.com/api/version/download/apk',
    apkSize: 45000000, // bytes (45MB)
    apkChecksum: 'sha256:abc123...', // For integrity check
    releaseNotes: {
      'pt': 'Correções de bugs e melhorias de notificações push',
      'en': 'Bug fixes and push notification improvements',
    },
    releaseDate: '2024-10-12T10:00:00Z',
  });
});

// Download APK endpoint
app.get('/download/apk', async (c) => {
  try {
    const apkPath = path.join(__dirname, '../../uploads/tcs-pace-scheduler.apk');
    const apkBuffer = await readFile(apkPath);
    
    return new Response(apkBuffer, {
      headers: {
        'Content-Type': 'application/vnd.android.package-archive',
        'Content-Disposition': 'attachment; filename="tcs-pace-scheduler.apk"',
        'Content-Length': apkBuffer.length.toString(),
      },
    });
  } catch (error) {
    return c.json({ error: 'APK not found' }, 404);
  }
});

export default app;
```

### 2. Flutter - Permissões Android

```xml
<!-- android/app/src/main/AndroidManifest.xml -->
<manifest>
    <!-- Permissões existentes... -->
    
    <!-- Install APK from unknown sources (Android 8+) -->
    <uses-permission android:name="android.permission.REQUEST_INSTALL_PACKAGES"/>
    
    <!-- Download files -->
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE"
        android:maxSdkVersion="28" />
    
    <application>
        <!-- FileProvider for APK installation (Android 7+) -->
        <provider
            android:name="androidx.core.content.FileProvider"
            android:authorities="${applicationId}.fileprovider"
            android:exported="false"
            android:grantUriPermissions="true">
            <meta-data
                android:name="android.support.FILE_PROVIDER_PATHS"
                android:resource="@xml/file_paths" />
        </provider>
    </application>
</manifest>
```

```xml
<!-- android/app/src/main/res/xml/file_paths.xml -->
<?xml version="1.0" encoding="utf-8"?>
<paths>
    <external-path name="external_files" path="." />
    <cache-path name="cache" path="." />
</paths>
```

### 3. Flutter - Dependencies

```yaml
# pubspec.yaml
dependencies:
  package_info_plus: ^8.0.0
  dio: ^5.4.0  # Para download com progress
  path_provider: ^2.1.0
  open_filex: ^4.4.0  # Para instalar APK
  permission_handler: ^11.3.0
```

### 4. Flutter - Auto-Update Service

```dart
// lib/services/apk_update_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'api_service.dart';

class APKUpdateService {
  static final APKUpdateService _instance = APKUpdateService._internal();
  factory APKUpdateService() => _instance;
  APKUpdateService._internal();

  final ApiService _apiService = ApiService();
  final Dio _dio = Dio();
  
  bool _isDownloading = false;
  double _downloadProgress = 0.0;

  /// Check for updates and download/install APK if available
  Future<void> checkAndUpdate(BuildContext context) async {
    if (!Platform.isAndroid) {
      debugPrint('[APK Update] Not Android, skipping');
      return;
    }

    try {
      // Get current version
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      
      // Check backend for latest version
      final response = await _apiService.get('/api/version/current');
      final latestVersion = response['version'] as String;
      final apkUrl = response['apkUrl'] as String;
      final forceUpdate = response['forceUpdate'] as bool;
      final releaseNotes = response['releaseNotes'] as Map<String, dynamic>;
      
      // Compare versions
      if (_isNewerVersion(latestVersion, currentVersion)) {
        debugPrint('[APK Update] ✅ Update available: $currentVersion -> $latestVersion');
        
        await _showUpdateDialog(
          context: context,
          currentVersion: currentVersion,
          newVersion: latestVersion,
          apkUrl: apkUrl,
          forceUpdate: forceUpdate,
          releaseNotes: releaseNotes['pt'] ?? releaseNotes['en'],
        );
      } else {
        debugPrint('[APK Update] App is up to date');
      }
    } catch (e) {
      debugPrint('[APK Update] Error checking for updates: $e');
    }
  }

  bool _isNewerVersion(String serverVersion, String currentVersion) {
    final serverParts = serverVersion.split('.').map(int.parse).toList();
    final currentParts = currentVersion.split('.').map(int.parse).toList();
    
    for (int i = 0; i < serverParts.length; i++) {
      if (i >= currentParts.length) return true;
      if (serverParts[i] > currentParts[i]) return true;
      if (serverParts[i] < currentParts[i]) return false;
    }
    return false;
  }

  Future<void> _showUpdateDialog({
    required BuildContext context,
    required String currentVersion,
    required String newVersion,
    required String apkUrl,
    required bool forceUpdate,
    required String releaseNotes,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('🎉 Nova Versão Disponível'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Versão atual: $currentVersion'),
                Text('Nova versão: $newVersion', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text('Novidades:', 
                  style: TextStyle(fontWeight: FontWeight.bold)),
                Text(releaseNotes),
                
                if (_isDownloading) ...[
                  SizedBox(height: 16),
                  LinearProgressIndicator(value: _downloadProgress),
                  SizedBox(height: 8),
                  Text('Baixando: ${(_downloadProgress * 100).toInt()}%',
                    textAlign: TextAlign.center),
                ],
              ],
            ),
            actions: [
              if (!forceUpdate && !_isDownloading)
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text('Depois'),
                ),
              ElevatedButton(
                onPressed: _isDownloading ? null : () async {
                  setState(() {
                    _isDownloading = true;
                    _downloadProgress = 0.0;
                  });
                  
                  await _downloadAndInstallAPK(
                    apkUrl,
                    onProgress: (progress) {
                      setState(() {
                        _downloadProgress = progress;
                      });
                    },
                  );
                  
                  if (!forceUpdate) Navigator.pop(context);
                },
                child: Text(_isDownloading ? 'Baixando...' : 'Atualizar Agora'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _downloadAndInstallAPK(
    String apkUrl, {
    required Function(double) onProgress,
  }) async {
    try {
      // Request install permission
      final hasPermission = await _requestInstallPermission();
      if (!hasPermission) {
        debugPrint('[APK Update] Install permission denied');
        return;
      }

      // Get download directory
      final dir = await getExternalStorageDirectory();
      final apkPath = '${dir!.path}/tcs-pace-scheduler-update.apk';
      
      debugPrint('[APK Update] Downloading APK to: $apkPath');

      // Download APK with progress
      await _dio.download(
        apkUrl,
        apkPath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = received / total;
            onProgress(progress);
            debugPrint('[APK Update] Progress: ${(progress * 100).toInt()}%');
          }
        },
      );

      debugPrint('[APK Update] ✅ Download complete, installing...');

      // Install APK
      await OpenFilex.open(apkPath);
      
      debugPrint('[APK Update] ✅ Install prompt opened');
    } catch (e) {
      debugPrint('[APK Update] ❌ Error downloading/installing: $e');
      rethrow;
    } finally {
      _isDownloading = false;
    }
  }

  Future<bool> _requestInstallPermission() async {
    if (Platform.isAndroid) {
      // Android 8+ requires REQUEST_INSTALL_PACKAGES permission
      final status = await Permission.requestInstallPackages.request();
      return status.isGranted;
    }
    return true;
  }
}
```

### 5. Usar no App

```dart
// lib/screens/dashboard_screen.dart
import '../services/apk_update_service.dart';

@override
void initState() {
  super.initState();
  
  // Check for updates 5 seconds after dashboard loads
  Future.delayed(Duration(seconds: 5), () {
    APKUpdateService().checkAndUpdate(context);
  });
}
```

---

## 🔧 Build & Deploy

### 1. Build APK de Produção

```bash
# Build release APK
flutter build apk --release

# APK estará em:
# build/app/outputs/flutter-apk/app-release.apk
```

### 2. Assinar APK (Importante!)

```bash
# Criar keystore (primeira vez)
keytool -genkey -v -keystore ~/tcs-scheduler-keystore.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias tcs-scheduler

# Configurar em android/key.properties:
storePassword=your_password
keyPassword=your_key_password
keyAlias=tcs-scheduler
storeFile=/home/user/tcs-scheduler-keystore.jks
```

```gradle
// android/app/build.gradle.kts
android {
    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }
    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### 3. Upload APK para Backend

```bash
# Copiar APK para backend
cp build/app/outputs/flutter-apk/app-release.apk \
   ../sched-be/uploads/tcs-pace-scheduler.apk

# Verificar tamanho
ls -lh ../sched-be/uploads/tcs-pace-scheduler.apk
```

### 4. Atualizar Versão no Backend

```typescript
// sched-be/src/routes/version.ts
app.get('/current', (c) => {
  return c.json({
    version: '1.0.1', // ← Incrementar aqui
    buildNumber: 2,   // ← Incrementar aqui
    // ...
  });
});
```

---

## 🧪 Testar Update

### Cenário 1: Update Opcional

1. App atual: versão 1.0.0
2. Backend retorna: versão 1.0.1, forceUpdate: false
3. Resultado: Dialog com "Depois" e "Atualizar Agora"

### Cenário 2: Update Forçado

1. App atual: versão 1.0.0
2. Backend retorna: versão 1.0.1, forceUpdate: true
3. Resultado: Dialog sem "Depois", usuário DEVE atualizar

### Cenário 3: Versão Mínima

1. App atual: versão 0.9.0
2. Backend retorna: minVersion: 1.0.0
3. Resultado: Bloqueia app até atualizar

---

## 📊 Fluxo Completo

```
App Start
   ↓
Login Success
   ↓
Wait 5 seconds
   ↓
Check /api/version/current
   ↓
Compare versions
   ↓
┌─────────────────────────────┐
│ New version available?      │
├─────────────────────────────┤
│ YES → Show update dialog    │
│       ├─ User clicks update │
│       ├─ Download APK (45MB)│
│       ├─ Show progress bar  │
│       ├─ Request install perm│
│       └─ Open APK installer │
│                              │
│ NO  → Continue normally     │
└─────────────────────────────┘
   ↓
User installs APK
   ↓
App restarts with new version
```

---

## ⚠️ Segurança

### 1. HTTPS Obrigatório
```typescript
// Sempre use HTTPS para download
const apkUrl = 'https://your-domain.com/api/version/download/apk';
```

### 2. Checksum Verification
```dart
// Verificar integridade do APK
import 'package:crypto/crypto.dart';

Future<bool> verifyAPKChecksum(String filePath, String expectedChecksum) async {
  final bytes = await File(filePath).readAsBytes();
  final digest = sha256.convert(bytes);
  return digest.toString() == expectedChecksum;
}
```

### 3. Assinatura Digital
- SEMPRE assine APKs com mesmo certificado
- Guarde keystore em local seguro
- Nunca comite keystore no Git

---

## 🎯 Vantagens vs Desvantagens

### ✅ Vantagens
- Controle total sobre atualizações
- Sem dependência de Google Play
- Deploy instantâneo (sem review)
- Funciona offline (após primeiro download)

### ❌ Desvantagens
- Usuários precisam permitir "fontes desconhecidas"
- Sem revisão de segurança da Google
- Você é responsável por bugs
- Não funciona em iOS (só Android)

---

## 🚀 Alternativa: Firebase App Distribution

Se quiser mais segurança e facilidade:

```bash
# Instalar Firebase CLI
npm install -g firebase-tools

# Upload APK
firebase appdistribution:distribute \
  build/app/outputs/flutter-apk/app-release.apk \
  --app 1:123456789:android:abc123 \
  --groups "internal-testers" \
  --release-notes "Bug fixes and improvements"
```

Firebase App Distribution oferece:
- ✅ Detecção automática de updates
- ✅ Notificação push de nova versão
- ✅ Dashboard de instalações
- ✅ Gratuito até 150 testadores

---

## 📝 Resumo

Para auto-update sem loja:

1. **Build APK signed** com release keystore
2. **Upload** para seu servidor (sched-be/uploads/)
3. **Endpoint** /api/version/download/apk
4. **Flutter service** baixa e instala automaticamente
5. **Usuário** só clica "Atualizar Agora"

**Recomendação:** Use Firebase App Distribution para testes, depois migre para Google Play em produção.
