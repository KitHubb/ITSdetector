process QIIME_DADA2_PE {

    tag { "${params.run_label}:${meta.method}_${meta.read_mode}" }
    label 'qiime_dada2'

    container "${params.qiime_sif}"

    publishDir {
        "${params.outdir}/dada2/${meta.method}/${meta.read_mode}"
    }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(demux_pe)

    output:
    tuple val(meta),
          path("table.qza"),
          path("repseq.qza"),
          path("denoising_stats.qza"),
          emit: dada2_results

    tuple val(meta),
          path("denoising_stats.qzv"),
          emit: stats_summary

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

    # Denoise paired-end reads.
    qiime dada2 denoise-paired \
      --i-demultiplexed-seqs ${demux_pe} \
      --p-trim-left-f ${params.dada2_trim_left_f} \
      --p-trim-left-r ${params.dada2_trim_left_r} \
      --p-trunc-len-f ${params.dada2_trunc_len_f} \
      --p-trunc-len-r ${params.dada2_trunc_len_r} \
      --p-trunc-q ${params.dada2_trunc_q} \
      --p-max-ee-f ${params.dada2_max_ee_f} \
      --p-max-ee-r ${params.dada2_max_ee_r} \
      --p-chimera-method ${params.dada2_chimera_method} \
      --p-pooling-method ${params.dada2_pooling_method} \
      --p-n-reads-learn ${params.dada2_n_reads_learn} \
      --p-n-threads ${task.cpus} \
      --o-table table.qza \
      --o-representative-sequences repseq.qza \
      --o-denoising-stats denoising_stats.qza

    # Create a tabulated DADA2 statistics report.
    qiime metadata tabulate \
      --m-input-file denoising_stats.qza \
      --o-visualization denoising_stats.qzv

    cat <<-END_VERSIONS > versions.yml
    "QIIME_DADA2_PE":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}


process QIIME_DADA2_SE {

    tag { "${params.run_label}:${meta.method}_${meta.read_mode}" }
    label 'qiime_dada2'

    container "${params.qiime_sif}"

    publishDir {
        "${params.outdir}/dada2/${meta.method}/${meta.read_mode}"
    }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(demux_se)

    output:
    tuple val(meta),
          path("table.qza"),
          path("repseq.qza"),
          path("denoising_stats.qza"),
          emit: dada2_results

    tuple val(meta),
          path("denoising_stats.qzv"),
          emit: stats_summary

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

    # Denoise single-end reads.
    qiime dada2 denoise-single \
      --i-demultiplexed-seqs ${demux_se} \
      --p-trim-left ${params.dada2_trim_left} \
      --p-trunc-len ${params.dada2_trunc_len} \
      --p-trunc-q ${params.dada2_trunc_q} \
      --p-max-ee ${params.dada2_max_ee} \
      --p-chimera-method ${params.dada2_chimera_method} \
      --p-pooling-method ${params.dada2_pooling_method} \
      --p-n-reads-learn ${params.dada2_n_reads_learn} \
      --p-n-threads ${task.cpus} \
      --o-table table.qza \
      --o-representative-sequences repseq.qza \
      --o-denoising-stats denoising_stats.qza

    # Create a tabulated DADA2 statistics report.
    qiime metadata tabulate \
      --m-input-file denoising_stats.qza \
      --o-visualization denoising_stats.qzv

    cat <<-END_VERSIONS > versions.yml
    "QIIME_DADA2_SE":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}
