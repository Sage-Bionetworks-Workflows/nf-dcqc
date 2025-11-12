# MultiQC DCQC Validation Plugin

A MultiQC plugin for displaying validation results from DCQC suite testing.

## Features

- **Validation Summary**: Overview table showing overall status for each validated file
- **Test Details**: Detailed breakdown of individual test results by suite type
- **Failed Tests**: Comprehensive error messages and validation failures
- **General Stats**: Key metrics added to MultiQC general statistics table
- **Multi-Suite Support**: Handles all DCQC suite types (H5AD, and more)

## Installation

Install the plugin using pip from the project directory:

```bash
pip install .
```

Or install in development mode:

```bash
pip install -e .
```

## Usage

Run MultiQC in a directory containing `suites.json` file(s):

```bash
multiqc .
```

Or specify the results directory:

```bash
multiqc results/
```

## Data Format

The plugin expects a `suites.json` file with the following structure:

```json
[
  {
    "type": "H5ADSuite",  // or other suite types
    "target": {
      "id": "sample_001",
      "files": [
        {
          "name": "sample.h5ad",  // or other file types
          "url": "...",
          "local_path": "..."
        }
      ]
    },
    "suite_status": {
      "status": "GREEN",
      "required_tests": [...]
    },
    "tests": [
      {
        "type": "TestName",
        "tier": 1,
        "status": "passed",
        "status_reason": "",
        "is_external_test": false
      }
    ]
  }
]
```

The plugin supports all DCQC suite types and will display the suite type in the reports.

## Configuration

The plugin automatically searches for `suites.json` files. You can customize the search pattern in your MultiQC configuration file:

```yaml
sp:
  dcqc_validation:
    fn: 'suites.json'
```

## Output

The plugin generates three main sections in the MultiQC report:

1. **Validation Summary**: High-level overview with pass/fail status for each file and suite type
2. **Test Details**: Individual test results for each file, organized by suite type
3. **Failed Tests**: Detailed error messages for any failed validation tests

All sections display the suite type to help distinguish between different validation workflows (e.g., H5ADSuite, etc.).

## License

MIT
