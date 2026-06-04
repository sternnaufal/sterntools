#!/bin/bash

BASE_DIR="${1:-.}"
OUTPUT_FILE="${2:-forensics_log_dump_$(date +%Y%m%d_%H%M%S).txt}"

if [ ! -d "$BASE_DIR" ]; then
    echo "Base directory tidak ditemukan: $BASE_DIR"
    exit 1
fi

echo "Forensics log dump created: $OUTPUT_FILE"
echo "========================================" > "$OUTPUT_FILE"
echo "Generated at: $(date)" >> "$OUTPUT_FILE"
echo "Base directory: $BASE_DIR" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

shopt -s nullglob
for dir in "$BASE_DIR"/*forensics_* "$BASE_DIR"/smart_forensics_*; do
    [ -d "$dir" ] || continue
    echo "==================================================" >> "$OUTPUT_FILE"
    echo "DIRECTORY: $dir" >> "$OUTPUT_FILE"
    echo "--------------------------------------------------" >> "$OUTPUT_FILE"

    if [ -f "$dir/summary.txt" ]; then
        echo "SUMMARY:" >> "$OUTPUT_FILE"
        sed -n '1,40p' "$dir/summary.txt" >> "$OUTPUT_FILE"
    else
        echo "No summary.txt found in $dir" >> "$OUTPUT_FILE"
    fi

    echo "" >> "$OUTPUT_FILE"
done

echo "Done. Buka $OUTPUT_FILE untuk melihat ringkasan hasil analisis."