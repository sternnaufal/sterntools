#!/bin/bash
# Example plugin for Sterntools
# Konvensi: PLUGIN_NAME + PLUGIN_DESC + plugin_main()

PLUGIN_NAME="Password Generator"
PLUGIN_DESC="Generate random passwords"

plugin_main() {
    echo -e "\033[0;34m  [PASSWORD GENERATOR]\033[0m"
    echo "  ─────────────────────────────────────────────"
    echo ""
    read -p "  Panjang password: " length
    length=${length:-16}

    echo ""
    echo -e "  \033[1;33m[*]\033[0m Generating 5 passwords (${length} chars)..."
    echo ""

    for i in $(seq 1 5); do
        pass=$(tr -dc 'A-Za-z0-9!#$%&()*+,-./:;<=>?@[]^_{|}~' < /dev/urandom 2>/dev/null | head -c"$length")
        if [ -z "$pass" ]; then
            # fallback for systems without /dev/urandom
            pass=$(openssl rand -base64 60 2>/dev/null | head -c"$length")
        fi
        printf "  \033[0;32m[%d]\033[0m  %s\n" "$i" "$pass"
    done

    echo ""
    read -p "  [Enter] kembali..."
}
