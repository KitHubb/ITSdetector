nextflow.enable.dsl = 2

params.input = null
params.outdir = 'results'

include { VALIDATE_SAMPLESHEET } from './modules/local/validate_samplesheet'
include { RAW_QC } from './subworkflows/local/raw_qc'
include { READ_CLEANUP } from './subworkflows/local/read_cleanup'
include { BUILD_QIIME_MANIFEST } from './subworkflows/local/make_qiime_manifest'
include { QIIME_IMPORT } from './subworkflows/local/qiime_import'
include { QIIME_PREPROCESS } from './subworkflows/local/qiime_preprocess'
include { QIIME_DADA2 } from './subworkflows/local/qiime_dada2'
include { QIIME_TAXONOMY } from './subworkflows/local/qiime_taxonomy'
include { ITSX_EXPORT_ASV; ITSX_EXTRACT_ASV; ITSX_IMPORT_ASV } from './modules/local/itsx_asv'
include { BLAST_REFSEQ_ITS_WORKFLOW } from './subworkflows/local/blast_refseq_its'

workflow {

    if (!params.input) {
        error "Please provide --input <samplesheet.csv>"
    }

    // CLI booleans can arrive as strings (e.g. "false") in Nextflow.
    // Convert explicitly: a non-empty "false" string is otherwise truthy.
    // Reject invalid ITSx settings before launching upstream work.
    if (params.itsx_enabled.toString().toBoolean()) {
        if (!(params.itsx_region in ['ITS1', 'ITS2'])) {
            error "--itsx_region must be ITS1 or ITS2"
        }
        if (!(params.itsx_partial.toString() ==~ /[0-9]+/)) {
            error "--itsx_partial must be a non-negative integer"
        }
        if (!(params.itsx_taxa.toString() ==~ /[A-Za-z]+(,[A-Za-z]+)*/)) {
            error "--itsx_taxa must contain ITSx taxon codes separated by commas"
        }
        if (!(params.preprocess_method in ['primer', 'both'])) {
            error "--itsx_enabled requires --preprocess_method primer or both"
        }
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

    // For ITSxpress, preprocessing is always performed from paired-end input.
    // If --analysis_mode single is requested, the paired-end ITSxpress-trimmed
    // artifact is routed to DADA2 single-end denoising downstream. This avoids
    // the unstable R1-only ITSxpress extraction path.
    QIIME_DADA2(
        QIIME_PREPROCESS.out.itsxpress_pe_trimmed,
        QIIME_PREPROCESS.out.itsxpress_se_trimmed,
        QIIME_PREPROCESS.out.primer_pe_trimmed,
        QIIME_PREPROCESS.out.primer_se_trimmed
    )

    // Keep original ASVs for comparison; ITSx never reruns DADA2.
    dada2_results = QIIME_DADA2.out.paired_results.mix(QIIME_DADA2.out.single_results)
    taxonomy_dada2_results = dada2_results

    if (params.itsx_enabled.toString().toBoolean()) {
        // Map addition preserves the original metadata. Both read modes use
        // the same processes; ITSxpress results never enter this branch.
        itsx_inputs = dada2_results
            .filter { meta, table, repseq, stats -> meta.method == 'cutadapt' }
            .map { meta, table, repseq, stats ->
                tuple(meta + [method: 'cutadapt_itsx'], table, repseq, stats)
            }
        ITSX_EXPORT_ASV(itsx_inputs)
        ITSX_EXTRACT_ASV(ITSX_EXPORT_ASV.out.exported)
        ITSX_IMPORT_ASV(
            ITSX_EXTRACT_ASV.out.extracted,
            file("${projectDir}/bin/summarize_itsx_asv.py", checkIfExists: true)
        )
        taxonomy_dada2_results = dada2_results.mix(ITSX_IMPORT_ASV.out.dada2_results)
    }

    if (params.taxonomy_enabled.toString().toBoolean()) {

        QIIME_TAXONOMY(taxonomy_dada2_results)

        if (params.blast_refseq_enabled.toString().toBoolean()) {
            BLAST_REFSEQ_ITS_WORKFLOW(
                QIIME_TAXONOMY.out.blast_inputs
            )
        }
    }
}
