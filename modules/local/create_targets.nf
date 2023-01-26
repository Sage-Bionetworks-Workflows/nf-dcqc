process CREATE_TARGETS {
    label 'process_single'
    label 'dcqc'

    input:
    path input_csv

    output:
    path 'targets/*.json'

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    dcqc create-targets "${input_csv}" targets/
    """
}
