process CREATE_SUITE {
    tag "$target_id"
    label 'process_single'
    label 'dcqc'

    input:
    tuple val(target_id), path(test_results)

    output:
    path("${target_id}.suite.json")

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    dcqc create-suite "${target_id}.suite.json" *.json
    """
}
