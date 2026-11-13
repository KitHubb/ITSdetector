include {
    QIIME_EXPORT_ASVS_FOR_ITSX
    ITSX_EXTRACT_ASV_ITS2
    QIIME_COLLAPSE_ITSX_ITS2
} from '../../modules/local/qiime_post_dada2_itsx'

workflow POST_DADA2_ITSX {

    take:
    dada2_results

    main:
    collapse_script = file(
        "${projectDir}/bin/collapse_itsx_features.py",
        checkIfExists: true
    )

    QIIME_EXPORT_ASVS_FOR_ITSX(dada2_results)
    ITSX_EXTRACT_ASV_ITS2(QIIME_EXPORT_ASVS_FOR_ITSX.out.exported)

    collapse_inputs = ITSX_EXTRACT_ASV_ITS2.out.extracted.map {
        meta, table_biom, its2_fasta, denoising_stats ->
        def its2_meta = meta + [
            source_method: meta.method,
            method: 'cutadapt_itsx',
            region: params.itsx_region
        ]
        tuple(its2_meta, table_biom, its2_fasta, denoising_stats)
    }

    QIIME_COLLAPSE_ITSX_ITS2(collapse_inputs, collapse_script)

    emit:
    dada2_results = QIIME_COLLAPSE_ITSX_ITS2.out.dada2_results
    extraction_reports = ITSX_EXTRACT_ASV_ITS2.out.reports
    collapse_reports = QIIME_COLLAPSE_ITSX_ITS2.out.reports
    versions = QIIME_COLLAPSE_ITSX_ITS2.out.versions
}
