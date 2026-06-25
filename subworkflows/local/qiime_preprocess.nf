include { QIIME_CUTADAPT_PRIMER_PE } from '../../modules/local/qiime_cutadapt_primer'
include { QIIME_CUTADAPT_PRIMER_SE } from '../../modules/local/qiime_cutadapt_primer'
include { QIIME_ITSXPRESS_PE } from '../../modules/local/qiime_itsxpress'
include { QIIME_ITSXPRESS_SE } from '../../modules/local/qiime_itsxpress'

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
    if (params.preprocess_method in ['primer', 'both'] &&
        params.analysis_mode in ['single', 'both']) {

        QIIME_CUTADAPT_PRIMER_SE(demux_r1)

        primer_se_trimmed = QIIME_CUTADAPT_PRIMER_SE.out.trimmed
        primer_se_summary = QIIME_CUTADAPT_PRIMER_SE.out.summary
    }

    // Run ITSxpress paired-end preprocessing when requested.
    if (params.preprocess_method in ['itsxpress', 'both'] &&
        params.analysis_mode in ['paired', 'both']) {

        QIIME_ITSXPRESS_PE(demux_pe)

        itsxpress_pe_trimmed = QIIME_ITSXPRESS_PE.out.trimmed
        itsxpress_pe_summary = QIIME_ITSXPRESS_PE.out.summary
    }

    // Run ITSxpress single-end preprocessing when requested.
    if (params.preprocess_method in ['itsxpress', 'both'] &&
        params.analysis_mode in ['single', 'both']) {

        QIIME_ITSXPRESS_SE(demux_r1)

        itsxpress_se_trimmed = QIIME_ITSXPRESS_SE.out.trimmed
        itsxpress_se_summary = QIIME_ITSXPRESS_SE.out.summary
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
