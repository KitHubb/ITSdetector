process FASTQC {

    tag "${meta.id}:${reads.baseName}"
    label 'qc'

    container "${params.qc_sif}"

    publishDir "${params.outdir}/raw_qc/fastqc", mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(reads)

    output:
    tuple val(meta), path("*_fastqc.zip"), path("*_fastqc.html"), emit: reports
    path "versions.yml", emit: versions

    script:
    """
    fastqc \
      --threads ${task.cpus} \
      --outdir . \
      ${reads}

    cat <<-END_VERSIONS > versions.yml
    "FASTQC":
      fastqc: \$(fastqc --version | sed 's/FastQC v//')
    END_VERSIONS
    """
}
