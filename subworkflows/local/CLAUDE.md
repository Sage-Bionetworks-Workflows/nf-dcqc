## Project

The four local subworkflows implement the DCQC pipeline's core branching logic: target/test generation, internal-vs-external test execution, and report assembly.

## Conventions

- **`prepare_tests.nf`**: `CREATE_TARGETS` emits one JSON per QC target; each is parsed with `Utils.parseJson` and keyed by `parsed.id`. `CREATE_TESTS` then runs per target, its output is transposed, and each test JSON is parsed for `parsed.is_external_test` to branch into `internal`/`external` channels shaped `[val(target_id), path(test_json)]`. Follow this parse-then-branch pattern for new logic here — a new channel shape needs a matching update at the merge point in `prepare_reports.nf`.
- **`internal_tests.nf`**: pads the tuple with three copies of `testdata/dummy.txt` as placeholder stdout/stderr/exit-code files before calling `COMPUTE_TEST`. This keeps the internal and external branches at the same input arity so `dcqc.nf` can `.mix()` them back together — don't drop the padding without also changing what `COMPUTE_TEST` expects.
- **`external_tests.nf`**: sets `cpus`/`memory`/`container` directives on `RUN_PROCESS` dynamically, from values parsed out of `CREATE_PROCESS`'s JSON output at runtime. This is not the usual static-directive pattern used elsewhere in the repo — if a process needs different resources, that comes from the JSON payload, not from `conf/modules.config`.
- **`prepare_reports.nf`**: groups computed tests by `target_id`, builds one suite per target (`CREATE_SUITE`), combines all suites into `suites.json` (`COMBINE_SUITES`), then writes the final `output.csv` (`UPDATE_INPUT` / `dcqc update-csv`). Order matters: `COMBINE_SUITES` must see every target's suite before `UPDATE_INPUT` runs.
