# CORDIC VHDL FPGA Project

This repository contains the VHDL implementation of a CORDIC-based hardware module for Cartesian to polar coordinate transformation.

The design receives two signed Cartesian coordinates, `x` and `y`, and computes the corresponding magnitude `rho` and phase angle `theta`. The implementation is based on the CORDIC algorithm in vectoring mode and is intended for FPGA implementation.

## Project overview

The project implements a fixed-point CORDIC architecture for converting Cartesian coordinates into polar coordinates:

```text
(x, y) -> (rho, theta)
```

The main goal of the design is to compute:

```text
rho   = sqrt(x^2 + y^2)
theta = atan2(y, x)
```

without directly implementing complex arithmetic operations such as square roots, divisions or trigonometric functions. Instead, the CORDIC algorithm uses additions, subtractions, arithmetic shifts and a small lookup table containing the arctangent coefficients.

## Main features

* CORDIC algorithm in vectoring mode
* Fixed-point signed input format Q2.14
* Internal datapath format Q4.16
* 16 CORDIC iterations
* Arctangent lookup table
* CORDIC gain correction
* Quadrant correction for vectors with negative `x`
* Special handling of the zero vector `(0, 0)`
* VHDL testbench for functional verification
* Vivado implementation targeting a Zynq-7000 FPGA device
* FPGA wrapper for testing with switches, buttons and LEDs
* Final project report included in the repository

## Repository structure

```text
CORDIC-VHDL-FPGA/
├── src/        Synthesizable VHDL source files
├── tb/         VHDL testbench files
├── modelsim/   ModelSim simulation scripts and simulation-related files
├── vivado/     Vivado constraints and implementation-related files
├── scripts/    Python scripts used to generate LUT coefficients
├── doc/        Final report and documentation
├── README.md   Project documentation
├── .gitignore  Files and folders excluded from version control
└── LICENSE     License file
```

## Folder description

### `src/`

This folder contains the synthesizable VHDL source files of the project.

Main files include:

```text
CORDIC.vhd
CORDIC_WRAPPER.vhd
atan_lut.vhd
Counter.vhd
DFF_N.vhd
DFF_N_Signed.vhd
full_adder.vhd
ripple_carry_adder.vhd
```

### `tb/`

This folder contains the VHDL testbench used to verify the functional behavior of the CORDIC core.

Main file:

```text
CORDIC_tb.vhd
```

### `modelsim/`

This folder contains simulation-related files, such as build scripts, clean scripts, waveform files or screenshots.

### `vivado/`

This folder contains Vivado-related files, such as FPGA constraints and implementation files required to reproduce the FPGA setup.

### `scripts/`

This folder contains the Python script used to generate the arctangent lookup table coefficients used by the CORDIC algorithm.

### `doc/`

This folder contains the final project report and documentation files.

## Fixed-point formats

The input coordinates are represented in signed Q2.14 format on 16 bits.

The internal datapath and the outputs are represented in signed Q4.16 format on 20 bits.

The output `rho` represents the magnitude of the input vector, while `theta` represents the corresponding angle in radians.

## CORDIC gain correction

The CORDIC rotations introduce a constant gain. For this reason, the final magnitude is corrected by multiplying the final `x` value by the inverse CORDIC gain:

```text
K_CORDIC ≈ 0.607252935
```

In the VHDL implementation, this value is represented in fixed-point format using the integer value:

```text
39797
```

## Functional verification

The design was verified through simulation using a VHDL testbench. The testbench covers several relevant cases, including:

* vector on the positive x-axis;
* vectors in the first, second, third and fourth quadrants;
* zero vector;
* generic non-symmetric input vectors;
* start signal applied while the core is already running.

The simulation verifies the correct generation of `rho`, `theta` and `valid`.

## FPGA implementation

The project includes a wrapper module for possible FPGA implementation and testing. The wrapper connects the CORDIC core to physical inputs and outputs such as buttons, switches and LEDs.

The implementation was tested using Vivado on a Zynq-7000 FPGA device.

## Tools used

* VHDL
* ModelSim
* Xilinx Vivado
* Python
* LaTeX

## How to use

Clone the repository:

```bash
git clone https://github.com/matteotonini2003/CORDIC-VHDL-FPGA.git
```

To simulate the design, add the VHDL files from `src/` and the testbench from `tb/` to your simulator.

To implement the design on FPGA, create a Vivado project, add the VHDL source files from `src/`, add the constraint files from `vivado/`, and select the wrapper module as top-level entity.

## Authors

Matteo Tonini
Antonio Tuma
