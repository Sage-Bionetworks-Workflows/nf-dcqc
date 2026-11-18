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

    // Stop the run after any help flag. nf-schema (the validation.help config
    // block) prints the help, but it does not stop the run. Without this exit,
    // the run continues to validateParameters() and can start the pipeline.
    //
    // nf-schema prints the help for '--help <param>', '--helpFull', and for
    // 'help: true' from a params file (Seqera Platform launches use this). It
    // does not print the help for '--help' alone on the CLI: that value is the
    // string 'true', and nf-schema looks for a param with that name. Only that
    // case needs the paramsHelp() fallback. If the fallback also ran for the
    // boolean true, the help would print twice.
    // tests/main.nf.test checks all of these cases.
    def help_flags = ['help', 'helpFull', 'showHidden']
    if (help_flags.any { params.containsKey(it) && params[it].toString() != 'false' }) {
        if (params.help instanceof String && params.help == 'true') {
            log.info paramsHelp()
        }
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
