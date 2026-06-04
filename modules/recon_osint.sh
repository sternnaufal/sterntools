#!/bin/bash

TARGET="$1"
OUTPUT_DIR="${2:-recon_$(echo "$TARGET" | tr '/' '_' | tr ':' '_')}"
mkdir -p "$OUTPUT_DIR"
LOG_FILE="$OUTPUT_DIR/recon.log"

exec > >(tee -a "$LOG_FILE") 2>&1

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; NC='\033[0m'

echo -e "${CYAN}"
echo "  ╔══════════════════════════════════════════╗"
echo "  ║        RECON & OSINT ENGINE             ║"
echo "  ║     Automated Target Profiling           ║"
echo "  ╚══════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${YELLOW}[*] Target:${NC} $TARGET"
echo -e "${YELLOW}[*] Output:${NC} $OUTPUT_DIR/"
echo ""

is_domain() {
    echo "$1" | grep -qP '^([a-zA-Z0-9-]+\.)+[a-zA-Z]{2,}$'
}

write_summary() {
    local fast_ports=$(wc -l < "$OUTPUT_DIR/ports_open.txt" 2>/dev/null || echo 0)
    local web_dirs=$(wc -l < "$OUTPUT_DIR/web_directories.txt" 2>/dev/null || echo 0)
    local subs=$(wc -l < "$OUTPUT_DIR/subdomains.txt" 2>/dev/null || echo 0)

    cat > "$OUTPUT_DIR/summary.txt" <<EOF
=== RECON & OSINT SUMMARY ===
Target: $TARGET
Date: $(date)

[PORT SCAN]
Open ports found: $fast_ports

[SERVICE DETECTION]
$(cat "$OUTPUT_DIR/services.txt" 2>/dev/null || echo "N/A")

[WEB FUZZING]
Directories found: $web_dirs
Subdomains found: $subs

[RAW FILES]
- fast_scan.txt       (nmap fast scan all ports)
- ports_open.txt      (list of open ports)
- services.txt        (nmap -sV -sC detail)
- web_directories.txt (feroxbuster results)
- subdomains.txt      (subfinder results)
- summary.txt         (this file)
EOF
}

# ──────────────────────────────────────────────
# PHASE 1: FAST PORT SCAN
# ──────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PHASE 1: Fast Port Scan (all 65535 ports)${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""

FAST_SCAN="$OUTPUT_DIR/fast_scan.txt"
PORTS_OPEN="$OUTPUT_DIR/ports_open.txt"

if command -v masscan >/dev/null 2>&1; then
    echo -e "${YELLOW}[*] Using masscan (ultra fast)...${NC}"
    sudo masscan -p1-65535 --rate=10000 -oL "$OUTPUT_DIR/masscan_raw.txt" "$TARGET" 2>/dev/null
    awk '{print $3}' "$OUTPUT_DIR/masscan_raw.txt" | sort -n | paste -sd ',' > "$PORTS_OPEN"
    echo "[OK] masscan selesai."
elif command -v nmap >/dev/null 2>&1; then
    echo -e "${YELLOW}[*] Using nmap -p- (fast mode)...${NC}"
    nmap -p- --min-rate=2000 -T4 -oN "$FAST_SCAN" "$TARGET" 2>/dev/null
    grep '^[0-9]' "$FAST_SCAN" | grep '/tcp.*open' | cut -d'/' -f1 | sort -n | paste -sd ',' > "$PORTS_OPEN"
    echo "[OK] nmap fast scan selesai."
else
    echo -e "${RED}[!] nmap tidak ditemukan. Install: sudo apt install nmap${NC}"
    exit 1
fi

OPEN_PORTS=$(cat "$PORTS_OPEN" 2>/dev/null)
if [ -z "$OPEN_PORTS" ]; then
    echo -e "${RED}[!] Tidak ada port terbuka ditemukan.${NC}"
    write_summary
    exit 0
fi

echo -e "${GREEN}[+] Open ports: $OPEN_PORTS${NC}"
echo ""

# ──────────────────────────────────────────────
# PHASE 2: SERVICE DETECTION
# ──────────────────────────────────────────────
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo -e "${BLUE}  PHASE 2: Service & Version Detection    ${NC}"
echo -e "${BLUE}════════════════════════════════════════════${NC}"
echo ""

SERVICES_FILE="$OUTPUT_DIR/services.txt"

nmap -p"$OPEN_PORTS" -sV -sC -oN "$SERVICES_FILE" "$TARGET" 2>/dev/null
echo -e "${GREEN}[+] Service detection selesai.${NC}"
echo ""

grep '^[0-9]' "$SERVICES_FILE" 2>/dev/null | while IFS= read -r line; do
    echo "  $line"
done
echo ""

# ──────────────────────────────────────────────
# PHASE 3: WEB FUZZING CASCADE
# ──────────────────────────────────────────────
WEB_PORTS=$(grep -E '^\s*(80|443|8080|8443)/tcp' "$SERVICES_FILE" 2>/dev/null | grep -oP '^\s*\K[0-9]+')

if [ -n "$WEB_PORTS" ]; then
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  PHASE 3: Web Fuzzing Cascade            ${NC}"
    echo -e "${BLUE}════════════════════════════════════════════${NC}"
    echo ""

    for port in $WEB_PORTS; do
        PROTO="http"
        [ "$port" = "443" ] || [ "$port" = "8443" ] && PROTO="https"
        BASE_URL="${PROTO}://${TARGET}:${port}"

        echo -e "${YELLOW}[*] Web fuzzing: $BASE_URL${NC}"

        # Directory fuzzing with feroxbuster
        DIR_FILE="$OUTPUT_DIR/web_directories.txt"
        if command -v feroxbuster >/dev/null 2>&1; then
            echo -e "     └─ Directory fuzzing (feroxbuster)..."
            feroxbuster -u "$BASE_URL" -w /usr/share/wordlists/dirb/common.txt \
                -o "$DIR_FILE" --silent --no-state 2>/dev/null
        elif command -v gobuster >/dev/null 2>&1; then
            echo -e "     └─ Directory fuzzing (gobuster)..."
            gobuster dir -u "$BASE_URL" -w /usr/share/wordlists/dirb/common.txt \
                -o "$DIR_FILE" 2>/dev/null
        else
            echo -e "     └─ ${RED}[SKIP] feroxbuster/gobuster tidak ditemukan${NC}"
        fi

        # Subdomain enumeration (only if target is a domain)
        SUB_FILE="$OUTPUT_DIR/subdomains.txt"
        if is_domain "$TARGET" && command -v subfinder >/dev/null 2>&1; then
            echo -e "     └─ Subdomain enumeration (subfinder)..."
            subfinder -d "$TARGET" -o "$SUB_FILE" -silent 2>/dev/null
        elif is_domain "$TARGET"; then
            echo -e "     └─ ${YELLOW}[SKIP] subfinder tidak ditemukan${NC}"
        fi
    done
else
    echo -e "${YELLOW}[*] Tidak ada web port terdeteksi, lewati fuzzing.${NC}"
fi

# ──────────────────────────────────────────────
# SUMMARY TABLE
# ──────────────────────────────────────────────
write_summary

echo ""
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo -e "${GREEN}  RECON COMPLETE                          ${NC}"
echo -e "${GREEN}════════════════════════════════════════════${NC}"
echo ""

echo -e "${WHITE}  PORT SUMMARY:${NC}"
echo "  ┌───────┬────────────────────────┬──────────────────┐"
echo "  │ PORT  │ SERVICE                │ VERSION          │"
echo "  ├───────┼────────────────────────┼──────────────────┤"
grep '^[0-9]' "$SERVICES_FILE" 2>/dev/null | while IFS= read -r line; do
    port=$(echo "$line" | awk '{print $1}')
    svc=$(echo "$line" | awk '{print $3}')
    ver=$(echo "$line" | cut -d' ' -f4-)
    printf "  │ %-5s │ %-22s │ %-16s │\n" "$port" "$svc" "${ver:0:16}"
done
echo "  └───────┴────────────────────────┴──────────────────┘"

if [ -s "$OUTPUT_DIR/web_directories.txt" ] 2>/dev/null; then
    echo ""
    echo -e "${WHITE}  WEB DIRECTORIES FOUND:${NC}"
    cat "$OUTPUT_DIR/web_directories.txt" 2>/dev/null
fi

if [ -s "$OUTPUT_DIR/subdomains.txt" ] 2>/dev/null; then
    echo ""
    echo -e "${WHITE}  SUBDOMAINS FOUND:${NC}"
    cat "$OUTPUT_DIR/subdomains.txt" 2>/dev/null
fi

echo ""
echo -e "${CYAN}[>] All results saved to: $OUTPUT_DIR/${NC}"
