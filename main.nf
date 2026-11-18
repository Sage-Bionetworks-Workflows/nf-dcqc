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

include { paramsHelp; validateParameters; paramsSummaryLog; paramsSummaryMap } from 'plugin/nf-schema'
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

    // Fallback for '--help' with no value. The validation.help config block
    // handles '--help <param>' and '--helpFull', but it sees '--help' alone as
    // the string 'true' and looks for a param with that name. nf-schema then
    // writes the error only to the debug log, and the run continues to here.
    // nf-schema also does not stop the run after '--help <param>', so the check
    // must accept only true or 'true'. A param name such as 'input' is also
    // true in Groovy, and would print the full list after the param detail.
    // paramsHelp() gets the command from the validation.help config.
    if (params.containsKey('help') && params.help.toString() == 'true') {
        log.info paramsHelp()
        exit 0
    }

    // On Nextflow 26+, boolean flags from the command line arrive as strings
    // ('--validate_params false' gives 'false', which is true in Groovy).
    // toString().toBoolean() gives the correct value for strings and booleans.

    // Print workflow version and exit on --version
    if (params.version.toString().toBoolean()) {
        log.info "${workflow.manifest.name} ${NfcoreTemplate.version(workflow)}"
        exit 0
    }

    // Validate workflow parameters via the JSON schema
    if (params.validate_params.toString().toBoolean()) {
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
        error "Please provide an input samplesheet to the pipeline e.g. '--input samplesheet.csv'"
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
