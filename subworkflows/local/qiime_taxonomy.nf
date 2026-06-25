include { QIIME_TAXONOMY_CLASSIFIER } from '../../modules/local/qiime_taxonomy_classifier'

workflow QIIME_TAXONOMY {

    take:
    dada2_results

    main:
    classifier_qza = file(
        params.taxonomy_classifier,
        checkIfExists: true
    )

    repseq_bridge = dada2_results.map { meta, table, repseq, denoising_stats ->

        def taxonomy_meta = meta + [
            reference_id: params.taxonomy_reference_id
        ]

        def bridge_key = "${taxonomy_meta.method}__${taxonomy_meta.read_mode}__${taxonomy_meta.reference_id}"

        tuple(
            bridge_key,
            taxonomy_meta,
            repseq
        )
    }

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

    taxonomy_bridge = QIIME_TAXONOMY_CLASSIFIER.out.taxonomy_results.map {
        meta, taxonomy_qza, taxonomy_qzv, taxonomy_tsv ->

        def bridge_key = "${meta.method}__${meta.read_mode}__${meta.reference_id}"

        tuple(
            bridge_key,
            meta,
            taxonomy_tsv
        )
    }

    blast_inputs = repseq_bridge
        .join(taxonomy_bridge)
        .map {
            bridge_key,
            repseq_meta,
            repseq_qza,
            taxonomy_meta,
            taxonomy_tsv ->

            tuple(
                taxonomy_meta,
                repseq_qza,
                taxonomy_tsv
            )
        }

    emit:
    taxonomy_results = QIIME_TAXONOMY_CLASSIFIER.out.taxonomy_results
    blast_inputs = blast_inputs
    versions = QIIME_TAXONOMY_CLASSIFIER.out.versions
}
