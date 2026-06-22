include { FASTQC } from '../../modules/local/fastqc'
include { MULTIQC } from '../../modules/local/multiqc'

workflow RAW_QC {

    take:
    samplesheet

    main:
    reads_ch = samplesheet
        .splitCsv(header: true)
        .flatMap { row ->

            def meta = [
                id        : row.sample_id,
                run_id    : row.run_id,
                assay_id  : row.assay_id,
                read_mode : row.read_mode
            ]

            def records = [tuple(meta, file(row.fastq_1))]

            if (row.read_mode == 'paired' && row.fastq_2) {
                records << tuple(meta, file(row.fastq_2))
            }

            return records
        }

    FASTQC(reads_ch)

    fastqc_zips_ch = FASTQC.out.reports
        .map { meta, zip_file, html_file -> zip_file }
        .collect()

    MULTIQC(fastqc_zips_ch)

    emit:
    fastqc_reports = FASTQC.out.reports
    multiqc_report = MULTIQC.out.report
}
