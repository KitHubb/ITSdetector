include { QIIME_CUTADAPT_PRIMER_PE } from '../../modules/local/qiime_cutadapt_primer'
include { QIIME_CUTADAPT_PRIMER_SE } from '../../modules/local/qiime_cutadapt_primer'
include { QIIME_ITSXPRESS_PE } from '../../modules/local/qiime_itsxpress'

workflow QIIME_PREPROCESS {

    take:
    demux_pe
    demux_r1

    main:
    // Initialize empty channels for optional preprocessing branches.
    primer_pe_trimmed = Channel.empty()
    primer_pe_summary = Channel.empty()

    primer_se_trimmed = Channel.empty()
    primer_se_summary = Channel.empty()

    itsxpress_pe_trimmed = Channel.empty()
    itsxpress_pe_summary = Channel.empty()

    // IMPORTANT:
    // ITSxpress preprocessing is intentionally run from paired-end input only.
    // R1-only ITSxpress extraction can leave very short partial ITS fragments,
    // which can collapse downstream species-level classification.
    //
    // Therefore:
    //   --analysis_mode paired : ITSxpress PE output -> DADA2 paired
    //   --analysis_mode single : ITSxpress PE output -> DADA2 single
    //   --analysis_mode both   : ITSxpress PE output -> both DADA2 paired and single
    itsxpress_se_trimmed = Channel.empty()
    itsxpress_se_summary = Channel.empty()

    // Run primer-only paired-end preprocessing when requested.
    if (params.preprocess_method in ['primer', 'both'] &&
        params.analysis_mode in ['paired', 'both']) {

        QIIME_CUTADAPT_PRIMER_PE(demux_pe)

        primer_pe_trimmed = QIIME_CUTADAPT_PRIMER_PE.out.trimmed
        primer_pe_summary = QIIME_CUTADAPT_PRIMER_PE.out.summary
    }

    // Run primer-only single-end preprocessing when requested.
    // This remains true single-end because cutadapt only trims primer/adapter sequence;
    // it does not infer or extract ITS subregions using R1 alone.
    if (params.preprocess_method in ['primer', 'both'] &&
        params.analysis_mode in ['single', 'both']) {

        QIIME_CUTADAPT_PRIMER_SE(demux_r1)

        primer_se_trimmed = QIIME_CUTADAPT_PRIMER_SE.out.trimmed
        primer_se_summary = QIIME_CUTADAPT_PRIMER_SE.out.summary
    }

    // Run ITSxpress paired-end preprocessing whenever ITSxpress is requested,
    // regardless of whether DADA2 will be run as paired, single, or both.
    if (params.preprocess_method in ['itsxpress', 'both'] &&
        params.analysis_mode in ['paired', 'single', 'both']) {

        QIIME_ITSXPRESS_PE(
            demux_pe,
            file("${projectDir}/bin/itsxpress_empty_pair_patch", checkIfExists: true)
        )

        itsxpress_pe_summary = QIIME_ITSXPRESS_PE.out.summary

        // Paired-end DADA2 branch uses this when analysis_mode is paired/both.
        if (params.analysis_mode in ['paired', 'both']) {
            itsxpress_pe_trimmed = QIIME_ITSXPRESS_PE.out.trimmed
        }

        // Single-end DADA2 branch also receives the paired-end ITSxpress output.
        // Downstream DADA2 decides whether to denoise as single according to meta/read_mode.
        if (params.analysis_mode in ['single', 'both']) {
            itsxpress_se_trimmed = QIIME_ITSXPRESS_PE.out.trimmed
            itsxpress_se_summary = QIIME_ITSXPRESS_PE.out.summary
        }
    }

    emit:
    primer_pe_trimmed = primer_pe_trimmed
    primer_pe_summary = primer_pe_summary

    primer_se_trimmed = primer_se_trimmed
    primer_se_summary = primer_se_summary

    itsxpress_pe_trimmed = itsxpress_pe_trimmed
    itsxpress_pe_summary = itsxpress_pe_summary

    itsxpress_se_trimmed = itsxpress_se_trimmed
    itsxpress_se_summary = itsxpress_se_summary
}
