process QIIME_EXPORT_REPSEQ {

    tag "${meta.method}:${meta.read_mode}:${meta.reference_id}"
    label 'qiime_taxonomy_import'
    container params.qiime_sif

    input:
    tuple val(meta), path(repseq_qza)

    output:
    tuple val(meta), path('dna-sequences.fasta'), emit: repseq_fasta

    script:
    """
    set -euo pipefail

    export TMPDIR="\$PWD/qiime_tmp"
    export TMP="\$TMPDIR"
    export TEMP="\$TMPDIR"
    export NUMBA_CACHE_DIR="\$PWD/numba_cache"
    export MPLCONFIGDIR="\$PWD/matplotlib_cache"
    export XDG_CACHE_HOME="\$PWD/xdg_cache"

    mkdir -p "\$TMPDIR" "\$NUMBA_CACHE_DIR" "\$MPLCONFIGDIR" "\$XDG_CACHE_HOME"

    qiime tools export \
        --input-path "${repseq_qza}" \
        --output-path repseq_export

    cp repseq_export/dna-sequences.fasta dna-sequences.fasta
    """
}


process BLAST_REFSEQ_RECONCILE {

    tag "${meta.method}:${meta.read_mode}:${meta.reference_id}"
    label 'blast_taxonomy'

    container params.blast_taxonomy_sif
    containerOptions '--bind /data:/data'

    publishDir {
        "${params.outdir}/taxonomy_blast/${meta.method}/${meta.read_mode}/${meta.reference_id}"
    }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(repseq_fasta), path(taxonomy_tsv), path(scripts_dir)

    output:
    tuple val(meta), path('taxonomy_blast_qiime.tsv'), emit: qiime_input
    tuple val(meta), path('taxonomy_blast.tsv'), emit: taxonomy_final
    tuple val(meta), path('taxonomy_blast_evidence.tsv'), emit: evidence
    tuple val(meta), path('taxonomy_blast_changed.tsv'), emit: changed
    tuple val(meta), path('taxonomy_blast_report.tsv'), emit: report

    path 'taxonomy_normalized.tsv', emit: normalized
    path 'blast_hits_raw.tsv', emit: raw_blast
    path 'blast_candidates_top5.tsv', emit: blast_candidates
    path 'blast_taxonomy.tsv', emit: blast_taxonomy

    script:
    """
    set -euo pipefail

    python3 ${scripts_dir}/normalize_qiime_taxonomy.py \
        --input "${taxonomy_tsv}" \
        --output-dir normalized \
        --profile "${params.taxonomy_profile}"

    blastn \
        -query "${repseq_fasta}" \
        -db "${params.blast_db}" \
        -task blastn \
        -dust no \
        -num_threads ${task.cpus} \
        -max_target_seqs ${params.blast_retrieval_n} \
        -outfmt '6 qacc staxids sacc evalue bitscore qcovus pident length' \
        -out blast_hits_raw.tsv

    python3 ${scripts_dir}/select_blast_hits.py \
        --blast-raw blast_hits_raw.tsv \
        --output-dir blast_selection \
        --top-n ${params.blast_top_n} \
        --max-evalue ${params.blast_max_evalue} \
        --min-pident ${params.blast_min_pident} \
        --min-qcovus ${params.blast_min_qcovus}

    {
        printf 'TaxID\tKingdom\tPhylum\tClass\tOrder\tFamily\tGenus\tSpecies\n'

        if [ -s blast_selection/blast_candidate_taxids.txt ]; then
            taxonkit reformat \
                -I 1 \
                -F \
                -f '{k}\t{p}\t{c}\t{o}\t{f}\t{g}\t{s}' \
                --data-dir "${params.taxdump_dir}" \
                < blast_selection/blast_candidate_taxids.txt \
                | cut -f1-8
        fi
    } > taxonkit_lineage.tsv

    python3 ${scripts_dir}/build_blast_taxonomy.py \
        --candidates blast_selection/blast_candidates_top5.tsv \
        --lineage taxonkit_lineage.tsv \
        --selection-report blast_selection/blast_selection_report.tsv \
        --output-dir blast_taxonomy

    python3 ${scripts_dir}/reconcile_qiime_blast_species.py \
        --qiime-normalized normalized/taxonomy_normalized.tsv \
        --blast-taxonomy blast_taxonomy/blast_taxonomy.tsv \
        --output-dir final_taxonomy \
        --min-qiime-confidence ${params.blast_min_qiime_confidence} \
        --max-evalue ${params.blast_max_evalue} \
        --min-pident ${params.blast_min_pident} \
        --min-qcovus ${params.blast_min_qcovus}

    cp normalized/taxonomy_normalized.tsv .
    cp blast_selection/blast_candidates_top5.tsv .
    cp blast_taxonomy/blast_taxonomy.tsv .
    cp final_taxonomy/taxonomy_blast*.tsv .
    """
}


process QIIME_IMPORT_RECONCILED_TAXONOMY {

    tag "${meta.method}:${meta.read_mode}:${meta.reference_id}"
    label 'qiime_taxonomy_import'
    container params.qiime_sif

    publishDir {
        "${params.outdir}/taxonomy_blast/${meta.method}/${meta.read_mode}/${meta.reference_id}"
    }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(taxonomy_blast_qiime)

    output:
    tuple val(meta), path('taxonomy_blast.qza'), path('taxonomy_blast.qzv'), emit: taxonomy_qza

    script:
    """
    set -euo pipefail

    export TMPDIR="\$PWD/qiime_tmp"
    export TMP="\$TMPDIR"
    export TEMP="\$TMPDIR"
    export NUMBA_CACHE_DIR="\$PWD/numba_cache"
    export MPLCONFIGDIR="\$PWD/matplotlib_cache"
    export XDG_CACHE_HOME="\$PWD/xdg_cache"

    mkdir -p "\$TMPDIR" "\$NUMBA_CACHE_DIR" "\$MPLCONFIGDIR" "\$XDG_CACHE_HOME"

    qiime tools import \
        --type 'FeatureData[Taxonomy]' \
        --input-path "${taxonomy_blast_qiime}" \
        --output-path taxonomy_blast.qza

    qiime metadata tabulate \
        --m-input-file taxonomy_blast.qza \
        --o-visualization taxonomy_blast.qzv
    """
}
