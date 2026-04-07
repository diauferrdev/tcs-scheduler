# Pace Scheduler — Deploy & Build Guide

## Infrastructure

| Service | URL | Tech | Process |
|---------|-----|------|---------|
| Frontend | https://pacesched.com | Flutter Web | Caddy (static files) |
| Backend | https://api.pacesched.com | Hono + Bun | PM2 `tcs-backend` |
| WebSocket | wss://api.pacesched.com/ws | Native Bun WS | Same PM2 process |
| Database | localhost:5432 | PostgreSQL 15+ | systemd |
| APK Download | https://api.pacesched.com/uploads/pace-scheduler-latest.apk | — | Caddy static |

### VPS Access
```bash
ssh root@aimaturity.lat
# Project: /root/tcs/tcs-sched
# Flutter: /opt/flutter/bin/flutter
# Bun: /root/.bun/bin/bun
```

### Caddy Config
- Config file: `/etc/caddy/Caddyfile`
- Frontend: serves `build/web/` with no-cache headers
- Backend: reverse proxy to `localhost:7777`
- Reload: `caddy reload --config /etc/caddy/Caddyfile`

---

## Quick Deploy (Full Stack)

```bash
ssh root@aimaturity.lat "export PATH=/root/.bun/bin:/opt/flutter/bin:\$PATH && \
  cd /root/tcs/tcs-sched && git pull origin main && \
  cd sched-be && bun install && pm2 restart tcs-backend && \
  cd ../sched-fe && rm -rf build/web && flutter clean && flutter pub get && \
  flutter build web --release && \
  sed -i 's|<head>|<head>\n<script>if(\"serviceWorker\" in navigator){navigator.serviceWorker.getRegistrations().then(function(r){r.forEach(function(reg){reg.unregister()})});caches.keys().then(function(c){c.forEach(function(n){caches.delete(n)})})}</script>|' build/web/index.html && \
  echo 'DEPLOY DONE'"
```

### Backend Only
```bash
ssh root@aimaturity.lat "export PATH=/root/.bun/bin:\$PATH && \
  cd /root/tcs/tcs-sched && git pull origin main && \
  cd sched-be && bun install && pm2 restart tcs-backend"
```

### Frontend Only
```bash
ssh root@aimaturity.lat "export PATH=/opt/flutter/bin:\$PATH && \
  cd /root/tcs/tcs-sched && git pull origin main && \
  cd sched-fe && rm -rf build/web && flutter clean && flutter pub get && \
  flutter build web --release && \
  sed -i 's|<head>|<head>\n<script>if(\"serviceWorker\" in navigator){navigator.serviceWorker.getRegistrations().then(function(r){r.forEach(function(reg){reg.unregister()})});caches.keys().then(function(c){c.forEach(function(n){caches.delete(n)})})}</script>|' build/web/index.html"
```

> **Important**: Always use `flutter clean && rm -rf build/web` before building. Stale cache caused production bugs previously.

---

## Android APK

### Build
```bash
cd sched-fe
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk (~97MB)
```

### Signing
- Keystore: `android/pace-scheduler.jks` (gitignored, 10,000 days validity)
- Config: `android/key.properties` (gitignored)
- Alias: `pace-scheduler`
- Falls back to debug signing if `key.properties` is missing

### Upload to VPS (direct download)
```bash
VERSION="1.2.12"  # change this

scp build/app/outputs/flutter-apk/app-release.apk \
  root@aimaturity.lat:/root/tcs/tcs-sched/sched-be/uploads/pace-scheduler-v${VERSION}.apk

ssh root@aimaturity.lat "ln -sf pace-scheduler-v${VERSION}.apk \
  /root/tcs/tcs-sched/sched-be/uploads/pace-scheduler-latest.apk"
```
The landing page links to `pace-scheduler-latest.apk` (symlink always points to newest version).

### Firebase App Distribution
```bash
firebase appdistribution:distribute build/app/outputs/flutter-apk/app-release.apk \
  --app "1:874457674237:android:81596c5009b03f9a9fa994" \
  --groups "testers" \
  --release-notes "v${VERSION} - description here"
```
- Project: `tcs-paceport-scheduler`
- Group: `testers` (Gmail accounts only — @tcs.com emails don't work)
- Testers get push notification to download

---

## Multi-Platform Build

### Prerequisites per Platform

**Windows:**
- Flutter SDK (e.g. `C:\src\flutter`)
- Visual Studio 2022 with "Desktop development with C++" workload
- Git

**Linux (Ubuntu/WSL):**
```bash
sudo apt-get install -y libgstreamer1.0-dev libgstreamer-plugins-base1.0-dev \
  libgtk-3-dev ninja-build cmake clang
```
> Note: `rive_common` plugin has `-Werror` issues. The project CMakeLists already disables it.
> If build still fails, patch pub cache: `sed -i 's/apply_standard_settings/# apply_standard_settings/' ~/.pub-cache/hosted/pub.dev/rive_common-*/linux/CMakeLists.txt`

**macOS:** Xcode 14+ with command line tools
**Android:** Android SDK, JDK 11+, keystore (see Android section above)

---

### Windows Build (run in PowerShell)

```powershell
git clone git@github.com:diauferrdev/tcs-scheduler.git C:\tcs\scheduler
cd C:\tcs\scheduler\sched-fe
flutter pub get
flutter build windows --release
```
Output: `build\windows\x64\runner\Release\`

To zip for distribution:
```powershell
Compress-Archive -Path build\windows\x64\runner\Release\* -DestinationPath pace-scheduler-windows-v1.2.12.zip
```

Upload to VPS:
```bash
scp pace-scheduler-windows-v1.2.12.zip root@aimaturity.lat:/root/tcs/tcs-sched/sched-be/uploads/
ssh root@aimaturity.lat "ln -sf pace-scheduler-windows-v1.2.12.zip /root/tcs/tcs-sched/sched-be/uploads/pace-scheduler-windows-latest.zip"
```

### Linux Build (run in Ubuntu/WSL)

```bash
cd sched-fe
flutter build linux --release
# Package:
cd build/linux/x64/release
tar czf pace-scheduler-linux-v1.2.12.tar.gz -C bundle .
```

Upload to VPS:
```bash
scp pace-scheduler-linux-v1.2.12.tar.gz root@aimaturity.lat:/root/tcs/tcs-sched/sched-be/uploads/
ssh root@aimaturity.lat "ln -sf pace-scheduler-linux-v1.2.12.tar.gz /root/tcs/tcs-sched/sched-be/uploads/pace-scheduler-linux-latest.tar.gz"
```

### Unified Script (Linux/macOS only)

```bash
cd sched-fe
bash build_all.sh          # Interactive menu
bash build_all.sh android  # Direct build
bash build_all.sh web
bash build_all.sh linux
```

### Download Links

| Platform | URL |
|----------|-----|
| Android APK | https://api.pacesched.com/uploads/pace-scheduler-latest.apk |
| Linux tar.gz | https://api.pacesched.com/uploads/pace-scheduler-linux-latest.tar.gz |
| Windows zip | https://api.pacesched.com/uploads/pace-scheduler-windows-latest.zip |

### Platform Status

| Platform | Build Command | Output | Distribution |
|----------|--------------|--------|-------------|
| Android | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` | Firebase / Direct download |
| Web | `flutter build web --release` | `build/web/` | Caddy on VPS |
| Windows | `flutter build windows --release` | `build\windows\x64\runner\Release\` | Zip download |
| Linux | `flutter build linux --release` | `build/linux/x64/release/bundle/` | tar.gz download |
| macOS | `flutter build macos --release` | `build/macos/Build/Products/Release/` | DMG |
| iOS | `flutter build ipa --release` | `build/ios/` | TestFlight |

---

## PM2 Commands

```bash
pm2 list                    # See all processes
pm2 restart tcs-backend     # Restart backend
pm2 logs tcs-backend        # Live logs
pm2 logs tcs-backend --lines 50 --nostream  # Recent logs
```

---

## Database

```bash
# Push schema changes
cd sched-be && bunx prisma db push

# Generate client after schema change
bunx prisma generate

# Open Prisma Studio
bunx prisma studio
```

---

## Troubleshooting

### Stale frontend in production
Always clean build + inject SW killer. The deploy commands above handle this.

### WebSocket not connecting
Check Caddy config has WebSocket matcher:
```
@websocket {
    header Connection *Upgrade*
    header Upgrade websocket
}
reverse_proxy @websocket localhost:7777
```

### Backend not starting
```bash
pm2 logs tcs-backend --lines 20 --nostream  # Check errors
pm2 restart tcs-backend --update-env         # Restart with fresh env
```
