#!/bin/bash

# ========================================
# TCS Pace Scheduler - Build Menu
# Central script para builds multiplataforma
# ========================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

clear

echo -e "${CYAN}"
cat << "EOF"
╔════════════════════════════════════════════════════════════════╗
║                                                                ║
║     ████████╗ ██████╗███████╗    ██████╗  █████╗  ██████╗███████╗ ║
║     ╚══██╔══╝██╔════╝██╔════╝    ██╔══██╗██╔══██╗██╔════╝██╔════╝ ║
║        ██║   ██║     ███████╗    ██████╔╝███████║██║     █████╗   ║
║        ██║   ██║     ╚════██║    ██╔═══╝ ██╔══██║██║     ██╔══╝   ║
║        ██║   ╚██████╗███████║    ██║     ██║  ██║╚██████╗███████╗ ║
║        ╚═╝    ╚═════╝╚══════╝    ╚═╝     ╚═╝  ╚═╝ ╚═════╝╚══════╝ ║
║                                                                ║
║              S C H E D U L E R   -   B U I L D                 ║
║                                                                ║
╚════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Navigate to project root
cd "$(dirname "$0")/../.."

# Get current version
CURRENT_VERSION=$(grep "^version:" pubspec.yaml | sed 's/version: //')
VERSION_NAME=$(echo $CURRENT_VERSION | cut -d'+' -f1)
BUILD_NUMBER=$(echo $CURRENT_VERSION | cut -d'+' -f2)

echo -e "${BLUE}Current Version:${NC} $VERSION_NAME (build $BUILD_NUMBER)"
echo ""

# Check Firebase CLI
if command -v firebase &> /dev/null; then
    echo -e "${GREEN}✓${NC} Firebase CLI: Installed"
else
    echo -e "${RED}✗${NC} Firebase CLI: Not installed"
fi

# Check Flutter
if command -v flutter &> /dev/null; then
    FLUTTER_VERSION=$(flutter --version | head -1)
    echo -e "${GREEN}✓${NC} Flutter: $FLUTTER_VERSION"
else
    echo -e "${RED}✗${NC} Flutter: Not installed"
fi

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

# Menu
echo -e "${YELLOW}Select build platform:${NC}"
echo ""
echo -e "  ${GREEN}1)${NC} 📱 Android (APK + Firebase Distribution)"
echo -e "  ${GREEN}2)${NC} 🍎 iOS (IPA)"
echo -e "  ${GREEN}3)${NC} 🖥️  macOS (App)"
echo -e "  ${GREEN}4)${NC} 🪟 Windows (EXE)"
echo -e "  ${GREEN}5)${NC} 🐧 Linux (Binary)"
echo -e "  ${GREEN}6)${NC} 🌐 Web (HTML/JS)"
echo ""
echo -e "  ${MAGENTA}7)${NC} 🚀 Build All Platforms"
echo ""
echo -e "  ${RED}0)${NC} Exit"
echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════${NC}"
echo ""

read -p "$(echo -e ${YELLOW}Enter choice [0-7]: ${NC})" choice

echo ""

case $choice in
    1)
        echo -e "${GREEN}Building Android APK...${NC}"
        echo ""
        ./scripts/build/android.sh
        ;;
    2)
        echo -e "${GREEN}Building iOS IPA...${NC}"
        echo ""
        ./scripts/build/ios.sh
        ;;
    3)
        echo -e "${GREEN}Building macOS App...${NC}"
        echo ""
        ./scripts/build/macos.sh
        ;;
    4)
        echo -e "${GREEN}Building Windows EXE...${NC}"
        echo ""
        ./scripts/build/windows.sh
        ;;
    5)
        echo -e "${GREEN}Building Linux Binary...${NC}"
        echo ""
        ./scripts/build/linux.sh
        ;;
    6)
        echo -e "${GREEN}Building Web App...${NC}"
        echo ""
        ./scripts/build/web.sh
        ;;
    7)
        echo -e "${MAGENTA}Building ALL platforms...${NC}"
        echo ""
        echo -e "${YELLOW}This will take a while...${NC}"
        echo ""

        # Android
        echo -e "${CYAN}[1/6] Building Android...${NC}"
        ./scripts/build/android.sh
        echo ""

        # iOS (only on macOS)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo -e "${CYAN}[2/6] Building iOS...${NC}"
            ./scripts/build/ios.sh
            echo ""
        else
            echo -e "${YELLOW}[2/6] Skipping iOS (requires macOS)${NC}"
            echo ""
        fi

        # macOS (only on macOS)
        if [[ "$OSTYPE" == "darwin"* ]]; then
            echo -e "${CYAN}[3/6] Building macOS...${NC}"
            ./scripts/build/macos.sh
            echo ""
        else
            echo -e "${YELLOW}[3/6] Skipping macOS (requires macOS)${NC}"
            echo ""
        fi

        # Windows
        echo -e "${CYAN}[4/6] Building Windows...${NC}"
        ./scripts/build/windows.sh
        echo ""

        # Linux
        echo -e "${CYAN}[5/6] Building Linux...${NC}"
        ./scripts/build/linux.sh
        echo ""

        # Web
        echo -e "${CYAN}[6/6] Building Web...${NC}"
        ./scripts/build/web.sh
        echo ""

        echo -e "${GREEN}✓ All builds completed!${NC}"
        ;;
    0)
        echo -e "${BLUE}Exiting...${NC}"
        exit 0
        ;;
    *)
        echo -e "${RED}Invalid choice!${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}Build process completed!${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════════${NC}"
echo ""
