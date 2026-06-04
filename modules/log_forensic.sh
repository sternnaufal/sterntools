#!/bin/bash
TARGET="$1"
OUTPUT_DIR="${2:-log_forensics_$(basename "$TARGET" | cut -d. -f1)}"
mkdir -p "$OUTPUT_DIR"
LOG_FILE="$OUTPUT_DIR/debug.log"
SUMMARY_FILE="$OUTPUT_DIR/summary.txt"
echo "Started at $(date)" > "$LOG_FILE"
exec > >(tee -a "$LOG_FILE") 2>&1
echo "=================================================="
echo "            AUTOMATED LOG FORENSICS              "
echo "=================================================="
echo "[*] Menyisir file log untuk aktivitas mencurigakan..."
write_summary() {
    local web_attacks=$(wc -l < "$OUTPUT_DIR/web_attacks.txt" 2>/dev/null || echo 0)
    local brute_force=$(wc -l < "$OUTPUT_DIR/brute_force_attempts.txt" 2>/dev/null || echo 0)
    local scanners=$(wc -l < "$OUTPUT_DIR/attacker_scanners.txt" 2>/dev/null || echo 0)
    local secrets=$(wc -l < "$OUTPUT_DIR/potential_flags.txt" 2>/dev/null || echo 0)
    local top_ips=$(head -n 5 "$OUTPUT_DIR/top_20_active_ips.txt" 2>/dev/null || echo "")
    cat > "$SUMMARY_FILE" <<EOF
Target: $TARGET
Output directory: $OUTPUT_DIR
Started: $(date)
Web attack indicators: $web_attacks
Brute force indicators: $brute_force
Attack scanner hits: $scanners
Potential flags or secrets: $secrets
Top active IPs:
$top_ips
EOF
}
echo "[+] Memeriksa indikasi Web Hacking..."
grep -iE "(union.*select|select.*from|concat\(|<script>|alert\(|..\/..\/|etc\/passwd)" "$TARGET" > "$OUTPUT_DIR/web_attacks.txt"
echo "[+] Memeriksa indikasi Brute Force..."
grep -iE "(failed|unauthorized|invalid user|access denied|401)" "$TARGET" > "$OUTPUT_DIR/brute_force_attempts.txt"
echo "[+] Mencari jejak otomatisasi scanner penyerang..."
grep -iE "(sqlmap|nmap|dirbuster|nikto|gobuster|w3af|hydra)" "$TARGET" > "$OUTPUT_DIR/attacker_scanners.txt"
echo "[+] Mencari keyword sensitif (flag/ctf)..."
grep -iE "(flag|ctf|secret|password|key=)" "$TARGET" > "$OUTPUT_DIR/potential_flags.txt"
echo "[+] Mendata IP dengan aktivitas tertinggi..."
awk '{print $1}' "$TARGET" | sort | uniq -c | sort -nr | head -n 20 > "$OUTPUT_DIR/top_20_active_ips.txt"
write_summary
echo "[OK] Selesai! Hasil penyisiran log disimpan di folder: $OUTPUT_DIR/"
