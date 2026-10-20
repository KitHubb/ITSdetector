nextflow.enable.dsl = 2
params.fixture_root = null

// Exercise the production processes with existing DADA2 artifacts. This skips
// expensive upstream denoising, while using real QIIME and ITSx containers.
include { ITSX_EXPORT_ASV; ITSX_EXTRACT_ASV; ITSX_IMPORT_ASV } from '../modules/local/itsx_asv'
include { QIIME_TAXONOMY } from '../subworkflows/local/qiime_taxonomy'

workflow {
    if (!params.fixture_root) {
        error "Please provide --fixture_root containing paired and single DADA2 artifacts"
    }
    inputs = Channel.of('paired', 'single').map { mode ->
        def folder = file("${params.fixture_root}/dada2_cutadapt_${mode == 'paired' ? 'merge' : 'forward'}", checkIfExists: true)
        tuple([method: 'cutadapt_itsx', read_mode: mode],
            file("${folder}/table.qza", checkIfExists: true),
            file("${folder}/representative_sequences.qza", checkIfExists: true),
            file("${folder}/denoising_stats.qza", checkIfExists: true))
    }
    ITSX_EXPORT_ASV(inputs)
    ITSX_EXTRACT_ASV(ITSX_EXPORT_ASV.out.exported)
    ITSX_IMPORT_ASV(
        ITSX_EXTRACT_ASV.out.extracted,
        file("${projectDir}/../bin/summarize_itsx_asv.py", checkIfExists: true)
    )
    if (params.taxonomy_enabled.toString().toBoolean()) {
        QIIME_TAXONOMY(ITSX_IMPORT_ASV.out.dada2_results)
    }
}
