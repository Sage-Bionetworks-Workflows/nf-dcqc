#!/usr/bin/env python3
"""Cirro preprocess step: build the --input samplesheet from the input dataset.

The input dataset must contain exactly one samplesheet CSV (columns: url,
file_type, md5_checksum, optional test). Any `url` value that is a bare file
name matching a file uploaded alongside the samplesheet is rewritten to that
file's S3 path; other values (e.g. syn:// URIs) are left untouched.
"""

import posixpath

from cirro.helpers.preprocess_dataset import PreprocessDataset, read_csv

REQUIRED_COLUMNS = ["url", "file_type", "md5_checksum"]


def is_samplesheet(path, logger):
    try:
        cols = read_csv(path).columns
    except Exception as e:  # unreadable/empty CSVs are just data files
        logger.info(f"Skipping {path} as samplesheet candidate: {e}")
        return False
    return all(c in cols for c in REQUIRED_COLUMNS)


def main():
    ds = PreprocessDataset.from_running()
    ds.logger.info(f"Starting params: {ds.params}")
    ds.logger.info(f"Input files:\n{ds.files}")

    files = [str(f) for f in ds.files["file"].unique()]
    candidates = [f for f in files if f.lower().endswith(".csv")]
    samplesheets = [f for f in candidates if is_samplesheet(f, ds.logger)]
    if len(samplesheets) != 1:
        raise ValueError(
            f"Expected exactly one samplesheet CSV with columns {REQUIRED_COLUMNS} "
            f"in the input dataset, found {len(samplesheets)}: {samplesheets}"
        )
    samplesheet_path = samplesheets[0]

    by_name = {}
    for f in files:
        if f != samplesheet_path:
            by_name.setdefault(posixpath.basename(f), []).append(f)

    def resolve(url):
        url = str(url).strip()
        if "://" in url:
            return url
        matches = by_name.get(posixpath.basename(url), [])
        if len(matches) != 1:
            raise ValueError(f"Samplesheet url '{url}' matched {len(matches)} uploaded files: {matches}")
        return matches[0]

    samplesheet = read_csv(samplesheet_path, required_columns=REQUIRED_COLUMNS)
    samplesheet["url"] = samplesheet["url"].map(resolve)
    ds.logger.info(f"Resolved samplesheet:\n{samplesheet.to_csv(index=False)}")

    samplesheet.to_csv("samplesheet.csv", index=False)
    ds.add_param("input", "samplesheet.csv", overwrite=True)

    # Drop blank optional test lists so the pipeline's regex validation doesn't reject an empty string
    for key in ("required_tests", "skipped_tests"):
        if key in ds.params and not ds.params[key]:
            ds.remove_param(key)

    ds.logger.info(f"Final params: {ds.params}")


if __name__ == "__main__":
    main()
