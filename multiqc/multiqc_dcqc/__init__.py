"""
MultiQC plugin for DCQC validation results.
"""

from multiqc.utils import config

# Make sure this plugin runs after any standard MultiQC modules
config.module_order.append(
    {
        "dcqc_validation": {
            "module_tag": ["QC", "Validation"],
            "name": "DCQC Validation",
            "anchor": "dcqc-validation",
            "target": "DCQC Validation",
            "info": "displays validation results from DCQC suite testing",
        }
    }
)

# Configure search patterns for finding suites.json files
config.sp["dcqc_validation"] = {
    "fn": "suites.json",
}

# Import the module
from multiqc_dcqc import dcqc_validation
