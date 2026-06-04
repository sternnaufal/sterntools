#!/bin/bash
TARGET="$1"
OUTPUT_DIR="${2:-smart_forensics_$(basename "$TARGET" | cut -d. -f1)}"
mkdir -p "$OUTPUT_DIR"/{metadata,extracted,strings}
LOG_FILE="$OUTPUT_DIR/debug.log"
SUMMARY_FILE="$OUTPUT_DIR/summary.txt"
echo "Started at $(date)" > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=================================================="
echo "    DEBIAN SMART TRIAGE & AUTO-DECODE ENGINE     "
echo "=================================================="
echo "[*] Target: $TARGET"
echo "--------------------------------------------------"
auto_decode_strings() {
    local input_file="$1"
    local output_file="$2"
    echo "[*] Menjalankan mesin Auto-Decode pada string yang ditemukan..."
    grep -oP '[A-Za-z0-9+/]{16,}={0,2}' "$input_file" | sort -u | while read -r line; do
        decoded=$(echo "$line" | base64 -d 2>/dev/null)
        if [[ "$decoded" =~ [[:print:]] && ${#decoded} -gt 4 ]]; then
            echo "[BASE64 DECODED] $line  -->  $decoded" >> "$output_file"
        fi
    done
    grep -oP '\b[0-9a-fA-F]{20,}\b' "$input_file" | sort -u | while read -r line; do
        decoded=$(echo "$line" | xxd -r -p 2>/dev/null)
        if [[ "$decoded" =~ [[:print:]] && ${#decoded} -gt 4 ]]; then
            echo "[HEX DECODED] $line  -->  $decoded" >> "$output_file"
        fi
    done
    if grep -q "%" "$input_file"; then
        grep -oP '(?:%[0-9a-fA-F]{2}){2,}' "$input_file" | sort -u | while read -r line; do
            decoded=$(echo -e "${line//%/\\x}")
            if [[ "$decoded" =~ [[:print:]] ]]; then
                echo "https://decoded.com/ $line  -->  $decoded" >> "$output_file"
            fi
        done
    fi
}
write_summary() {
    local hints_count=0
    local decoded_count=0
    local strings_count=0
    if [ -f "$OUTPUT_DIR/strings/hints.txt" ]; then hints_count=$(wc -l < "$OUTPUT_DIR/strings/hints.txt"); fi
    if [ -f "$OUTPUT_DIR/strings/auto_decoded_results.txt" ]; then decoded_count=$(wc -l < "$OUTPUT_DIR/strings/auto_decoded_results.txt"); fi
    if [ -f "$OUTPUT_DIR/strings/all_strings.txt" ]; then strings_count=$(wc -l < "$OUTPUT_DIR/strings/all_strings.txt"); fi
    cat > "$SUMMARY_FILE" <<EOF
Target: $TARGET
Output directory: $OUTPUT_DIR
Started: $(date)
Strings extracted: $strings_count
Hints found: $hints_count
Auto-decode results: $decoded_count
Binwalk: $(command -v binwalk >/dev/null 2>&1 && echo "RUN" || echo "SKIPPED")
Foremost: $(command -v foremost >/dev/null 2>&1 && echo "RUN" || echo "SKIPPED")
EOF
}
if command -v file >/dev/null 2>&1; then echo "[+] [OK] Memeriksa tipe file..."; file "$TARGET" > "$OUTPUT_DIR/metadata/file_type.txt"; fi
if command -v exiftool >/dev/null 2>&1; then echo "[+] [OK] Mengekstrak Metadata via Exiftool..."; exiftool "$TARGET" > "$OUTPUT_DIR/metadata/exif_metadata.txt"; fi
if command -v strings >/dev/null 2>&1; then
    echo "[+] [OK] Mengekstrak String teks..."
    strings "$TARGET" > "$OUTPUT_DIR/strings/all_strings.txt"
    grep -iE "flag|ctf|secret|pass|key" "$OUTPUT_DIR/strings/all_strings.txt" > "$OUTPUT_DIR/strings/hints.txt"
    auto_decode_strings "$OUTPUT_DIR/strings/all_strings.txt" "$OUTPUT_DIR/strings/auto_decoded_results.txt"
fi
if command -v binwalk >/dev/null 2>&1; then echo "[+] [OK] Memeriksa file tersembunyi via Binwalk..."; binwalk "$TARGET" > "$OUTPUT_DIR/metadata/binwalk_report.txt"; binwalk -e "$TARGET" --outdir="$OUTPUT_DIR/extracted/binwalk_out" --quiet 2>/dev/null & BINWALK_PID=$!; fi
if command -v foremost >/dev/null 2>&1; then echo "[+] [OK] Mengekstrak file via Foremost..."; foremost -i "$TARGET" -o "$OUTPUT_DIR/extracted/foremost_out" >/dev/null 2>&1 & FOREMOST_PID=$!; fi
echo "[*] Menyelaraskan proses ekstraksi file..."
[[ -n $BINWALK_PID ]] && wait $BINWALK_PID
[[ -n $FOREMOST_PID ]] && wait $FOREMOST_PID
write_summary
echo "--------------------------------------------------"
echo "             [ TRIAGE SELESAI ]                   "
echo "=================================================="
echo "[>] Hasil disimpan di: $OUTPUT_DIR/"
if [ -f "$OUTPUT_DIR/strings/auto_decoded_results.txt" ]; then
    echo "[!] INFO: Ditemukan string sandi yang berhasil di-decode!"
    echo "    Silakan cek file: $OUTPUT_DIR/strings/auto_decoded_results.txt"
fi
echo "=================================================="
