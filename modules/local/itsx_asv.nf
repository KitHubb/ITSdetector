// QIIME exports/imports artifacts; standalone ITSx searches ASV sequences.
// Carry table and stats in each tuple to keep paired/single inputs together.
process ITSX_EXPORT_ASV {
    tag { "${meta.method}:${meta.read_mode}" }
    label 'qiime_import'
    container "${params.qiime_sif}"

    input:
    tuple val(meta), path(table), path(repseq), path(stats)

    output:
    tuple val(meta), path(table), path("asv_export/dna-sequences.fasta"), path(stats), emit: exported

    script:
    """
    export TMPDIR="\$PWD/qiime_tmp"
    export XDG_CACHE_HOME="\$PWD/xdg_cache"
    export MPLCONFIGDIR="\$PWD/matplotlib_cache"
    mkdir -p "\$TMPDIR" "\$XDG_CACHE_HOME" "\$MPLCONFIGDIR"
    qiime tools export --input-path '${repseq}' --output-path asv_export
    """
}

process ITSX_EXTRACT_ASV {
    tag { "${meta.method}:${meta.read_mode}:${params.itsx_region}:partial=${params.itsx_partial}" }
    label 'itsx_asv'
    container "${params.itsx_container}"
    // Publish extraction products only, not the unchanged table/stats inputs.
    publishDir { "${params.outdir}/itsx/${meta.read_mode}/extraction" },
        mode: 'copy', overwrite: true, pattern: '{extracted.fasta,itsx_output,versions.yml}'

    input:
    tuple val(meta), path(table), path(fasta), path(stats)

    output:
    tuple val(meta), path(table), path("extracted.fasta"), path(stats), emit: extracted
    path "itsx_output", emit: reports
    path "versions.yml", emit: versions

    script:
    def suffix = params.itsx_partial.toInteger() > 0 ? '.full_and_partial' : ''
    """
    mkdir -p itsx_output
    # Preserve original ASV IDs, even when ITSx reverses a sequence.
    # Never dereplicate: these IDs link extracted sequences to abundance.
    ITSx -i '${fasta}' -o itsx_output/asv \
      -t '${params.itsx_taxa}' --save_regions '${params.itsx_region}' \
      --preserve T --partial ${params.itsx_partial} --cpu ${task.cpus} \
      > itsx_output/run.log 2>&1

    # Partial mode must consume its dedicated FASTA, not the default output.
    selected='itsx_output/asv.${params.itsx_region}${suffix}.fasta'
    if [[ ! -s "\$selected" ]] || ! grep -q '^>' "\$selected"; then
      echo "ERROR: ITSx extracted zero ASVs (${params.itsx_region}, partial=${params.itsx_partial}). See itsx_output/run.log." >&2
      exit 1
    fi
    cp "\$selected" extracted.fasta
    printf 'ITSX_EXTRACT_ASV:\\n  itsx: %s\\n' "\$(ITSx --help 2>&1 | sed -n 's/^Version: //p')" > versions.yml
    """
}

process ITSX_IMPORT_ASV {
    tag { "${meta.method}:${meta.read_mode}" }
    label 'qiime_import'
    container "${params.qiime_sif}"
    publishDir { "${params.outdir}/dada2/${meta.method}/${meta.read_mode}" }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(table), path(fasta), path(stats)
    // Stage the helper explicitly for container access and content-aware caching.
    path summary_script

    output:
    // Keep the four-field contract used by taxonomy and BLAST. The original
    // stats artifact describes DADA2; separate TSVs describe ITSx retention.
    tuple val(meta), path("table_itsx.qza"), path("repseq_itsx.qza"), path(stats), emit: dada2_results
    path "itsx_*.tsv", emit: retention
    path "retained_ids.tsv", emit: retained_ids
    path "versions.yml", emit: versions

    script:
    """
    export TMPDIR="\$PWD/qiime_tmp"
    export XDG_CACHE_HOME="\$PWD/xdg_cache"
    export MPLCONFIGDIR="\$PWD/matplotlib_cache"
    mkdir -p "\$TMPDIR" "\$XDG_CACHE_HOME" "\$MPLCONFIGDIR"

    # Validate IDs and report duplicate sequences without combining counts.
    python '${summary_script}' \
      --table '${table}' --fasta '${fasta}' \
      --region '${params.itsx_region}' --taxa '${params.itsx_taxa}' \
      --partial ${params.itsx_partial}
    qiime tools import --type 'FeatureData[Sequence]' \
      --input-path '${fasta}' --output-path repseq_itsx.qza
    # Keep even samples with zero retained reads for paired comparisons.
    qiime feature-table filter-features --i-table '${table}' \
      --m-metadata-file retained_ids.tsv --p-no-filter-empty-samples \
      --o-filtered-table table_itsx.qza
    printf 'ITSX_IMPORT_ASV:\\n  qiime2: %s\\n' "\$(qiime --version 2>&1 | head -n 1)" > versions.yml
    """
}
