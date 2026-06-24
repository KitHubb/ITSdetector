include { QIIME_TAXONOMY_CLASSIFIER } from '../../modules/local/qiime_taxonomy_classifier'

workflow QIIME_TAXONOMY {

    take:
    dada2_results

    main:
    classifier_qza = file(
        params.taxonomy_classifier,
        checkIfExists: true
    )

    taxonomy_input = dada2_results.map { meta, table, repseq, denoising_stats ->

        def taxonomy_meta = meta + [
            reference_id: params.taxonomy_reference_id
        ]

        tuple(
            taxonomy_meta,
            repseq,
            classifier_qza
        )
    }

    QIIME_TAXONOMY_CLASSIFIER(taxonomy_input)

    emit:
    taxonomy_results = QIIME_TAXONOMY_CLASSIFIER.out.taxonomy_results
    versions = QIIME_TAXONOMY_CLASSIFIER.out.versions
}