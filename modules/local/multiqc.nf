process MULTIQC {

    tag "raw_fastqc"

    container "${params.qc_sif}"

    publishDir "${params.outdir}/raw_qc/multiqc", mode: 'copy', overwrite: true

    input:
    path fastqc_zips

    output:
    path "multiqc_report.html", emit: report
    path "multiqc_data", emit: data
    path "versions.yml", emit: versions

    script:
    """
    multiqc \
      --force \
      --outdir . \
      ${fastqc_zips}

    cat <<-END_VERSIONS > versions.yml
    "MULTIQC":
      multiqc: \$(multiqc --version | sed 's/multiqc, version //')
    END_VERSIONS
    """
}
