nextflow.enable.dsl = 2

include {
    QIIME_EXPORT_REPSEQ
    BLAST_REFSEQ_ITS
    QIIME_IMPORT_BLAST_TAXONOMY
} from '../modules/local/blast_refseq_its'


workflow {

    sample_meta = [
        method       : params.method,
        read_mode    : params.read_mode,
        reference_id : params.reference_id
    ]

    repseq_input = Channel.of(
        tuple(
            sample_meta,
            file(params.repseq_qza, checkIfExists: true)
        )
    )

    QIIME_EXPORT_REPSEQ(repseq_input)

    taxonomy_file = file(params.taxonomy_tsv, checkIfExists: true)
    scripts_folder = file(params.scripts_dir, checkIfExists: true)

    blast_input = QIIME_EXPORT_REPSEQ.out.repseq_fasta.map {
        m, repseq_fasta ->
        tuple(
            m,
            repseq_fasta,
            taxonomy_file,
            scripts_folder
        )
    }

    BLAST_REFSEQ_ITS(blast_input)

    QIIME_IMPORT_BLAST_TAXONOMY(
        BLAST_REFSEQ_ITS.out.qiime_input
    )
}
