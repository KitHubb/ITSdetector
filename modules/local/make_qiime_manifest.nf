process MAKE_QIIME_MANIFEST {

    tag "${params.run_label}"
    label 'read_cleanup'

    container "${params.cutadapt_sif}"

    publishDir "${params.outdir}/qiime_manifest", mode: 'copy', overwrite: true

    input:
    path read_records

    output:
    path "qiime_manifest_pe.csv", emit: manifest
    path "qiime_manifest_validation.tsv", emit: validation
    path "versions.yml", emit: versions

    script:
    """
    build_qiime_manifest.py \
      --input ${read_records} \
      --manifest qiime_manifest_pe.csv \
      --validation qiime_manifest_validation.tsv

    cat <<-END_VERSIONS > versions.yml
    "MAKE_QIIME_MANIFEST":
      python: \$(python --version 2>&1 | awk '{print \$2}')
    END_VERSIONS
    """
}
