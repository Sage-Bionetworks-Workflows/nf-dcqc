process DCQC_VERSION {
    label 'process_single'
    label 'dcqc'

    output:
    path "versions.yml"     , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        dcqc: \$(dcqc --version | sed 's/.*: //g')
    END_VERSIONS
    """
}
