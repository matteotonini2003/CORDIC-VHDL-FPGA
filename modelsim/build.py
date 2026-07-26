# -------------------------------------------------------------------------- #
# ModelSim build script for CORDIC project
# -------------------------------------------------------------------------- #

from pathlib import Path
import subprocess
import sys
import shutil

# Folder paths
MODELSIM_DIR = Path(__file__).resolve().parent
ROOT_DIR = MODELSIM_DIR.parent

# VHDL compile order
VHDL_FILES = [
    ROOT_DIR / "src" / "full_adder.vhd",
    ROOT_DIR / "src" / "ripple_carry_adder.vhd",
    ROOT_DIR / "src" / "DFF_N.vhd",
    ROOT_DIR / "src" / "DFF_N_Signed.vhd",
    ROOT_DIR / "src" / "Counter.vhd",
    ROOT_DIR / "src" / "atan_lut.vhd",
    ROOT_DIR / "src" / "CORDIC.vhd",
    ROOT_DIR / "src" / "CORDIC_WRAPPER.vhd",
    ROOT_DIR / "tb"  / "CORDIC_tb.vhd",
]

TOP_TB = "CORDIC_tb"

# Set this to False if you only want compilation
RUN_SIMULATION = True


def run_cmd(cmd, check=True):
    print("\n> " + " ".join(str(c) for c in cmd))
    result = subprocess.run(cmd, cwd=MODELSIM_DIR, check=check)
    return result


def main():
    print("=== CORDIC ModelSim build ===")

    # Check that all files exist
    missing_files = [f for f in VHDL_FILES if not f.exists()]
    if missing_files:
        print("\nERROR: missing files:")
        for f in missing_files:
            print("  " + str(f))
        sys.exit(1)

    # Create work library
    work_dir = MODELSIM_DIR / "work"

    if work_dir.exists():
        shutil.rmtree(work_dir)

    run_cmd(["vlib", "work"])
    run_cmd(["vmap", "work", "work"], check=False)

    # Compile all VHDL files
    for file in VHDL_FILES:
        run_cmd(["vcom", "-2008", str(file)])

    print("\nCompilation completed successfully.")

    # Optional simulation
    if RUN_SIMULATION:
        print("\nStarting simulation...")
        run_cmd([
            "vsim",
            "-c",
            f"work.{TOP_TB}",
            "-do",
            "run -all; quit -f"
        ], check=False)

    print("\nBuild finished.")


if __name__ == "__main__":
    main()