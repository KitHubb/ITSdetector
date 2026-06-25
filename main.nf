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
include { QIIME_DADA2 } from './subworkflows/local/qiime_dada2'
include { QIIME_TAXONOMY } from './subworkflows/local/qiime_taxonomy'
include { BLAST_REFSEQ_ITS_WORKFLOW } from './subworkflows/local/blast_refseq_its'

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

    QIIME_DADA2(
        QIIME_PREPROCESS.out.itsxpress_pe_trimmed,
        QIIME_PREPROCESS.out.itsxpress_se_trimmed,
        QIIME_PREPROCESS.out.primer_pe_trimmed,
        QIIME_PREPROCESS.out.primer_se_trimmed
    )

    if (params.taxonomy_enabled) {

        taxonomy_dada2_results = QIIME_DADA2.out.paired_results
            .mix(QIIME_DADA2.out.single_results)

        QIIME_TAXONOMY(taxonomy_dada2_results)

        if (params.blast_refseq_enabled) {
            BLAST_REFSEQ_ITS_WORKFLOW(
                QIIME_TAXONOMY.out.blast_inputs
            )
        }
    }
}
