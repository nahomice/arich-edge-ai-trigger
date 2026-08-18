# ARICH Edge AI Trigger FPGA Hardware Acceleration

Comprehensive repository containing the complete end-to-end pipeline for the Belle II ARICH Edge AI Trigger system, including data analysis, model training, HLS4ML C-synthesis, and Vivado hardware integration.

## 📂 Repository Structure

* `01_data_analysis/`: Data preprocessing, exploratory scripts, and individual dataset files.
* `02_model_development/`: Jupyter notebooks (`97% MODEL FINAL`) and Keras/QKeras model architectures.
* `03_hls4ml_synthesis/`: Vitis HLS C++ source files, `Tcl` configurations, and synthesis reports.
* `05_vivado_hardware/`: AXI-Stream wrappers and IP core integration scripts.
* `docs/plots/`: Performance visualization graphs, ROC curves, and ring plots.

## 🚀 Quick Start

1. **Environment Setup**: `pip install -r requirements.txt`
2. **Model Training**: Open `02_model_development/notebooks/97% MODEL FINAL for N>=5.ipynb`
3. **HLS Synthesis**: Run the C-synthesis script under `03_hls4ml_synthesis/src/`
