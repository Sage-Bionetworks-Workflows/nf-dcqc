#!/usr/bin/env python3
"""Cirro preprocess step: point --input at the samplesheet CSV in the input dataset."""

from cirro.helpers.preprocess_dataset import PreprocessDataset


def main():
    ds = PreprocessDataset.from_running()
    ds.logger.info(f"Starting params: {ds.params}")
    ds.logger.info(f"Input files:\n{ds.files}")

    csv_files = [f for f in ds.files["file"].unique() if str(f).lower().endswith(".csv")]
    if len(csv_files) != 1:
        raise ValueError(
            f"Expected exactly one samplesheet CSV in the input dataset, found {len(csv_files)}: {csv_files}"
        )
    ds.add_param("input", csv_files[0])

    # Drop blank optional test lists so the pipeline's regex validation doesn't reject an empty string
    for key in ("required_tests", "skipped_tests"):
        if key in ds.params and not ds.params[key]:
            ds.remove_param(key)

    ds.logger.info(f"Final params: {ds.params}")


if __name__ == "__main__":
    main()
