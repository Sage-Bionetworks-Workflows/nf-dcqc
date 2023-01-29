include { COMPUTE_TEST } from '../../modules/local/compute_test'

workflow INTERNAL_TESTS {
    take:
    ch_tests  // channel: [ val(target_id), path(test_json), path(staged_file) ]

    main:
    ch_tests_extra =
        ch_tests
        | map { target_id, test_json, staged_file ->
            dummy_file = file("${projectDir}/testdata/dummy.txt")
            [ target_id, test_json, staged_file, dummy_file, dummy_file, dummy_file ]
        }

    ch_tests_computed = COMPUTE_TEST(ch_tests_extra)

    emit:
    results = ch_tests_computed  // channel: [ val(target_id), path(result_json) ]
}
