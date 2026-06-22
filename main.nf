nextflow.enable.dsl = 2

process CHECK_QIIME {

    tag 'qiime2-container-check'

    container "${params.qiime_sif}"

    publishDir "${params.outdir}/smoke_test", mode: 'copy', overwrite: true

    output:
    path 'qiime_version.txt'

    script:
    """
    qiime --version > qiime_version.txt
    """
}

workflow {
    CHECK_QIIME()
}
