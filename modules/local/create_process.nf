process CREATE_PROCESS {
    tag "$target_id"
    label 'process_single'
    label 'dcqc'

    input:
    tuple val(target_id), path(test_json), path(staged_file)

    output:
    tuple val(target_id), path(test_json), path(staged_file), path("${test_json.baseName}.process.json")

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    dcqc create-process "${test_json}" "${test_json.baseName}.process.json"
    """
}
