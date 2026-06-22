#!/usr/bin/env python3
import csv
import os
import sys

required = ["sample_id", "run_id", "assay_id", "read_mode", "fastq_1", "fastq_2"]

if len(sys.argv) != 3:
    sys.exit("Usage: validate_samplesheet.py <input.csv> <output.csv>")

input_csv, output_csv = sys.argv[1], sys.argv[2]

seen = set()
valid_rows = []

with open(input_csv, newline="") as f:
    reader = csv.DictReader(f)

    if reader.fieldnames != required:
        sys.exit(
            f"[ERROR] Header must be exactly:\n"
            f"{','.join(required)}\n"
            f"Found:\n{','.join(reader.fieldnames or [])}"
        )

    for i, row in enumerate(reader, start=2):
        sample_id = row["sample_id"].strip()
        read_mode = row["read_mode"].strip().lower()
        r1 = row["fastq_1"].strip()
        r2 = row["fastq_2"].strip()

        if not sample_id:
            sys.exit(f"[ERROR] Row {i}: empty sample_id")

        if sample_id in seen:
            sys.exit(f"[ERROR] Row {i}: duplicated sample_id: {sample_id}")
        seen.add(sample_id)

        if read_mode not in {"paired", "single"}:
            sys.exit(f"[ERROR] Row {i}: read_mode must be paired or single")

        if not os.path.isfile(r1):
            sys.exit(f"[ERROR] Row {i}: R1 not found: {r1}")

        if read_mode == "paired":
            if not r2:
                sys.exit(f"[ERROR] Row {i}: paired sample has empty fastq_2")
            if not os.path.isfile(r2):
                sys.exit(f"[ERROR] Row {i}: R2 not found: {r2}")

        if read_mode == "single":
            row["fastq_2"] = ""

        valid_rows.append(row)

with open(output_csv, "w", newline="") as f:
    writer = csv.DictWriter(f, fieldnames=required)
    writer.writeheader()
    writer.writerows(valid_rows)

print(f"[DONE] Valid samplesheet: {output_csv}")
print(f"[DONE] Samples: {len(valid_rows)}")
