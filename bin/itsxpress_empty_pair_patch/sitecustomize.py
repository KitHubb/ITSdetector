"""Prevent ITSxpress 2.1.4 from emitting empty paired-end FASTQ records.

ITSxpress identifies ITS coordinates on a merged read, then applies those
coordinates to the original R1 and R2 reads.  When the selected ITS interval
does not overlap one of the original mates, version 2.1.4 writes a zero-length
FASTQ record.  QIIME 2 correctly rejects that output artifact.

This module is loaded only by the QIIME_ITSXPRESS_PE process through its
process-local PYTHONPATH.  It replaces the affected generator with equivalent
logic that clips coordinates to each mate and discards the pair when either
clipped interval is empty.
"""

import builtins
from itertools import tee
import logging
import sys

LOGGER = logging.getLogger("itsxpress.empty_pair_patch")
_ORIGINAL_IMPORT = builtins.__import__
_PATCHED = False


def _get_paired_seq_generator_without_empty_mates(
    self, zipseqgen, itspos, wri_file
):
    """Return synchronized trimmed mates, excluding zero-length results."""

    def _trimmed_pairs():
        kept = 0
        discarded_empty = 0

        for record1, record2 in zipseqgen:
            try:
                repseq = self.matchdict[record1.id]
                start, stop, merged_length = itspos.get_position(repseq)
            except (KeyError, TypeError):
                continue

            if (
                start is None
                or stop is None
                or merged_length is None
                or start >= stop
            ):
                continue

            # ITSxpress coordinates refer to the merged amplicon. Clip them to
            # the bases physically present in each original mate.
            r1_start = max(0, start)
            r1_end = min(len(record1), stop)
            r2_start = max(0, merged_length - stop)
            r2_end = min(len(record2), merged_length - start)

            if r1_start >= r1_end or r2_start >= r2_end:
                discarded_empty += 1
                continue

            kept += 1
            yield record1[r1_start:r1_end], record2[r2_start:r2_end]

        LOGGER.warning(
            "ITSxpress empty-mate safeguard kept %d pairs and discarded %d "
            "pairs whose ITS interval did not overlap both mates.",
            kept,
            discarded_empty,
        )

    pairs_for_r1, pairs_for_r2 = tee(_trimmed_pairs(), 2)
    return (
        (record1 for record1, _ in pairs_for_r1),
        (record2 for _, record2 in pairs_for_r2),
    )


def _install_patch_after_import(name, globals=None, locals=None, fromlist=(), level=0):
    """Delay importing ITSxpress until QIIME has initialized its cache paths."""
    global _PATCHED

    module = _ORIGINAL_IMPORT(name, globals, locals, fromlist, level)
    dedup_module = sys.modules.get("itsxpress.Dedup")
    dedup_class = getattr(dedup_module, "Dedup", None)
    if not _PATCHED and dedup_class is not None:
        dedup_class._get_paired_seq_generator = (
            _get_paired_seq_generator_without_empty_mates
        )
        _PATCHED = True
        builtins.__import__ = _ORIGINAL_IMPORT
    return module


builtins.__import__ = _install_patch_after_import

