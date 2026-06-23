process QIIME_CUTADAPT_PRIMER_PE {

    tag "${params.run_label}:primer_paired"
    label 'qiime_preprocess'

    container "${params.qiime_sif}"

    publishDir "${params.outdir}/qiime_preprocess/primer/paired",
        mode: 'copy',
        overwrite: true

    input:
    path demux_pe

    output:
    path "trimmed_primer_pe.qza", emit: trimmed
    path "trimmed_primer_pe.qzv", emit: summary
    path "versions.yml", emit: versions

    script:
    def discard_untrimmed_args = params.primer_discard_untrimmed ?
        "--p-discard-untrimmed" : ""

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

    # Trim forward and reverse primer-related sequences from paired-end reads.
    qiime cutadapt trim-paired \
      --i-demultiplexed-sequences ${demux_pe} \
      --p-front-f "${params.primer_fwd}" \
      --p-adapter-f "${params.primer_fwd_adapter}" \
      --p-front-r "${params.primer_rev}" \
      --p-adapter-r "${params.primer_rev_adapter}" \
      ${discard_untrimmed_args} \
      --o-trimmed-sequences trimmed_primer_pe.qza

    # Summarize retained paired-end reads after primer trimming.
    qiime demux summarize \
      --i-data trimmed_primer_pe.qza \
      --o-visualization trimmed_primer_pe.qzv

    cat <<-END_VERSIONS > versions.yml
    "QIIME_CUTADAPT_PRIMER_PE":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}


process QIIME_CUTADAPT_PRIMER_SE {

    tag "${params.run_label}:primer_single"
    label 'qiime_preprocess'

    container "${params.qiime_sif}"

    publishDir "${params.outdir}/qiime_preprocess/primer/single",
        mode: 'copy',
        overwrite: true

    input:
    path demux_r1

    output:
    path "trimmed_primer_se.qza", emit: trimmed
    path "trimmed_primer_se.qzv", emit: summary
    path "versions.yml", emit: versions

    script:
    def discard_untrimmed_args = params.primer_discard_untrimmed ?
        "--p-discard-untrimmed" : ""

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

    # Trim forward primer-related sequences from R1-only reads.
    qiime cutadapt trim-single \
      --i-demultiplexed-sequences ${demux_r1} \
      --p-front "${params.primer_fwd}" \
      --p-adapter "${params.primer_fwd_adapter}" \
      ${discard_untrimmed_args} \
      --o-trimmed-sequences trimmed_primer_se.qza

    # Summarize retained single-end reads after primer trimming.
    qiime demux summarize \
      --i-data trimmed_primer_se.qza \
      --o-visualization trimmed_primer_se.qzv

    cat <<-END_VERSIONS > versions.yml
    "QIIME_CUTADAPT_PRIMER_SE":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}
