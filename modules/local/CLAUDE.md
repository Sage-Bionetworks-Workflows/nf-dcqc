## Project

Thin Nextflow process wrappers around the external `dcqc` CLI (from the `py-dcqc` container). Most modules map to one `dcqc` subcommand: `create-targets`, `create-tests`, `create-process`, `compute-test`, `create-suite`, `combine-suites`, `update-csv`. Two exceptions: `run_process.nf` runs the `${command}` string built by `create_process.nf` directly, not a fixed subcommand, and `dcqc_version.nf` calls `dcqc --version`, a flag rather than a subcommand.

## Conventions

- The actual QC logic lives in the `py-dcqc` repo/container, not here — keep these modules as thin wrappers and don't add business logic to them.
- Every process here except `RUN_PROCESS` carries `label 'dcqc'` in addition to a size label. The `withLabel:dcqc` block in `conf/base.config` centrally sets the `py-dcqc` container (`ghcr.io/sage-bionetworks-workflows/py-dcqc`, pinned to a specific version tag — not `:latest`) and the `SYNAPSE_AUTH_TOKEN` secret for all of them. Never add `container`/`secret` directives directly on these processes — it would fight the centralized override. To change the image or its version, edit the tag in that `conf/base.config` block only — it's the single source of truth, so the exact tag is deliberately not restated here. The `local` profile (`conf/local.config`) overrides the same block to use a locally built `dcqc` image.
- `RUN_PROCESS` is the deliberate exception: it has no labels, and it sets `cpus`, `memory` and `container` from input values that `CREATE_PROCESS`'s JSON supplies at runtime (see `subworkflows/local/CLAUDE.md`). It does not get the `SYNAPSE_AUTH_TOKEN` secret — the file is already staged by `CREATE_PROCESS`. Do not add `label 'dcqc'` to it; that would replace the test's container with the `py-dcqc` one.
- No module emits `versions.yml`, except `dcqc_version.nf` (`DCQC_VERSION`). That module is not `include`d anywhere, so it never runs — it is dead code, like the uncalled `CUSTOM_DUMPSOFTWAREVERSIONS` (see `workflows/CLAUDE.md`).
- `params.required_tests` / `params.skipped_tests` flow into `CREATE_TESTS`/`CREATE_SUITE` via `ext.args` in `conf/modules.config`, not via logic inside these module files. Add new CLI flags the same way.
- Only `COMBINE_SUITES` (`suites.json`) and `UPDATE_INPUT` (`output.csv`) are published; their `publishDir` is set in `conf/modules.config`, not in the module files.
