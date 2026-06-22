nextflow.enable.dsl = 2

params.outdir = 'results'

process HELLO_ITSDETECTOR {

    publishDir "${params.outdir}/smoke_test", mode: 'copy'

    output:
    path 'hello.txt'

    script:
    """
    echo "ITSdetector Nextflow smoke test passed." > hello.txt
    """
}

workflow {
    HELLO_ITSDETECTOR()
}
