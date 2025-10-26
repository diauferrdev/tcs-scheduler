# 📜 Scripts - TCS Pace Scheduler

Scripts organizados por categoria para facilitar desenvolvimento e builds.

## 📁 Estrutura

```
scripts/
├── build/          # Scripts de build por plataforma
│   ├── android.sh
│   ├── web.sh
│   ├── windows.sh
│   ├── windows.bat
│   └── README.md
│
└── setup/          # Scripts de configuração inicial
    ├── install_icons.sh
    └── README.md
```

## 🚀 Build Scripts

Para builds de produção, use os scripts em `build/`:

```bash
# Android
./scripts/build/android.sh

# Web
./scripts/build/web.sh

# Windows (Git Bash/WSL)
./scripts/build/windows.sh

# Windows (CMD)
scripts\build\windows.bat
```

Ver: [scripts/build/README.md](build/README.md)

## 🛠️ Setup Scripts

Para configuração inicial do projeto:

```bash
# Instalar ícones
./scripts/setup/install_icons.sh
```

Ver: [scripts/setup/README.md](setup/README.md)

---

**Última atualização**: 2024-10-17
