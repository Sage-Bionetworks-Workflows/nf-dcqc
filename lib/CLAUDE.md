## Project

nf-core template Groovy helper classes (parameter validation, help text, logging, schema checks), plus a vendored Joda-Time jar (`nfcore_external_java_deps.jar` — binary, don't open or edit).

## Constraints

- Never delete or rewrite `WorkflowMain.groovy` / `NfcoreSchema.groovy` to adopt the newer `nf-schema` plugin pattern. This repo intentionally still uses the pre-`nf-schema` template style. Migrating away from it is exactly what the reverted commit `8b32ac9` / still-open PR #22 attempted, and it hit two confirmed, unfixed Nextflow bugs. See the root `CLAUDE.md` Constraints section for the full reasoning before touching anything here.

## Anti-Patterns — Do NOT

- Do NOT treat `WorkflowDcqc.groovy`'s `initialise()` as doing real work — it's an empty stub, with genome-check logic already commented out (leftover from the rnaseq template). Don't build new logic on top of it assuming it validates anything.
