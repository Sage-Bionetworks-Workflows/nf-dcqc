include { CREATE_PROCESS } from '../../modules/local/create_process'
include { RUN_PROCESS } from '../../modules/local/run_process'
include { COMPUTE_TEST } from '../../modules/local/compute_test'

workflow EXTERNAL_TESTS {
    take:
    ch_tests  // channel: [ val(target_id), path(test_json) ]

    main:
    ch_processes_raw = CREATE_PROCESS(ch_tests)

    ch_processes =
        ch_processes_raw
        | map { target_id, test, staged, cmd ->
            parsed = Utils.parseJson(cmd)
            [ target_id, test, staged, parsed.container, parsed.cpus, parsed.memory, parsed.command ]
        }

    ch_process_outputs = RUN_PROCESS(ch_processes)

    ch_tests_computed = COMPUTE_TEST(ch_process_outputs)

    emit:
    results = ch_tests_computed  // channel: [ val(target_id), path(result_json) ]
}
