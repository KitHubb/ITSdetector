#!/usr/bin/env python
# -*- coding: utf-8 -*-

from __future__ import print_function

import argparse
import csv
import json
import os
import re
import sys


def as_int(value):
    if value is None:
        return 0
    return int(value)


def percent(numerator, denominator):
    if denominator == 0:
        return 0.0
    return round((float(numerator) / float(denominator)) * 100.0, 4)


def get_adapter_sequence(adapter):
    three_prime = adapter.get("three_prime_end")
    if three_prime and three_prime.get("sequence"):
        return three_prime.get("sequence")

    five_prime = adapter.get("five_prime_end")
    if five_prime and five_prime.get("sequence"):
        return five_prime.get("sequence")

    return None


def count_exact_adapter_matches(adapters, target_sequence):
    total = 0

    for adapter in adapters or []:
        sequence = get_adapter_sequence(adapter)

        if sequence == target_sequence:
            total += as_int(adapter.get("total_matches"))

    return total


def count_polyg_matches(adapters, min_run):
    total = 0
    pattern = re.compile(r"^G{%d,}$" % min_run)

    for adapter in adapters or []:
        sequence = get_adapter_sequence(adapter)

        if sequence and pattern.match(sequence):
            total += as_int(adapter.get("total_matches"))

    return total


def main():
    parser = argparse.ArgumentParser(
        description="Summarize Cutadapt JSON reports for ITSdetector."
    )

    parser.add_argument("--profile", required=True)
    parser.add_argument("--adapter-trim", required=True)
    parser.add_argument("--poly-g-trim", required=True)
    parser.add_argument("--quality-trim", required=True)
    parser.add_argument("--quality-cutoff", required=True)
    parser.add_argument("--apply-min-length", required=True)
    parser.add_argument("--min-length", required=True)

    parser.add_argument("--adapter-f", required=True)
    parser.add_argument("--adapter-r", required=True)
    parser.add_argument("--poly-g-min-run", required=True)

    parser.add_argument("--output", required=True)
    parser.add_argument("json_files", nargs="+")

    args = parser.parse_args()

    output_dir = os.path.dirname(args.output)
    if output_dir and not os.path.exists(output_dir):
        os.makedirs(output_dir)

    min_run = int(args.poly_g_min_run)

    fields = [
        "sample_id",
        "profile",
        "cutadapt_version",
        "adapter_trim",
        "poly_g_trim",
        "quality_trim",
        "quality_cutoff",
        "apply_min_length",
        "min_length",
        "input_pairs",
        "output_pairs",
        "retained_percent",
        "too_short_pairs",
        "input_bp",
        "output_bp",
        "bp_retained_percent",
        "input_r1_bp",
        "input_r2_bp",
        "output_r1_bp",
        "output_r2_bp",
        "quality_trimmed_bp",
        "quality_trimmed_r1_bp",
        "quality_trimmed_r2_bp",
        "r1_with_any_adapter",
        "r2_with_any_adapter",
        "nextera_r1_matches",
        "nextera_r2_matches",
        "polyg_r1_matches",
        "polyg_r2_matches",
    ]

    rows = []

    for json_file in sorted(args.json_files):
        if not os.path.exists(json_file):
            sys.exit("[ERROR] JSON file not found: {}".format(json_file))

        with open(json_file, "r") as handle:
            report = json.load(handle)

        if report.get("tag") != "Cutadapt report":
            sys.exit(
                "[ERROR] Invalid Cutadapt JSON report: {}".format(json_file)
            )

        filename = os.path.basename(json_file)
        sample_id = filename.replace(".cutadapt.json", "")

        read_counts = report.get("read_counts", {})
        filtered = read_counts.get("filtered", {})
        basepair_counts = report.get("basepair_counts", {})

        input_pairs = as_int(read_counts.get("input"))
        output_pairs = as_int(read_counts.get("output"))

        input_bp = as_int(basepair_counts.get("input"))
        output_bp = as_int(basepair_counts.get("output"))

        adapters_r1 = report.get("adapters_read1", [])
        adapters_r2 = report.get("adapters_read2", [])

        rows.append({
            "sample_id": sample_id,
            "profile": args.profile,
            "cutadapt_version": report.get("cutadapt_version", "unknown"),
            "adapter_trim": args.adapter_trim,
            "poly_g_trim": args.poly_g_trim,
            "quality_trim": args.quality_trim,
            "quality_cutoff": args.quality_cutoff,
            "apply_min_length": args.apply_min_length,
            "min_length": args.min_length,

            "input_pairs": input_pairs,
            "output_pairs": output_pairs,
            "retained_percent": percent(output_pairs, input_pairs),
            "too_short_pairs": as_int(filtered.get("too_short")),

            "input_bp": input_bp,
            "output_bp": output_bp,
            "bp_retained_percent": percent(output_bp, input_bp),

            "input_r1_bp": as_int(basepair_counts.get("input_read1")),
            "input_r2_bp": as_int(basepair_counts.get("input_read2")),
            "output_r1_bp": as_int(basepair_counts.get("output_read1")),
            "output_r2_bp": as_int(basepair_counts.get("output_read2")),

            "quality_trimmed_bp": as_int(
                basepair_counts.get("quality_trimmed")
            ),
            "quality_trimmed_r1_bp": as_int(
                basepair_counts.get("quality_trimmed_read1")
            ),
            "quality_trimmed_r2_bp": as_int(
                basepair_counts.get("quality_trimmed_read2")
            ),

            "r1_with_any_adapter": as_int(
                read_counts.get("read1_with_adapter")
            ),
            "r2_with_any_adapter": as_int(
                read_counts.get("read2_with_adapter")
            ),
            "nextera_r1_matches": count_exact_adapter_matches(
                adapters_r1,
                args.adapter_f
            ),
            "nextera_r2_matches": count_exact_adapter_matches(
                adapters_r2,
                args.adapter_r
            ),
            "polyg_r1_matches": count_polyg_matches(
                adapters_r1,
                min_run
            ),
            "polyg_r2_matches": count_polyg_matches(
                adapters_r2,
                min_run
            ),
        })

    with open(args.output, "w") as handle:
        writer = csv.DictWriter(
            handle,
            fieldnames=fields,
            delimiter="\t",
            lineterminator="\n"
        )
        writer.writeheader()
        writer.writerows(rows)

    print("[DONE] Samples summarized: {}".format(len(rows)))
    print("[DONE] Output: {}".format(args.output))


if __name__ == "__main__":
    main()