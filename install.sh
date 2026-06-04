#!/bin/bash

echo "=============================================="
echo "  STERNTOOLS - Auto Installer"
echo "=============================================="
echo ""

if [ "$EUID" -eq 0 ]; then
    SUDO=""
else
    SUDO="sudo"
fi

detect_pkg_manager() {
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v apt-get >/dev/null 2>&1; then
        echo "apt-get"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    else
        echo "unknown"
    fi
}

install_debian() {
    echo "[*] Detected Debian/Ubuntu"
    echo "[*] Updating package lists..."
    $SUDO apt update -qq

    echo "[*] Installing tools..."
    $SUDO apt install -y \
        nmap \
        feroxbuster \
        whatweb \
        nikto \
        volatility3 \
        tshark \
        binwalk \
        foremost \
        exiftool \
        curl \
        wget \
        xxd \
        file

    # subfinder (Go-based, install manually if not available)
    if ! command -v subfinder >/dev/null 2>&1; then
        echo "[*] Installing subfinder (Go-based)..."
        if command -v go >/dev/null 2>&1; then
            go install github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest
            $SUDO cp ~/go/bin/subfinder /usr/local/bin/
        else
            echo "  [!] Go not found. Install via: sudo apt install golang-go"
            echo "  [!] Then rerun this script, or manually: go install ..."
        fi
    fi

    # nuclei (Go-based)
    if ! command -v nuclei >/dev/null 2>&1; then
        echo "[*] Installing nuclei (Go-based)..."
        if command -v go >/dev/null 2>&1; then
            go install github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest
            $SUDO cp ~/go/bin/nuclei /usr/local/bin/
            nuclei -update-templates 2>/dev/null &
        fi
    fi
}

install_arch() {
    echo "[*] Detected Arch Linux"
    $SUDO pacman -S --noconfirm \
        nmap \
        whatweb \
        nikto \
        volatility3 \
        tshark \
        foremost \
        exiftool \
        curl \
        wget
    echo "  [!] Install feroxbuster, subfinder, nuclei manually:"
    echo "      yay -S feroxbuster subfinder nuclei binwalk"
}

install_fedora() {
    echo "[*] Detected Fedora"
    $SUDO dnf install -y \
        nmap \
        whatweb \
        nikto \
        tshark \
        foremost \
        exiftool \
        curl \
        wget
    echo "  [!] Install volatility3: pip3 install volatility3"
    echo "  [!] Install feroxbuster: cargo install feroxbuster"
}

PKG_MANAGER=$(detect_pkg_manager)
case "$PKG_MANAGER" in
    apt|apt-get) install_debian ;;
    pacman)      install_arch ;;
    dnf)         install_fedora ;;
    *)
        echo "[!] Unknown package manager. Install manually:"
        echo "    nmap feroxbuster whatweb nikto nuclei subfinder"
        echo "    volatility3 tshark binwalk foremost exiftool"
        ;;
esac

echo ""
echo "=============================================="
echo "  Verification:"
echo "=============================================="
for tool in nmap feroxbuster whatweb nikto nuclei subfinder volatility3 tshark binwalk foremost exiftool curl wget; do
    if command -v "$tool" >/dev/null 2>&1; then
        echo "  [OK] $tool"
    else
        echo "  [--] $tool (not installed)"
    fi
done
echo ""
echo "Done. Run ./sterntools.sh to start."
