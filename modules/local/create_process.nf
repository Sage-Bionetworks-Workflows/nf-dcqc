process CREATE_PROCESS {
    tag "$target_id"
    label 'process_single'
    label 'dcqc'

    input:
    tuple val(target_id), path(test_json)

    output:
    tuple val(target_id), path(test_json), path("dcqc-staged-*"), path("${test_json.baseName}.process.json")

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    export TMPDIR="./"
    dcqc create-process "${test_json}" "${test_json.baseName}.process.json"
    """
}
