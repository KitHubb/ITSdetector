process QIIME_TAXONOMY_CLASSIFIER {

    tag { "${params.run_label}:${meta.method}_${meta.read_mode}:${meta.reference_id}" }
    label 'qiime_taxonomy'

    container "${params.taxonomy_qiime_sif ?: params.qiime_sif}"

    publishDir {
        "${params.outdir}/taxonomy/${meta.method}/${meta.read_mode}/${meta.reference_id}"
    }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(repseq), path(classifier)

    output:
    tuple val(meta),
          path("taxonomy.qza"),
          path("taxonomy.qzv"),
          path("taxonomy.tsv"),
          emit: taxonomy_results

    path "versions.yml", emit: versions

    script:
    """
    # Create task-local writable directories for QIIME 2 and Python caches.
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

    # Assign taxonomy using one pre-trained reference classifier.
    qiime feature-classifier classify-sklearn \
      --i-reads ${repseq} \
      --i-classifier ${classifier} \
      --p-reads-per-batch ${params.taxonomy_reads_per_batch} \
      --p-n-jobs ${task.cpus} \
      --p-confidence ${params.taxonomy_confidence} \
      --o-classification taxonomy.qza

    # Create an interactive taxonomy summary.
    qiime metadata tabulate \
      --m-input-file taxonomy.qza \
      --o-visualization taxonomy.qzv

    # Export the taxonomy table for downstream benchmarking and R analysis.
    qiime tools export \
      --input-path taxonomy.qza \
      --output-path taxonomy_export

    cp taxonomy_export/taxonomy.tsv taxonomy.tsv

    cat <<-END_VERSIONS > versions.yml
    "QIIME_TAXONOMY_CLASSIFIER":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}