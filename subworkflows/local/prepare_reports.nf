include { CREATE_SUITE } from '../../modules/local/create_suite'
include { COMBINE_SUITES } from '../../modules/local/combine_suites'

workflow PREPARE_REPORTS {
    take:
    ch_tests_computed  // channel: [ val(target_id), path(result_json) ]

    main:
    ch_tests_by_target = ch_tests_computed.groupTuple()

    ch_suites = CREATE_SUITE(ch_tests_by_target)

    ch_suites_collected = ch_suites.collect()

    ch_summary_report = COMBINE_SUITES(ch_suites_collected)

    emit:
    summary = ch_summary_report  // channel: path(summary_json)
}
