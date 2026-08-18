# ARICH Edge AI Trigger FPGA Acceleration Pipeline

## Executive Overview
This repository contains the complete end-to-end hardware acceleration and machine learning pipeline for the Aerogel Ring Imaging Cherenkov (ARICH) Edge AI Trigger system. Developed to enable ultra-low-latency, real-time event identification and particle classification, this project integrates deep learning algorithms with Field Programmable Gate Array (FPGA) hardware targets.

The architecture covers the full system lifecycle: exploratory data analysis, high-accuracy quantized model development, High-Level Synthesis (HLS) with hls4ml, C-simulation and resource estimation, AXI4-Stream packet framing, and Vivado block-design hardware implementation targeting Virtex UltraScale devices.

---

## Author & Project Credits

* **Primary Developer & Researcher:** Nahom Wondale Habtamu  
  * *Affiliation:* Electrical and Computer Engineering Student, Addis Ababa University (AAU)
* **Research Supervision:** Assistant Professor Dr. Yun-Tsung Lai
* **Host Institution & Program:** High Energy Accelerator Research Organization (KEK), Tsukuba, Ibaraki, Japan (KEK Summer Student Program Collaboration)
* **Project Impact:** A key milestone in implementing real-time machine learning inference directly on FPGA edge nodes, achieving high signal classification efficiency (up to 97% classification performance) within microsecond-level latency constraints required for high-luminosity particle collider experiments.

---

## Project Structure & Module Breakdown

The repository is structured logically to maintain a clear boundary between algorithmic design, hardware compilation, build reports, and visualization assets.

### `01_data_analysis/`
Focuses on pre-processing raw detector signals, noise suppression, and data framing for neural network ingestion.
* **`data/dataset_individual_files/`**: Individual processed detector signal feature vectors and ground-truth label formats.
* **`scripts/`**: Python scripts for reading event files, performing grid spatial transformations, and extracting Cherenkov ring parameters.

### `02_model_development/`
Contains model architecture exploration, baseline training, quantization-aware training (QAT), and pruning routines.
* **`notebooks/97% MODEL FINAL for N>=5.ipynb`**: Primary production notebook demonstrating high-accuracy ring classification (>= 97%) for hit multiplicities N >= 5.
* **`notebooks/*.ipynb`**: Iterative model architecture trials (CNN variants, Maxout architectures, and depthwise separable convolutions).

### `03_hls4ml_synthesis/`
Contains the C-synthesis bridge converting trained deep learning models into optimized C++/RTL structures using hls4ml.
* **`src/`**: Top-level C++ synthesis source code (myproject.cpp, myproject.h), testbenches, directives, and Vitis HLS configuration settings (hls_config.cfg, directives.tcl).
* **`reports/`**: Full C-Synthesis, C-Simulation, and Co-Simulation performance summaries containing timing schedules, DSP/LUT utilization profiles, and clock slack reports.

### `05_vivado_hardware/`
Hosts the full Xilinx Vivado hardware design for board-level deployment.
* **`src/`**: Top-level Verilog/VHDL design wrappers (top_wrapper.v) managing clock domain crossing (CDC) and AXI4-Stream interface logic.
* **`constraints/`**: Pin mapping and clock constraint definitions (constraints.xdc).
* **`bd/`**: Vivado IP Integrator Block Designs (.bd) connecting the synthesized HLS IP core with clocking wizards (clk_wiz) and system interconnects.
* **`ip_stubs/`**: Instantiation templates and stub wrappers for integrated hardware IP cores (ILA, VIO, Clocking Wizards).
* **`project_1.xpr`**: Top-level Vivado project file.

### `docs/plots/`
Comprehensive performance evaluation, hardware characterization graphs, and diagnostic visual outputs.
* **`best_ring_plots/`**, **`plots_24x36/`**, **`plots_cartesian/`**, **`strong_ring_plots/`**: Spatial reconstructions of particle hit distributions across detector coordinate arrays.
* **`*.png`**: ROC curves, resource consumption breakdowns, signal-to-noise distributions, and quantization efficiency comparisons.

---

## System Architecture & Technical Workflow

1. Raw Detector Signals -> 01 Data Analysis & Transformation
2. 01 Data Analysis -> 02 Quantized Model Training (QKeras / Keras) [Target: 97% Accuracy]
3. 02 Model Training -> 03 HLS4ML C++ Translation & C-Synthesis [Optimized C-RTL]
4. 03 C-Synthesis -> 05 Vivado Top Wrapper & Block Design [Xilinx Virtex UltraScale Target]

* Feature Extraction: Raw Cherenkov photon hit matrices are processed into normalized spatial inputs.
* Quantization & Sparsification: Models are compressed using bit-width reduction to minimize LUT/FF consumption while maintaining target classification accuracy.
* C-Synthesis: hls4ml generates pipeline-parallelized C++ representations tuned for fixed-point integer math (ap_fixed<>).
* Hardware Integration: The generated IP is embedded inside top_wrapper.v alongside clocking wizards and AXI-Stream interface interfaces for real-time trigger decisions.

---

## Quick Start & Reproduction Guide

### Prerequisites
* **Operating System:** RHEL / CentOS / Ubuntu Linux
* **Python Environment:** Python 3.8+ with TensorFlow, QKeras, hls4ml, NumPy, Matplotlib, Scikit-Learn
* **FPGA Toolchain:** AMD/Xilinx Vivado Design Suite & Vitis HLS (Tested on 2023.2 / 2026 releases)

### Installation & Execution

1. Clone the Repository:
   git clone https://github.com/nahomice/arich-edge-ai-trigger.git
   cd arich-edge-ai-trigger

2. Install Python Dependencies:
   pip install -r requirements.txt

3. Run Model Training & Analysis:
   Launch Jupyter Notebook and run the final production model:
   jupyter notebook 02_model_development/notebooks/"97% MODEL FINAL for N>=5.ipynb"

4. Inspect HLS Synthesis & Vivado Projects:
   Review C++ sources and reports in 03_hls4ml_synthesis/
   Open the Vivado hardware project:
   vivado 05_vivado_hardware/project_1.xpr &

---

## License

This project is licensed under the MIT License - see the LICENSE file for details.
