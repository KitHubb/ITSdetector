# ITSx integration validation — 2026-10-20

Branch: `v2_dev`. Containers: ITSx 1.1.3 and QIIME 2 2025.7; Nextflow 26.04.2.

## Scope

Real Cutadapt DADA2 artifacts from `/data/home2/ksy/Gut-myco/3.Downstream/ITS2/Denosing` were processed in both paired and single modes. These are validation inputs, not a rerun of the current production samplesheet.

Both partial settings completed QIIME export → ITSx → QIIME import/table filtering → the existing UNITE taxonomy workflow. Each run completed 8 tasks with exit code 0. Raw FASTQ cleanup, DADA2, and BLAST were not rerun.

## Results

| Mode | Partial | ASVs before | ASVs after | Reads before | Reads after | Read retention | Excess duplicate ASVs |
|---|---:|---:|---:|---:|---:|---:|---:|
| paired | 0 | 2337 | 895 | 9510749 | 7679157 | 80.74% | 199 |
| single | 0 | 3151 | 1084 | 12377674 | 10037564 | 81.09% | 245 |
| paired | 50 | 2337 | 953 | 9510749 | 7777325 | 81.77% | 200 |
| single | 50 | 3151 | 1101 | 12377674 | 10046232 | 81.16% | 245 |

Identical extracted sequences remain separate features; no abundance aggregation was performed.

## Checks

- Extracted sequence IDs exactly match filtered table IDs.
- Every retained feature keeps its original abundance in every sample.
- Original sample order/set and DADA2 statistics bytes are preserved.
- Total and per-sample retention reports agree with the resulting artifacts.
- Taxonomy feature IDs match the extracted ASVs (`--require-taxonomy`).
- Four integrity edge-case tests passed: identical sequences with separate IDs, empty extraction, unknown ID, and duplicate ID.
- ITSx enabled/disabled main-workflow previews passed. Negative partial values are rejected before tasks launch.
- Real ITS1 inputs requested as ITS2 triggered the expected explicit zero-ASV error.
- `git diff --check` passed.

The test exposed CLI `false` values arriving as strings in this Nextflow environment. The touched ITSx, taxonomy, and BLAST conditions now convert them explicitly to booleans. The initial default-mode test also ran taxonomy despite its `false` CLI argument; the reproduction command below explicitly enables classification.

## Reproduction

```bash
nextflow run tests/run_itsx_asv.nf -c nextflow.config \
  --fixture_root /data/home2/ksy/Gut-myco/3.Downstream/ITS2/Denosing \
  --itsx_partial 0 --taxonomy_enabled true \
  --outdir results/itsx_validation_default -with-trace
```

Repeat with `--itsx_partial 50` and a different outdir. See [the usage guide](itsx_asv.md) for verification and unit-test commands.

Saved artifacts, `trace.tsv`, and `verification.log` are under `results_validation/itsx_asv/default/` and `results_validation/itsx_asv/partial50/`.

Existing unrelated working-tree changes were preserved.
