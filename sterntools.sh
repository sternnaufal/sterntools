#!/bin/bash

VERSION="1.2.0"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULES_DIR="$BASE_DIR/modules"
INPUT_DIR="$BASE_DIR/input"
OUTPUT_DIR="$BASE_DIR/output"
LOGS_DIR="$BASE_DIR/logs"
REPORTS_DIR="$BASE_DIR/reports"
mkdir -p "$MODULES_DIR" "$INPUT_DIR" "$OUTPUT_DIR" "$LOGS_DIR" "$REPORTS_DIR"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOGS_DIR/sterntools.log"; }
clear_screen() { printf "\033c"; }

show_banner() {
    clear_screen
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    echo "  ║          STERNTOOLS v$VERSION              ║"
    echo "  ║      Digital Forensics Toolkit           ║"
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}  Working Dir:${NC} $BASE_DIR"
    echo ""
}

show_menu() {
    echo -e "${WHITE}  ┌──────────────────────────────────────────────┐${NC}"
    echo -e "${WHITE}  │${NC}  ${GREEN}1${NC}  Recon & OSINT       (Nmap + Web fuzzing)   ${WHITE}  │${NC}"
    echo -e "${WHITE}  │${NC}  ${GREEN}2${NC}  Web Vuln Scanner   (nikto + nuclei)       ${WHITE}  │${NC}"
    echo -e "${WHITE}  │${NC}  ${GREEN}3${NC}  Privesc Triage     (Linux PE check)       ${WHITE}  │${NC}"
    echo -e "${WHITE}  │${NC}  ${YELLOW}  ───────────────── ATTACK ─────────────────${WHITE}  │${NC}"
    echo -e "${WHITE}  │${NC}  ${GREEN}4${NC}  File Forensics      (strings, metadata)    ${WHITE}  │${NC}"
    echo -e "${WHITE}  │${NC}  ${GREEN}5${NC}  Memory Forensics    (RAM - Volatility 3)   ${WHITE}  │${NC}"
    echo -e "${WHITE}  │${NC}  ${GREEN}6${NC}  Network Forensics   (PCAP - tshark)        ${WHITE}  │${NC}"
    echo -e "${WHITE}  │${NC}  ${GREEN}7${NC}  Log Forensics       (Web Server/SSH logs)  ${WHITE}  │${NC}"
    echo -e "${WHITE}  │${NC}  ${YELLOW}  ─────────────── FORENSICS ───────────────${WHITE}  │${NC}"
    echo -e "${WHITE}  │${NC}  ${GREEN}8${NC}  Build Master Timeline                    ${WHITE}  │${NC}"
    echo -e "${WHITE}  │${NC}  ${GREEN}9${NC}  Export All Reports                        ${WHITE}  │${NC}"
    echo -e "${WHITE}  │${NC}  ${YELLOW}  ──────────────── REPORTS ────────────────${WHITE}  │${NC}"
    echo -e "${WHITE}  │${NC}  ${GREEN}0${NC}  About / Help                              ${WHITE}  │${NC}"
    echo -e "${WHITE}  │${NC}  ${GREEN}x${NC}  Exit                                      ${WHITE}  │${NC}"
    echo -e "${WHITE}  └──────────────────────────────────────────────┘${NC}"
    echo ""
}

run_recon_osint() {
    show_banner
    echo -e "${BLUE}  [RECON & OSINT]${NC}"
    echo "  ─────────────────────────────────────────────"
    echo ""
    echo -e "  Masukkan target (${YELLOW}IP atau domain${NC}):"
    read -p "  > " target

    if [ -z "$target" ]; then
        echo -e "${RED}  [!] Target tidak boleh kosong!${NC}"
        read -p "  [Enter] kembali..."
        return
    fi

    local safe=$(echo "$target" | tr '/' '_' | tr ':' '_')
    local outdir="$OUTPUT_DIR/recon_${safe}"
    mkdir -p "$outdir"
    local logfile="$LOGS_DIR/recon_${safe}.log"

    echo ""
    echo -e "${YELLOW}  [*] Menjalankan recon_osint.sh...${NC}"
    echo -e "      Target: ${CYAN}$target${NC}"
    echo -e "      Output: ${CYAN}$outdir/${NC}"
    echo ""
    "$MODULES_DIR/recon_osint.sh" "$target" "$outdir" 2>&1 | tee "$logfile"

    echo ""
    echo -e "${GREEN}  [OK] Selesai!${NC}"
    echo -e "      Output: ${CYAN}$outdir/${NC}"
    echo -e "      Log:    ${CYAN}$logfile${NC}"
    log "Recon completed: $target -> $outdir"
    read -p "  [Enter] kembali..."
}

run_file_forensic() {
    show_banner
    echo -e "${BLUE}  [FILE FORENSICS]${NC}"
    echo "  ─────────────────────────────────────────────"
    echo ""
    echo -e "  Masukkan path file target (${YELLOW}atau${NC} taruh di folder ${CYAN}input/${NC}):"
    read -p "  > " target

    if [ -z "$target" ]; then
        local input_files=("$INPUT_DIR"/*)
        if [ ${#input_files[@]} -gt 0 ] && [ -f "${input_files[0]}" ]; then
            echo ""
            echo "  File di folder input/:"
            select f in "${input_files[@]}"; do
                target="$f"
                break
            done
        fi
    fi

    if [ ! -f "$target" ]; then
        echo -e "${RED}  [!] File tidak ditemukan: $target${NC}"
        log "ERROR: File $target not found"
        read -p "  [Enter] kembali..."
        return
    fi

    local fname=$(basename "$target")
    local outdir="$OUTPUT_DIR/file_${fname%.*}"
    mkdir -p "$outdir"
    local logfile="$LOGS_DIR/file_${fname%.*}.log"

    echo ""
    echo -e "${YELLOW}  [*] Menjalankan file_forensic.sh...${NC}"
    "$MODULES_DIR/file_forensic.sh" "$target" "$outdir" 2>&1 | tee "$logfile"

    echo ""
    echo -e "${GREEN}  [OK] Selesai!${NC}"
    echo -e "      Output: ${CYAN}$outdir/${NC}"
    echo -e "      Log:    ${CYAN}$logfile${NC}"
    log "File forensics completed: $target -> $outdir"
    read -p "  [Enter] kembali..."
}

run_memory_forensic() {
    show_banner
    echo -e "${BLUE}  [MEMORY FORENSICS - Volatility 3]${NC}"
    echo "  ─────────────────────────────────────────────"
    echo ""
    echo -e "  Masukkan path file memory dump (${YELLOW}*.raw / *.mem${NC}):"
    read -p "  > " target

    if [ ! -f "$target" ]; then
        echo -e "${RED}  [!] File tidak ditemukan: $target${NC}"
        log "ERROR: Memory file $target not found"
        read -p "  [Enter] kembali..."
        return
    fi

    local fname=$(basename "$target")
    local outdir="$OUTPUT_DIR/mem_${fname%.*}"
    mkdir -p "$outdir"
    local logfile="$LOGS_DIR/mem_${fname%.*}.log"

    echo ""
    echo -e "${YELLOW}  [*] Menjalankan memory_forensic.sh...${NC}"
    "$MODULES_DIR/memory_forensic.sh" "$target" "$outdir" 2>&1 | tee "$logfile"

    echo ""
    echo -e "${GREEN}  [OK] Selesai!${NC}"
    echo -e "      Output: ${CYAN}$outdir/${NC}"
    echo -e "      Log:    ${CYAN}$logfile${NC}"
    log "Memory forensics completed: $target -> $outdir"
    read -p "  [Enter] kembali..."
}

run_network_forensic() {
    show_banner
    echo -e "${BLUE}  [NETWORK FORENSICS - tshark]${NC}"
    echo "  ─────────────────────────────────────────────"
    echo ""
    echo -e "  Masukkan path file PCAP (${YELLOW}*.pcap / *.pcapng${NC}):"
    read -p "  > " target

    if [ ! -f "$target" ]; then
        echo -e "${RED}  [!] File tidak ditemukan: $target${NC}"
        read -p "  [Enter] kembali..."
        return
    fi

    local fname=$(basename "$target")
    local outdir="$OUTPUT_DIR/net_${fname%.*}"
    mkdir -p "$outdir"
    local logfile="$LOGS_DIR/net_${fname%.*}.log"

    echo ""
    echo -e "${YELLOW}  [*] Menjalankan network_forensic.sh...${NC}"
    "$MODULES_DIR/network_forensic.sh" "$target" "$outdir" 2>&1 | tee "$logfile"

    echo ""
    echo -e "${GREEN}  [OK] Selesai!${NC}"
    echo -e "      Output: ${CYAN}$outdir/${NC}"
    echo -e "      Log:    ${CYAN}$logfile${NC}"
    read -p "  [Enter] kembali..."
}

run_log_forensic() {
    show_banner
    echo -e "${BLUE}  [LOG FORENSICS]${NC}"
    echo "  ─────────────────────────────────────────────"
    echo ""
    echo -e "  Masukkan path file log (${YELLOW}access.log / auth.log${NC}):"
    read -p "  > " target

    if [ ! -f "$target" ]; then
        echo -e "${RED}  [!] File tidak ditemukan: $target${NC}"
        read -p "  [Enter] kembali..."
        return
    fi

    local fname=$(basename "$target")
    local outdir="$OUTPUT_DIR/log_${fname%.*}"
    mkdir -p "$outdir"
    local logfile="$LOGS_DIR/log_${fname%.*}.log"

    echo ""
    echo -e "${YELLOW}  [*] Menjalankan log_forensic.sh...${NC}"
    "$MODULES_DIR/log_forensic.sh" "$target" "$outdir" 2>&1 | tee "$logfile"

    echo ""
    echo -e "${GREEN}  [OK] Selesai!${NC}"
    echo -e "      Output: ${CYAN}$outdir/${NC}"
    echo -e "      Log:    ${CYAN}$logfile${NC}"
    read -p "  [Enter] kembali..."
}

run_web_vuln() {
    show_banner
    echo -e "${BLUE}  [WEB VULNERABILITY SCANNER]${NC}"
    echo "  ─────────────────────────────────────────────"
    echo ""
    echo -e "  Masukkan URL target (${YELLOW}http://example.com${NC}):"
    read -p "  > " target

    if [ -z "$target" ]; then
        echo -e "${RED}  [!] URL tidak boleh kosong!${NC}"
        read -p "  [Enter] kembali..."
        return
    fi

    local safe=$(echo "$target" | tr '/' '_' | tr ':' '_')
    local outdir="$OUTPUT_DIR/webvuln_${safe}"
    mkdir -p "$outdir"
    local logfile="$LOGS_DIR/webvuln_${safe}.log"

    echo ""
    echo -e "${YELLOW}  [*] Menjalankan web_vuln_scanner.sh...${NC}"
    echo -e "      Target: ${CYAN}$target${NC}"
    echo ""
    "$MODULES_DIR/web_vuln_scanner.sh" "$target" "$outdir" 2>&1 | tee "$logfile"

    echo ""
    echo -e "${GREEN}  [OK] Selesai!${NC}"
    echo -e "      Output: ${CYAN}$outdir/${NC}"
    log "Web vuln scan completed: $target -> $outdir"
    read -p "  [Enter] kembali..."
}

run_privesc() {
    show_banner
    echo -e "${BLUE}  [PRIVESC TRIAGE - Linux]${NC}"
    echo "  ─────────────────────────────────────────────"
    echo ""
    echo -e "  Modul ini bisa digunakan 2 cara:"
    echo ""
    echo -e "  ${GREEN}  Cara 1:${NC} Jalankan lokal (untuk practice)"
    echo -e "  ${GREEN}  Cara 2:${NC} Copy ke server target via:"
    echo ""
    echo -e "  ${YELLOW}  Di host kamu (dari folder sterntools):${NC}"
    echo "    python3 -m http.server 8080"
    echo ""
    echo -e "  ${YELLOW}  Di server target:${NC}"
    echo "    wget http://<IP_HOST>:8080/modules/privesc_triage.sh"
    echo "    bash privesc_triage.sh"
    echo ""
    echo "  ─────────────────────────────────────────────"
    echo ""
    read -p "  Lanjutkan jalanin lokal? (y/n): " confirm

    if [ "$confirm" != "y" ]; then
        echo -e "${YELLOW}  [*] Dibatalkan.${NC}"
        read -p "  [Enter] kembali..."
        return
    fi

    local outdir="$OUTPUT_DIR/privesc_$(date +%Y%m%d_%H%M%S)"
    mkdir -p "$outdir"
    local logfile="$LOGS_DIR/privesc_$(date +%Y%m%d_%H%M%S).log"

    echo ""
    echo -e "${YELLOW}  [*] Menjalankan privesc_triage.sh...${NC}"
    "$MODULES_DIR/privesc_triage.sh" "$outdir" 2>&1 | tee "$logfile"

    echo ""
    echo -e "${GREEN}  [OK] Selesai!${NC}"
    echo -e "      Output: ${CYAN}$outdir/${NC}"
    log "Privesc triage completed -> $outdir"
    read -p "  [Enter] kembali..."
}

run_timeline() {
    show_banner
    echo -e "${BLUE}  [BUILD MASTER TIMELINE]${NC}"
    echo "  ─────────────────────────────────────────────"
    echo ""
    echo -e "${YELLOW}  [*] Membangun timeline dari semua output forensics...${NC}"
    echo ""

    local tfile="$REPORTS_DIR/master_timeline_$(date +%Y%m%d_%H%M%S).txt"

    "$MODULES_DIR/timeline_parser.sh" "$OUTPUT_DIR" 2>&1 | tee "$LOGS_DIR/timeline.log"
    local result_file=$(ls -t master_timeline_*.txt 2>/dev/null | head -1)
    if [ -n "$result_file" ]; then
        mv "$result_file" "$tfile" 2>/dev/null
    fi

    echo ""
    if [ -f "$tfile" ] && [ -s "$tfile" ]; then
        echo -e "${GREEN}  [OK] Timeline berhasil dibuat!${NC}"
        echo -e "      File: ${CYAN}$tfile${NC}"
        echo ""
        echo "  PREVIEW:"
        echo "  ─────────────────────────────────────────"
        head -n 15 "$tfile"
        echo "  ─────────────────────────────────────────"
    else
        echo -e "${RED}  [!] Tidak ada data untuk timeline.${NC}"
        echo "      Jalankan tools forensics terlebih dahulu."
    fi
    read -p "  [Enter] kembali..."
}

export_reports() {
    show_banner
    echo -e "${BLUE}  [EXPORT ALL REPORTS]${NC}"
    echo "  ─────────────────────────────────────────────"
    echo ""

    local report="$REPORTS_DIR/full_report_$(date +%Y%m%d_%H%M%S).txt"
    echo "  Mengekspor semua hasil ke: $report"

    "$MODULES_DIR/forensics_log_dump.sh" "$OUTPUT_DIR" "$report" 2>/dev/null

    echo ""
    echo -e "${GREEN}  [OK] Report exported!${NC}"
    echo -e "      File: ${CYAN}$report${NC}"
    read -p "  [Enter] kembali..."
}

show_help() {
    show_banner
    echo -e "${BLUE}  [TENTANG STERNTOOLS]${NC}"
    echo "  ─────────────────────────────────────────────"
    echo ""
    echo "  Sterntools adalah toolkit forensics digital"
    echo "  untuk CTF dan incident response."
    echo ""
    echo -e "  ${GREEN}Struktur Folder:${NC}"
    echo "  sterntools/"
    echo "  ├── sterntools.sh        <- Menu utama"
    echo "  ├── modules/             <- Script modul forensics"
    echo "  ├── input/               <- Taruh file target"
    echo "  ├── output/              <- Hasil analisis"
    echo "  ├── logs/                <- Debug logs"
    echo "  └── reports/             <- Timeline & laporan"
    echo ""
    echo -e "  ${GREEN}Tools yang dibutuhkan:${NC}"
    echo "  - nmap         (recon & port scanning)"
    echo "  - feroxbuster  (web directory fuzzing)"
    echo "  - subfinder    (subdomain enumeration)"
    echo "  - whatweb      (tech stack detection)"
    echo "  - nuclei       (vuln scanner)"
    echo "  - nikto        (web server scanner)"
    echo "  - volatility3  (memory forensics)"
    echo "  - tshark       (network forensics)"
    echo "  - binwalk      (file extraction)"
    echo "  - foremost     (file carving)"
    echo "  - exiftool     (metadata)"
    echo ""
    echo -e "  ${YELLOW}Cara install:${NC}"
    echo "  sudo apt install nmap feroxbuster subfinder whatweb nikto nuclei volatility3 tshark binwalk foremost exiftool"
    echo ""
    read -p "  [Enter] kembali..."
}

move_modules() {
    for script in recon_osint.sh web_vuln_scanner.sh privesc_triage.sh file_forensic.sh log_forensic.sh memory_forensic.sh network_forensic.sh timeline_parser.sh forensics_log_dump.sh; do
        if [ -f "$BASE_DIR/$script" ] && [ ! -f "$MODULES_DIR/$script" ]; then
            cp "$BASE_DIR/$script" "$MODULES_DIR/$script"
            chmod +x "$MODULES_DIR/$script"
            echo "  [*] Modul $script siap."
        fi
    done
}

echo -e "${CYAN}[*] Initializing Sterntools...${NC}"
move_modules
log "Sterntools v$VERSION started"

while true; do
    show_banner
    show_menu
    read -p "  Pilih menu [0-9]: " choice

    case $choice in
        1) run_recon_osint ;;
        2) run_web_vuln ;;
        3) run_privesc ;;
        4) run_file_forensic ;;
        5) run_memory_forensic ;;
        6) run_network_forensic ;;
        7) run_log_forensic ;;
        8) run_timeline ;;
        9) export_reports ;;
        0) show_help ;;
        x|X)
            echo -e "${GREEN}  Thanks for using Sterntools!${NC}"
            log "Sterntools exited"
            exit 0
            ;;
        *)
            echo -e "${RED}  [!] Pilihan tidak valid!${NC}"
            sleep 1
            ;;
    esac
done
