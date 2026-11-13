#!/usr/bin/env python3
"""Collapse ITSx-trimmed ASVs and their source BIOM table by sequence."""

import argparse
import csv
import hashlib
import json
from collections import OrderedDict
from decimal import Decimal
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("--fasta", required=True)
    parser.add_argument("--table-tsv", required=True)
    parser.add_argument("--output-fasta", required=True)
    parser.add_argument("--output-table-tsv", required=True)
    parser.add_argument("--mapping-tsv", required=True)
    parser.add_argument("--sample-retention-tsv", required=True)
    parser.add_argument("--summary-json", required=True)
    return parser.parse_args()


def read_fasta(path):
    records = OrderedDict()
    feature_id = None
    chunks = []

    def save_record():
        if feature_id is None:
            return
        sequence = "".join(chunks).upper()
        if not sequence:
            raise ValueError(f"Empty sequence for feature {feature_id}")
        if feature_id in records:
            raise ValueError(f"Duplicate FASTA feature ID: {feature_id}")
        records[feature_id] = sequence

    with open(path) as handle:
        for raw_line in handle:
            line = raw_line.strip()
            if not line:
                continue
            if line.startswith(">"):
                save_record()
                feature_id = line[1:].split()[0]
                chunks = []
            elif feature_id is None:
                raise ValueError("Sequence encountered before first FASTA header")
            else:
                chunks.append(line)
    save_record()

    if not records:
        raise ValueError("ITSx produced no ITS2 sequences")
    return records


def read_biom_tsv(path):
    sample_ids = None
    rows = OrderedDict()
    with open(path, newline="") as handle:
        for raw_line in handle:
            if raw_line.startswith("#OTU ID\t"):
                sample_ids = raw_line.rstrip("\n\r").split("\t")[1:]
                continue
            if raw_line.startswith("#") or not raw_line.strip():
                continue
            fields = raw_line.rstrip("\n\r").split("\t")
            if sample_ids is None:
                raise ValueError("BIOM TSV header '#OTU ID' was not found")
            if len(fields) != len(sample_ids) + 1:
                raise ValueError(f"Unexpected BIOM TSV column count for {fields[0]}")
            if fields[0] in rows:
                raise ValueError(f"Duplicate table feature ID: {fields[0]}")
            rows[fields[0]] = [Decimal(value) for value in fields[1:]]
    if sample_ids is None or not rows:
        raise ValueError("The feature table is empty or malformed")
    return sample_ids, rows


def decimal_text(value):
    if value == value.to_integral_value():
        return str(int(value))
    return format(value.normalize(), "f")


def main():
    args = parse_args()
    sequences = read_fasta(args.fasta)
    sample_ids, table_rows = read_biom_tsv(args.table_tsv)

    missing_from_table = sorted(set(sequences) - set(table_rows))
    if missing_from_table:
        raise ValueError(
            f"{len(missing_from_table)} ITSx feature IDs are absent from the table; "
            f"first={missing_from_table[0]}"
        )

    sequence_to_id = {}
    id_to_sequence = OrderedDict()
    source_to_its2 = OrderedDict()
    collapsed_rows = OrderedDict()

    for source_id, sequence in sequences.items():
        its2_id = sequence_to_id.get(sequence)
        if its2_id is None:
            its2_id = "ITS2_" + hashlib.sha256(sequence.encode("ascii")).hexdigest()[:24]
            if its2_id in id_to_sequence and id_to_sequence[its2_id] != sequence:
                raise RuntimeError(f"Truncated SHA-256 collision for {its2_id}")
            sequence_to_id[sequence] = its2_id
            id_to_sequence[its2_id] = sequence
            collapsed_rows[its2_id] = [Decimal(0)] * len(sample_ids)
        source_to_its2[source_id] = its2_id
        collapsed_rows[its2_id] = [
            old + add for old, add in zip(collapsed_rows[its2_id], table_rows[source_id])
        ]

    output_paths = [args.output_fasta, args.output_table_tsv, args.mapping_tsv,
                    args.sample_retention_tsv, args.summary_json]
    for output_path in output_paths:
        Path(output_path).parent.mkdir(parents=True, exist_ok=True)

    with open(args.output_fasta, "w") as handle:
        for its2_id, sequence in sorted(id_to_sequence.items()):
            handle.write(f">{its2_id}\n{sequence}\n")

    with open(args.output_table_tsv, "w", newline="") as handle:
        handle.write("# Constructed by collapse_itsx_features.py\n")
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(["#OTU ID"] + sample_ids)
        for its2_id in sorted(collapsed_rows):
            writer.writerow([its2_id] + [decimal_text(v) for v in collapsed_rows[its2_id]])

    group_sizes = {}
    for its2_id in source_to_its2.values():
        group_sizes[its2_id] = group_sizes.get(its2_id, 0) + 1
    with open(args.mapping_tsv, "w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(["source_asv_id", "its2_feature_id", "its2_length", "collapsed_group_size"])
        for source_id, its2_id in source_to_its2.items():
            writer.writerow([source_id, its2_id, len(id_to_sequence[its2_id]), group_sizes[its2_id]])

    input_sample_totals = [Decimal(0)] * len(sample_ids)
    for values in table_rows.values():
        input_sample_totals = [old + add for old, add in zip(input_sample_totals, values)]
    retained_sample_totals = [Decimal(0)] * len(sample_ids)
    for values in collapsed_rows.values():
        retained_sample_totals = [old + add for old, add in zip(retained_sample_totals, values)]

    with open(args.sample_retention_tsv, "w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow(["sample_id", "input_reads", "retained_reads", "retained_percent"])
        for sample_id, before, after in zip(sample_ids, input_sample_totals, retained_sample_totals):
            percent = Decimal(0) if before == 0 else after * Decimal(100) / before
            writer.writerow([sample_id, decimal_text(before), decimal_text(after), f"{percent:.6f}"])

    input_reads = sum(input_sample_totals)
    retained_reads = sum(retained_sample_totals)
    summary = {
        "input_asvs": len(table_rows),
        "itsx_its2_asvs": len(sequences),
        "collapsed_its2_features": len(collapsed_rows),
        "dropped_asvs": len(table_rows) - len(sequences),
        "duplicate_its2_asvs_collapsed": len(sequences) - len(collapsed_rows),
        "input_reads": int(input_reads),
        "retained_reads": int(retained_reads),
        "retained_percent": 0.0 if input_reads == 0 else float(retained_reads * Decimal(100) / input_reads),
    }
    with open(args.summary_json, "w") as handle:
        json.dump(summary, handle, indent=2)
        handle.write("\n")


if __name__ == "__main__":
    main()
