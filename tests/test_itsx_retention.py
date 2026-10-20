#!/usr/bin/env python3
"""Exercise data-integrity edge cases with real QIIME artifacts (inside QIIME)."""
import csv
import importlib.util
import os
from pathlib import Path
import tempfile
import unittest

import biom
import numpy as np
from qiime2 import Artifact

spec = importlib.util.spec_from_file_location(
    'summary', Path(__file__).resolve().parents[1] / 'bin' / 'summarize_itsx_asv.py')
summary = importlib.util.module_from_spec(spec)
spec.loader.exec_module(summary)


class RetentionTests(unittest.TestCase):
    def setUp(self):
        self.previous = Path.cwd()
        self.temp = tempfile.TemporaryDirectory()
        os.chdir(self.temp.name)
        table = biom.Table(np.array([[4, 0], [6, 0], [0, 7]]),
                           ['asv_a', 'asv_b', 'asv_c'], ['sample_1', 'sample_2'])
        Artifact.import_data('FeatureTable[Frequency]', table).save('table.qza')

    def tearDown(self):
        os.chdir(self.previous)
        self.temp.cleanup()

    def run_summary(self, fasta):
        Path('extracted.fasta').write_text(fasta)
        summary.summarize('table.qza', 'extracted.fasta', 'ITS2', 'F', 0)

    def test_identical_sequences_keep_both_ids_and_counts(self):
        self.run_summary('>asv_a\nACGT\n>asv_b\nACGT\n')
        with open('itsx_retention.tsv') as handle:
            row = next(csv.DictReader(handle, delimiter='\t'))
        self.assertEqual(int(row['asvs_after']), 2)
        self.assertEqual(int(row['reads_after']), 10)
        self.assertEqual(int(row['duplicate_sequence_groups']), 1)
        self.assertEqual(int(row['excess_duplicate_asvs']), 1)
        with open('itsx_sample_retention.tsv') as handle:
            samples = list(csv.DictReader(handle, delimiter='\t'))
        self.assertEqual(samples[1]['sample_id'], 'sample_2')
        self.assertEqual(int(samples[1]['reads_after']), 0)
        self.assertEqual(Path('retained_ids.tsv').read_text().splitlines(),
                         ['feature-id', 'asv_a', 'asv_b'])

    def test_empty_extraction(self):
        with self.assertRaisesRegex(ValueError, 'zero ASVs'):
            self.run_summary('')

    def test_unknown_id(self):
        with self.assertRaisesRegex(ValueError, 'absent from the original'):
            self.run_summary('>unknown\nACGT\n')

    def test_duplicate_id(self):
        with self.assertRaisesRegex(ValueError, 'duplicate ASV IDs'):
            self.run_summary('>asv_a\nACGT\n>asv_a\nACGA\n')


if __name__ == '__main__':
    unittest.main(verbosity=2)
