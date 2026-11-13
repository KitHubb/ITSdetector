process QIIME_PHYLOGENY_FASTTREE {

    tag { "${params.run_label}:${meta.method}_${meta.read_mode}" }
    label 'qiime_phylogeny'

    container "${params.qiime_sif}"

    publishDir {
        "${params.outdir}/phylogeny/${meta.method}/${meta.read_mode}"
    }, mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(repseq)

    output:
    tuple val(meta),
          path("aligned-rep-seqs.qza"),
          path("masked-aligned-rep-seqs.qza"),
          path("unrooted-tree.qza"),
          path("rooted-tree.qza"),
          emit: phylogeny_results

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

    qiime phylogeny align-to-tree-mafft-fasttree \
      --i-sequences ${repseq} \
      --p-n-threads ${task.cpus} \
      --o-alignment aligned-rep-seqs.qza \
      --o-masked-alignment masked-aligned-rep-seqs.qza \
      --o-tree unrooted-tree.qza \
      --o-rooted-tree rooted-tree.qza

    cat <<-END_VERSIONS > versions.yml
    "QIIME_PHYLOGENY_FASTTREE":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
      mafft: \$(mafft --version 2>&1 | head -n 1)
      fasttree: \$(FastTree 2>&1 | head -n 1)
    END_VERSIONS
    """
}
