#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function

import argparse
import csv
import os
import sys


def main():
    parser = argparse.ArgumentParser(
        description="Build a QIIME 2 paired-end FASTQ manifest."
    )
    parser.add_argument("--input", required=True)
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--validation", required=True)
    args = parser.parse_args()

    seen = set()
    records = []

    with open(args.input, "r") as handle:
        reader = csv.reader(handle, delimiter="\t")

        for line_no, row in enumerate(reader, start=1):
            if not row or all(not value.strip() for value in row):
                continue

            if len(row) != 3:
                sys.exit(
                    "[ERROR] Line {} must contain sample_id, R1, R2".format(
                        line_no
                    )
                )

            sample_id, read1, read2 = [value.strip() for value in row]

            if not sample_id:
                sys.exit("[ERROR] Line {}: empty sample_id".format(line_no))

            if sample_id in seen:
                sys.exit(
                    "[ERROR] Line {}: duplicated sample_id: {}".format(
                        line_no,
                        sample_id
                    )
                )
            seen.add(sample_id)

            read1 = os.path.realpath(read1)
            read2 = os.path.realpath(read2)

            if not os.path.isfile(read1):
                sys.exit("[ERROR] R1 not found: {}".format(read1))

            if not os.path.isfile(read2):
                sys.exit("[ERROR] R2 not found: {}".format(read2))

            records.append((sample_id, read1, read2))

    if not records:
        sys.exit("[ERROR] No paired FASTQ records found.")

    with open(args.manifest, "w") as handle:
        writer = csv.writer(handle, lineterminator="\n")
        writer.writerow([
            "sample-id",
            "forward-absolute-filepath",
            "reverse-absolute-filepath",
        ])
        writer.writerows(records)

    with open(args.validation, "w") as handle:
        writer = csv.writer(handle, delimiter="\t", lineterminator="\n")
        writer.writerow([
            "sample_id",
            "forward_absolute_filepath",
            "reverse_absolute_filepath",
            "status",
        ])

        for sample_id, read1, read2 in records:
            writer.writerow([sample_id, read1, read2, "PASS"])

    print("[DONE] Paired samples: {}".format(len(records)))
    print("[DONE] Manifest: {}".format(args.manifest))


if __name__ == "__main__":
    main()
