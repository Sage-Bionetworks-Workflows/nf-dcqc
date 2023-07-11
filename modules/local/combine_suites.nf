process COMBINE_SUITES {
    label 'process_low'
    label 'dcqc'

    input:
    path report_jsons

    output:
    path "suites.json"

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    dcqc combine-suites "suites.json" *.json
    """
}
