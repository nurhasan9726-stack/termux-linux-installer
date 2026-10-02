#!/data/data/com.termux/files/usr/bin/bash
#######################################################
#  📱 LINUX ON ANDROID - Automatic Installer
#  
#  One-command Linux installer for Android (Termux)
#  No root required
#
#  Usage:
#  curl -sL https://raw.githubusercontent.com/USERNAME/linux-on-android/main/install.sh | bash
#######################################################

set -e

# ============== CONFIG ==============
TOTAL_STEPS=7
CURRENT_STEP=0
DISTRO="ubuntu"                 # ubuntu | debian | archlinux | alpine | fedora
INSTALL_DESKTOP="yes"           # yes / no  ← ubah ke "no" kalau tidak mau desktop
USERNAME=$(whoami)

# ============== COLORS ==============
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
GRAY='\033[0;90m'
NC='\033[0m'

# ============== FUNCTIONS ==============
update_progress() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    PERCENT=$((CURRENT_STEP * 100 / TOTAL_STEPS))
    FILLED=$((PERCENT / 5))
    EMPTY=$((20 - FILLED))

    BAR="${GREEN}"
    for ((i=0; i<FILLED; i++)); do BAR+="█"; done
    BAR+="${GRAY}"
    for ((i=0; i<EMPTY; i++)); do BAR+="░"; done
    BAR+="${NC}"

    echo ""
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  📊 PROGRESS: ${WHITE}Step ${CURRENT_STEP}/${TOTAL_STEPS}${NC} ${BAR} ${WHITE}${PERCENT}%${NC}"
    echo -e "${WHITE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

spinner() {
    local pid=$1
    local message=$2
    local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
    local i=0

    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % 10 ))
        printf "\r  ${YELLOW}⏳${NC} ${message} ${CYAN}${spin:$i:1}${NC}  "
        sleep 0.1
    done
    wait $pid
    local code=$?
    if [ $code -eq 0 ]; then
        printf "\r  ${GREEN}✓${NC} ${message}                    \n"
    else
        printf "\r  ${RED}✗${NC} ${message} ${RED}(failed)${NC}\n"
        return $code
    fi
}

install_pkg() {
    local pkg=$1
    local name=${2:-$pkg}
    (yes | pkg install -y $pkg > /dev/null 2>&1) &
    spinner $! "Installing ${name}..."
}

show_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'BANNER'
    ╔══════════════════════════════════════╗
    ║                                      ║
    ║   🐧  LINUX ON ANDROID  🐧           ║
    ║                                      ║
    ║     Automatic Installer              ║
    ║                                      ║
    ╚══════════════════════════════════════╝
BANNER
    echo -e "${NC}"
    echo -e "${WHITE}         Termux + proot-distro${NC}"
    echo ""
}

detect_device() {
    echo -e "${PURPLE}[*] Detecting device...${NC}"
    echo ""
    DEVICE_MODEL=$(getprop ro.product.model 2>/dev/null || echo "Unknown")
    DEVICE_BRAND=$(getprop ro.product.brand 2>/dev/null || echo "Unknown")
    ANDROID_VERSION=$(getprop ro.build.version.release 2>/dev/null || echo "Unknown")
    CPU_ABI=$(getprop ro.product.cpu.abi 2>/dev/null || echo "arm64-v8a")

    echo -e "  ${GREEN}📱${NC} Device  : ${WHITE}${DEVICE_BRAND} ${DEVICE_MODEL}${NC}"
    echo -e "  ${GREEN}🤖${NC} Android : ${WHITE}${ANDROID_VERSION}${NC}"
    echo -e "  ${GREEN}⚙️${NC}  CPU     : ${WHITE}${CPU_ABI}${NC}"
    echo -e "  ${GREEN}🐧${NC} Distro  : ${WHITE}${DISTRO^}${NC}"
    echo ""
    sleep 1
}

# ============== STEPS ==============
step_update() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}] Updating Termux packages...${NC}"
    (yes | pkg update -y > /dev/null 2>&1) &
    spinner $! "Updating package lists..."
    (yes | pkg upgrade -y > /dev/null 2>&1) &
    spinner $! "Upgrading packages..."
}

step_deps() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}] Installing dependencies...${NC}"
    install_pkg "proot-distro" "proot-distro"
    install_pkg "wget" "wget"
    install_pkg "curl" "curl"
    install_pkg "git" "git"
    install_pkg "proot" "proot"
}

step_install_distro() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}] Installing ${DISTRO^} Linux...${NC}"
    echo -e "  ${YELLOW}→${NC} Ini bisa memakan waktu 3-10 menit tergantung koneksi"

    if proot-distro list 2>/dev/null | grep -qi "${DISTRO}.*installed"; then
        echo -e "  ${GREEN}✓${NC} ${DISTRO^} sudah terinstall sebelumnya"
    else
        (proot-distro install $DISTRO > /tmp/proot-install.log 2>&1) &
        spinner $! "Downloading & extracting ${DISTRO^}..."
    fi
}

step_configure() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}] Configuring ${DISTRO^}...${NC}"

    proot-distro login $DISTRO --shared-tmp -- bash -c '
        export DEBIAN_FRONTEND=noninteractive
        apt-get update -qq > /dev/null 2>&1 || true
        apt-get upgrade -y -qq > /dev/null 2>&1 || true
        apt-get install -y -qq sudo nano wget curl git neofetch locales > /dev/null 2>&1 || true
        echo "export TERM=xterm-256color" >> ~/.bashrc
        echo "export LANG=C.UTF-8" >> ~/.bashrc
    ' &
    spinner $! "Installing base packages inside Linux..."
}

step_desktop() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}] Desktop Environment...${NC}"

    if [ "$INSTALL_DESKTOP" = "yes" ]; then
        install_pkg "x11-repo" "X11 Repository"
        install_pkg "termux-x11-nightly" "Termux-X11"
        install_pkg "xfce4" "XFCE4 Desktop"
        install_pkg "xfce4-terminal" "XFCE Terminal"
        install_pkg "pulseaudio" "PulseAudio"

        # Desktop launcher
        cat > $HOME/start-linux-desktop.sh << 'EOF'
#!/data/data/com.termux/files/usr/bin/bash
echo ""
echo "🚀 Starting Linux Desktop (XFCE)..."
echo ""

# Cleanup
pkill -9 -f "termux.x11" 2>/dev/null || true
pkill -9 -f "xfce" 2>/dev/null || true
pkill -9 -f "dbus" 2>/dev/null || true

# Audio
pulseaudio --start --exit-idle-time=-1 2>/dev/null || true
export PULSE_SERVER=127.0.0.1

# X11
echo "📺 Starting Termux-X11..."
termux-x11 :0 -ac &
sleep 3
export DISPLAY=:0

echo "🖥️  Launching XFCE4..."
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Buka aplikasi Termux-X11 untuk melihat desktop"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

proot-distro login ubuntu --shared-tmp -- env DISPLAY=:0 PULSE_SERVER=127.0.0.1 startxfce4
EOF
        chmod +x $HOME/start-linux-desktop.sh
        echo -e "  ${GREEN}✓${NC} Desktop launcher: ~/start-linux-desktop.sh"
    else
        echo -e "  ${YELLOW}→${NC} Desktop dilewati (INSTALL_DESKTOP=no)"
    fi
}

step_launcher() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}] Creating launcher...${NC}"

    # Command: linux
    cat > $HOME/linux << EOF
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login $DISTRO --shared-tmp \$@
EOF
    chmod +x $HOME/linux

    # Alias
    if ! grep -q "alias linux=" $HOME/.bashrc 2>/dev/null; then
        echo "" >> $HOME/.bashrc
        echo "# Linux on Android" >> $HOME/.bashrc
        echo "alias linux='proot-distro login $DISTRO --shared-tmp'" >> $HOME/.bashrc
    fi

    # Symlink ke bin biar bisa dipanggil dari mana saja
    mkdir -p $PREFIX/bin
    ln -sf $HOME/linux $PREFIX/bin/linux 2>/dev/null || true

    echo -e "  ${GREEN}✓${NC} Command 'linux' siap digunakan"
}

step_finish() {
    update_progress
    echo -e "${PURPLE}[Step ${CURRENT_STEP}] Finalizing...${NC}"
    echo -e "  ${GREEN}✓${NC} Semua selesai!"
}

# ============== MAIN ==============
main() {
    show_banner
    detect_device

    echo -e "${WHITE}Script akan menginstal Linux (${DISTRO^}) secara otomatis.${NC}"
    echo -e "${WHITE}Tidak perlu root. Membutuhkan ±1.5–2.5 GB storage.${NC}"
    echo ""
    read -p "  Lanjutkan? (y/n): " confirm
    [[ "$confirm" =~ ^[Yy]$ ]] || { echo -e "${RED}Dibatalkan.${NC}"; exit 0; }

    step_update
    step_deps
    step_install_distro
    step_configure
    step_desktop
    step_launcher
    step_finish

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            ✅ INSTALASI SELESAI!                 ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${WHITE}Cara masuk ke Linux:${NC}"
    echo -e "  ${CYAN}linux${NC}"
    echo ""
    if [ "$INSTALL_DESKTOP" = "yes" ]; then
        echo -e "${WHITE}Cara jalankan Desktop:${NC}"
        echo -e "  1. Buka aplikasi ${CYAN}Termux-X11${NC}"
        echo -e "  2. Jalankan perintah: ${CYAN}bash ~/start-linux-desktop.sh${NC}"
        echo ""
    fi
    echo -e "${YELLOW}Tips:${NC}"
    echo -e "  • Setelah masuk Linux ketik: ${CYAN}neofetch${NC}"
    echo -e "  • Update Linux: ${CYAN}apt update && apt upgrade${NC}"
    echo ""
    echo -e "${GRAY}Restart Termux disarankan agar alias 'linux' aktif.${NC}"
    echo ""
}

# Jalankan hanya jika di Termux
if [ -z "$PREFIX" ] || [[ "$PREFIX" != *"com.termux"* ]]; then
    echo -e "${RED}Error: Script ini harus dijalankan di dalam Termux!${NC}"
    exit 1
fi

main
