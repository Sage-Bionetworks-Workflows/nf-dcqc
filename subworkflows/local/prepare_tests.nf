include { CREATE_TARGETS } from '../../modules/local/create_targets'
include { STAGE_TARGET } from '../../modules/local/stage_target'
include { CREATE_TESTS } from '../../modules/local/create_tests'

workflow PREPARE_TESTS {
    take:
    ch_input  // file: CSV list of QC targets

    main:
    ch_targets_raw = CREATE_TARGETS(ch_input)

    ch_targets =
        ch_targets_raw
        | flatten
        | map {
            parsed = Utils.parseJson(it)
            [ parsed.id, it ]
        }

    ch_targets_staged = STAGE_TARGET(ch_targets)

    ch_tests_raw = CREATE_TESTS(ch_targets_staged)

    ch_tests =
        ch_tests_raw
        | transpose
        | map { target_id, test, staged ->
            parsed = Utils.parseJson(test)
            [ parsed.is_external_test, [ target_id, test, staged ] ]
        }

    ch_tests_split =
        ch_tests
        | branch { is_external_test, it ->
            internal: !is_external_test
                return it
            external: is_external_test
                return it
        }

    emit:
    internal = ch_tests_split.internal  // channel: [ val(target_id), path(test_json), path(staged_file) ]
    external = ch_tests_split.external  // channel: [ val(target_id), path(test_json), path(staged_file) ]
}
