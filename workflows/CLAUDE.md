## Project

`dcqc.nf` is the pipeline's single entry workflow (`DCQC`), included by `main.nf`'s `SAGE_DCQC` wrapper. See root `CLAUDE.md` for the overall project and version constraints.

## Architecture

Data flow through `DCQC`:

```
ch_input = file(params.input)
  → PREPARE_TESTS        (subworkflows/local/prepare_tests.nf)
  → INTERNAL_TESTS.mix(EXTERNAL_TESTS)   (grouped by target_id)
  → PREPARE_REPORTS       (subworkflows/local/prepare_reports.nf)
  → published output.csv
```

`ch_input` is read directly as a file — there is no samplesheet-check subworkflow run before `PREPARE_TESTS`. Row-level validation happens inside `dcqc create-targets` (called from `PREPARE_TESTS`), not against `assets/schema_input.json` (that schema is stale — see root `CLAUDE.md`).

## Conventions

- `CUSTOM_DUMPSOFTWAREVERSIONS` is imported in this file but never invoked in the `DCQC` workflow body — a dead import. Don't assume version reporting works end-to-end just because the import is present.
