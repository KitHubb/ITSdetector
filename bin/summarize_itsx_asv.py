#!/usr/bin/env python3
"""Validate extracted ASVs and report retention using the original QIIME table.

Run inside the QIIME container. Read totals are DADA2 feature-table abundances,
not raw FASTQ counts. Identical extracted sequences remain separate ASVs.
"""
import argparse
import csv
from collections import Counter

import biom
from skbio import DNA, read
from qiime2 import Artifact


def write_tsv(path, header, rows):
    with open(path, "w", newline="") as handle:
        writer = csv.writer(handle, delimiter="\t")
        writer.writerow(header)
        writer.writerows(rows)


def summarize(table_path, fasta_path, region, taxa, partial):
    table = Artifact.load(table_path).view(biom.Table)
    records = list(read(fasta_path, format="fasta", constructor=DNA))
    ids = [record.metadata["id"] for record in records]
    if not ids:
        raise ValueError("ITSx extracted zero ASVs; cannot create a filtered table.")
    if len(ids) != len(set(ids)):
        raise ValueError("ITSx output contains duplicate ASV IDs.")
    if any(not len(record) for record in records):
        raise ValueError("ITSx output contains an empty ASV sequence.")
    unknown = set(ids) - set(table.ids(axis="observation"))
    if unknown:
        raise ValueError(f"ITSx IDs absent from the original feature table: {sorted(unknown)[:10]}")

    # BIOM preserves sample order, including samples whose retained total is 0.
    filtered = table.filter(ids, axis="observation", inplace=False)
    before = table.sum(axis="sample")
    after = filtered.sum(axis="sample")
    total_before, total_after = int(sum(before)), int(sum(after))
    asvs_before = len(table.ids(axis="observation"))
    sequences = Counter(str(record).upper() for record in records)
    write_tsv("retained_ids.tsv", ["feature-id"], ((id_,) for id_ in ids))
    write_tsv(
        "itsx_sample_retention.tsv",
        ["sample_id", "reads_before", "reads_after", "read_retention_fraction"],
        ((sample, int(b), int(a), float(a / b) if b else 0.0)
         for sample, b, a in zip(table.ids(axis="sample"), before, after)),
    )
    write_tsv(
        "itsx_retention.tsv",
        ["region", "taxa", "partial", "asvs_before", "asvs_after",
         "asv_retention_fraction", "reads_before", "reads_after",
         "read_retention_fraction", "unique_extracted_sequences",
         "duplicate_sequence_groups", "excess_duplicate_asvs"],
        [(region, taxa, partial, asvs_before, len(ids), len(ids) / asvs_before,
          total_before, total_after, total_after / total_before if total_before else 0.0,
          len(sequences), sum(n > 1 for n in sequences.values()),
          sum(n - 1 for n in sequences.values()))],
    )


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--table", required=True)
    parser.add_argument("--fasta", required=True)
    parser.add_argument("--region", required=True)
    parser.add_argument("--taxa", required=True)
    parser.add_argument("--partial", type=int, required=True)
    args = parser.parse_args()
    summarize(args.table, args.fasta, args.region, args.taxa, args.partial)
