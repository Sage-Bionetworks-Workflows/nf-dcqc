[![Cite with Zenodo](http://img.shields.io/badge/DOI-10.5281/zenodo.XXXXXXX-1073c8?labelColor=000000)](https://doi.org/10.5281/zenodo.XXXXXXX)

[![Nextflow](https://img.shields.io/badge/nextflow%20DSL2-%E2%89%A522.10.4-23aa62.svg)](https://www.nextflow.io/)
[![run with conda](http://img.shields.io/badge/run%20with-conda-3EB049?labelColor=000000&logo=anaconda)](https://docs.conda.io/en/latest/)
[![run with docker](https://img.shields.io/badge/run%20with-docker-0db7ed?labelColor=000000&logo=docker)](https://www.docker.com/)
[![run with singularity](https://img.shields.io/badge/run%20with-singularity-1d355c.svg?labelColor=000000)](https://sylabs.io/docs/)
[![Launch on Nextflow Tower](https://img.shields.io/badge/Launch%20%F0%9F%9A%80-Nextflow%20Tower-%234256e7)](https://tower.nf/launch?pipeline=https://github.com/Sage-Bionetworks-Workflows/nf-dcqc)

## Introduction

<!-- TODO nf-core: Write a 1-2 sentence summary of what data the pipeline is for and what it does -->

**Sage-Bionetworks-Workflows/nf-dcqc** is a bioinformatics best-practice analysis pipeline for Nextflow Workflow for Data Coordination Quality Control.

The pipeline is built using [Nextflow](https://www.nextflow.io), a workflow tool to run tasks across multiple compute infrastructures in a very portable manner. It uses Docker/Singularity containers making installation trivial and results highly reproducible. The [Nextflow DSL2](https://www.nextflow.io/docs/latest/dsl2.html) implementation of this pipeline uses one container per process which makes it much easier to maintain and update software dependencies. Where possible, these processes have been submitted to and installed from [nf-core/modules](https://github.com/nf-core/modules) in order to make them available to all nf-core pipelines, and to everyone within the Nextflow community!

<!-- TODO nf-core: Add full-sized test dataset and amend the paragraph below if applicable -->

On release, automated continuous integration tests run the pipeline on a full-sized dataset on the AWS cloud infrastructure. This ensures that the pipeline runs on AWS, has sensible resource allocation defaults set to run on real-world datasets, and permits the persistent storage of results to benchmark between pipeline releases and other analysis sources.

## Pipeline summary

1. Prepare Tests
   - Create targets (`dcqc create-targets`) - Generates target specifications from input CSV
   - Create tests (`dcqc create-tests`) - Creates test specifications for each target
1. Run Internal Tests
   - Compute test results (`dcqc compute-test`) - Runs internal tests that don't require external processes
1. Run External Tests
   - Create process (`dcqc create-process`) - Generates process specifications for external tests
   - Run process - Executes external processes
   - Compute test results (`dcqc compute-test`) - Evaluates results from external processes
1. Prepare Reports
   - Create test suites (`dcqc create-suite`) - Groups test results by target
   - Combine test suites (`dcqc combine-suites`) - Aggregates results across all test suites
   - Update input CSV (`dcqc update-csv`) - Updates the original input CSV with test results

## Pipeline Flow

```mermaid
  flowchart LR;
    subgraph PREPARE TESTS;
    A[CREATE TARGETS]-->B[CREATE TESTS];
    end;
    subgraph INTERNAL TESTS;
    B-->C[COMPUTE TEST];
    end;
    subgraph EXTERNAL TESTS;
    B-->D[CREATE PROCESS];
    D-->E[RUN PROCESS];
    E-->F[COMPUTE TEST];
    end;
    subgraph PREPARE REPORTS;
    C-->G[CREATE SUITE];
    F-->G;
    G-->H[COMBINE SUITES];
    H-->I[UPDATE INPUT CSV];
    end;
```

## Quick Start

1. Install [`Nextflow`](https://www.nextflow.io/docs/latest/getstarted.html#installation) (`>=22.10.4`)

2. Install any of [`Docker`](https://docs.docker.com/engine/installation/), [`Singularity`](https://www.sylabs.io/guides/3.0/user-guide/) (you can follow [this tutorial](https://singularity-tutorial.github.io/01-installation/)), [`Podman`](https://podman.io/), [`Shifter`](https://nersc.gitlab.io/development/shifter/how-to-use/) or [`Charliecloud`](https://hpc.github.io/charliecloud/) for full pipeline reproducibility _(you can use [`Conda`](https://conda.io/miniconda.html) both to install Nextflow itself and also to manage software within pipelines. Please only use it within pipelines as a last resort; see [docs](https://nf-co.re/usage/configuration#basic-configuration-profiles))_.

3. Add your Synapse token as a nextflow secret

   ```bash
   nextflow secrets set SYNAPSE_AUTH_TOKEN <token>
   ```

4. Download the pipeline and test it on a minimal dataset with a single command:

   ```bash
   nextflow run Sage-Bionetworks-Workflows/nf-dcqc -profile test,YOURPROFILE --outdir <OUTDIR>
   ```

   Note that some form of configuration will be needed so that Nextflow knows how to fetch the required software. This is usually done in the form of a config profile (`YOURPROFILE` in the example command above). You can chain multiple config profiles in a comma-separated string.

   > - The pipeline comes with config profiles called `docker`, `singularity`, `podman`, `shifter`, `charliecloud` and `conda` which instruct the pipeline to use the named tool for software management. For example, `-profile test,docker`.
   > - Please check [nf-core/configs](https://github.com/nf-core/configs#documentation) to see if a custom config file to run nf-core pipelines already exists for your Institute. If so, you can simply use `-profile <institute>` in your command. This will enable either `docker` or `singularity` and set the appropriate execution settings for your local compute environment.
   > - If you are using `singularity`, please use the [`nf-core download`](https://nf-co.re/tools/#downloading-pipelines-for-offline-use) command to download images first, before running the pipeline. Setting the [`NXF_SINGULARITY_CACHEDIR` or `singularity.cacheDir`](https://www.nextflow.io/docs/latest/singularity.html?#singularity-docker-hub) Nextflow options enables you to store and re-use the images from a central location for future pipeline runs.
   > - If you are using `conda`, it is highly recommended to use the [`NXF_CONDA_CACHEDIR` or `conda.cacheDir`](https://www.nextflow.io/docs/latest/conda.html) settings to store the environments in a central location for future pipeline runs.

4. Start running your own analysis!

   <!-- TODO nf-core: Update the example "typical command" below used to run the pipeline -->

   ```bash
   nextflow run Sage-Bionetworks-Workflows/nf-dcqc --input samplesheet.csv --outdir <OUTDIR> --genome GRCh37 -profile <docker/singularity/podman/shifter/charliecloud/conda/institute>
   ```

## Special Considerations for Running `nf-dcqc` on Nextflow Tower

`nf-dcqc` leverages the reports feature when executed on Tower. This is done by pointing Tower to the generated `output.csv` file which is saved to `params.outdir` after a successful run. By default, the `outdir` for the workflow is set to a local directory called `results`. This does not work on Nextflow Tower runs, as you will not have access to the `results` directory once the job has completed. Thus, the `outdir` should be set to an S3 bucket location that the Tower workspace you are using has access to. For example, in the `pipeline parameters` for a Tower run, you can provide YAML such as:

```yaml
outdir: s3://example-project-tower-bucket/dcqc_output
```

From the reports tab within your workflow run, you can view and download the generated `output.csv` file.

## Credits

Sage-Bionetworks-Workflows/nf-dcqc (sage/dcqc) was originally written by Bruno Grande.

<!-- TODO nf-core: If applicable, make list of people who have also contributed -->

## Contributions and Support

If you would like to contribute to this pipeline, please see the [contributing guidelines](.github/CONTRIBUTING.md).

## Citations

<!-- TODO nf-core: Add citation for pipeline after first release. Uncomment lines below and update Zenodo doi and badge at the top of this file. -->
<!-- If you use  Sage-Bionetworks-Workflows/nf-dcqc for your analysis, please cite it using the following doi: [10.5281/zenodo.XXXXXX](https://doi.org/10.5281/zenodo.XXXXXX) -->

<!-- TODO nf-core: Add bibliography of tools and data used in your pipeline -->

An extensive list of references for the tools used by the pipeline can be found in the [`CITATIONS.md`](CITATIONS.md) file.

This pipeline uses code and infrastructure developed and maintained by the [nf-core](https://nf-co.re) community, reused here under the [MIT license](https://github.com/nf-core/tools/blob/master/LICENSE).

> **The nf-core framework for community-curated bioinformatics pipelines.**
>
> Philip Ewels, Alexander Peltzer, Sven Fillinger, Harshil Patel, Johannes Alneberg, Andreas Wilm, Maxime Ulysse Garcia, Paolo Di Tommaso & Sven Nahnsen.
>
> _Nat Biotechnol._ 2020 Feb 13. doi: [10.1038/s41587-020-0439-x](https://dx.doi.org/10.1038/s41587-020-0439-x).
