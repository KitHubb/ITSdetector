include { MAKE_QIIME_MANIFEST } from '../../modules/local/make_qiime_manifest'

workflow BUILD_QIIME_MANIFEST {

    take:
    paired_reads

    main:
    read_records_ch = paired_reads
        .map { meta, read1, read2 ->
            "${meta.id}\t${read1.toAbsolutePath()}\t${read2.toAbsolutePath()}"
        }
        .collectFile(
            name: 'qiime_input_records.tsv',
            newLine: true
        )

    MAKE_QIIME_MANIFEST(read_records_ch)

    emit:
    manifest = MAKE_QIIME_MANIFEST.out.manifest
    validation = MAKE_QIIME_MANIFEST.out.validation
}
