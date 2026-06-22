nextflow.enable.dsl = 2

params.input  = null
params.outdir = 'results'

include { VALIDATE_SAMPLESHEET } from './modules/local/validate_samplesheet'
include { RAW_QC } from './subworkflows/local/raw_qc'
include { READ_CLEANUP } from './subworkflows/local/read_cleanup'

workflow {

    if (!params.input) {
        error "Please provide --input <samplesheet.csv>"
    }

    samplesheet_ch = Channel.fromPath(
        params.input,
        checkIfExists: true
    )

    VALIDATE_SAMPLESHEET(samplesheet_ch)

    RAW_QC(VALIDATE_SAMPLESHEET.out.validated_samplesheet)
    
    READ_CLEANUP(VALIDATE_SAMPLESHEET.out.validated_samplesheet)
    
}
