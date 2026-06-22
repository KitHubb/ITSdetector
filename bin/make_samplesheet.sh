#!/usr/bin/env bash
set -euo pipefail

# Usage:
# bash bin/make_samplesheet.sh <FASTQ_DIR> <OUTPUT.csv> <RUN_ID> <ASSAY_ID>

INPUT_DIR="$(cd "$1" && pwd)"
OUTPUT_CSV="$2"
RUN_ID="$3"
ASSAY_ID="$4"

mkdir -p "$(dirname "$OUTPUT_CSV")"
echo "sample_id,run_id,assay_id,read_mode,fastq_1,fastq_2" > "$OUTPUT_CSV"

find "$INPUT_DIR" -maxdepth 1 -type f -name "*.fastq.gz" | sort | while read -r r1; do
    base="$(basename "$r1")"

    # R1 파일만 인식: _1, _R1, _R1_001
    if [[ "$base" =~ ^(.+)_1\.fastq\.gz$ ]]; then
        sample_id="${BASH_REMATCH[1]}"
        r2="${r1%_1.fastq.gz}_2.fastq.gz"

    elif [[ "$base" =~ ^(.+)_R1\.fastq\.gz$ ]]; then
        sample_id="${BASH_REMATCH[1]}"
        r2="${r1%_R1.fastq.gz}_R2.fastq.gz"

    elif [[ "$base" =~ ^(.+)_R1_001\.fastq\.gz$ ]]; then
        sample_id="${BASH_REMATCH[1]}"
        r2="${r1%_R1_001.fastq.gz}_R2_001.fastq.gz"

    else
        continue
    fi

    if [[ -f "$r2" ]]; then
        mode="paired"
    else
        mode="single"
        r2=""
        echo "[WARN] R2 not found: $sample_id" >&2
    fi

    printf "%s,%s,%s,%s,%s,%s\n" \
        "$sample_id" "$RUN_ID" "$ASSAY_ID" "$mode" "$r1" "$r2" \
        >> "$OUTPUT_CSV"
done

echo "[DONE] Created: $OUTPUT_CSV"
