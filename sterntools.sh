#!/bin/bash

VERSION="1.3.0"
BASE_DIR="$(cd "$(dirname "$0")" && pwd)"
MODULES_DIR="$BASE_DIR/modules"
PLUGINS_DIR="$BASE_DIR/plugins"
CASES_DIR="$BASE_DIR/cases"
ACTIVE_CASE_FILE="$CASES_DIR/.active"

mkdir -p "$MODULES_DIR" "$PLUGINS_DIR" "$CASES_DIR"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; WHITE='\033[1;37m'; DIM='\033[2m'; NC='\033[0m'

ACTIVE_CASE=""
INPUT_DIR="$BASE_DIR/input"
OUTPUT_DIR="$BASE_DIR/output"
LOGS_DIR="$BASE_DIR/logs"
REPORTS_DIR="$BASE_DIR/reports"
mkdir -p "$INPUT_DIR" "$OUTPUT_DIR" "$LOGS_DIR" "$REPORTS_DIR"

load_case() {
    if [ -f "$ACTIVE_CASE_FILE" ]; then
        local case_name=$(cat "$ACTIVE_CASE_FILE")
        local case_path="$CASES_DIR/$case_name"
        if [ -d "$case_path" ]; then
            ACTIVE_CASE="$case_name"
            INPUT_DIR="$case_path/input"
            OUTPUT_DIR="$case_path/output"
            LOGS_DIR="$case_path/logs"
            REPORTS_DIR="$case_path/reports"
            mkdir -p "$INPUT_DIR" "$OUTPUT_DIR" "$LOGS_DIR" "$REPORTS_DIR"
        fi
    fi
}

load_case

log() { echo "[$(date '+%H:%M:%S')] $*" >> "$LOGS_DIR/sterntools.log"; }
clear_screen() { printf "\033c"; }

# ──────────────────────────────────────────────
# PLUGIN ENGINE
# ──────────────────────────────────────────────
PLUGIN_NAMES=()
PLUGIN_DESCS=()
PLUGIN_FILES=()

load_plugins() {
    PLUGIN_NAMES=(); PLUGIN_DESCS=(); PLUGIN_FILES=()
    local idx=0
    for pfile in "$PLUGINS_DIR"/*.sh; do
        [ -f "$pfile" ] || continue
        local name=""; local desc=""
        name=$(grep -oP '^PLUGIN_NAME="\K[^"]+' "$pfile" 2>/dev/null || grep -oP "^PLUGIN_NAME='\K[^']+" "$pfile" 2>/dev/null)
        desc=$(grep -oP '^PLUGIN_DESC="\K[^"]+' "$pfile" 2>/dev/null || grep -oP "^PLUGIN_DESC='\K[^']+" "$pfile" 2>/dev/null)
        [ -z "$name" ] && name="$(basename "$pfile" .sh)"
        [ -z "$desc" ] && desc="No description"
        PLUGIN_NAMES[$idx]="$name"
        PLUGIN_DESCS[$idx]="$desc"
        PLUGIN_FILES[$idx]="$pfile"
        ((idx++))
    done
}
load_plugins

run_plugin() {
    local idx=$1
    local file="${PLUGIN_FILES[$idx]}"
    if [ -f "$file" ]; then
        source "$file"
        plugin_main
    fi
}

# ──────────────────────────────────────────────
# DEPENDENCY CHECKER
# ──────────────────────────────────────────────
check_deps() {
    local tools=(nmap feroxbuster subfinder whatweb nikto nuclei volatility3 tshark binwalk foremost exiftool)
    local missing=0
    for t in "${tools[@]}"; do
        if ! command -v "$t" >/dev/null 2>&1; then
            ((missing++))
        fi
    done
    if [ "$missing" -gt 0 ]; then
        echo ""
        echo -e "${YELLOW}  ⚠  $missing tools belum terinstall. Jalankan: bash install.sh${NC}"
        echo ""
        sleep 2
    fi
}

# ──────────────────────────────────────────────
# CASE MANAGEMENT
# ──────────────────────────────────────────────
create_case() {
    clear_screen
    echo -e "${BLUE}  [CREATE NEW CASE]${NC}"
    echo "  ─────────────────────────────────────────────"
    echo ""
    read -p "  Nama case (ctf_2025_01): " case_name
    case_name=${case_name:-ctf_$(date +%Y%m%d)}
    local case_path="$CASES_DIR/$case_name"
    if [ -d "$case_path" ]; then
        echo -e "${RED}  [!] Case '$case_name' sudah ada.${NC}"
        read -p "  [Enter] kembali..."
        return
    fi
    mkdir -p "$case_path"/{input,output,logs,reports}
    cat > "$case_path/notes.txt" << EOF
# STERNTOOLS CASE NOTES
## Case: $case_name
## Created: $(date)

### Target Information
IP: 
Domain:
OS:
Ports:

### Findings
1.

### Flags
1.

### Notes

EOF
    echo "$case_name" > "$ACTIVE_CASE_FILE"
    load_case
    echo -e "${GREEN}  [OK] Case '$case_name' dibuat dan aktif!${NC}"
    log "Case created: $case_name"
    read -p "  [Enter] kembali..."
}

switch_case() {
    clear_screen
    echo -e "${BLUE}  [SWITCH CASE]${NC}"
    echo "  ─────────────────────────────────────────────"
    echo ""
    local cases=()
    for d in "$CASES_DIR"/*/; do
        [ -d "$d" ] || continue
        local name=$(basename "$d")
        [ "$name" = ".active" ] && continue
        cases+=("$name")
    done
    if [ ${#cases[@]} -eq 0 ]; then
        echo -e "${YELLOW}  [!] Belum ada case. Buat dulu: menu [C]${NC}"
        read -p "  [Enter] kembali..."
        return
    fi
    echo "  Pilih case:"
    for i in "${!cases[@]}"; do
        local marker=""
        [ "${cases[$i]}" = "$ACTIVE_CASE" ] && marker="  ← aktif"
        printf "  %2d. %s%s\n" $((i+1)) "${cases[$i]}" "$marker"
    done
    echo ""
    read -p "  Nomor: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le "${#cases[@]}" ]; then
        local selected="${cases[$((choice-1))]}"
        echo "$selected" > "$ACTIVE_CASE_FILE"
        load_case
        echo -e "${GREEN}  [OK] Switch ke case: $ACTIVE_CASE${NC}"
        log "Case switched: $ACTIVE_CASE"
    else
        echo -e "${RED}  [!] Pilihan tidak valid.${NC}"
    fi
    read -p "  [Enter] kembali..."
}

edit_notes() {
    local notes_file="$CASES_DIR/$ACTIVE_CASE/notes.txt"
    if [ -z "$ACTIVE_CASE" ]; then
        echo -e "${RED}  [!] Tidak ada case aktif.${NC}"
        read -p "  [Enter] kembali..."
        return
    fi
    if command -v nano >/dev/null 2>&1; then
        nano "$notes_file"
    elif command -v vim >/dev/null 2>&1; then
        vim "$notes_file"
    else
        echo -e "${YELLOW}  [!] nano/vim tidak ditemukan. Isi notes di:${NC}"
        echo "      $notes_file"
    fi
    read -p "  [Enter] kembali..."
}

# ──────────────────────────────────────────────
# MENU & BANNER
# ──────────────────────────────────────────────
show_banner() {
    clear_screen
    echo -e "${CYAN}"
    echo "  ╔══════════════════════════════════════════╗"
    printf "  ║          STERNTOOLS v%-11s              ║\n" "$VERSION"
    if [ -n "$ACTIVE_CASE" ]; then
        printf "  ║     Case: ${GREEN}%-30s${CYAN}  ║\n" "$ACTIVE_CASE"
    fi
    echo "  ╚══════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${YELLOW}  Working Dir:${NC} $BASE_DIR"
    echo ""
}

show_menu() {
    local m=0

    echo -e "${WHITE}  ┌──────────────────────────────────────────────┐${NC}"

    # ATTACK
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "1" "Recon & OSINT       (Nmap + Web fuzzing)"
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "2" "Web Vuln Scanner   (nikto + nuclei)"
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "3" "Privesc Triage     (Linux PE check)"
    echo -e "${WHITE}  │${NC}  ${YELLOW}  ───────────────── ATTACK ─────────────────${WHITE}  │${NC}"
    ((m++))

    # FORENSICS
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "4" "File Forensics      (strings, metadata)"
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "5" "Memory Forensics    (RAM - Volatility 3)"
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "6" "Network Forensics   (PCAP - tshark)"
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "7" "Log Forensics       (Web Server/SSH logs)"
    echo -e "${WHITE}  │${NC}  ${YELLOW}  ─────────────── FORENSICS ───────────────${WHITE}  │${NC}"
    ((m++))

    # REPORTS
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "8" "Build Master Timeline"
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "9" "Export All Reports"
    echo -e "${WHITE}  │${NC}  ${YELLOW}  ──────────────── REPORTS ────────────────${WHITE}  │${NC}"
    ((m++))

    # PLUGINS
    if [ ${#PLUGIN_NAMES[@]} -gt 0 ]; then
        echo -e "${WHITE}  │${NC}  ${CYAN}  ──────────────── PLUGINS ────────────────${WHITE}  │${NC}"
        for i in "${!PLUGIN_NAMES[@]}"; do
            local key="p$((i+1))"
            local label="${PLUGIN_NAMES[$i]}"
            local desc="${PLUGIN_DESCS[$i]}"
            printf "${WHITE}  │${NC}  ${CYAN}%-3s${NC}  %-41s${WHITE}  │${NC}\n" "$key" "$label  ($desc)"
        done
        ((m++))
    fi

    # CASE MANAGEMENT
    echo -e "${WHITE}  │${NC}  ${YELLOW}  ──────────────── SYSTEM ────────────────${WHITE}  │${NC}"
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "C" "Create New Case"
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "S" "Switch Case"
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "N" "Edit Case Notes"
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "0" "About / Help"
    printf "${WHITE}  │${NC}  ${GREEN}%-2s${NC}  %-41s${WHITE}  │${NC}\n" "x" "Exit"
    echo -e "${WHITE}  └──────────────────────────────────────────────┘${NC}"
    echo ""
}

# ──────────────────────────────────────────────
# MENU FUNCTIONS
# ──────────────────────────────────────────────
run_file_forensic() {
    show_banner
    echo -e "${BLUE}  [FILE FORENSICS]${NC}"
    echo "  ─────────────────────────────────────────────"
    echo ""
    echo -e "  Masukkan path file target (${YELLOW}atau${NC} taruh di folder ${CYAN}$INPUT_DIR${NC}):"
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
    echo ""
    "$MODULES_DIR/recon_osint.sh" "$target" "$outdir" 2>&1 | tee "$logfile"
    echo ""
    echo -e "${GREEN}  [OK] Selesai!${NC}"
    echo -e "      Output: ${CYAN}$outdir/${NC}"
    log "Recon completed: $target -> $outdir"
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
    echo "  Sterntools adalah toolkit forensics digital &"
    echo "  penetration testing untuk CTF dan incident response."
    echo ""
    echo -e "  ${GREEN}Fitur:${NC}"
    echo "  - Case management (pisah tiap CTF)"
    echo "  - Plugin system (auto-detect)"
    echo "  - Master Timeline (kronologi otomatis)"
    echo ""
    echo -e "  ${GREEN}Struktur Folder:${NC}"
    echo "  sterntools/"
    echo "  ├── sterntools.sh     <- Menu utama"
    echo "  ├── modules/          <- Modul forensics"
    echo "  ├── plugins/          <- Plugin tambahan"
    echo "  ├── cases/            <- Case CTF"
    echo "  │   ├── ctf_2025_01/"
    echo "  │   └── htb_machine/"
    echo "  ├── install.sh        <- Auto installer"
    echo ""
    echo -e "  ${YELLOW}Buat plugin sendiri:${NC}"
    echo "  Taruh file .sh di plugins/, dengan:"
    echo "    PLUGIN_NAME=\"Nama\""
    echo "    PLUGIN_DESC=\"Deskripsi\""
    echo "    plugin_main() { ... }"
    echo ""
    read -p "  [Enter] kembali..."
}

# ──────────────────────────────────────────────
# MODULE SYNC
# ──────────────────────────────────────────────
move_modules() {
    for script in recon_osint.sh web_vuln_scanner.sh privesc_triage.sh \
                  file_forensic.sh log_forensic.sh memory_forensic.sh \
                  network_forensic.sh timeline_parser.sh forensics_log_dump.sh; do
        if [ -f "$BASE_DIR/$script" ] && [ ! -f "$MODULES_DIR/$script" ]; then
            cp "$BASE_DIR/$script" "$MODULES_DIR/$script"
            chmod +x "$MODULES_DIR/$script"
            echo "  [*] Modul $script siap."
        fi
    done
}

# ──────────────────────────────────────────────
# INIT
# ──────────────────────────────────────────────
echo -e "${CYAN}[*] Initializing Sterntools v$VERSION...${NC}"
move_modules
load_plugins
check_deps
log "Sterntools v$VERSION started | Case: ${ACTIVE_CASE:-none} | Plugins: ${#PLUGIN_NAMES[@]}"

# ──────────────────────────────────────────────
# MAIN LOOP
# ──────────────────────────────────────────────
while true; do
    show_banner
    show_menu
    read -p "  Pilih: " choice

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
        C|c) create_case ;;
        S|s) switch_case ;;
        N|n) edit_notes ;;
        0) show_help ;;
        p|P)
            echo -e "  Plugin number:"
            read -p "  > " pn
            if [[ "$pn" =~ ^[0-9]+$ ]] && [ "$pn" -ge 1 ] && [ "$pn" -le "${#PLUGIN_NAMES[@]}" ]; then
                run_plugin $((pn-1))
            fi
            ;;
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
