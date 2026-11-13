include { QIIME_PHYLOGENY_FASTTREE } from '../../modules/local/qiime_phylogeny'

workflow QIIME_PHYLOGENY {

    take:
    dada2_results

    main:
    repseq_inputs = dada2_results.map { meta, table, repseq, stats ->
        tuple(meta, repseq)
    }

    QIIME_PHYLOGENY_FASTTREE(repseq_inputs)

    emit:
    phylogeny_results = QIIME_PHYLOGENY_FASTTREE.out.phylogeny_results
    versions = QIIME_PHYLOGENY_FASTTREE.out.versions
}
