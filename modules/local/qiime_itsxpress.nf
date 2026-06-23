process QIIME_ITSXPRESS_PE {

    tag "${params.run_label}:itsxpress_paired"
    label 'qiime_preprocess'

    container "${params.qiime_its_sif}"

    publishDir "${params.outdir}/qiime_preprocess/itsxpress/paired",
        mode: 'copy',
        overwrite: true

    input:
    path demux_pe

    output:
    path "trimmed_itsxpress_pe.qza", emit: trimmed
    path "trimmed_itsxpress_pe.qzv", emit: summary
    path "versions.yml", emit: versions

    script:
    """
    # Use task-local writable directories for QIIME 2 and Python caches.
    export TMPDIR="\$PWD/qiime_tmp"
    export TMP="\$TMPDIR"
    export TEMP="\$TMPDIR"
    export NUMBA_CACHE_DIR="\$PWD/numba_cache"
    export MPLCONFIGDIR="\$PWD/matplotlib_cache"
    export XDG_CACHE_HOME="\$PWD/xdg_cache"

    mkdir -p \
      "\$TMPDIR" \
      "\$NUMBA_CACHE_DIR" \
      "\$MPLCONFIGDIR" \
      "\$XDG_CACHE_HOME"

    # Extract the target ITS region while retaining paired-end reads.
    qiime itsxpress trim-pair-output-unmerged \
      --i-per-sample-sequences ${demux_pe} \
      --p-region "${params.itsxpress_region}" \
      --p-taxa "${params.itsxpress_taxa}" \
      --p-cluster-id ${params.itsxpress_cluster_id} \
      --p-threads ${task.cpus} \
      --o-trimmed trimmed_itsxpress_pe.qza

    # Summarize retained paired-end reads after ITS extraction.
    qiime demux summarize \
      --i-data trimmed_itsxpress_pe.qza \
      --o-visualization trimmed_itsxpress_pe.qzv

    cat <<-END_VERSIONS > versions.yml
    "QIIME_ITSXPRESS_PE":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}


process QIIME_ITSXPRESS_SE {

    tag "${params.run_label}:itsxpress_single"
    label 'qiime_preprocess'

    container "${params.qiime_its_sif}"

    publishDir "${params.outdir}/qiime_preprocess/itsxpress/single",
        mode: 'copy',
        overwrite: true

    input:
    path demux_r1

    output:
    path "trimmed_itsxpress_se.qza", emit: trimmed
    path "trimmed_itsxpress_se.qzv", emit: summary
    path "versions.yml", emit: versions

    script:
    """
    # Use task-local writable directories for QIIME 2 and Python caches.
    export TMPDIR="\$PWD/qiime_tmp"
    export TMP="\$TMPDIR"
    export TEMP="\$TMPDIR"
    export NUMBA_CACHE_DIR="\$PWD/numba_cache"
    export MPLCONFIGDIR="\$PWD/matplotlib_cache"
    export XDG_CACHE_HOME="\$PWD/xdg_cache"

    mkdir -p \
      "\$TMPDIR" \
      "\$NUMBA_CACHE_DIR" \
      "\$MPLCONFIGDIR" \
      "\$XDG_CACHE_HOME"

    # Extract the target ITS region from R1-only reads.
    qiime itsxpress trim-single \
      --i-per-sample-sequences ${demux_r1} \
      --p-region "${params.itsxpress_region}" \
      --p-taxa "${params.itsxpress_taxa}" \
      --p-cluster-id ${params.itsxpress_cluster_id} \
      --p-threads ${task.cpus} \
      --o-trimmed trimmed_itsxpress_se.qza

    # Summarize retained single-end reads after ITS extraction.
    qiime demux summarize \
      --i-data trimmed_itsxpress_se.qza \
      --o-visualization trimmed_itsxpress_se.qzv

    cat <<-END_VERSIONS > versions.yml
    "QIIME_ITSXPRESS_SE":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}
