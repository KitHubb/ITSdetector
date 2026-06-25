include {
    QIIME_EXPORT_REPSEQ
    BLAST_REFSEQ_RECONCILE
    QIIME_IMPORT_RECONCILED_TAXONOMY
} from '../../modules/local/blast_refseq_its'

workflow BLAST_REFSEQ_ITS_WORKFLOW {

    take:
    taxonomy_inputs

    main:
    scripts_dir = file(
        "${projectDir}/bin",
        checkIfExists: true
    )

    export_input = taxonomy_inputs.map { meta, repseq_qza, taxonomy_tsv ->
        tuple(meta, repseq_qza)
    }

    taxonomy_lookup = taxonomy_inputs.map { meta, repseq_qza, taxonomy_tsv ->

        def bridge_key = "${meta.method}__${meta.read_mode}__${meta.reference_id}"

        tuple(
            bridge_key,
            meta,
            taxonomy_tsv
        )
    }

    QIIME_EXPORT_REPSEQ(export_input)

    repseq_lookup = QIIME_EXPORT_REPSEQ.out.repseq_fasta.map { meta, repseq_fasta ->

        def bridge_key = "${meta.method}__${meta.read_mode}__${meta.reference_id}"

        tuple(
            bridge_key,
            meta,
            repseq_fasta
        )
    }

    blast_input = repseq_lookup
        .join(taxonomy_lookup)
        .map {
            bridge_key,
            repseq_meta,
            repseq_fasta,
            taxonomy_meta,
            taxonomy_tsv ->

            tuple(
                taxonomy_meta,
                repseq_fasta,
                taxonomy_tsv,
                scripts_dir
            )
        }

    BLAST_REFSEQ_RECONCILE(blast_input)

    QIIME_IMPORT_RECONCILED_TAXONOMY(
        BLAST_REFSEQ_RECONCILE.out.qiime_input
    )

    emit:
    taxonomy_blast_results = QIIME_IMPORT_RECONCILED_TAXONOMY.out.taxonomy_qza
    taxonomy_blast_tables = BLAST_REFSEQ_RECONCILE.out.taxonomy_final
    taxonomy_blast_evidence = BLAST_REFSEQ_RECONCILE.out.evidence
    taxonomy_blast_changed = BLAST_REFSEQ_RECONCILE.out.changed
    taxonomy_blast_report = BLAST_REFSEQ_RECONCILE.out.report
}
