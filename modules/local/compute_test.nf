process COMPUTE_TEST {
    tag "$target_id"
    label 'process_single'
    label 'dcqc'

    input:
    tuple val(target_id), path(test_json), path(staged_file), path("std_out.txt"), path("std_err.txt"), path("exit_code.txt")

    output:
    tuple val(target_id), path("${test_json.baseName}.computed.json")

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    dcqc compute-test "${test_json}" "${test_json.baseName}.computed.json"
    """
}
