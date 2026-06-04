#!/bin/bash

BASE_DIR="${1:-.}"
TIMELINE_FILE="master_timeline_$(date +%Y%m%d_%H%M%S).txt"
TEMP_DIR="/tmp/timeline_parser_$$"
mkdir -p "$TEMP_DIR"

echo "=============================================="
echo "    STERNTOOLS - SUPER PARSER MASTER TIMELINE "
echo "=============================================="
echo "[*] Scanning directory: $BASE_DIR"
echo ""

to_epoch() {
    local raw="$1"
    local epoch

    epoch=$(date -d "$(echo "$raw" | sed 's/\.[0-9]*//')" +%s 2>/dev/null)
    if [ -n "$epoch" ] && [ "$epoch" -gt 1000000000 ] 2>/dev/null; then
        echo "$epoch"
        return
    fi

    epoch=$(date -d "$(echo "$raw" | sed 's/\[//;s/\]//;s/\// /g; s/:/ /3')" +%s 2>/dev/null)
    if [ -n "$epoch" ] && [ "$epoch" -gt 1000000000 ] 2>/dev/null; then
        echo "$epoch"
        return
    fi

    epoch=$(date -d "$raw" +%s 2>/dev/null)
    if [ -n "$epoch" ] && [ "$epoch" -gt 1000000000 ] 2>/dev/null; then
        echo "$epoch"
        return
    fi

    echo "0"
}

fmt_ts() {
    date -d "@$1" "+%Y-%m-%d %H:%M:%S" 2>/dev/null
}

parse_os_info() {
    local file="$1"
    local src="[RAM/Memory]"
    echo "[*] Membaca $file ..."

    while IFS= read -r line; do
        if echo "$line" | grep -qi "systemtime"; then
            local ts_raw=$(echo "$line" | awk -F'|' '{print $2}' | xargs)
            local epoch=$(to_epoch "$ts_raw")
            if [ "$epoch" -gt 0 ] 2>/dev/null; then
                local ts=$(fmt_ts "$epoch")
                echo "$epoch|$ts|$src|System Time: $ts_raw" >> "$TEMP_DIR/entries.txt"
            fi
        fi
    done < "$file"
}

parse_http_requests() {
    local file="$1"
    local dir=$(dirname "$file")
    local pcap=""

    echo "[*] Membaca $file ..."

    for f in "$BASE_DIR"/*.pcap* "$dir"/*.pcap* "$(dirname "$dir")"/*.pcap*; do
        if [ -f "$f" ]; then
            pcap="$f"
            break
        fi
    done

    if [ -n "$pcap" ] && command -v tshark >/dev/null 2>&1; then
        echo "   -> Re-ekstrak dari pcap: $pcap"
        tshark -r "$pcap" -Y http.request \
            -T fields -e frame.time -e http.host -e http.request.uri \
            -E separator='|' 2>/dev/null | while IFS='|' read -r ts host uri; do
            local epoch=$(to_epoch "$ts")
            if [ "$epoch" -gt 0 ] 2>/dev/null; then
                local ts_fmt=$(fmt_ts "$epoch")
                echo "$epoch|$ts_fmt|[Network]|HTTP REQUEST: $host$uri" >> "$TEMP_DIR/entries.txt"
            fi
        done
    else
        while IFS= read -r line; do
            if [ -n "$line" ]; then
                echo "0|--:--:--|[Network]|HTTP: $line (NO TIMESTAMP)" >> "$TEMP_DIR/entries.txt"
            fi
        done < "$file"
        echo "   WARNING: http_requests.txt tanpa timestamp."
        echo "   Sediakan file pcap untuk hasil maksimal."
    fi
}

parse_web_attacks() {
    local file="$1"
    local label="$2"
    echo "[*] Membaca $file ..."

    while IFS= read -r line; do
        [ -z "$line" ] && continue

        local apache_ts=$(echo "$line" | grep -oP '\[\d{2}/\w{3}/\d{4}:\d{2}:\d{2}:\d{2}\s[^\]]+\]')
        if [ -n "$apache_ts" ]; then
            local epoch=$(to_epoch "$apache_ts")
            if [ "$epoch" -gt 0 ] 2>/dev/null; then
                local ts_fmt=$(fmt_ts "$epoch")
                echo "$epoch|$ts_fmt|[Log/$label]|$line" >> "$TEMP_DIR/entries.txt"
                continue
            fi
        fi

        local syslog_ts=$(echo "$line" | grep -oP '^\w{3}\s+\d{1,2}\s\d{2}:\d{2}:\d{2}')
        if [ -n "$syslog_ts" ]; then
            local epoch=$(to_epoch "$syslog_ts")
            if [ "$epoch" -gt 0 ] 2>/dev/null; then
                local ts_fmt=$(fmt_ts "$epoch")
                echo "$epoch|$ts_fmt|[Log/$label]|$line" >> "$TEMP_DIR/entries.txt"
                continue
            fi
        fi

        echo "0|--:--:--|[Log/$label]|$line (NO TS)" >> "$TEMP_DIR/entries.txt"
    done < "$file"
}

parse_process_list() {
    local file="$1"
    echo "[*] Membaca $file ..."

    tail -n +5 "$file" 2>/dev/null | while IFS= read -r line; do
        [ -z "$line" ] && continue

        local create_time=$(echo "$line" | awk '{
            for(i=1;i<=NF;i++) {
                if($i ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) {
                    print $i" "$(i+1)
                    break
                }
            }
        }' 2>/dev/null)
        local proc_name=$(echo "$line" | awk '{print $4}' 2>/dev/null)
        local pid=$(echo "$line" | awk '{print $2}' 2>/dev/null)

        if [ -n "$create_time" ] && [ -n "$proc_name" ]; then
            local epoch=$(to_epoch "$create_time")
            if [ "$epoch" -gt 0 ] 2>/dev/null; then
                local ts_fmt=$(fmt_ts "$epoch")
                echo "$epoch|$ts_fmt|[RAM/Process]|Process START: $proc_name (PID: $pid)" >> "$TEMP_DIR/entries.txt"
            fi
        fi
    done
}

parse_network_connections() {
    local file="$1"
    echo "[*] Membaca $file ..."

    tail -n +5 "$file" 2>/dev/null | while IFS= read -r line; do
        [ -z "$line" ] && continue

        local conn_time=$(echo "$line" | awk '{
            for(i=1;i<=NF;i++) {
                if($i ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/) {
                    print $i" "$(i+1)
                    break
                }
            }
        }' 2>/dev/null)
        local conn_info=$(echo "$line" | awk '{print $2, $3, $5}' 2>/dev/null)

        if [ -n "$conn_time" ] && [ -n "$conn_info" ]; then
            local epoch=$(to_epoch "$conn_time")
            if [ "$epoch" -gt 0 ] 2>/dev/null; then
                local ts_fmt=$(fmt_ts "$epoch")
                echo "$epoch|$ts_fmt|[RAM/Network]|Koneksi: $conn_info" >> "$TEMP_DIR/entries.txt"
            fi
        fi
    done
}

parse_dns_queries() {
    local file="$1"
    local dir=$(dirname "$file")
    local pcap=""

    echo "[*] Membaca $file ..."

    for f in "$BASE_DIR"/*.pcap* "$dir"/*.pcap* "$(dirname "$dir")"/*.pcap*; do
        if [ -f "$f" ]; then
            pcap="$f"
            break
        fi
    done

    if [ -n "$pcap" ] && command -v tshark >/dev/null 2>&1; then
        echo "   -> Re-ekstrak dari pcap: $pcap"
        tshark -r "$pcap" -Y "dns.flags.response==0" \
            -T fields -e frame.time -e dns.qry.name \
            -E separator='|' 2>/dev/null | while IFS='|' read -r ts domain; do
            local epoch=$(to_epoch "$ts")
            if [ "$epoch" -gt 0 ] 2>/dev/null; then
                local ts_fmt=$(fmt_ts "$epoch")
                echo "$epoch|$ts_fmt|[Network]|DNS QUERY: $domain" >> "$TEMP_DIR/entries.txt"
            fi
        done
    fi
}

echo "--------------------------------------------------"
echo "  1. Memori Forensics (RAM)"
echo "--------------------------------------------------"
for dir in "$BASE_DIR"/mem_forensics_*; do
    [ -d "$dir" ] || continue
    echo "   -> Folder: $dir"
    [ -f "$dir/os_info.txt" ] && parse_os_info "$dir/os_info.txt"
    [ -f "$dir/process_list.txt" ] && parse_process_list "$dir/process_list.txt"
    [ -f "$dir/network_connections.txt" ] && parse_network_connections "$dir/network_connections.txt"
done

echo ""
echo "--------------------------------------------------"
echo "  2. Network Forensics (Jaringan)"
echo "--------------------------------------------------"
for dir in "$BASE_DIR"/net_forensics_*; do
    [ -d "$dir" ] || continue
    echo "   -> Folder: $dir"
    [ -f "$dir/http_requests.txt" ] && parse_http_requests "$dir/http_requests.txt"
    [ -f "$dir/dns_queries.txt" ] && parse_dns_queries "$dir/dns_queries.txt"
done

echo ""
echo "--------------------------------------------------"
echo "  3. Log Forensics (Web Server)"
echo "--------------------------------------------------"
for dir in "$BASE_DIR"/log_forensics_*; do
    [ -d "$dir" ] || continue
    echo "   -> Folder: $dir"
    [ -f "$dir/web_attacks.txt" ] && parse_web_attacks "$dir/web_attacks.txt" "Web"
    [ -f "$dir/brute_force_attempts.txt" ] && parse_web_attacks "$dir/brute_force_attempts.txt" "BruteForce"
    [ -f "$dir/attacker_scanners.txt" ] && parse_web_attacks "$dir/attacker_scanners.txt" "Scanner"
    [ -f "$dir/potential_flags.txt" ] && parse_web_attacks "$dir/potential_flags.txt" "Flag"
done

echo ""
echo "=============================================="
echo "  Menyusun Master Timeline..."
echo "=============================================="

{
    echo "======================================================================"
    echo "  STERNTOOLS - MASTER TIMELINE (Syslog Style)"
    echo "  Generated: $(date)"
    echo "  Base Directory: $BASE_DIR"
    echo "======================================================================"
    echo ""
    echo "  Format: [WAKTU] [SUMBER] [DESKRIPSI]"
    echo "======================================================================"
    echo ""
} > "$TIMELINE_FILE"

if [ -f "$TEMP_DIR/entries.txt" ] && [ -s "$TEMP_DIR/entries.txt" ]; then
    sort -t'|' -k1 -n "$TEMP_DIR/entries.txt" | while IFS='|' read -r epoch ts src desc; do
        printf "  [%s] [%s] %s\n" "$ts" "$src" "$desc" >> "$TIMELINE_FILE"
    done

    TOTAL_ENTRIES=$(wc -l < "$TIMELINE_FILE")
    echo "[OK] Sukses! Timeline: $TOTAL_ENTRIES entri."
else
    echo "[!] Tidak ada data timeline."
    echo "   Jalankan tools forensics terlebih dahulu:"
    echo "   ./memory_forensic.sh memory.raw"
    echo "   ./network_forensic.sh traffic.pcapng"
    echo "   ./log_forensic.sh access.log"
    echo ""
    echo "No timeline entries found." >> "$TIMELINE_FILE"
fi

echo ""
echo "=============================================="
echo "  HASIL: $TIMELINE_FILE"
echo "=============================================="

rm -rf "$TEMP_DIR"

if [ -f "$TIMELINE_FILE" ]; then
    echo ""
    echo "  PREVIEW (10 baris pertama):"
    echo "----------------------------------------------"
    head -n 12 "$TIMELINE_FILE"
    echo "----------------------------------------------"
    echo ""
    echo "  Lihat full: cat $TIMELINE_FILE | less"
fi
