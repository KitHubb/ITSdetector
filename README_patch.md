# BLAST species rescue patch

## Default behavior

`BLAST_REFSEQ_RECONCILE` now runs `reconcile_qiime_blast_species.py` with:

```nextflow
--reconcile-mode high_confidence_species
--species-min-pident 99.0
--species-min-qcovus 99.0
```

This means that a BLAST top-1 species assignment replaces the QIIME taxonomy when the BLAST hit passes the species-level cutoffs. Genus concordance is not required in this default mode.

## Legacy/conservative option

To restore the previous genus-concordant behavior, set:

```nextflow
params.blast_reconcile_mode = 'same_genus_only'
```

## Intermediate option

To rescue only higher-rank QIIME assignments or same-genus assignments, set:

```nextflow
params.blast_reconcile_mode = 'higher_rank_rescue'
```

## Suggested config block

```nextflow
params.blast_reconcile_mode = 'high_confidence_species'
params.blast_species_min_pident = 99.0
params.blast_species_min_qcovus = 99.0
params.blast_species_max_evalue = '1e-10'
```

The previous candidate-selection parameters are still used upstream:

```nextflow
params.blast_min_pident = 99.0
params.blast_min_qcovus = 80.0
params.blast_max_evalue = '1e-10'
```

Keeping candidate selection broader than species replacement is intentional. It preserves BLAST candidates for evidence tables, while species-level replacement remains strict at 99/99 by default.
