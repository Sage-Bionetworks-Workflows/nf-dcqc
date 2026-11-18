## Project

nf-dcqc (`sage/dcqc`) is a Nextflow DSL2 pipeline that runs Data Curator QC (DCQC) checks against files staged from Synapse (imaging, sequencing, tabular data). All QC logic lives in the external `ghcr.io/sage-bionetworks-workflows/py-dcqc` container (a separate repo) — this repo only orchestrates that CLI. The pipeline was bootstrapped from a ~2022 nf-core rnaseq-style template and repurposed for QC; some genomics-flavored template leftovers (`--genome`, FASTQ docs) are unused cruft, not active features.

## Stack

- Nextflow DSL2. The supported Nextflow range is declared in `manifest.nextflowVersion` (`nextflow.config`) — read it there for the exact bound. There is a lower bound only (no upper cap): the code was migrated to work with Nextflow's strict config parser (default since 26.04.0).
- Parameter validation, help text and the parameter summary come from the `nf-schema` plugin (version pinned in the `plugins {}` block of `nextflow.config`), called from the entry `workflow {}` block in `main.nf` (`validateParameters`, `paramsSummaryLog`, `paramsSummaryMap`). The `--help <param>` and `--helpFull` messages come from the `validation { help { ... } }` block in `nextflow.config`. That block sees `--help` with no value as the string `'true'` and fails silently, so `main.nf` calls `paramsHelp()` as a fallback for that case. Do not declare a `help` param.
- Resource caps use the native `process.resourceLimits` in `conf/base.config` (fed by `params.max_cpus` / `max_memory` / `max_time`), not the old `check_max()` function.
- Groovy: `lib/*.groovy`, the remaining nf-core template helper classes (see `lib/CLAUDE.md`).
- Python: `bin/check_samplesheet.py` (Black line-length 120, isort black profile via `pyproject.toml`) — currently dead code, not invoked anywhere (see Anti-Patterns).
- Execution profiles: `docker`, `singularity`, `podman`, `shifter`, `charliecloud`, `conda`, `mamba`, `debug`, `arm`, `gitpod`, `local`, `test`, `test_full`. `conda`/`mamba` are template leftovers: no module has a Conda environment, so they work only if `dcqc` is on the host PATH. `local` swaps the `py-dcqc` image for a locally built `dcqc` image. `conf/test_tiff.config` is not wired to any profile and points at a missing `testdata/input_tiff.csv` (dead).

## Commands

```bash
# Verify the installed Nextflow satisfies manifest.nextflowVersion before running anything below
# (lower bound only — see nextflow.config for the exact value)
nextflow -version

# Set the Synapse credential once per machine (never do this on the user's behalf)
nextflow secrets set SYNAPSE_AUTH_TOKEN <token>

# Run the pipeline against the bundled test dataset
nextflow run . -profile test,docker --outdir ./results

# Run the larger integration test dataset (inferred from conf/test_full.config; not wired into CI)
nextflow run . -profile test_full,docker --outdir <outdir>  # inferred

# Lint (nf-core pipeline conventions)
nf-core pipelines lint --dir . --markdown lint_results.md

# Formatting checks (all run in .github/workflows/linting.yml)
prettier --check .
editorconfig-checker
# Black is run via the psf/black@stable GitHub Action, equivalent to: black .
```

nf-test (`nf-test.config`, tests in `tests/`) checks only the help flags: each help flag must print the help once and stop the run. These tests set no `--input`, so they need no container or Synapse token. Run them with `nf-test test`. CI runs them too (the `nf-test` job in `.github/workflows/ci.yml`, nf-test 0.9.5). nf-test runs Nextflow with `-quiet`, so `log.info` output is only in `.nf-test/tests/<hash>/meta/nextflow.log`, not in `workflow.stdout`. The QC logic is checked only by running the `test`/`test_full` profiles end-to-end.

## Data Models

- **Real input format**: a CSV samplesheet with columns `url` (a `syn://` Synapse URI, required), `file_type` (one of TXT/TIFF/OME-TIFF/HDF5/TSV/CSV/JSON/JSON-LD/BAM/FASTQ), `md5_checksum`, and optionally `test`. See `testdata/input_full.csv` / `testdata/input_txt.csv` for the actual shape.
- **`assets/schema_input.json`** describes this format (`url` required; `file_type`, `md5_checksum` optional; extra columns such as `test` are allowed). `nextflow_schema.json` points `--input`'s `schema` at it, so `nf-schema`'s `validateParameters()` checks the samplesheet at startup. This check is shallow (no spaces, `url` present); the full per-row validation still happens inside the external `dcqc create-targets` CLI call.
- **`docs/usage.md` and `docs/output.md` are stale** — they still describe the old rnaseq-template FASTQ samplesheet (`sample`, `fastq_1`, `fastq_2`) and FastQC/MultiQC outputs. Do not treat them as ground truth. The root `README.md` has the current input and output description.
- **Pipeline data flow** (see `workflows/CLAUDE.md` and `subworkflows/local/CLAUDE.md` for detail): samplesheet CSV → `dcqc create-targets` → per-target target JSON → `dcqc create-tests` → per-test JSON, branched into internal/external (external tests first go through `dcqc create-process` and a `RUN_PROCESS` task in the test's own container) → `dcqc compute-test` → per-target suite (`dcqc create-suite`) → combined `suites.json` (`dcqc combine-suites`) → `dcqc update-csv` → published `output.csv` (`suites.json` is also published).
- `params.required_tests` / `params.skipped_tests` are comma-separated test-name lists (regex-validated) passed as CLI args via `conf/modules.config` `ext.args`, controlling which DCQC tests gate pass/fail per target.

## Conventions

- All `dcqc`-labelled processes share one container and one secret, set centrally via the `withLabel:dcqc` block in `conf/base.config` — never add per-process `container`/`secret` directives, they would fight the centralized override. The one exception is `RUN_PROCESS`: it has no `dcqc` label and takes its container, CPUs and memory from `dcqc create-process` JSON at runtime.
- Version reporting is meant to go through the single `CUSTOM_DUMPSOFTWAREVERSIONS` nf-core module; `modules/local/*` processes do not emit their own `versions.yml` (a deliberate deviation from the usual nf-core module convention). Currently no version report is produced: `CUSTOM_DUMPSOFTWAREVERSIONS` is imported in `workflows/dcqc.nf` but never called, and `modules/local/dcqc_version.nf` is never included.
- Keep config and script code compatible with the strict config parser / strict syntax: no top-level `def` functions or `try`/`catch` in `nextflow.config`, declare closure-local variables with `def` (e.g. `def parsed = Utils.parseJson(...)` in subworkflows), no top-level executable code (only `include`s and definitions) outside `workflow {}` blocks in `.nf` files, and use `workflow.onComplete = { ... }` inside the entry workflow rather than a top-level `workflow.onComplete { }` handler.
- `nextflow_schema.json` and `assets/schema_input.json` use JSON Schema draft 2020-12 with `$defs` (required by `nf-schema`). New parameters must be added to `nextflow_schema.json` under the matching `$defs` group.

## Constraints

- **Never set, request, or hardcode `SYNAPSE_AUTH_TOKEN`.** It is a per-machine credential the user sets themselves via `nextflow secrets set` — treat it as entirely out of scope to touch.
- **Do not add an upper cap to `manifest.nextflowVersion` or lower the minimum below the `nf-schema` plugin's requirement** without a confirmed reason. `main` previously capped the range (PR #25) because the pre-migration code failed under the strict parser; that cap is obsolete for the migrated code.
- CI (`.github/workflows/ci.yml`) runs the `test` profile and nf-test over an `NXF_VER` matrix: the declared lower bound (25.10.0, the minimum for `nf-schema` 2.7.2), 26.04.0 (the Seqera Platform version) and `latest-everything` — check that file for the exact values. A green `latest-everything` run is the evidence that the "no upper cap" claim is still true; if it fails, investigate before you change the manifest.

## Anti-Patterns — Do NOT

- Do NOT reintroduce `check_max()`, `lib/NfcoreSchema.groovy`, `lib/WorkflowMain.groovy`, or the draft-07 `definitions` schema layout. They were removed in the `nf-schema` migration (commit `5c8b5be`, PR #22) and do not work with the strict config parser.
- Do NOT use the earlier reverted migration attempt (commit `8b32ac9`, reverted in `7883a67`) as a reference for the current code. It hit Nextflow bugs nextflow-io/nextflow#5261 and #804; read PR #22's description for the pitfalls if a related problem comes back.
- Do NOT trust `bin/check_samplesheet.py`, `docs/usage.md`, `docs/output.md` or `assets/samplesheet.csv` as reflecting the real input or output — they still describe the old rnaseq FASTQ samplesheet and FastQC/MultiQC outputs; `check_samplesheet.py` is not invoked anywhere in `workflows/` or `subworkflows/` (dead code).
- Do NOT assume `modules/nf-core/fastqc` or `modules/nf-core/multiqc` run — they're installed in `modules.json` but never `include`d or called in `workflows/dcqc.nf` (dead vendored code left from the rnaseq template).
- Do NOT add `--genome`/genome-reference logic — it's leftover rnaseq-template cruft; `lib/WorkflowDcqc.groovy`'s genome-check code is already commented out and dead.

## Related Systems

- `ghcr.io/sage-bionetworks-workflows/py-dcqc` — the actual QC engine, a separate repo/container. Every `dcqc <subcommand>` call in `modules/local/*.nf` depends on its CLI contract; coordinate changes there.
- Sage's Seqera Platform (Tower) instance — the production runner. It must run Nextflow 25.10.0 or later, because `nf-schema` 2.7.2 needs that version. CI labels 26.04.0 as the Seqera version; confirm against the instance if this matters. The instance must be able to download the `nf-schema` plugin.
- Jira DPE-1808 and GitHub PR #22 ("[DPE-1808] Updated workflow to work with newer versions of Nextflow", branch `DPE-1808`) — the `nf-schema` / strict-parser migration this code is based on. PR #25 ("Cap Nextflow version at 25.10.0", merged to `main`) was the stopgap before this migration; PR #22 replaces that cap with an open-ended range. PR #24 ("Fix linting issues") reverted a draft 2020-12 schema change because the legacy validator could not read it — that reason no longer applies after the migration.
