#!/usr/bin/env nextflow
/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    sage/dcqc
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    Github : https://github.com/sage/dcqc
----------------------------------------------------------------------------------------
*/

nextflow.enable.dsl = 2

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    GENOME PARAMETER VALUES
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

// params.fasta = getGenomeAttribute(params, 'fasta')

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    NAMED WORKFLOW FOR PIPELINE
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

include { validateParameters; paramsSummaryLog; paramsSummaryMap; paramsHelp } from 'plugin/nf-schema'
include { DCQC } from './workflows/dcqc'

//
// WORKFLOW: Run main sage/dcqc analysis pipeline
//
workflow SAGE_DCQC {

    take:
    ch_input

    main:
    DCQC (ch_input)
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    RUN ALL WORKFLOWS
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/

//
// WORKFLOW: Execute a single named workflow for the pipeline
// See: https://github.com/nf-core/rnaseq/issues/619
//
workflow {

    // Print help to screen if required
    if (params.help) {
        log.info paramsHelp("nextflow run ${workflow.manifest.name} --input samplesheet.csv -profile docker")
        System.exit(0)
    }

    // Print workflow version and exit on --version
    if (params.version) {
        log.info "${workflow.manifest.name} ${NfcoreTemplate.version(workflow)}"
        System.exit(0)
    }

    // Validate workflow parameters via the JSON schema
    if (params.validate_params) {
        validateParameters()
    }

    // Print parameter summary log to screen
    log.info paramsSummaryLog(workflow)

    // Check that a -profile or Nextflow config has been provided to run the pipeline
    NfcoreTemplate.checkConfigProvided(workflow, log)

    // Check that conda channels are set-up correctly
    if (workflow.profile.tokenize(',').intersect(['conda', 'mamba']).size() >= 1) {
        Utils.checkCondaChannels(log)
    }

    // Check AWS batch settings
    NfcoreTemplate.awsBatch(workflow, params)

    // Check input has been provided
    if (!params.input) {
        log.error "Please provide an input samplesheet to the pipeline e.g. '--input samplesheet.csv'"
        System.exit(1)
    }
    def ch_input = file(params.input, checkIfExists: true)

    // Info required for completion email and summary
    summary_params = paramsSummaryMap(workflow)
    def multiqc_report = []

    SAGE_DCQC (ch_input)

    workflow.onComplete = {
        if (params.email || params.email_on_fail) {
            NfcoreTemplate.email(workflow, params, summary_params, projectDir, log, multiqc_report)
        }
        NfcoreTemplate.summary(workflow, params, log)
        if (params.hook_url) {
            NfcoreTemplate.IM_notification(workflow, params, summary_params, projectDir, log)
        }
    }
}

/*
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
    THE END
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
*/
