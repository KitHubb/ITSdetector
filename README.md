# ITSdetector

A reproducible Nextflow workflow for fungal ITS amplicon sequencing analysis, designed for robust preprocessing, benchmarking, and taxonomic assignment of ITS1 and ITS2 datasets.

## Overview

**ITSdetector** is a modular workflow for Illumina fungal ITS amplicon sequencing data. It is being developed to support both routine analysis and systematic benchmarking of alternative preprocessing, denoising, and taxonomic assignment strategies.

The workflow is particularly intended for studies in which fungal mock communities, technical controls, or reference datasets are available and can be used to evaluate analytical performance against known or expected taxonomic compositions.

The primary goals of ITSdetector are to:

* provide a reproducible ITS1/ITS2 analysis workflow;
* support paired-end and forward-read-only processing strategies;
* compare ITSxpress-based ITS extraction with primer-based Cutadapt trimming;
* evaluate the effects of quality filtering and DADA2 expected-error filtering;
* support multiple fungal reference databases and taxonomic refinement strategies;
* generate standardized quality-control and benchmark summaries;
* establish an extensible framework for consensus taxonomic assignment.

## Current Workflow

```text
FASTQ input
  │
  ├── Sample-sheet validation
  ├── Raw read quality control
  ├── Adapter and poly-G trimming
  ├── Optional quality filtering
  ├── Cleaned-read quality-control summary
  ├── QIIME 2 import
  │
  └── ITS preprocessing
       ├── ITSxpress paired-end
       ├── ITSxpress forward-read-only
       ├── Cutadapt primer trimming paired-end
       └── Cutadapt primer trimming forward-read-only
```

Downstream modules will include DADA2 denoising, taxonomy assignment, taxonomic refinement, benchmarking, export, and automated reporting.

## Design Principles

ITSdetector follows several design principles.

1. **Reproducibility**
   All major processing steps are implemented as version-controlled Nextflow modules with containerized software environments.

2. **Study-specific configuration**
   Primer sequences, ITS region, ITSxpress settings, reference databases, and filtering thresholds are specified through study-level YAML parameter files or command-line options.

3. **Benchmark-oriented analysis**
   The workflow is designed not only to generate taxonomic profiles but also to evaluate which analytical settings best reproduce known mock-community compositions.

4. **Modular extensibility**
   Alternative trimming, denoising, classification, and refinement methods can be added without changing the core workflow structure.

5. **Transparent intermediate outputs**
   Quality-control summaries, trimming outputs, denoising statistics, taxonomy evidence tables, and benchmark metrics are retained for inspection.

## Supported Input Data

ITSdetector is intended for Illumina amplicon sequencing datasets, including:

* ITS1 amplicon libraries;
* ITS2 amplicon libraries;
* paired-end FASTQ files;
* forward-read-only sensitivity analyses;
* fungal mock communities;
* negative controls;
* clinical, environmental, host-associated, and experimental fungal communities.

The sample sheet contains the following fields:

```text
sample_id
run_id
assay_id
read_mode
fastq_1
fastq_2
```

## Current Preprocessing Strategies

### ITSxpress-based ITS extraction

ITSxpress is used to identify and extract the targeted ITS region while retaining sequence quality information.

Supported modes:

* paired-end output with unmerged reads;
* forward-read-only processing;
* ITS1, ITS2, or full ITS extraction;
* configurable fungal or broader taxonomic HMM settings;
* configurable clustering identity threshold.

The default production strategy is currently:

```text
ITSxpress + paired-end processing
```

### Cutadapt-based primer trimming

Primer-based trimming is available as an alternative preprocessing strategy.

Supported modes:

* paired-end primer trimming;
* forward-read-only primer trimming;
* optional removal of reads without detectable primer sequences;
* study-specific primer and read-through sequence configuration.

Cutadapt branches are primarily intended for benchmark comparison and sensitivity analyses.

## Quality Filtering and Benchmarking

ITSdetector is being developed to evaluate how preprocessing choices affect fungal community reconstruction.

The benchmarking framework will support comparison across:

```text
Quality filtering profiles
  ├── default
  ├── Q15
  ├── Q20
  └── Q30

ITS preprocessing strategies
  ├── ITSxpress paired-end
  ├── ITSxpress forward-read-only
  ├── Cutadapt paired-end
  └── Cutadapt forward-read-only

DADA2 filtering strategies
  ├── default settings
  └── alternative maximum expected error thresholds

Taxonomic assignment strategies
  ├── reference classifier only
  ├── reference classifier plus BLAST refinement
  └── future consensus classification approaches
```

Benchmarking against mock-community ground truth will include:

* read retention at each processing stage;
* retained sequence length distributions;
* DADA2 denoising and chimera-removal statistics;
* detected taxa;
* false-positive and false-negative taxa;
* sensitivity;
* precision;
* F1-score;
* agreement with expected relative abundance;
* Bray-Curtis distance from theoretical composition;
* species-level assignment rate;
* reproducibility across technical replicates.

## Reference Databases

### UNITE

UNITE will serve as the primary fungal ITS reference database for standard taxonomic classification.

Planned uses include:

* QIIME 2 naive Bayes classifier assignment;
* fungi-focused ITS taxonomic profiling;
* comparison across confidence thresholds;
* species-level assignment evaluation.

### EUKARYOME

EUKARYOME will be added as an alternative eukaryotic rRNA reference database.

This database will support:

* broader eukaryotic sequence classification;
* evaluation of fungal assignments in the presence of non-fungal eukaryotic sequences;
* comparison with fungi-focused UNITE assignments;
* assessment of discordant or unresolved taxa.

## BLAST-assisted Taxonomic Refinement

ITSdetector will support optional BLAST-based refinement after primary classifier assignment.

The intended approach is:

```text
QIIME 2 classifier assignment
  │
  ├── Species-level assignment retained when supported
  │
  └── Unresolved or ambiguous ASVs
       │
       └── BLAST search against curated ITS reference sequences
```

BLAST refinement will be configurable by parameters such as:

* minimum percentage identity;
* minimum query coverage;
* maximum e-value;
* target database;
* taxonomic rank required for replacement or refinement.

The objective is not to overwrite all primary classifier results, but to provide transparent evidence for ASVs that remain unresolved at species level.

## Planned Consensus Taxonomy Framework

A future version of ITSdetector will integrate multiple taxonomic evidence sources to generate a consensus taxonomy table.

Planned evidence sources include:

```text
1. UNITE classifier assignment
2. EUKARYOME classifier assignment
3. BLAST-based sequence alignment
4. AI-based taxonomic classifier 1
5. AI-based taxonomic classifier 2
6. AI-based taxonomic classifier 3
```

The workflow will retain each individual result and generate a harmonized evidence table.

```text
taxonomy_unite.tsv
taxonomy_eukaryome.tsv
taxonomy_blast.tsv
taxonomy_ai_1.tsv
taxonomy_ai_2.tsv
taxonomy_ai_3.tsv
taxonomy_evidence.tsv
taxonomy_final.tsv
discordant_asvs.fasta
```

The final consensus taxonomy will be generated using predefined decision rules that consider:

* agreement across independent methods;
* assigned taxonomic rank;
* sequence identity and query coverage;
* classifier confidence;
* database-specific limitations;
* taxonomic synonym normalization;
* unresolved or discordant assignments.

Discordant ASVs will be retained separately for manual review rather than forced into an unsupported species-level label.

## Planned Automated Report

ITSdetector will include an automated analysis report to summarize major workflow outputs.

The report is planned to include:

* sequencing depth and quality-control summaries;
* adapter, poly-G, and quality-trimming statistics;
* per-sample read retention;
* ITSxpress or Cutadapt retention summaries;
* DADA2 denoising statistics;
* ASV counts and sequence-length distributions;
* taxonomic assignment rates by database and method;
* benchmark performance metrics for mock communities;
* comparison of preprocessing strategies;
* concordance and discordance among taxonomic tools;
* key warnings, failed samples, and low-depth samples.

The final report will be designed for both technical review and study-level interpretation.

## Directory Structure

```text
ITSdetector/
├── assets/                     # Sample sheets and study-specific input files
├── bin/                        # Helper scripts
├── conf/                       # Optional execution profiles
├── docs/                       # Documentation and study notes
├── modules/local/              # Nextflow process modules
├── params/                     # Study and benchmark YAML parameter files
├── subworkflows/local/         # Reusable Nextflow subworkflows
├── tests/                      # Test input and validation resources
├── main.nf                     # Main workflow entry point
├── nextflow.config             # Default configuration
└── README.md
```

## Example Usage

### Default production analysis

The default production configuration runs ITSxpress with paired-end reads.

```bash
nextflow run main.nf \
  --input assets/samplesheet.csv \
  --outdir results \
  --itsxpress_region ITS2 \
  --itsxpress_taxa F \
  --itsxpress_cluster_id 1.0 \
  -resume
```

### Study-specific configuration

```bash
nextflow run main.nf \
  -params-file params/study_its2.yml \
  --input assets/samplesheet.csv \
  --outdir results/study_its2 \
  -resume
```

### Benchmark configuration

```bash
nextflow run main.nf \
  -params-file params/benchmark_q30.yml \
  --input assets/samplesheet.csv \
  --outdir results/benchmark/q30 \
  -resume
```

## Example Benchmark Parameters

```yaml
run_label: benchmark_q30

quality_trim: true
quality_cutoff: 30

apply_min_length: true
min_length: 50

preprocess_method: both
analysis_mode: both

primer_fwd: "FORWARD_PRIMER_SEQUENCE"
primer_rev: "REVERSE_PRIMER_SEQUENCE"
primer_fwd_adapter: "FORWARD_READTHROUGH_SEQUENCE"
primer_rev_adapter: "REVERSE_READTHROUGH_SEQUENCE"

primer_discard_untrimmed: false

itsxpress_region: ITS2
itsxpress_taxa: F
itsxpress_cluster_id: 1.0
```

## Development Status

### Implemented

* sample-sheet validation;
* raw FASTQ quality control;
* adapter and poly-G trimming;
* optional quality trimming;
* cleaned-read summary generation;
* QIIME 2 import for paired-end and forward-read-only reads;
* ITSxpress paired-end preprocessing;
* ITSxpress forward-read-only preprocessing;
* Cutadapt paired-end primer trimming;
* Cutadapt forward-read-only primer trimming.

### In Development

* DADA2 paired-end and single-end modules;
* maximum expected error benchmarking;
* UNITE classifier workflow;
* EUKARYOME classifier workflow;
* BLAST-based taxonomic refinement;
* benchmark metric calculation;
* mock-community ground-truth comparison;
* automated HTML or Quarto report;
* consensus taxonomy framework;
* AI-assisted taxonomic classifiers;
* discordant-ASV review workflow.

## Intended Applications

ITSdetector is intended for:

* fungal mock-community validation;
* clinical mycobiome studies;
* skin, scalp, gut, and host-associated fungal microbiome research;
* ITS1 and ITS2 amplicon sequencing studies;
* method comparison studies;
* extraction-kit benchmarking;
* primer and preprocessing sensitivity analyses;
* fungal taxonomic reference database comparison.

## Citation

Citation information will be added after public release or publication of the workflow.

## License

License information will be added before public release.

