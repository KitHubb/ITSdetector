include { QIIME_IMPORT_PE } from '../../modules/local/qiime_import'
include { QIIME_IMPORT_SE } from '../../modules/local/qiime_import'

workflow QIIME_IMPORT {

    take:
    pe_manifest
    r1_manifest

    main:
    // Import paired-end and R1-only artifacts in parallel.
    QIIME_IMPORT_PE(pe_manifest)
    QIIME_IMPORT_SE(r1_manifest)

    emit:
    demux_pe = QIIME_IMPORT_PE.out.demux
    demux_pe_qzv = QIIME_IMPORT_PE.out.summary

    demux_r1 = QIIME_IMPORT_SE.out.demux
    demux_r1_qzv = QIIME_IMPORT_SE.out.summary
}
