include { READ_CLEANUP_PE } from '../../modules/local/read_cleanup'
include { CLEANUP_QC_SUMMARY } from '../../modules/local/cleanup_qc_summary'
include { FASTQC as POST_CLEANUP_FASTQC } from '../../modules/local/fastqc'
include { MULTIQC as POST_CLEANUP_MULTIQC } from '../../modules/local/multiqc'

workflow READ_CLEANUP {

    take:
    samplesheet

    main:
    paired_reads_ch = samplesheet
        .splitCsv(header: true)
        .filter { row -> row.read_mode == 'paired' }
        .map { row ->

            def meta = [
                id        : row.sample_id,
                run_id    : row.run_id,
                assay_id  : row.assay_id,
                read_mode : row.read_mode
            ]

            tuple(
                meta,
                file(row.fastq_1),
                file(row.fastq_2)
            )
        }

    READ_CLEANUP_PE(paired_reads_ch)

    json_files_ch = READ_CLEANUP_PE.out.json.collect()
    CLEANUP_QC_SUMMARY(json_files_ch)

    post_cleanup_reads_ch = READ_CLEANUP_PE.out.cleaned_reads
        .flatMap { meta, read1, read2 ->
            [
                tuple(meta, read1),
                tuple(meta, read2)
            ]
        }

    POST_CLEANUP_FASTQC(post_cleanup_reads_ch)

    post_cleanup_fastqc_zips_ch = POST_CLEANUP_FASTQC.out.reports
        .map { meta, zip_file, html_file -> zip_file }
        .collect()

    POST_CLEANUP_MULTIQC(post_cleanup_fastqc_zips_ch)

    emit:
    cleaned_reads = READ_CLEANUP_PE.out.cleaned_reads
    json          = READ_CLEANUP_PE.out.json
    cutadapt_log  = READ_CLEANUP_PE.out.cutadapt_log

    cleanup_summary = CLEANUP_QC_SUMMARY.out.summary

    post_cleanup_fastqc_reports = POST_CLEANUP_FASTQC.out.reports
    post_cleanup_multiqc_report = POST_CLEANUP_MULTIQC.out.report
    post_cleanup_multiqc_data = POST_CLEANUP_MULTIQC.out.data
}
