process QIIME_EXPORT_ASVS_FOR_ITSX {

    tag { "${params.run_label}:${meta.method}_${meta.read_mode}" }
    label 'qiime_post_dada2_itsx'
    container "${params.qiime_sif}"

    publishDir {
        "${params.outdir}/post_dada2_itsx/${meta.method}/${meta.read_mode}/input"
    }, mode: 'copy', overwrite: true, saveAs: { name ->
        name in ['feature-table.biom', 'dna-sequences.fasta'] ? name : null
    }

    input:
    tuple val(meta), path(table), path(repseq), path(denoising_stats)

    output:
    tuple val(meta), path("feature-table.biom"), path("dna-sequences.fasta"),
          path(denoising_stats), emit: exported

    script:
    """
    export TMPDIR="\$PWD/qiime_tmp"
    export TMP="\$TMPDIR"
    export TEMP="\$TMPDIR"
    export XDG_CACHE_HOME="\$PWD/xdg_cache"
    mkdir -p "\$TMPDIR" "\$XDG_CACHE_HOME" table_export repseq_export

    qiime tools export --input-path ${table} --output-path table_export
    qiime tools export --input-path ${repseq} --output-path repseq_export

    cp table_export/feature-table.biom feature-table.biom
    cp repseq_export/dna-sequences.fasta dna-sequences.fasta
    """
}


process ITSX_EXTRACT_ASV_ITS2 {

    tag { "${params.run_label}:${meta.method}_${meta.read_mode}" }
    label 'itsx_asv'
    container "${params.itsx_sif}"

    publishDir {
        "${params.outdir}/post_dada2_itsx/${meta.method}/${meta.read_mode}/itsx"
    }, mode: 'copy', overwrite: true, saveAs: { name ->
        name == 'raw_itsx' ? name : null
    }

    input:
    tuple val(meta), path(table_biom), path(repseq_fasta), path(denoising_stats)

    output:
    tuple val(meta), path(table_biom), path("its2-extracted.fasta"),
          path(denoising_stats), emit: extracted
    tuple val(meta), path("raw_itsx"), emit: reports

    script:
    def partial_option = (params.itsx_partial_cutoff as Integer) > 0 \
        ? "--partial ${params.itsx_partial_cutoff}" \
        : ""
    """
    mkdir -p raw_itsx

    ITSx \
      -i ${repseq_fasta} \
      -o raw_itsx/itsx \
      -t ${params.itsx_taxa} \
      --save_regions ${params.itsx_region} \
      --preserve T \
      --cpu ${task.cpus} \
      ${partial_option}

    if [[ -s raw_itsx/itsx.${params.itsx_region}.full_and_partial.fasta ]]; then
        cp raw_itsx/itsx.${params.itsx_region}.full_and_partial.fasta its2-extracted.fasta
    elif [[ -s raw_itsx/itsx.${params.itsx_region}.fasta ]]; then
        cp raw_itsx/itsx.${params.itsx_region}.fasta its2-extracted.fasta
    else
        echo "ITSx did not produce a non-empty ${params.itsx_region} FASTA" >&2
        exit 1
    fi
    """
}


process QIIME_COLLAPSE_ITSX_ITS2 {

    tag { "${params.run_label}:${meta.method}_${meta.read_mode}" }
    label 'qiime_post_dada2_itsx'
    container "${params.qiime_sif}"

    publishDir {
        "${params.outdir}/dada2/${meta.method}/${meta.read_mode}"
    }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(table_biom), path(its2_fasta), path(denoising_stats)
    path collapse_script

    output:
    tuple val(meta), path("table.qza"), path("repseq.qza"),
          path(denoising_stats), emit: dada2_results
    tuple val(meta), path("itsx_asv_mapping.tsv"),
          path("itsx_sample_retention.tsv"),
          path("itsx_collapse_summary.json"),
          path("table.qzv"), path("repseq.qzv"), emit: reports
    path "versions.yml", emit: versions

    script:
    """
    export TMPDIR="\$PWD/qiime_tmp"
    export TMP="\$TMPDIR"
    export TEMP="\$TMPDIR"
    export NUMBA_CACHE_DIR="\$PWD/numba_cache"
    export MPLCONFIGDIR="\$PWD/matplotlib_cache"
    export XDG_CACHE_HOME="\$PWD/xdg_cache"
    mkdir -p "\$TMPDIR" "\$NUMBA_CACHE_DIR" "\$MPLCONFIGDIR" "\$XDG_CACHE_HOME"

    biom convert -i ${table_biom} -o source-table.tsv --to-tsv

    python3 ${collapse_script} \
      --fasta ${its2_fasta} \
      --table-tsv source-table.tsv \
      --output-fasta its2-collapsed.fasta \
      --output-table-tsv its2-collapsed-table.tsv \
      --mapping-tsv itsx_asv_mapping.tsv \
      --sample-retention-tsv itsx_sample_retention.tsv \
      --summary-json itsx_collapse_summary.json

    biom convert \
      -i its2-collapsed-table.tsv \
      -o its2-collapsed-table.biom \
      --table-type "OTU table" \
      --to-hdf5

    qiime tools import \
      --type 'FeatureTable[Frequency]' \
      --input-path its2-collapsed-table.biom \
      --output-path table.qza

    qiime tools import \
      --type 'FeatureData[Sequence]' \
      --input-path its2-collapsed.fasta \
      --output-path repseq.qza

    qiime tools validate table.qza
    qiime tools validate repseq.qza
    qiime feature-table summarize --i-table table.qza --o-visualization table.qzv
    qiime feature-table tabulate-seqs --i-data repseq.qza --o-visualization repseq.qzv

    cat <<-END_VERSIONS > versions.yml
    "QIIME_COLLAPSE_ITSX_ITS2":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
      biom: \$(biom --version 2>&1 | head -n 1)
      python: \$(python3 --version 2>&1)
    END_VERSIONS
    """
}
