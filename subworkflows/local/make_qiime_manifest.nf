include { MAKE_QIIME_MANIFEST } from '../../modules/local/make_qiime_manifest'

workflow BUILD_QIIME_MANIFEST {

    take:
    cleaned_reads

    main:
    read_records_ch = cleaned_reads
        .map { meta, read1, read2 ->

            def sample_id = meta.id
            // Use READ_CLEANUP outputs directly; publishDir copies asynchronously.
            def r1_path = read1.toAbsolutePath()
            def r2_path = read2.toAbsolutePath()

            "${sample_id}\t${r1_path}\t${r2_path}"
        }
        .collectFile(
            name: 'qiime_manifest_input.tsv',
            newLine: true
        )

    MAKE_QIIME_MANIFEST(read_records_ch)

    emit:
    pe_manifest = MAKE_QIIME_MANIFEST.out.pe_manifest
    r1_manifest = MAKE_QIIME_MANIFEST.out.r1_manifest
    validation  = MAKE_QIIME_MANIFEST.out.validation
}
