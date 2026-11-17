## Project

`dcqc.nf` holds the pipeline's main workflow (`DCQC`). `main.nf`'s unnamed entry `workflow {}` block runs the startup checks, builds `ch_input`, and passes it to the `SAGE_DCQC` wrapper, which calls `DCQC(ch_input)`. See root `CLAUDE.md` for the overall project and version constraints.

## Architecture

Startup in `main.nf` (before `DCQC` runs): `--help` / `--version` handling, `nf-schema` `validateParameters()` (when `params.validate_params` is true; this also checks the samplesheet against `assets/schema_input.json`), `paramsSummaryLog`, config/conda/AWS checks, a check that `params.input` is set, and the `workflow.onComplete` email/summary handler.

Data flow through `DCQC`:

```
take: ch_input            (= file(params.input, checkIfExists: true), from main.nf)
  → PREPARE_TESTS        (subworkflows/local/prepare_tests.nf)
  → INTERNAL_TESTS.mix(EXTERNAL_TESTS)   (grouped by target_id)
  → PREPARE_REPORTS       (subworkflows/local/prepare_reports.nf)
  → published output.csv
```

`ch_input` is a single file value, not a channel of rows — there is no samplesheet-check subworkflow before `PREPARE_TESTS`. Full row-level validation happens inside `dcqc create-targets` (called from `PREPARE_TESTS`).

## Conventions

- Keep pipeline-level setup (validation, summary, completion handlers) in the entry `workflow {}` block of `main.nf`, not at the top level of `dcqc.nf`. The strict syntax does not allow top-level executable code, and `DCQC` must receive its inputs through `take:`.
- `CUSTOM_DUMPSOFTWAREVERSIONS` is imported in this file but never invoked in the `DCQC` workflow body — a dead import. Don't assume version reporting works end-to-end just because the import is present.
