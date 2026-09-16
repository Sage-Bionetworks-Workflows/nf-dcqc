# nf-dcqc: Nextflow 26.04 compatibility

Tracking ticket: [DPE-1808](https://sagebionetworks.jira.com/browse/DPE-1808)

## Problem

nf-dcqc fails to start on Nextflow 26.04 and later.

Nextflow 26.04.0 turned on a new, strict parser by default. This parser
checks config files and script files more closely than before. It rejects
old Groovy code patterns. nf-dcqc uses an old nf-core template (roughly
2022-era). This template has several of these old patterns.

Command used to reproduce:

```
nextflow run . -profile test,docker,local --outdir ./results
```

## What has been done

### Fixed: `nextflow.config` parse errors

Three problems were found and fixed, one at a time, by re-running the
command above after each fix:

1. `nextflow.config` had a custom function, `check_max(obj, type)`. The
   strict parser does not allow functions in config files.
   - Removed the function.
   - Added the built-in `resourceLimits` process directive to
     `conf/base.config` instead. It uses the existing
     `params.max_cpus`, `params.max_memory`, `params.max_time` values.
   - Removed all `check_max(...)` calls in `conf/base.config`. Replaced
     them with plain values, matching the current nf-core template style.

2. `nextflow.config` had a `try/catch` block, used to load an optional
   external config file. The strict parser does not allow `try/catch` in
   config files.
   - Replaced it with a single conditional `includeConfig` line. This
     matches the current nf-core template pattern.

3. `nextflow.config` had a bare variable, `def trace_timestamp = ...`,
   used to name report files. The strict parser does not allow bare
   variable declarations in config files.
   - Moved the value into `params.trace_report_suffix`.
   - Updated the `timeline`, `report`, `trace`, and `dag` blocks to use
     `params.trace_report_suffix`.

Result: `nextflow.config` now parses without error under Nextflow 26.04.6.

Status: fixed locally in `conf/base.config` and `nextflow.config`. Not
yet committed.

### Compatibility note

`resourceLimits` needs Nextflow 24.04.0 or later. On an older Nextflow,
the pipeline will still run. But it prints a warning, and the
`--max_cpus`, `--max_memory`, `--max_time` flags silently stop working.

Open question: should `nextflowVersion` in the manifest (currently
`!>=22.10.4`) be raised to `!>=24.04.0`? This would turn the silent
behavior change into a clear error. Not yet decided.

### Fixed: `main.nf` / `workflows/dcqc.nf` script parse errors

The `main.nf` error from before was:

```
Error main.nf:26:1: Statements cannot be mixed with script declarations
WorkflowMain.initialise(workflow, params, log)
```

`main.nf` called `WorkflowMain.initialise(...)` as a bare statement,
outside any workflow block. The strict parser does not allow this.
Fixing this needed a larger migration than the config fixes. Each
change below was found and fixed one at a time, by re-running the
test command after each fix, same as the config fixes.

**Compatibility check done first:** looked up the actual
`nextflowVersion` requirement of each nf-schema plugin release (from
the plugin's own `build.gradle`/`gradle.properties` in its GitHub
repo, not from search-engine summaries, which gave inconsistent
answers). Chose nf-schema 2.4.2, which was believed at the time to
need Nextflow 24.04.0 or later. This lined up with the
`resourceLimits` floor already set in the earlier config fix, so the
pipeline seemed to have one clear minimum version instead of a silent
gap. Nextflow 25.04.8 (the version mentioned in discussion) satisfies
this floor.

**Correction (found later, from an actual run):** a test run on
Nextflow 24.04.0 failed to start, with this plugin error:

```
Failed requirement - Plugin nf-schema@2.4.2 requires Nextflow version >=24.10.0 (current 24.04.0)
```

So the real minimum Nextflow version for nf-schema 2.4.2 is 24.10.0,
not 24.04.0. The `build.gradle`/`gradle.properties` check done above
was wrong, or read the wrong value. The `resourceLimits` floor of
24.04.0 (see "Compatibility note" above) is still correct on its own,
but it is no longer the binding floor — nf-schema 2.4.2 now sets the
real minimum, at 24.10.0. `manifest.nextflowVersion` should be raised
to `!>=24.10.0` to match (see below; not yet done).

Changes made so far:

1. `nextflow.config`
   - Added `plugins { id 'nf-schema@2.4.2' }`.
   - Raised `manifest.nextflowVersion` from `!>=22.10.4` to
     `!>=24.04.0`. **Needs a further raise to `!>=24.10.0`** — see the
     correction note above. Not yet done.

2. `main.nf`
   - Removed the bare `WorkflowMain.initialise(workflow, params, log)`
     call.
   - Added `include { validateParameters; paramsSummaryLog; paramsHelp } from 'plugin/nf-schema'`.
   - Moved all of the old initialise logic (help, version, parameter
     validation/summary, config-provided check, conda channel check,
     AWS Batch check, input-provided check) into the entry `workflow { }`
     block, using the nf-schema plugin functions in place of the old
     `NfcoreSchema.groovy` calls.
   - `SAGE_DCQC` now takes `ch_input` via `take:`/`main:` instead of
     reading a script-level variable, and the entry workflow computes
     `ch_input = file(params.input, checkIfExists: true)` and passes it
     through.
   - Deleted `lib/WorkflowMain.groovy` and `lib/NfcoreSchema.groovy`
     (`git rm`) — both are fully replaced by the plugin now, and
     nothing else referenced them (checked with a repo-wide grep).

3. `workflows/dcqc.nf`
   - `DCQC` workflow now declares `take: ch_input` instead of reading
     a script-level `ch_input` variable.
   - Moved the old top-level statements (`summary_params`,
     `multiqc_report`, `WorkflowDcqc.initialise(...)`, the
     `checkPathParamList` existence check, and the `workflow.onComplete { }`
     block) inside the `DCQC` workflow's `main:` section. There was a
     duplicate `workflow.onComplete { }` block at the bottom of the file
     (left over from the old template layout) — removed it since the
     one now inside `DCQC` replaces it.
   - Replaced `NfcoreSchema.paramsSummaryMap(workflow, params)` with
     the plugin's `paramsSummaryMap(workflow)`.
   - Replaced the old-style `for (param in checkPathParamList) { ... }`
     loop with `checkPathParamList.each { param -> ... }` — the strict
     parser rejects old-style `for` loops entirely (not just at the
     top level).

4. `subworkflows/local/external_tests.nf`,
   `subworkflows/local/internal_tests.nf`,
   `subworkflows/local/prepare_tests.nf`
   - Added `def` to three closure-local variables (`parsed`,
     `dummy_file`) that were being implicitly declared. The strict
     parser rejects implicit variable declarations inside closures.

5. `nextflow_schema.json`, `assets/schema_input.json`
   - nf-schema (unlike the old `NfcoreSchema.groovy`/nf-validation)
     requires JSON Schema draft 2020-12, not draft-07. Ran the sed
     command from the official nf-schema migration guide on both
     schema files:
     ```
     sed -i -e 's#https\?://json-schema.org/draft-07/schema#https://json-schema.org/draft/2020-12/schema#g' -e 's/definitions/$defs/g' <file>
     ```
     This updated the `$schema` URL in both files, and renamed
     `definitions` to `$defs` in `nextflow_schema.json` (
     `schema_input.json` had no `definitions` key).

Status: all Groovy/script parse errors are resolved and the schema
draft version is updated. Not yet re-run after the schema fix — the
session was interrupted before confirming the next `nextflow run`
result. All of the above is uncommitted.

- Possible follow-up: the pipeline schema still sets
  `params.schema_ignore_params = 'genomes'`, `params.validate_params`,
  `params.show_hidden_params`, `params.monochrome_logs` — these are
  old nf-validation-style params. nf-schema's `validateParameters()`
  does not automatically read `schema_ignore_params`; the new
  equivalent is the `validation.defaultIgnoreParams`/
  `validation.ignoreParams` config scope. Not yet addressed since the
  `genomes` param is unused in this pipeline (only referenced in a
  commented-out line in `main.nf`) and no error has surfaced from it
  yet. Revisit only if `nextflow run` actually errors on it.
- `--help` output now uses the plugin's `paramsHelp()` function, which
  logs a deprecation warning (nf-schema auto-generates help text as of
  2.1.0 and recommends against calling `paramsHelp()` directly). Not
  changed yet, kept for minimal diff / feature parity with the old
  `--help` behavior. Could be revisited later.

### Fixed: `assets/schema_input.json` had the wrong column definitions

Re-ran the test command after the draft-2020-12 fix above. Parameter
validation failed with a new error, distinct from the migration work:

```
* --input (.../testdata/input_txt.csv): Validation of file failed:
        -> Entry 1: Missing required field(s): fastq_1, sample
```

This is a pre-existing bug, not caused by the Nextflow 26.04 migration.
`assets/schema_input.json` still had the column definitions from the
old nf-core rnaseq template (`sample`, `fastq_1`, `fastq_2`), left over
and never updated for this pipeline. Confirmed the real input format by
reading the CsvParser class in the sibling `py-dcqc` repo
(`src/dcqc/parsers.py`) and `modules/local/create_targets.nf`: the
manifest needs one required column, `url`; two optional metadata
columns are read by code, `file_type` and `md5_checksum`. This also
matches `testdata/input_txt.csv` (`url,file_type,md5_checksum`) and the
`help_text` already in `nextflow_schema.json` ("3 columns").

Fix: rewrote the `properties`/`required` block in
`assets/schema_input.json` to require `url` and describe `file_type`/
`md5_checksum` as optional strings. Dropped the fastq-specific regex
patterns since they don't apply. Did not add an enum for `file_type` —
`FileType` in `py-dcqc` is an open, code-defined registry, not a fixed
set of values, so constraining it in the schema would be wrong.

Status: fixed and confirmed — re-running the test command now passes
parameter validation (progresses past the point where this used to
fail).

### Blocked: missing `SYNAPSE_AUTH_TOKEN` secret

After the schema fix, `nextflow run` progresses to the
`CREATE_TARGETS` process and fails with:

```
Required secret is missing: 'SYNAPSE_AUTH_TOKEN'
```

Not a bug — `testdata/input_txt.csv` uses `syn://` URLs, and
`conf/base.config`/`conf/local.config` both declare
`secret = ['SYNAPSE_AUTH_TOKEN']` on the `dcqc` process label. This is
a per-machine credential, not something to fix in code. Confirmed with
`nextflow secrets list` that no secrets are configured on this
machine.

Status: waiting on the user to run
`nextflow secrets set SYNAPSE_AUTH_TOKEN <token>` themselves (a
Synapse personal access token, from Synapse account settings →
Personal Access Tokens). Not something Claude should set or ask for
directly, since it's a credential.

### Fixed: `workflow.onComplete` NullPointerException

Independent of the secret above — the same failed run also throws a
second error while shutting down:

```
ERROR nextflow.script.WorkflowMetadata - Failed to invoke `workflow.onComplete` event handler
java.lang.NullPointerException: Cannot get property 'email' on null object
```

This means `params` itself resolves to null inside the
`workflow.onComplete { ... }` closure in `workflows/dcqc.nf` (the
closure references `params.email`). This closure lives inside the
named `DCQC` workflow, not the entry `workflow { }` block in `main.nf`.

Hypothesis tested: that `params` doesn't resolve correctly inside
`workflow.onComplete` when the closure is defined in a named
(non-entry) workflow, under Nextflow 26.04.6. Built a minimal
reproduction in the scratchpad (`onc_test/`) with no processes at all —
just a `SUB` workflow containing `workflow.onComplete { log.info
"${params.email}" }`, called from an entry `workflow { SUB(x) }`. This
reproduced the identical NullPointerException, supporting the
hypothesis.

Acting on that hypothesis, moved `workflow.onComplete { ... }` (and the
`summary_params`/`multiqc_report` values it needs) out of the `DCQC`
workflow in `workflows/dcqc.nf` and into the entry `workflow { }` block
in `main.nf`, matching the current nf-core template pattern:

- `workflows/dcqc.nf`: removed `summary_params`, `multiqc_report`, and
  the `workflow.onComplete { }` block from `DCQC`. Removed the now-
  unused `include { paramsSummaryMap } from 'plugin/nf-schema'`.
- `main.nf`: added `paramsSummaryMap` to the nf-schema include. Added
  `summary_params`/`multiqc_report` and the `workflow.onComplete { }`
  block (identical body) to the entry `workflow { }`, after
  `SAGE_DCQC(ch_input)`.

**This fix is unverified and may not be correct.** Re-tested the same
hypothesis with the minimal reproduction script, this time putting the
`workflow.onComplete` block directly in the entry `workflow { }` (no
named subworkflow at all) — and got the exact same
`NullPointerException: Cannot get property 'email' on null object`.
This contradicts the original hypothesis: the problem is not
named-workflow vs. entry-workflow placement. The real cause of `params`
being null inside `workflow.onComplete` under Nextflow 26.04.6 is still
unknown.

Root cause found: this is a known Nextflow bug, not a mistake in the
migration. Confirmed via
[nextflow-io/nextflow#5261](https://github.com/nextflow-io/nextflow/issues/5261)
(duplicate:
[#5445](https://github.com/nextflow-io/nextflow/issues/5445)).
`workflow` and `params` resolve to null inside a
`workflow.onComplete { ... }` *block* defined in the entry workflow,
regardless of whether it's nested in a named workflow first. The
maintainer confirms this and lists two workarounds:

1. Assign the handler instead of declaring it as a block:
   `workflow.onComplete = { ... }`.
2. Capture local copies of `params`/`workflow` before the block.

A third, longer-term option exists: Nextflow's strict (v2) parser
(default since 26.04) supports a new `onComplete:` section inside the
entry `workflow { }`, which is meant to eventually replace the
`workflow.onComplete { }` form. Not used here — it would require
reworking the `NfcoreTemplate.email(...)`/`summary(...)`/
`IM_notification(...)` calls into that section, a larger change than
needed right now.

Fix applied: workaround 1. In `main.nf`, changed

```groovy
workflow.onComplete {
```

to

```groovy
workflow.onComplete = {
```

(line 97). No other lines in the block changed.

Status: **confirmed fixed.** User re-ran
`nextflow run . -profile test,docker,local --outdir ./results` after
the change and confirmed it worked.

### Fixed: `Variable workflow already defined in the process scope` compile error

Found when re-testing on Nextflow 24.10.0, the actual nf-schema 2.4.2
floor (see correction note above). `nextflow run` failed to compile,
before reaching any process:

```
ERROR ~ Script compilation error
- file : /home/alamb/Repos/nf-dcqc/main.nf
- cause: Variable `workflow` already defined in the process scope @ line 92, column 43.
   ary_params = paramsSummaryMap(workflow)
                                 ^
```

Root cause: a Nextflow compiler bug, not a mistake in the migration.
Confirmed by testing a minimal reproduction under three real Nextflow
versions already installed locally (24.04.0, 24.10.0, 26.04.6). The
bug needs two things inside the entry `workflow { }` block:

1. The implicit `workflow` variable read inside a string, for example
   `"${workflow.manifest.name}"` (line 55 in `main.nf`, inside the
   `params.help` check).
2. Later, a new local variable declared with `def`, whose value also
   reads `workflow` — for example
   `def summary_params = paramsSummaryMap(workflow)` (line 92).

When both are present, the Nextflow compiler wrongly reports that
`workflow` is "already defined," even though the code declares
`summary_params`, not `workflow`. The bug is present in Nextflow
24.04.0 and 24.10.0. It is fixed in Nextflow 26.04.6. It matches a
known Nextflow variable-scope bug class
([nextflow-io/nextflow#804](https://github.com/nextflow-io/nextflow/issues/804),
fixed by PR #5765 — but that fix landed after 24.10.0 and is not in
the 24.10.x patch branch).

Fix applied: removed the `def` keyword from line 92 in `main.nf`, so
`summary_params` becomes an implicit script-level variable instead of
a locally scoped one:

```groovy
summary_params = paramsSummaryMap(workflow)
```

Confirmed in the minimal reproduction that this compiles and runs
correctly on Nextflow 24.10.0, including correct access to
`summary_params` from inside the `workflow.onComplete = { ... }`
closure. Not yet re-confirmed against the actual `nf-dcqc` pipeline
run.

### Fixed: version floor propagated to CI and README

Once `nextflow.config` was corrected to `nextflowVersion = '!>=24.10.0'`
(see correction note above), checked the rest of the repo for other
places that mention a Nextflow version, so they would not go stale:

- `.github/workflows/ci.yml`: the `NXF_VER` test matrix did not
  include `24.10.0` at all (it only tested `25.04.6` and
  `latest-everything`), so CI would not have caught the compile bug
  found in this session. Added `24.10.0` to the matrix. The matrix now
  reads:
  ```yaml
  NXF_VER:
    - "24.10.0" # Oldest version that works
    - "25.04.6" # Current version used by Sage's Seqera server
    - "latest-everything"
  ```
  (edited directly by the user after Claude's initial addition — also
  briefly included `26.04.0`, then removed again by the user.)
- `README.md`: two references still showed the old `>=22.10.4` floor,
  left over from before this whole migration (unrelated to the
  24.04.0/24.10.0 mixup above). Updated both to `24.10.0`:
  - Line 3, the Nextflow badge.
  - Line 62, the Quick Start install instruction.

Other Nextflow-version mentions in the repo were checked and left
alone, since they read the version at runtime rather than pinning one:
`lib/NfcoreTemplate.groovy` (run summary/email),
`assets/methods_description_template.yml` (MultiQC methods text), and
`modules/nf-core/custom/dumpsoftwareversions/templates/dumpsoftwareversions.py`
(software-versions YAML). Also left alone: `.github/CONTRIBUTING.md`
(a generic nf-core "Nextflow version bumping" section heading) and
`.github/ISSUE_TEMPLATE/bug_report.yml` (example text in the bug
report template).

Status: all done. Not yet committed.

### Not yet done / next steps

- Review all the changes made during this migration as a whole (they
  were applied iteratively) before committing.
- ~~Raise `manifest.nextflowVersion` in `nextflow.config` from
  `!>=24.04.0` to `!>=24.10.0`~~ — done. `nextflow.config` now reads
  `nextflowVersion = '!>=24.10.0'`.
- Revisit the two open questions noted earlier, if desired:
  - Whether to raise `manifest.nextflowVersion` from `!>=24.04.0` to
    something stricter (see "Compatibility note" above) — this part
    is already done, nextflowVersion was raised as part of the
    nf-schema migration.
  - Whether to address `schema_ignore_params`/`validate_params`/
    `show_hidden_params`/`monochrome_logs` (old nf-validation-style
    params) — still deferred, no error has surfaced from it.
  - Whether to move off the deprecated `paramsHelp()` call — still
    deferred, kept for `--help` feature parity.
  - Whether to eventually migrate `workflow.onComplete { }` to the
    new `onComplete:` section syntax (option 3 above), ahead of
    Nextflow removing the old form.

## Environment

- Nextflow version used for testing: 26.04.6
