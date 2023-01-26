process CREATE_TESTS {
    tag "$target_id"
    label 'process_single'
    label 'dcqc'

    input:
    tuple val(target_id), path(target_json), path(staged_file)

    output:
    tuple val(target_id), path("tests/*"), path(staged_file)

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    dcqc create-tests "${target_json}" tests/
    """
}
