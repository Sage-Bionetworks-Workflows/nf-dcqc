## Project

The remaining nf-core template Groovy helper classes, plus a vendored Joda-Time jar (`nfcore_external_java_deps.jar` — binary, don't open or edit). Parameter validation, help text and the parameter summary are no longer done here — they come from the `nf-schema` plugin, called in `main.nf`.

- `NfcoreTemplate.groovy` — called from the entry `workflow {}` block in `main.nf`: `version()` (for `--version`), `checkConfigProvided()`, `awsBatch()`, and, in `workflow.onComplete`, `email()`, `summary()` and `IM_notification()`. Also has logging helpers (`logColours()`, `dashedLine()`, `logo()`).
- `Utils.groovy` — `parseJson()` is used by `subworkflows/local/prepare_tests.nf` and `external_tests.nf` to read `dcqc` JSON output; `checkCondaChannels()` is called from `main.nf` for the `conda`/`mamba` profiles.
- `WorkflowDcqc.groovy` — `initialise()` is called from the `DCQC` workflow in `workflows/dcqc.nf`; also holds unused MultiQC helper methods.

## Constraints

- Do NOT add back `WorkflowMain.groovy` or `NfcoreSchema.groovy`. They were removed in the `nf-schema` migration (commit `5c8b5be`, PR #22). Use the `nf-schema` plugin functions (`validateParameters`, `paramsHelp`, `paramsSummaryLog`, `paramsSummaryMap`) in `main.nf` instead.
- `email()` and `IM_notification()` take the `summary_params` map produced by `nf-schema`'s `paramsSummaryMap(workflow)`. If you change how that map is built, keep its group → param → value shape.

## Anti-Patterns — Do NOT

- Do NOT treat `WorkflowDcqc.groovy`'s `initialise()` as doing real work — it's an empty stub, with genome-check logic already commented out (leftover from the rnaseq template). Don't build new logic on top of it assuming it validates anything.
