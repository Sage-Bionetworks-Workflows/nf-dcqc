#!/usr/bin/env python
"""
Setup script for multiqc_dcqc MultiQC plugin
"""

from setuptools import setup, find_packages

setup(
    name="multiqc_dcqc",
    version="0.1.0",
    description="MultiQC plugin for DCQC validation results",
    long_description="""
    A MultiQC plugin that parses and visualizes validation results
    from the DCQC (Data Quality Control) suite. It displays validation status,
    test results, and detailed error messages for data files validated against
    various schema requirements (including HTAN and CELLxGENE).
    """,
    author="HTAN Data Coordinating Center",
    url="https://github.com/ncihtan/dcqc",
    license="MIT",
    packages=find_packages(),
    include_package_data=True,
    zip_safe=False,
    install_requires=[
        "multiqc>=1.14",
    ],
    entry_points={
        "multiqc.modules.v1": [
            "dcqc_validation = multiqc_dcqc.dcqc_validation:MultiqcModule",
        ],
    },
    classifiers=[
        "Development Status :: 4 - Beta",
        "Environment :: Console",
        "Environment :: Web Environment",
        "Intended Audience :: Science/Research",
        "License :: OSI Approved :: MIT License",
        "Natural Language :: English",
        "Operating System :: OS Independent",
        "Programming Language :: Python",
        "Programming Language :: Python :: 3",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Topic :: Scientific/Engineering",
        "Topic :: Scientific/Engineering :: Bio-Informatics",
    ],
)
