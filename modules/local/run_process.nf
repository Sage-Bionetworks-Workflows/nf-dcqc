process RUN_PROCESS {
    tag "$target_id"
    container "${container}"
    cpus "${cpus}"
    memory "${memory}"

    input:
    tuple val(target_id), path(test_json), path(staged_file), val(container), val(cpus), val(memory), val(command)

    output:
    tuple val(target_id), path(test_json), path(staged_file), path("std_out.txt"), path("std_err.txt"), path("exit_code.txt")

    when:
    task.ext.when == null || task.ext.when

    script:
    """
    ( (${command}) > "std_out.txt" 2> "std_err.txt"; echo \$? > "exit_code.txt" ) || true
    """
}
