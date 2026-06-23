include { CLEANUP_QC_SUMMARY } from '../../modules/local/cleanup_qc_summary'

workflow CLEANUP_QC {

    take:
    cutadapt_json

    main:
    json_files_ch = cutadapt_json.collect()

    CLEANUP_QC_SUMMARY(json_files_ch)

    emit:
    summary = CLEANUP_QC_SUMMARY.out.summary
}
