## Project

Thin Nextflow process wrappers around the external `dcqc` CLI (from the `py-dcqc` container). Most modules map to one `dcqc` subcommand: `create-targets`, `create-tests`, `create-process`, `compute-test`, `create-suite`, `combine-suites`, `update-csv`. Two exceptions: `run_process.nf` runs the `${command}` string built by `create_process.nf` directly, not a fixed subcommand, and `dcqc_version.nf` calls `dcqc --version`, a flag rather than a subcommand.

## Conventions

- The actual QC logic lives in the `py-dcqc` repo/container, not here — keep these modules as thin wrappers and don't add business logic to them.
- Every process here carries `label 'dcqc'` in addition to a size label. `label 'dcqc'` centrally sets the container (`ghcr.io/sage-bionetworks-workflows/py-dcqc:latest`) and the `SYNAPSE_AUTH_TOKEN` secret via the `withLabel:dcqc` block in `conf/base.config`. Never add `container`/`secret` directives directly on these processes — it would fight the centralized override.
- No per-module `versions.yml` emission (unlike typical nf-core modules). `dcqc_version.nf` reports the `py-dcqc` container's own version, which is a separate concern from the pipeline-wide version report handled by `CUSTOM_DUMPSOFTWAREVERSIONS`.
- `params.required_tests` / `params.skipped_tests` flow into `CREATE_TESTS`/`CREATE_SUITE` via `ext.args` in `conf/modules.config`, not via logic inside these module files. Add new CLI flags the same way.
