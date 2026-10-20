# Optional ITSx postprocessing of Cutadapt ASVs

ITSx runs **after DADA2** and only on the `cutadapt` result branch. The original
Cutadapt and ITSxpress results remain available. No additional denoising is run.
In this repository, `preprocess_method: primer` selects Cutadapt preprocessing;
`both` selects Cutadapt and ITSxpress.

```text
Cutadapt -> DADA2 -> original ASVs -----------------> taxonomy -> optional BLAST
                 -> ITSx -> extracted ASVs --------> taxonomy -> optional BLAST
                         -> table filtered by ASV ID
ITSxpress -> DADA2 ---------------------------------> taxonomy -> optional BLAST
```

## Configuration

```yaml
itsx_enabled: false
itsx_container: /data/software/singularity/itsx_1.1.3.sif
itsx_region: ITS2       # One region: ITS1 or ITS2
itsx_taxa: F            # ITSx fungal profile code
itsx_partial: 0         # 0: ordinary output; >0: full-and-partial output cutoff
```

`--preserve T` retains ASV IDs. `partial=50` consumes
`asv.ITS2.full_and_partial.fasta`; `partial=0` consumes `asv.ITS2.fasta`.
The ordinary output uses ITSx defaults: this is not an additional
`--only_full T` restriction. See the [ITSx manual](https://microbiology.se/publ/itsx_users_guide.pdf).

## Run a comparison

Use the existing parameter file to retain your primer and DADA2 settings.
This example selects the existing single-end Cutadapt benchmark. Override
`--analysis_mode paired` or `both` when appropriate for your input.

```bash
nextflow run main.nf \
  -params-file params/benchmark_q30_SE_primer.yml \
  --input assets/HN00276571_samplesheet.csv \
  --preprocess_method primer --itsx_enabled true --itsx_partial 0 \
  --outdir results/itsx_default -resume

nextflow run main.nf \
  -params-file params/benchmark_q30_SE_primer.yml \
  --input assets/HN00276571_samplesheet.csv \
  --preprocess_method primer --itsx_enabled true --itsx_partial 50 \
  --outdir results/itsx_partial50 -resume
```

Use different output directories for the two modes: both use the method label
`cutadapt_itsx`. Taxonomy and BLAST retain their existing enable/disable settings.
ITSx also runs when taxonomy is disabled. This change does not modify upstream
paired-read cleanup or turn it into an independent R1-only cleanup pipeline.

## Outputs and interpretation

- `itsx/<paired|single>/extraction/`: extracted FASTA, native ITSx reports and log.
- `dada2/cutadapt_itsx/<paired|single>/table_itsx.qza`: original counts filtered
  to surviving ASV IDs. Samples with zero surviving reads are retained.
- `repseq_itsx.qza`: extracted sequences, with original ASV IDs.
- `denoising_stats.qza`: unchanged original DADA2 statistics.
- `retained_ids.tsv`: the exact feature-ID whitelist used to filter the table.
- `itsx_retention.tsv`: ASV/read totals before and after ITSx, retention fractions
  in the range 0–1, unique sequence count, duplicate sequence groups, and excess
  duplicate ASVs (sum of group size minus one).
- `itsx_sample_retention.tsv`: read retention for each sample.
- `taxonomy/cutadapt_itsx/...`: results from the existing taxonomy module.

Read retention uses **DADA2 feature-table abundances**, not raw FASTQ reads.
Identical extracted sequences are counted in the duplicate report but are never
merged. Their separate ASV IDs and abundances remain intact. Empty extraction
fails with an explicit error; invalid/duplicate IDs also fail before import.

## Implementation and focused test run

`modules/local/itsx_asv.nf` defines three processes: QIIME export, standalone ITSx,
and QIIME import/table filtering. `bin/summarize_itsx_asv.py` handles ID validation
and retention reporting inside the QIIME container. `main.nf` mixes original and
ITSx results into the existing taxonomy workflow using the same tuple contract.

The test runner consumes existing paired/single DADA2 artifacts. Its fixture root
must contain `dada2_cutadapt_merge/` and `dada2_cutadapt_forward/`, each containing
`table.qza`, `representative_sequences.qza`, and `denoising_stats.qza`.

```bash
nextflow run tests/run_itsx_asv.nf -c nextflow.config \
  --fixture_root /absolute/path/to/fixture_root \
  --itsx_partial 50 --taxonomy_enabled true \
  --outdir results/itsx_test -with-trace

singularity exec -B /data:/data --pwd "$PWD" \
  /data/software/singularity/qiime2_amplicon_2025.7.sif \
  python tests/verify_itsx_asv.py \
  --fixture-root /absolute/path/to/fixture_root --results results/itsx_test --require-taxonomy
```

This focused run tests actual containers and existing DADA2 results; it does not
rerun raw FASTQ preprocessing or DADA2. The verifier checks ID correspondence,
unchanged retained abundances, sample retention, summary totals, unchanged DADA2
statistics, and taxonomy IDs when classification output is present.

The CLI switches are explicitly converted to booleans in `main.nf`, because
Nextflow can pass `--itsx_enabled false` as a non-empty string. The same guard
is applied to the existing taxonomy and BLAST switches.

Run the data-integrity edge cases inside the QIIME container:

```bash
singularity exec -B /data:/data --pwd "$PWD" \
  /data/software/singularity/qiime2_amplicon_2025.7.sif \
  python -B tests/test_itsx_retention.py
```
