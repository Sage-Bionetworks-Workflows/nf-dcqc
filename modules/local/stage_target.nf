process STAGE_TARGET {
    tag "$target_id"
    label 'process_single'
    label 'dcqc'

    input:
    tuple val(target_id), path(target_json)

    output:
    tuple val(target_id), path(target_json), path("staged/*")

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    dcqc stage-target "${target_json}" staged/
    """
}
