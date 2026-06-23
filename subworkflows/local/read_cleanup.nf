include { READ_CLEANUP_PE } from '../../modules/local/read_cleanup'

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

    emit:
    cleaned_reads = READ_CLEANUP_PE.out.cleaned_reads
    json          = READ_CLEANUP_PE.out.json
    cutadapt_log  = READ_CLEANUP_PE.out.cutadapt_log
}
