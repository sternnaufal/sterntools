#!/bin/bash
TARGET="$1"
OUTPUT_DIR="${2:-net_forensics_$(basename "$TARGET" | cut -d. -f1)}"
mkdir -p "$OUTPUT_DIR/extracted_files"
LOG_FILE="$OUTPUT_DIR/debug.log"
SUMMARY_FILE="$OUTPUT_DIR/summary.txt"
echo "Started at $(date)" > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=================================================="
echo "          AUTOMATED NETWORK FORENSICS            "
echo "=================================================="
if ! command -v tshark >/dev/null 2>&1; then
    echo "[-] [ERROR] tshark tidak ditemukan."
    exit 1
fi
echo "[+] [OK] Menjalankan tshark Triage..."
write_summary() {
    local http_count=$(wc -l < "$OUTPUT_DIR/http_requests.txt" 2>/dev/null || echo 0)
    local dns_count=$(wc -l < "$OUTPUT_DIR/dns_queries.txt" 2>/dev/null || echo 0)
    local extract_count=$(find "$OUTPUT_DIR/extracted_files" -type f | wc -l 2>/dev/null || echo 0)
    cat > "$SUMMARY_FILE" <<EOF
Target: $TARGET
Output directory: $OUTPUT_DIR
Started: $(date)
HTTP request lines: $http_count
DNS query lines: $dns_count
Extracted files count: $extract_count
Available reports:
- protocol_hierarchy.txt
- ip_conversations.txt
- tcp_conversations.txt
- http_requests.txt
- dns_queries.txt
- extracted_files/
EOF
}
tshark -r "$TARGET" -q -z io,phs > "$OUTPUT_DIR/protocol_hierarchy.txt" 2>/dev/null &
tshark -r "$TARGET" -q -z conv,ip > "$OUTPUT_DIR/ip_conversations.txt" 2>/dev/null &
tshark -r "$TARGET" -q -z conv,tcp > "$OUTPUT_DIR/tcp_conversations.txt" 2>/dev/null &
tshark -r "$TARGET" -Y http.request -T fields -e frame.time -e http.host -e http.request.uri > "$OUTPUT_DIR/http_requests.txt" 2>/dev/null &
tshark -r "$TARGET" -Y dns.flags.response==0 -T fields -e frame.time -e dns.qry.name > "$OUTPUT_DIR/dns_queries.txt" 2>/dev/null &
tshark -r "$TARGET" --export-objects http,"$OUTPUT_DIR/extracted_files" -q 2>/dev/null &
wait
write_summary
echo "[OK] Selesai! Analisis jaringan disimpan di folder: $OUTPUT_DIR/"
