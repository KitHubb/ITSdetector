process VALIDATE_SAMPLESHEET {

    tag "${samplesheet.baseName}"

    publishDir "${params.outdir}/input_validation", mode: 'copy', overwrite: true

    input:
    path samplesheet

    output:
    path "samplesheet.validated.csv", emit: validated_samplesheet

    script:
    """
    validate_samplesheet.py \
      ${samplesheet} \
      samplesheet.validated.csv
    """
}
