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
    def args = task.ext.args ?: ''
    """
    dcqc create-suite ${args} "${target_id}.suite.json" *.json
    """
}
