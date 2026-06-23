nextflow.enable.dsl = 2

params.input = null
params.outdir = 'results'

include { VALIDATE_SAMPLESHEET } from './modules/local/validate_samplesheet'
include { RAW_QC } from './subworkflows/local/raw_qc'
include { READ_CLEANUP } from './subworkflows/local/read_cleanup'
include { CLEANUP_QC } from './subworkflows/local/cleanup_qc_summary'
include { BUILD_QIIME_MANIFEST } from './subworkflows/local/make_qiime_manifest'
include { QIIME_IMPORT } from './subworkflows/local/qiime_import'
include { QIIME_PREPROCESS } from './subworkflows/local/qiime_preprocess'

workflow {

    if (!params.input) {
        error "Please provide --input <samplesheet.csv>"
    }

    samplesheet_ch = Channel.fromPath(
        params.input,
        checkIfExists: true
    )

    VALIDATE_SAMPLESHEET(samplesheet_ch)

    RAW_QC(
        VALIDATE_SAMPLESHEET.out.validated_samplesheet
    )

    READ_CLEANUP(
        VALIDATE_SAMPLESHEET.out.validated_samplesheet
    )

    CLEANUP_QC(
        READ_CLEANUP.out.json
    )

    BUILD_QIIME_MANIFEST(
        READ_CLEANUP.out.cleaned_reads
    )

    QIIME_IMPORT(
        BUILD_QIIME_MANIFEST.out.pe_manifest,
        BUILD_QIIME_MANIFEST.out.r1_manifest
    )

    QIIME_PREPROCESS(
        QIIME_IMPORT.out.demux_pe,
        QIIME_IMPORT.out.demux_r1
    )
}
