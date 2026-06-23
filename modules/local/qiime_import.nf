process QIIME_IMPORT_PE {

    tag "${params.run_label}:paired"
    label 'qiime_import'

    container "${params.qiime_sif}"

    publishDir "${params.outdir}/qiime_import", mode: 'copy', overwrite: true

    input:
    path pe_manifest

    output:
    path "demux_pe.qza", emit: demux
    path "demux_pe.qzv", emit: summary
    path "versions.yml", emit: versions

    script:
    """
    # Set writable cache directories for QIIME 2 plugins inside Singularity.
    export NUMBA_CACHE_DIR="\$PWD/numba_cache"
    export MPLCONFIGDIR="\$PWD/matplotlib_cache"
    export XDG_CACHE_HOME="\$PWD/xdg_cache"

    mkdir -p "\$NUMBA_CACHE_DIR" "\$MPLCONFIGDIR" "\$XDG_CACHE_HOME"

    # Import paired-end FASTQ reads as a QIIME 2 artifact.
    qiime tools import \
      --type 'SampleData[PairedEndSequencesWithQuality]' \
      --input-path ${pe_manifest} \
      --input-format PairedEndFastqManifestPhred33V2 \
      --output-path demux_pe.qza

    # Create a read-quality summary visualization.
    qiime demux summarize \
      --i-data demux_pe.qza \
      --o-visualization demux_pe.qzv

    cat <<-END_VERSIONS > versions.yml
    "QIIME_IMPORT_PE":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}


process QIIME_IMPORT_SE {

    tag "${params.run_label}:r1_only"
    label 'qiime_import'

    container "${params.qiime_sif}"

    publishDir "${params.outdir}/qiime_import", mode: 'copy', overwrite: true

    input:
    path r1_manifest

    output:
    path "demux_r1.qza", emit: demux
    path "demux_r1.qzv", emit: summary
    path "versions.yml", emit: versions

    script:
    """
    # Set writable cache directories for QIIME 2 plugins inside Singularity.
    export NUMBA_CACHE_DIR="\$PWD/numba_cache"
    export MPLCONFIGDIR="\$PWD/matplotlib_cache"
    export XDG_CACHE_HOME="\$PWD/xdg_cache"

    mkdir -p "\$NUMBA_CACHE_DIR" "\$MPLCONFIGDIR" "\$XDG_CACHE_HOME"

    # Import forward reads as a single-end QIIME 2 artifact.
    qiime tools import \
      --type 'SampleData[SequencesWithQuality]' \
      --input-path ${r1_manifest} \
      --input-format SingleEndFastqManifestPhred33V2 \
      --output-path demux_r1.qza

    # Create a read-quality summary visualization.
    qiime demux summarize \
      --i-data demux_r1.qza \
      --o-visualization demux_r1.qzv

    cat <<-END_VERSIONS > versions.yml
    "QIIME_IMPORT_SE":
      qiime2: \$(qiime --version 2>&1 | head -n 1)
    END_VERSIONS
    """
}
