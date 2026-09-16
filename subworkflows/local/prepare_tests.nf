include { CREATE_TARGETS } from '../../modules/local/create_targets'
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

    ch_tests_raw = CREATE_TESTS(ch_targets)

    ch_tests =
        ch_tests_raw
        | transpose
        | map { target_id, test ->
            parsed = Utils.parseJson(test)
            [ parsed.is_external_test, [ target_id, test ] ]
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
    internal = ch_tests_split.internal  // channel: [ val(target_id), path(test_json) ]
    external = ch_tests_split.external  // channel: [ val(target_id), path(test_json) ]
}
