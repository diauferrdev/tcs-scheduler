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

Use the unified script:
```bash
cd sched-fe
bash build_all.sh          # Interactive menu
bash build_all.sh android  # Direct build
bash build_all.sh web
bash build_all.sh windows
bash build_all.sh linux
bash build_all.sh macos    # Requires macOS
bash build_all.sh ios      # Requires macOS
bash build_all.sh all      # Build everything
```

### Platform Status

| Platform | Build Command | Output | Distribution |
|----------|--------------|--------|-------------|
| Android | `flutter build apk --release` | `build/app/outputs/flutter-apk/app-release.apk` | Firebase / Direct download |
| Web | `flutter build web --release` | `build/web/` | Caddy on VPS |
| Windows | `flutter build windows --release` | `build/windows/x64/runner/Release/` | MSIX package |
| Linux | `flutter build linux --release` | `build/linux/x64/release/bundle/` | AppImage |
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
