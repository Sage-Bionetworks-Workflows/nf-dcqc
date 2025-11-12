"""
MultiQC module to parse DCQC validation results from suites.json
Supports all DCQC suite types (H5AD, etc.)
"""

import json
import logging
from collections import defaultdict

from multiqc.base_module import BaseMultiqcModule, ModuleNoSamplesFound
from multiqc.plots import table, bargraph

log = logging.getLogger(__name__)


class MultiqcModule(BaseMultiqcModule):
    """
    DCQC module for displaying validation results from DCQC suite testing.
    Parses suites.json and creates summary tables and detailed test results.
    """

    def __init__(self):
        # Initialize the parent module class
        super(MultiqcModule, self).__init__(
            name="DCQC Validation",
            anchor="dcqc_validation",
            href="https://github.com/ncihtan/dcqc",
            info="displays validation results from DCQC suite testing",
            extra="Validates data files against schema requirements using DCQC test suites",
        )

        # Storage for parsed data
        self.suite_data = dict()
        self.test_details = list()

        # Parse the suites.json file
        num_suites = self.parse_suites_json()

        if num_suites == 0:
            log.debug("Could not find any DCQC validation results")
            raise ModuleNoSamplesFound

        log.info(f"Found {num_suites} DCQC validation results")

        # Group data by suite type
        self.suite_types = self.group_by_suite_type()

        # Add general statistics
        self.add_general_statistics()

        # Add sections per suite type
        for suite_type in sorted(self.suite_types.keys()):
            self.add_suite_type_sections(suite_type)

    def parse_suites_json(self):
        """Parse suites.json file and extract validation data"""

        log.debug("Looking for DCQC validation files...")
        num_files = 0

        for f in self.find_log_files("dcqc_validation", filehandles=True):
            log.debug(f"Processing file: {f['fn']}")
            num_files += 1
            try:
                data = json.load(f["f"])

                for suite in data:
                    # Process all suite types, not just H5ADSuite
                    suite_type = suite.get("type", "Unknown")

                    # Extract file information
                    target = suite.get("target", {})
                    files = target.get("files", [])

                    if not files:
                        continue

                    file_info = files[0]  # Single file per suite
                    file_name = file_info.get("name", "Unknown")
                    sample_id = self.clean_s_name(target.get("id", file_name), f)

                    # Extract suite status
                    suite_status = suite.get("suite_status", {})
                    overall_status = suite_status.get("status", "UNKNOWN")
                    required_tests = suite_status.get("required_tests", [])

                    # Count test results
                    tests = suite.get("tests", [])
                    test_counts = {"passed": 0, "failed": 0, "skipped": 0}

                    for test in tests:
                        test_status = test.get("status", "unknown")
                        if test_status in test_counts:
                            test_counts[test_status] += 1

                        # Store detailed test info
                        self.test_details.append({
                            "sample": sample_id,
                            "file": file_name,
                            "suite_type": suite_type,
                            "test_type": test.get("type", "Unknown"),
                            "tier": test.get("tier", "-"),
                            "status": test_status,
                            "reason": test.get("status_reason", ""),
                            "external": test.get("is_external_test", False)
                        })

                    # Store summary data for this sample
                    self.suite_data[sample_id] = {
                        "file_name": file_name,
                        "suite_type": suite_type,
                        "overall_status": overall_status,
                        "total_tests": len(tests),
                        "passed": test_counts["passed"],
                        "failed": test_counts["failed"],
                        "skipped": test_counts["skipped"],
                        "required_tests_count": len(required_tests),
                    }

                    # Add sample to MultiQC general stats
                    self.add_data_source(f, s_name=sample_id)

            except json.JSONDecodeError as e:
                log.warning(f"Could not parse JSON from {f['fn']}: {e}")
                continue
            except Exception as e:
                log.warning(f"Error processing {f['fn']}: {e}")
                continue

        return len(self.suite_data)

    def group_by_suite_type(self):
        """Group suite_data and test_details by suite type"""
        grouped = {}

        for sample_id, data in self.suite_data.items():
            suite_type = data["suite_type"]
            if suite_type not in grouped:
                grouped[suite_type] = {
                    "samples": {},
                    "tests": []
                }
            grouped[suite_type]["samples"][sample_id] = data

        for test in self.test_details:
            suite_type = test["suite_type"]
            if suite_type in grouped:
                grouped[suite_type]["tests"].append(test)

        return grouped

    def add_general_statistics(self):
        """Add general statistics to the main MultiQC table"""
        if not self.suite_data:
            return

        # Prepare data for general stats
        stats_data = {}
        for sample_id, data in self.suite_data.items():
            stats_data[sample_id] = {
                "suite_type": data["suite_type"],
                "status": data["overall_status"],
                "passed": data["passed"],
                "failed": data["failed"],
                "total": data["total_tests"],
            }

        # Configure headers
        headers = {
            "suite_type": {
                "title": "Suite Type",
                "description": "Type of validation suite",
                "scale": False,
            },
            "status": {
                "title": "Status",
                "description": "Overall validation status",
                "scale": False,
                "cond_formatting_rules": {
                    "pass": [{"s_eq": "GREEN"}],
                    "warn": [{"s_eq": "YELLOW"}, {"s_eq": "AMBER"}, {"s_eq": "GREY"}],
                    "fail": [{"s_eq": "RED"}],
                },
            },
            "passed": {
                "title": "Passed",
                "description": "Number of tests passed",
                "scale": "Greens",
                "format": "{:,.0f}",
            },
            "failed": {
                "title": "Failed",
                "description": "Number of tests failed",
                "scale": "Reds",
                "format": "{:,.0f}",
            },
            "total": {
                "title": "Total",
                "description": "Total number of tests run",
                "scale": "Blues",
                "format": "{:,.0f}",
            },
        }

        # Add to general stats
        self.general_stats_addcols(stats_data, headers)

    def add_suite_type_sections(self, suite_type):
        """Add summary, details, and failed tests sections for a specific suite type"""
        suite_info = self.suite_types[suite_type]
        samples = suite_info["samples"]
        tests = suite_info["tests"]

        if not samples:
            return

        # Add summary table for this suite type
        self.add_suite_summary_section(suite_type, samples)

        # Add test details for this suite type
        self.add_suite_test_details_section(suite_type, tests)

        # Add failed tests for this suite type
        self.add_suite_failed_tests_section(suite_type, tests)

    def add_suite_summary_section(self, suite_type, samples):
        """Add summary table for a specific suite type"""

        if not samples:
            return

        # Prepare data for the summary table
        table_data = {}
        for sample_id, data in samples.items():
            table_data[sample_id] = {
                "file_name": data["file_name"],
                "status": data["overall_status"],
                "passed": data["passed"],
                "failed": data["failed"],
                "total": data["total_tests"],
            }

        # Configure table headers (no suite_type column since it's per-suite)
        headers = {
            "file_name": {
                "title": "File Name",
                "description": "Data file name",
                "scale": False,
            },
            "status": {
                "title": "Overall Status",
                "description": "Overall validation status",
                "scale": False,
                "cond_formatting_rules": {
                    "pass": [{"s_eq": "GREEN"}],
                    "warn": [{"s_eq": "YELLOW"}, {"s_eq": "AMBER"}, {"s_eq": "GREY"}],
                    "fail": [{"s_eq": "RED"}],
                },
            },
            "passed": {
                "title": "Passed",
                "description": "Number of tests passed",
                "scale": "Greens",
                "format": "{:,.0f}",
            },
            "failed": {
                "title": "Failed",
                "description": "Number of tests failed",
                "scale": "Reds",
                "format": "{:,.0f}",
            },
            "total": {
                "title": "Total Tests",
                "description": "Total number of tests run",
                "scale": "Blues",
                "format": "{:,.0f}",
            },
        }

        # Add the table to the report
        table_config = {
            "id": f"dcqc_{suite_type}_summary_table",
            "namespace": f"DCQC {suite_type}",
            "title": f"{suite_type} File Summary",
            "col1_header": "Sample ID",
        }

        self.add_section(
            name=f"{suite_type} Validation",
            anchor=f"dcqc-{suite_type.lower()}-summary",
            description=f"Validation results for {suite_type} files ({len(samples)} file{'s' if len(samples) > 1 else ''})",
            plot=table.plot(table_data, headers, table_config),
        )

    def add_suite_test_details_section(self, suite_type, tests):
        """Add detailed table showing individual test results for a specific suite type"""

        if not tests:
            return

        # Prepare data for detailed table
        table_data = {}
        for idx, test in enumerate(tests):
            row_id = f"{test['sample']}_{test['test_type']}_{idx}"

            table_data[row_id] = {
                "sample": test["sample"],
                "test": test["test_type"],
                "tier": test["tier"],
                "status": test["status"],
                "external": "Yes" if test["external"] else "No",
            }

        # Configure table headers (no suite_type since it's per-suite)
        headers = {
            "sample": {
                "title": "Sample ID",
                "description": "Sample identifier",
                "scale": False,
            },
            "test": {
                "title": "Test Name",
                "description": "Name of the validation test",
                "scale": False,
            },
            "tier": {
                "title": "Tier",
                "description": "Test tier level",
                "scale": False,
            },
            "status": {
                "title": "Status",
                "description": "Test result status",
                "scale": False,
                "cond_formatting_rules": {
                    "pass": [{"s_eq": "passed"}],
                    "warn": [{"s_eq": "skipped"}],
                    "fail": [{"s_eq": "failed"}],
                },
            },
            "external": {
                "title": "External",
                "description": "Whether this is an external test",
                "scale": False,
            },
        }

        # Add the table to the report
        table_config = {
            "id": f"dcqc_{suite_type}_details_table",
            "namespace": f"DCQC {suite_type}",
            "title": f"{suite_type} Test Details",
            "col1_header": "Test",
        }

        self.add_section(
            name=f"{suite_type} Test Details",
            anchor=f"dcqc-{suite_type.lower()}-details",
            description=f"Detailed results for each {suite_type} validation test",
            plot=table.plot(table_data, headers, table_config),
        )

    def add_suite_failed_tests_section(self, suite_type, tests):
        """Add section showing details of failed tests for a specific suite type"""

        # Filter for failed tests with reasons
        failed_tests = [t for t in tests if t["status"] == "failed" and t["reason"]]

        if not failed_tests:
            return

        # Build HTML content for failed tests
        html = '<div class="alert alert-danger">'
        html += f'<h4>{suite_type} Failed Test Details</h4>'

        for test in failed_tests:
            html += f'<div style="margin-bottom: 20px; padding: 10px; border-left: 3px solid #d9534f;">'
            html += f'<h5><strong>{test["file"]}</strong> - {test["test_type"]}</h5>'
            html += f'<p><strong>Sample:</strong> {test["sample"]} | <strong>Tier:</strong> {test["tier"]}</p>'
            html += '<div style="background-color: #f5f5f5; padding: 10px; border-radius: 4px; font-family: monospace; white-space: pre-wrap; font-size: 0.9em;">'

            # Parse and format the error reason
            reason = test["reason"]
            if reason:
                # Try to make it more readable
                lines = reason.split("\\n")
                for line in lines[:50]:  # Limit to first 50 lines
                    if line.strip():
                        html += f"{line}\n"
                if len(lines) > 50:
                    html += f"\n... ({len(lines) - 50} more lines)\n"

            html += '</div></div>'

        html += '</div>'

        self.add_section(
            name=f"{suite_type} Failed Tests",
            anchor=f"dcqc-{suite_type.lower()}-failed",
            description=f"Detailed error messages for {len(failed_tests)} failed {suite_type} test(s)",
            content=html,
        )


# Tell MultiQC to use this module
def MultiqcModule_run(*args, **kwargs):
    return MultiqcModule(*args, **kwargs)
