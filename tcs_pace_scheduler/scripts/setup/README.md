# 🛠️ Setup Scripts - TCS Pace Scheduler

Scripts de configuração e setup do projeto.

## 📋 Scripts Disponíveis

### 🎨 install_icons.sh

Instala ícones do aplicativo em todas as plataformas.

**Uso:**
```bash
./scripts/setup/install_icons.sh
```

**O que faz:**
- 📱 **Android**: Copia ícones para `android/app/src/main/res/mipmap-*`
- 🍎 **iOS**: Copia ícones para `ios/Runner/Assets.xcassets/AppIcon.appiconset/`
- 🖥️ **macOS**: Copia ícone `.icns` para macOS app
- 🌐 **Web**: Copia favicons e ícones PWA para `web/`

**Após executar:**
1. `flutter clean`
2. `flutter pub get`
3. Rebuild o app

**Requisitos:**
- Ícones devem estar em `assets/icons/` organizados por plataforma

---

## 📁 Estrutura Esperada de Ícones

```
assets/icons/
├── android/
│   └── res/
│       ├── mipmap-hdpi/
│       ├── mipmap-mdpi/
│       ├── mipmap-xhdpi/
│       ├── mipmap-xxhdpi/
│       └── mipmap-xxxhdpi/
├── ios/
│   └── (arquivos .png do AppIcon)
├── macos/
│   └── AppIcon.icns
└── web/
    ├── favicon.ico
    ├── icon-192.png
    ├── icon-192-maskable.png
    ├── icon-512.png
    ├── icon-512-maskable.png
    └── apple-touch-icon.png
```

---

**Última atualização**: 2024-10-17
