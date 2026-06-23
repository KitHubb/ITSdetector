#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function

import argparse
import csv
import os
import sys


def fail(message):
    sys.stderr.write("[ERROR] {}\n".format(message))
    sys.exit(1)


def main():
    parser = argparse.ArgumentParser(
        description="Create QIIME 2 paired-end and R1-only manifests."
    )
    parser.add_argument("--input", required=True)
    parser.add_argument("--pe-manifest", required=True)
    parser.add_argument("--r1-manifest", required=True)
    parser.add_argument("--validation", required=True)
    args = parser.parse_args()

    records = []
    seen = set()

    with open(args.input, "r") as handle:
        reader = csv.reader(handle, delimiter="\t")

        for line_no, row in enumerate(reader, start=1):
            if not row or all(not value.strip() for value in row):
                continue

            if len(row) != 3:
                fail(
                    "Line {} must contain sample_id, R1 path, and R2 path."
                    .format(line_no)
                )

            sample_id, r1_path, r2_path = [
                value.strip() for value in row
            ]

            if not sample_id:
                fail("Line {} has an empty sample_id.".format(line_no))

            if sample_id in seen:
                fail("Duplicated sample_id: {}".format(sample_id))

            seen.add(sample_id)

            r1_path = os.path.abspath(r1_path)
            r2_path = os.path.abspath(r2_path)

            if not os.path.isfile(r1_path):
                fail("R1 FASTQ not found: {}".format(r1_path))

            if not os.path.isfile(r2_path):
                fail("R2 FASTQ not found: {}".format(r2_path))

            records.append((sample_id, r1_path, r2_path))

    if not records:
        fail("No paired FASTQ records found.")

    with open(args.pe_manifest, "w") as handle:
        writer = csv.writer(
            handle,
            delimiter="\t",
            lineterminator="\n"
        )
        writer.writerow([
            "sample-id",
            "forward-absolute-filepath",
            "reverse-absolute-filepath",
        ])

        for sample_id, r1_path, r2_path in records:
            writer.writerow([sample_id, r1_path, r2_path])

    with open(args.r1_manifest, "w") as handle:
        writer = csv.writer(
            handle,
            delimiter="\t",
            lineterminator="\n"
        )
        writer.writerow([
            "sample-id",
            "absolute-filepath",
            "direction",
        ])

        for sample_id, r1_path, _ in records:
            writer.writerow([sample_id, r1_path, "forward"])

    with open(args.validation, "w") as handle:
        writer = csv.writer(
            handle,
            delimiter="\t",
            lineterminator="\n"
        )
        writer.writerow([
            "sample_id",
            "r1_path",
            "r2_path",
            "r1_exists",
            "r2_exists",
            "status",
        ])

        for sample_id, r1_path, r2_path in records:
            writer.writerow([
                sample_id,
                r1_path,
                r2_path,
                "PASS",
                "PASS",
                "PASS",
            ])

    print("[DONE] Paired samples: {}".format(len(records)))
    print("[DONE] PE manifest: {}".format(args.pe_manifest))
    print("[DONE] R1 manifest: {}".format(args.r1_manifest))


if __name__ == "__main__":
    main()