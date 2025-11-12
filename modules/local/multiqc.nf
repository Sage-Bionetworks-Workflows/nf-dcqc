process MULTIQC {
    label 'process_single'

    conda "bioconda::multiqc=1.15"
    container "${ workflow.containerEngine == 'singularity' && !task.ext.singularity_pull_docker_container ?
        'https://depot.galaxyproject.org/singularity/multiqc:1.15--pyhdfd78af_0' :
        'quay.io/biocontainers/multiqc:1.15--pyhdfd78af_0' }"

    input:
    path suites_json
    path multiqc_config
    path plugin_dir

    output:
    path "*multiqc_report.html", emit: report
    path "*_data"              , emit: data
    path "*_plots"             , optional:true, emit: plots
    path "versions.yml"        , emit: versions

    when:
    task.ext.when == null || task.ext.when

    script:
    def args = task.ext.args ?: ''
    """
    # Set up local Python environment
    export PYTHONUSERBASE=\${PWD}/.local
    export PATH=\${PYTHONUSERBASE}/bin:\${PATH}

    # Install the custom MultiQC plugin first
    cd ${plugin_dir}
    pip install --user --no-deps .
    cd -

    # Find the actual site-packages directory and set PYTHONPATH
    SITE_PACKAGES=\$(find \${PYTHONUSERBASE}/lib -name site-packages -type d | head -n 1)
    if [ -z "\${PYTHONPATH:-}" ]; then
        export PYTHONPATH=\${SITE_PACKAGES}
    else
        export PYTHONPATH=\${SITE_PACKAGES}:\${PYTHONPATH}
    fi

    # suites.json is already staged by Nextflow, no need to copy

    # Run MultiQC with the custom config
    multiqc \\
        --force \\
        --config ${multiqc_config} \\
        $args \\
        .

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """

    stub:
    """
    touch multiqc_data
    touch multiqc_plots
    touch multiqc_report.html

    cat <<-END_VERSIONS > versions.yml
    "${task.process}":
        multiqc: \$( multiqc --version | sed -e "s/multiqc, version //g" )
    END_VERSIONS
    """
}
