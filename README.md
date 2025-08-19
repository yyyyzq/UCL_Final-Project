# FPGA-Accelerated Optical Channel Modeling

This repository contains the implementation and supporting scripts for my MSc dissertation at University College London:  
**"FPGA-Accelerated Digital Fiber Channel Modeling / Hardware-Accelerated Evaluation of DSP in Optical Channels" (2025).**

## 🔹 Project Overview
The goal of this project is to build a low-cost, hardware-accurate verification platform for **digital signal processing (DSP) algorithms** in coherent optical receivers.  
The work is based on the open-source **[CHOICE framework](https://www.cse.chalmers.se/research/group/vlsi/choice/)** developed at Chalmers University, but extended with customized modules and FPGA-based implementations.

Key features:
- **Channel Modeling**: Additive White Gaussian Noise (AWGN) and Phase Noise (PN) models implemented in fixed-point arithmetic.
- **Modulation**: Support for QAM formats, with 16QAM used as the primary test case.
- **Carrier Phase Recovery**: A customized Blind Phase Search (BPS) algorithm with sliding window averaging to improve robustness under PN.
- **FPGA Deployment**: Hardware modules synthesized and tested on the Xilinx KC705 FPGA, including real-time constellation output via UART.
- **Simulation Framework**: VHDL-based testbenches exporting IQ samples, counters, and BER metrics using TextIO.
- **Python Integration**: Scripts for BER analysis, constellation visualization, and real-time monitoring of FPGA outputs.

## 🔹 Repository Structure
- `origin_sim/` – Simulation-oriented design files.
- `origin_const/` – Channel impairment modules.
- `originBER_sim/` – BER counting and analysis.
- `project_1/`, `project_2/` – Experiment-specific implementations.
- `BER_Compare.py`, `constellation.py`, `real_time_show.py` – Python scripts for post-processing and visualization.

> Note: Large Vivado-generated build artifacts (`.dcp`, `.runs/`, `.jou`, etc.) are excluded via `.gitignore`.

## 🔹 Dependencies
- [CHOICE Framework (Chalmers)](https://www.cse.chalmers.se/research/group/vlsi/choice/)  
- Xilinx Vivado HL Design Edition (for synthesis and hardware deployment)  
- Python 3.x with:
  - `numpy`
  - `matplotlib`
  - `pyserial`

## 🔹 Results
- Verified AWGN and PN impairments via simulation and hardware experiments.
- Implemented and tested BPS algorithm with sliding window extension.
- Demonstrated real-time constellation diagrams streamed from FPGA via UART.

## 🔹 Future Work
- Integrate PMD modeling and advanced DSP algorithms.
- Extend memory support with DDR3/SD card for data injection and offline playback.
- Optimize FPGA resource usage for larger-scale modulation formats.

---

📌 This repository documents the development and experiments of my UCL MSc dissertation.  
For more details, please refer to the [CHOICE Project](https://github.com/chalmers-choices/choice) and my thesis report.
