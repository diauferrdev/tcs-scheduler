# Auto-Update Implementation Guide - Flutter

## 🎯 Objetivo
Implementar sistema de atualização automática que detecta novas versões e atualiza o app automaticamente (como Google Play/App Store).

---

## 📱 Estratégias por Plataforma

### 1. **Android** - In-App Update (Google Play)

Usa a API oficial do Google Play para atualizações automáticas dentro do app.

#### Implementação:

```yaml
# pubspec.yaml
dependencies:
  in_app_update: ^4.2.2
```

```dart
// lib/services/update_service.dart
import 'package:in_app_update/in_app_update.dart';
import 'package:flutter/foundation.dart';

class UpdateService {
  static final UpdateService _instance = UpdateService._internal();
  factory UpdateService() => _instance;
  UpdateService._internal();

  /// Check for updates and show update dialog
  Future<void> checkForUpdate() async {
    if (!defaultTargetPlatform == TargetPlatform.android) {
      debugPrint('[Update] Not Android, skipping');
      return;
    }

    try {
      debugPrint('[Update] Checking for updates...');
      
      // Check if update is available
      final AppUpdateInfo info = await InAppUpdate.checkForUpdate();
      
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        debugPrint('[Update] ✅ Update available!');
        
        // Option 1: IMMEDIATE update (blocks UI until updated)
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
        }
        
        // Option 2: FLEXIBLE update (downloads in background)
        else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          
          // Listen for download status
          InAppUpdate.completeFlexibleUpdate().then((_) {
            debugPrint('[Update] ✅ Update installed successfully');
          });
        }
      } else {
        debugPrint('[Update] App is up to date');
      }
    } catch (e) {
      debugPrint('[Update] Error checking for updates: $e');
    }
  }
}
```

#### Usar no App:

```dart
// lib/main.dart ou lib/screens/dashboard_screen.dart
@override
void initState() {
  super.initState();
  
  // Check for updates on app start (after 3 seconds)
  Future.delayed(Duration(seconds: 3), () {
    UpdateService().checkForUpdate();
  });
}
```

#### Tipos de Update:

| Tipo | Comportamento | Uso |
|------|---------------|-----|
| **IMMEDIATE** | Bloqueia UI, força atualização | Updates críticos/segurança |
| **FLEXIBLE** | Download em background | Updates normais |

---

### 2. **iOS** - App Store Auto-Update

iOS usa o App Store para atualizações. Não há In-App Update como Android.

#### Opção 1: Verificar versão via API

```dart
import 'package:package_info_plus/package_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class IOSUpdateService {
  static const String APP_STORE_ID = 'YOUR_APP_ID_HERE'; // Get from App Store Connect
  
  Future<void> checkForUpdate() async {
    try {
      // Get current app version
      final PackageInfo info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      
      // Check App Store for latest version
      final response = await http.get(
        Uri.parse('https://itunes.apple.com/lookup?id=$APP_STORE_ID'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final storeVersion = data['results'][0]['version'];
        
        if (_isNewerVersion(storeVersion, currentVersion)) {
          _showUpdateDialog(storeVersion);
        }
      }
    } catch (e) {
      debugPrint('[iOS Update] Error: $e');
    }
  }
  
  bool _isNewerVersion(String storeVersion, String currentVersion) {
    final storeParts = storeVersion.split('.').map(int.parse).toList();
    final currentParts = currentVersion.split('.').map(int.parse).toList();
    
    for (int i = 0; i < storeParts.length; i++) {
      if (storeParts[i] > currentParts[i]) return true;
      if (storeParts[i] < currentParts[i]) return false;
    }
    return false;
  }
  
  void _showUpdateDialog(String newVersion) {
    // Show dialog with link to App Store
    final url = 'https://apps.apple.com/app/id$APP_STORE_ID';
    // Open URL using url_launcher
  }
}
```

#### Dependências:

```yaml
dependencies:
  package_info_plus: ^8.0.0
  url_launcher: ^6.3.0
```

---

### 3. **Web** - Service Worker Auto-Update

PWAs usam Service Workers para cache e atualizações automáticas.

#### Implementação:

```javascript
// web/sw.js (já existe no projeto)
self.addEventListener('install', (event) => {
  console.log('[SW] Installing new version...');
  self.skipWaiting(); // Force activate new SW immediately
});

self.addEventListener('activate', (event) => {
  console.log('[SW] Activating new version...');
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cacheName) => {
          // Delete old caches
          return caches.delete(cacheName);
        })
      );
    })
  );
  return self.clients.claim(); // Take control of all clients
});

// Notify clients about update
self.addEventListener('message', (event) => {
  if (event.data.action === 'skipWaiting') {
    self.skipWaiting();
  }
});
```

```dart
// lib/services/web_update_service.dart
import 'package:flutter/foundation.dart';
import 'dart:html' as html;

class WebUpdateService {
  void checkForUpdate() {
    if (!kIsWeb) return;
    
    html.window.navigator.serviceWorker?.ready.then((registration) {
      registration.addEventListener('updatefound', (event) {
        debugPrint('[Web Update] New version found!');
        
        final newWorker = registration.installing;
        newWorker?.addEventListener('statechange', (event) {
          if (newWorker.state == 'installed') {
            if (html.window.navigator.serviceWorker?.controller != null) {
              _showUpdateNotification();
            }
          }
        });
      });
    });
  }
  
  void _showUpdateNotification() {
    // Show snackbar/dialog: "New version available! Refresh to update"
  }
  
  void applyUpdate() {
    html.window.location.reload();
  }
}
```

---

### 4. **Solução Universal** - Backend Version Check

Funciona em TODAS as plataformas (recomendado para TCS Pace Scheduler).

#### Backend:

```typescript
// sched-be/src/routes/version.ts
import { Hono } from 'hono';

const app = new Hono();

app.get('/current', (c) => {
  return c.json({
    version: '1.0.0',
    buildNumber: 1,
    minVersion: '1.0.0', // Minimum supported version
    forceUpdate: false,  // Force user to update
    updateUrl: {
      android: 'https://play.google.com/store/apps/details?id=com.tcs.paceport.scheduler',
      ios: 'https://apps.apple.com/app/id123456789',
      web: 'https://scheduler.tcs.com',
    },
    releaseNotes: {
      'en': 'Bug fixes and performance improvements',
      'pt': 'Correções de bugs e melhorias de performance',
    }
  });
});

export default app;
```

```typescript
// sched-be/src/index.ts
import versionRoutes from './routes/version';
app.route('/api/version', versionRoutes);
```

#### Flutter:

```dart
// lib/services/version_service.dart
import 'package:package_info_plus/package_info_plus.dart';
import 'api_service.dart';

class VersionService {
  final ApiService _apiService = ApiService();
  
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      // Get current version
      final info = await PackageInfo.fromPlatform();
      final currentVersion = info.version;
      final currentBuild = int.parse(info.buildNumber);
      
      // Check backend for latest version
      final response = await _apiService.get('/api/version/current');
      final latestVersion = response['version'] as String;
      final minVersion = response['minVersion'] as String;
      final forceUpdate = response['forceUpdate'] as bool;
      final updateUrls = response['updateUrl'] as Map<String, dynamic>;
      final releaseNotes = response['releaseNotes'] as Map<String, dynamic>;
      
      // Compare versions
      if (_isNewerVersion(latestVersion, currentVersion)) {
        await _showUpdateDialog(
          context: context,
          currentVersion: currentVersion,
          newVersion: latestVersion,
          forceUpdate: forceUpdate,
          releaseNotes: releaseNotes['pt'] ?? releaseNotes['en'],
          updateUrl: _getUpdateUrl(updateUrls),
        );
      }
      
      // Force update if below minimum version
      if (_isOlderThan(currentVersion, minVersion)) {
        await _showForceUpdateDialog(
          context: context,
          updateUrl: _getUpdateUrl(updateUrls),
        );
      }
    } catch (e) {
      debugPrint('[Version] Error checking for updates: $e');
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
  
  bool _isOlderThan(String currentVersion, String minVersion) {
    return _isNewerVersion(minVersion, currentVersion);
  }
  
  String _getUpdateUrl(Map<String, dynamic> urls) {
    if (Platform.isAndroid) return urls['android'];
    if (Platform.isIOS) return urls['ios'];
    return urls['web'];
  }
  
  Future<void> _showUpdateDialog({
    required BuildContext context,
    required String currentVersion,
    required String newVersion,
    required bool forceUpdate,
    required String releaseNotes,
    required String updateUrl,
  }) async {
    await showDialog(
      context: context,
      barrierDismissible: !forceUpdate,
      builder: (context) => AlertDialog(
        title: Text('🎉 Nova Versão Disponível'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Versão atual: $currentVersion'),
            Text('Nova versão: $newVersion', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 16),
            Text('Novidades:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(releaseNotes),
          ],
        ),
        actions: [
          if (!forceUpdate)
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Depois'),
            ),
          ElevatedButton(
            onPressed: () {
              launchUrl(Uri.parse(updateUrl));
              if (!forceUpdate) Navigator.pop(context);
            },
            child: Text('Atualizar Agora'),
          ),
        ],
      ),
    );
  }
}
```

---

## 🚀 Melhor Solução para TCS Pace Scheduler

### Recomendação: **Backend Version Check + Platform-Specific Updates**

```dart
// lib/services/unified_update_service.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';
import 'version_service.dart';
import 'update_service.dart'; // Android in-app update

class UnifiedUpdateService {
  final VersionService _versionService = VersionService();
  final UpdateService _androidUpdateService = UpdateService();
  
  /// Check for updates (call after login)
  Future<void> checkForUpdate(BuildContext context) async {
    try {
      debugPrint('[UnifiedUpdate] Checking for updates...');
      
      if (!kIsWeb && Platform.isAndroid) {
        // Android: Try Google Play in-app update first
        await _androidUpdateService.checkForUpdate();
      }
      
      // All platforms: Check backend version
      await _versionService.checkForUpdate(context);
      
    } catch (e) {
      debugPrint('[UnifiedUpdate] Error: $e');
    }
  }
}
```

#### Usar no App:

```dart
// lib/screens/dashboard_screen.dart
@override
void initState() {
  super.initState();
  
  // Check for updates 5 seconds after dashboard loads
  Future.delayed(Duration(seconds: 5), () {
    UnifiedUpdateService().checkForUpdate(context);
  });
}
```

---

## 📦 Dependências Necessárias

```yaml
# pubspec.yaml
dependencies:
  # Version info
  package_info_plus: ^8.0.0
  
  # Android in-app updates
  in_app_update: ^4.2.2
  
  # Open update URLs
  url_launcher: ^6.3.0
  
  # HTTP requests for version check
  # (Already using ApiService with Dio)
```

---

## 🎯 Fluxo Completo

```
App Start
   ↓
Login Success
   ↓
Wait 5 seconds
   ↓
[Android] → Try Google Play in-app update
   ↓
[All Platforms] → Check backend /api/version/current
   ↓
Compare versions
   ↓
┌──────────────────────────────────────┐
│ New version available?               │
├──────────────────────────────────────┤
│ YES → Show update dialog             │
│       ├─ Force update? → Block UI    │
│       └─ Optional? → Show "Later"    │
│                                       │
│ NO  → Continue normally              │
└──────────────────────────────────────┘
```

---

## 📝 Exemplo de Versioning

```yaml
# pubspec.yaml
version: 1.2.3+10

# 1.2.3 = Version Name (shown to users)
# +10   = Build Number (incremental)
```

**Sempre incremente:**
- **Patch** (1.2.**3**) → Bug fixes
- **Minor** (1.**2**.3) → New features (backwards compatible)
- **Major** (**1**.2.3) → Breaking changes
- **Build** (+**10**) → Every release

---

## ✅ Implementação Recomendada

1. **Adicionar dependências** ao `pubspec.yaml`
2. **Criar** `lib/services/version_service.dart`
3. **Criar backend route** `/api/version/current`
4. **Chamar** `checkForUpdate()` após login
5. **Testar** incrementando versão no backend

Pronto! Seu app vai detectar e atualizar automaticamente! 🚀
