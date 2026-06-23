process CLEANUP_QC_SUMMARY {

    tag "${params.run_label}"
    label 'read_cleanup'

    container "${params.cutadapt_sif}"

    publishDir "${params.outdir}/cleanup_qc", mode: 'copy', overwrite: true

    input:
    path cutadapt_json_files

    output:
    path "cleanup_qc_summary.tsv", emit: summary
    path "versions.yml", emit: versions

    script:
    """
    summarize_cutadapt_json.py \
      --profile "${params.run_label}" \
      --adapter-trim "${params.adapter_trim}" \
      --poly-g-trim "${params.poly_g_trim}" \
      --quality-trim "${params.quality_trim}" \
      --quality-cutoff "${params.quality_cutoff}" \
      --apply-min-length "${params.apply_min_length}" \
      --min-length "${params.min_length}" \
      --adapter-f "${params.adapter_f}" \
      --adapter-r "${params.adapter_r}" \
      --poly-g-min-run "${params.poly_g_min_run}" \
      --output cleanup_qc_summary.tsv \
      ${cutadapt_json_files}

    cat <<-END_VERSIONS > versions.yml
    "CLEANUP_QC_SUMMARY":
      python: \$(python --version 2>&1 | awk '{print \$2}')
    END_VERSIONS
    """
}
