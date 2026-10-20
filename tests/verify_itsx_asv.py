#!/usr/bin/env python3
"""Check real ITSx outputs against the original table inside the QIIME container."""
import argparse
import csv
from pathlib import Path

import biom
import numpy as np
import pandas as pd
from qiime2 import Artifact

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--fixture-root', type=Path, required=True)
parser.add_argument('--results', type=Path, required=True)
parser.add_argument('--require-taxonomy', action='store_true')
args = parser.parse_args()
for mode, suffix in [('paired', 'merge'), ('single', 'forward')]:
    source = args.fixture_root / f'dada2_cutadapt_{suffix}'
    output = args.results / 'dada2' / 'cutadapt_itsx' / mode
    original = Artifact.load(source / 'table.qza').view(biom.Table)
    retained = Artifact.load(output / 'table_itsx.qza').view(biom.Table)
    sequences = Artifact.load(output / 'repseq_itsx.qza').view(pd.Series)
    assert set(retained.ids(axis='observation')) == set(sequences.index)
    assert list(retained.ids()) == list(original.ids()), 'Sample set/order changed'
    expected = original.filter(list(sequences.index), axis='observation', inplace=False)
    assert retained == expected, 'Retained abundances differ from the original table'
    with (output / 'itsx_retention.tsv').open() as handle:
        report = next(csv.DictReader(handle, delimiter='\t'))
    assert int(report['asvs_before']) == original.shape[0]
    assert int(report['asvs_after']) == retained.shape[0]
    assert int(report['reads_before']) == original.sum()
    assert int(report['reads_after']) == retained.sum()
    assert int(report['excess_duplicate_asvs']) == len(sequences) - sequences.map(str).str.upper().nunique()
    samples = pd.read_csv(output / 'itsx_sample_retention.tsv', sep='\t', index_col=0)
    np.testing.assert_array_equal(samples['reads_after'], retained.sum(axis='sample'))
    # DADA2 statistics are passed through byte-for-byte, not recomputed.
    assert (output / 'denoising_stats.qza').read_bytes() == (source / 'denoising_stats.qza').read_bytes()
    taxonomy = args.results / 'taxonomy' / 'cutadapt_itsx' / mode / 'unite_ver10_99' / 'taxonomy.tsv'
    if args.require_taxonomy:
        assert taxonomy.exists(), f'Missing taxonomy output: {taxonomy}'
    if taxonomy.exists():
        classified = pd.read_csv(taxonomy, sep='\t', index_col=0)
        assert set(classified.index) == set(sequences.index)
    print(f'PASS {mode}: {original.shape[0]} -> {retained.shape[0]} ASVs; '
          f'{int(original.sum())} -> {int(retained.sum())} reads; IDs, counts, samples and stats verified')
