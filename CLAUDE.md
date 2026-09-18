## Project

nf-dcqc (`sage/dcqc`) is a Nextflow DSL2 pipeline that runs Data Curator QC (DCQC) checks against files staged from Synapse (imaging, sequencing, tabular data). All QC logic lives in the external `ghcr.io/sage-bionetworks-workflows/py-dcqc` container (a separate repo) — this repo only orchestrates that CLI. The pipeline was bootstrapped from a ~2022 nf-core rnaseq-style template and repurposed for QC; some genomics-flavored template leftovers (`--genome`, FASTQ schemas) are unused cruft, not active features.

## Stack

- Nextflow DSL2, `manifest.nextflowVersion = '!>=22.10.4,<=25.10.0'` — the upper cap is enforced in the manifest itself, not just a practical limit (see Constraints).
- Groovy: `lib/*.groovy`, standard nf-core template helper classes.
- Python: `bin/check_samplesheet.py` (Black line-length 120, isort black profile via `pyproject.toml`) — currently dead code, not invoked anywhere (see Anti-Patterns).
- Execution profiles: `docker`, `singularity`, `podman`, `shifter`, `charliecloud`, `conda`, `mamba`, `debug`, `arm`, `gitpod`, `local`, `test`, `test_full`.

## Commands

```bash
# Verify the installed Nextflow is within the supported range before running anything below
# (must be >=22.10.4 and <=25.10.0 — see Constraints; 26.x+ breaks this pipeline)
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

There is no unit test framework (no nf-test); correctness is checked only by running the `test`/`test_full` profiles end-to-end.

## Data Models

- **Real input format**: a CSV samplesheet with columns `url` (a `syn://` Synapse URI, required), `file_type` (one of TXT/TIFF/OME-TIFF/HDF5/TSV/CSV/JSON/JSON-LD/BAM/FASTQ), `md5_checksum`, and optionally `test`. See `testdata/input_full.csv` / `testdata/input_txt.csv` for the actual shape.
- **`assets/schema_input.json` and `docs/usage.md` are stale** — they still describe the old rnaseq-template FASTQ samplesheet (`sample`, `fastq_1`, `fastq_2`). `nextflow_schema.json` still points `--input`'s schema at this stale file. Real per-row validation happens inside the external `dcqc create-targets` CLI call, not in this repo. Do not treat the JSON schema files as ground truth for the input format.
- **Pipeline data flow** (see `workflows/CLAUDE.md` and `subworkflows/local/CLAUDE.md` for detail): samplesheet CSV → `dcqc create-targets` → per-target target JSON → `dcqc create-tests` → per-test JSON, branched into internal/external → `dcqc compute-test` → per-target suite (`dcqc create-suite`) → combined `suites.json` (`dcqc combine-suites`) → `dcqc update-csv` → published `output.csv`.
- `params.required_tests` / `params.skipped_tests` are comma-separated test-name lists (regex-validated) passed as CLI args via `conf/modules.config` `ext.args`, controlling which DCQC tests gate pass/fail per target.

## Conventions

- All `dcqc`-labelled processes share one container and one secret, set centrally via the `withLabel:dcqc` block in `conf/base.config` — never add per-process `container`/`secret` directives, they would fight the centralized override.
- Version reporting only happens through the single `CUSTOM_DUMPSOFTWAREVERSIONS` nf-core module; individual `modules/local/*` processes do not emit their own `versions.yml` (a deliberate deviation from the usual nf-core module convention).

## Constraints

- **Never raise `manifest.nextflowVersion` past `25.10.0` or otherwise assume Nextflow ≥26.04 is supported.** Nextflow's strict config parser (default since 26.04.0) rejects the bare `def check_max(obj, type) { ... }` function at `nextflow.config:184` and other 2022-era Groovy patterns throughout `lib/` and `workflows/dcqc.nf`. Because: a full migration was attempted (commit `8b32ac9`), hit two confirmed unfixed Nextflow bugs (nextflow-io/nextflow#5261, #804), and was reverted the same day (commit `7883a67`) as incomplete/unverified. Tracked in Jira DPE-1808 and still-open PR #22. If asked to attempt this migration again, read PR #22's description and `git show 8b32ac9` first — they map the exact pitfalls.
- **Never set, request, or hardcode `SYNAPSE_AUTH_TOKEN`.** It is a per-machine credential the user sets themselves via `nextflow secrets set` — treat it as entirely out of scope to touch.
- CI (`.github/workflows/ci.yml`) currently tests `NXF_VER: ["22.10.4", "25.10.0"]` — both ends of the supported range set by the manifest cap. A green CI run now does confirm the pipeline works within that range, but it says nothing about Nextflow versions above 25.10.0.

## Anti-Patterns — Do NOT

- Do NOT migrate `check_max()` / `lib/NfcoreSchema.groovy` / `lib/WorkflowMain.groovy` to the newer `nf-schema` plugin pattern casually — a full attempt at exactly this (PR #22, commit `8b32ac9`) hit two confirmed Nextflow bugs and was reverted as incomplete the same day (evidence: commit `7883a67`, Confluence DPE-1808).
- Do NOT trust `bin/check_samplesheet.py` or `assets/schema_input.json` as reflecting the real input format — they still describe the old rnaseq FASTQ samplesheet, while the pipeline's actual input is a Synapse-URI manifest; `check_samplesheet.py` is not invoked anywhere in `workflows/` or `subworkflows/` (dead code).
- Do NOT assume `modules/nf-core/fastqc` or `modules/nf-core/multiqc` run — they're installed in `modules.json` but never `include`d or called in `workflows/dcqc.nf` (dead vendored code left from the rnaseq template).
- Do NOT add `--genome`/genome-reference logic — it's leftover rnaseq-template cruft; `lib/WorkflowDcqc.groovy`'s genome-check code is already commented out and dead.

## Related Systems

- `ghcr.io/sage-bionetworks-workflows/py-dcqc` — the actual QC engine, a separate repo/container. Every `dcqc <subcommand>` call in `modules/local/*.nf` depends on its CLI contract; coordinate changes there.
- Sage's Seqera Platform (Tower) instance — the production runner, currently on a Nextflow release implying ~25.10.2 client version. This is the practical version ceiling behind the constraint above; check for updates to that instance before attempting a Nextflow-version migration here.
- Jira DPE-1808, GitHub PR #22 ("Updated workflow to work with newer versions of Nextflow"), PR #25 ("Cap Nextflow version at 25.10.0") — active, unresolved threads on the version-compatibility problem. Check these before touching `nextflow.config`, `main.nf`, or `lib/`.
