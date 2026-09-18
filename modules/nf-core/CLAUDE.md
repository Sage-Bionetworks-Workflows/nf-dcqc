## Project

Vendored nf-core modules (`custom/dumpsoftwareversions`, `fastqc`, `multiqc`), installed via `nf-core modules install` and tracked in `../../modules.json`, pinned to git sha `c8e35eb2055c099720a75538d1b8adb3fb5a464c` on `nf-core/modules` (branch `master`).

## Constraints

- Never hand-edit files under this directory — they're managed by nf-core's module sync tooling (`nf-core modules update`). Local edits get silently overwritten on the next sync and diverge from what `modules.json` tracks.

## Anti-Patterns — Do NOT

- Do NOT assume `fastqc/` or `multiqc/` are active in the pipeline — they're present here and in `modules.json`, but never `include`d or called anywhere in `workflows/dcqc.nf`. They're dead vendored code left over from the original rnaseq template. To add QC-report functionality, wire `MULTIQC` in from `workflows/dcqc.nf` yourself — don't assume it already runs.
- `custom/dumpsoftwareversions` is imported into `workflows/dcqc.nf` but that import itself is never invoked in the workflow body — verify before assuming pipeline-wide version reporting actually works end-to-end.
