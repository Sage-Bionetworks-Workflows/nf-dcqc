process UPDATE_INPUT {
    label 'process_single'
    label 'dcqc'

    input:
    path suites_file
    path input_csv

    output:
    path "output.csv"

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    dcqc update-csv ${suites_file} ${input_csv} "output.csv"
    """
}
