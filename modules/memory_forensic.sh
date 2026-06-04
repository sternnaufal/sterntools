#!/bin/bash
TARGET="$1"
OUTPUT_DIR="${2:-mem_forensics_$(basename "$TARGET" | cut -d. -f1)}"
mkdir -p "$OUTPUT_DIR"
LOG_FILE="$OUTPUT_DIR/debug.log"
SUMMARY_FILE="$OUTPUT_DIR/summary.txt"
echo "Started at $(date)" > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=================================================="
echo "          AUTOMATED MEMORY FORENSICS             "
echo "=================================================="
VOL_CMD=""
if command -v volatility3 >/dev/null 2>&1; then VOL_CMD="volatility3"
elif command -v vol3 >/dev/null 2>&1; then VOL_CMD="vol3"
elif command -v vol >/dev/null 2>&1; then VOL_CMD="vol"
fi
if [ -z "$VOL_CMD" ]; then
    echo "[-] [ERROR] Volatility 3 tidak ditemukan."
    exit 1
fi
echo "[+] [OK] Menggunakan $VOL_CMD"
echo "[*] Menjalankan plugin utama secara paralel..."
write_summary() {
    local malfind_count=$(grep -c '^' "$OUTPUT_DIR/malware_alerts.txt" 2>/dev/null || echo 0)
    local cmd_history_count=$(wc -l < "$OUTPUT_DIR/cmd_history.txt" 2>/dev/null || echo 0)
    cat > "$SUMMARY_FILE" <<EOF
Target: $TARGET
Output directory: $OUTPUT_DIR
Started: $(date)
Volatility command: $VOL_CMD
Malfind hits: $malfind_count
Command-line entries: $cmd_history_count
Available reports:
- os_info.txt
- process_list.txt
- process_tree.txt
- network_connections.txt
- cmd_history.txt
- malware_alerts.txt
EOF
}
$VOL_CMD -f "$TARGET" windows.info > "$OUTPUT_DIR/os_info.txt" 2>/dev/null &
$VOL_CMD -f "$TARGET" windows.pslist > "$OUTPUT_DIR/process_list.txt" 2>/dev/null &
$VOL_CMD -f "$TARGET" windows.pstree > "$OUTPUT_DIR/process_tree.txt" 2>/dev/null &
$VOL_CMD -f "$TARGET" windows.netscan > "$OUTPUT_DIR/network_connections.txt" 2>/dev/null &
$VOL_CMD -f "$TARGET" windows.cmdline > "$OUTPUT_DIR/cmd_history.txt" 2>/dev/null &
$VOL_CMD -f "$TARGET" windows.malfind > "$OUTPUT_DIR/malware_alerts.txt" 2>/dev/null &
echo "[*] Menunggu Volatility selesai membedah memori..."
wait
write_summary
echo "[OK] Selesai! Analisis RAM disimpan di folder: $OUTPUT_DIR/"
