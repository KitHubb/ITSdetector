nextflow.enable.dsl = 2

params.input  = null
params.outdir = 'results'

include { VALIDATE_SAMPLESHEET } from './modules/local/validate_samplesheet'

workflow {

    if (!params.input) {
        error "Please provide --input <samplesheet.csv>"
    }

    samplesheet_ch = Channel.fromPath(
        params.input,
        checkIfExists: true
    )

    VALIDATE_SAMPLESHEET(samplesheet_ch)

    VALIDATE_SAMPLESHEET.out.validated_samplesheet.view {
        "Validated samplesheet: ${it}"
    }
}
