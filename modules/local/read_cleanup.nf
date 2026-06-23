process READ_CLEANUP_PE {

    tag "${meta.id}"
    label 'read_cleanup'

    container "${params.cutadapt_sif}"

    publishDir "${params.outdir}/read_cleanup", mode: 'copy', overwrite: true

    input:
    tuple val(meta), path(read1), path(read2)

    output:
    tuple val(meta),
          path("${meta.id}.R1.clean.fastq.gz"),
          path("${meta.id}.R2.clean.fastq.gz"),
          emit: cleaned_reads

    path "${meta.id}.cutadapt.json", emit: json
    path "${meta.id}.cutadapt.log",  emit: cutadapt_log
    path "versions.yml",              emit: versions

    script:
    def adapter_args = params.adapter_trim ?
        "-a '${params.adapter_f}' -A '${params.adapter_r}'" : ''

    def poly_g = "G{${params.poly_g_min_run}}"
    def poly_g_args = params.poly_g_trim ?
        "-a '${poly_g}' -A '${poly_g}'" : ''

    def quality_args = params.quality_trim ?
        "-q ${params.quality_cutoff},${params.quality_cutoff}" : ''

    def min_length_args = params.apply_min_length ?
        "--minimum-length ${params.min_length}" : ''

    """
    cutadapt \
      --cores ${task.cpus} \
      ${adapter_args} \
      ${poly_g_args} \
      ${quality_args} \
      ${min_length_args} \
      --json ${meta.id}.cutadapt.json \
      -o ${meta.id}.R1.clean.fastq.gz \
      -p ${meta.id}.R2.clean.fastq.gz \
      ${read1} \
      ${read2} \
      > ${meta.id}.cutadapt.log

    cat <<-END_VERSIONS > versions.yml
    "READ_CLEANUP_PE":
      cutadapt: \$(cutadapt --version)
    END_VERSIONS
    """
}
