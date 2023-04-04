process CREATE_TESTS {
    tag "$target_id"
    label 'process_single'
    label 'dcqc'

    input:
    tuple val(target_id), path(target_json)

    output:
    tuple val(target_id), path("tests/*")

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    dcqc create-tests ${args} "${target_json}" tests/
    """
}
