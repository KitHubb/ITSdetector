include { QIIME_DADA2_PE } from '../../modules/local/qiime_dada2'
include { QIIME_DADA2_SE } from '../../modules/local/qiime_dada2'

workflow QIIME_DADA2 {

    take:
    itsxpress_pe_trimmed
    itsxpress_se_trimmed
    primer_pe_trimmed
    primer_se_trimmed

    main:
    // Attach branch metadata to each preprocessing artifact.
    itsxpress_pe_input = itsxpress_pe_trimmed.map { qza ->
        tuple([method: 'itsxpress', read_mode: 'paired'], qza)
    }

    itsxpress_se_input = itsxpress_se_trimmed.map { qza ->
        tuple([method: 'itsxpress', read_mode: 'single'], qza)
    }

    cutadapt_pe_input = primer_pe_trimmed.map { qza ->
        tuple([method: 'cutadapt', read_mode: 'paired'], qza)
    }

    cutadapt_se_input = primer_se_trimmed.map { qza ->
        tuple([method: 'cutadapt', read_mode: 'single'], qza)
    }

    // Empty preprocessing channels remain empty and do not create DADA2 tasks.
    paired_inputs = itsxpress_pe_input.mix(cutadapt_pe_input)
    single_inputs = itsxpress_se_input.mix(cutadapt_se_input)

    QIIME_DADA2_PE(paired_inputs)
    QIIME_DADA2_SE(single_inputs)

    emit:
    paired_results = QIIME_DADA2_PE.out.dada2_results
    paired_stats = QIIME_DADA2_PE.out.stats_summary
    paired_versions = QIIME_DADA2_PE.out.versions

    single_results = QIIME_DADA2_SE.out.dada2_results
    single_stats = QIIME_DADA2_SE.out.stats_summary
    single_versions = QIIME_DADA2_SE.out.versions
}
