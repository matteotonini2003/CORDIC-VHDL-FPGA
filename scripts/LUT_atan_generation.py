#!/bin/python

###############################################################################
# Description  : Utility script for VHDL atan LUT generation
# File         : ATAN_LUT_generation.py
# Author(s)    : Matteo Tonini
###############################################################################

import math
import os


# =============================================================================
# USER PARAMETERS
# =============================================================================

# Numero di iterazioni CORDIC.
# Con ITERATIONS = 16 vengono generati:
# atan(2^0), atan(2^-1), ..., atan(2^-15)
ITERATIONS = 16

# Larghezza dell'uscita della LUT, uguale alla larghezza di z/theta
ANGLE_WIDTH = 20

# Numero di bit frazionari per la rappresentazione fixed-point dell'angolo.
# Con ANGLE_WIDTH = 20 e ANGLE_FRAC = 16 si ha formato signed Q4.16.
ANGLE_FRAC = 16

# Nome entity VHDL generata
ENTITY_NAME = "ATAN_LUT"

# Nome file VHDL in uscita
OUTPUT_FILE = "atan_lut.vhd"


# =============================================================================
# FUNCTIONS
# =============================================================================

def ceil_log2(n: int) -> int:
    """
    Calcola il numero minimo di bit necessari per indirizzare n elementi.
    Esempio:
        n = 16 -> 4 bit
        n = 17 -> 5 bit
    """
    if n <= 1:
        return 1
    return math.ceil(math.log2(n))


def to_fixed(value: float, frac_bits: int) -> int:
    """
    Converte un numero reale in fixed-point.
    Il valore viene scalato di 2^frac_bits e arrotondato all'intero più vicino.
    """
    return int(round(value * (2 ** frac_bits)))


def check_signed_range(value: int, width: int) -> None:
    """
    Verifica che value sia rappresentabile come signed su width bit.
    """
    min_value = -(2 ** (width - 1))
    max_value = (2 ** (width - 1)) - 1

    if value < min_value or value > max_value:
        raise ValueError(
            f"Value {value} cannot be represented as signed({width-1} downto 0). "
            f"Allowed range: [{min_value}, {max_value}]"
        )


# =============================================================================
# MAIN SCRIPT
# =============================================================================

def main():

    addr_width = ceil_log2(ITERATIONS)

    atan_values = []

    for i in range(ITERATIONS):
        angle_rad = math.atan(2 ** (-i))
        fixed_value = to_fixed(angle_rad, ANGLE_FRAC)

        check_signed_range(fixed_value, ANGLE_WIDTH)

        atan_values.append((i, angle_rad, fixed_value))

    with open(OUTPUT_FILE, "w") as f:

        f.write("library ieee;\n")
        f.write("use ieee.std_logic_1164.all;\n")
        f.write("use ieee.numeric_std.all;\n\n")

        f.write(f"entity {ENTITY_NAME} is\n")
        f.write("    port(\n")
        f.write(f"        addr       : in  unsigned({addr_width-1} downto 0);\n")
        f.write(f"        atan_value : out signed({ANGLE_WIDTH-1} downto 0)\n")
        f.write("    );\n")
        f.write(f"end entity {ENTITY_NAME};\n\n")

        f.write(f"architecture rtl of {ENTITY_NAME} is\n")
        f.write("begin\n\n")

        f.write("    process(addr)\n")
        f.write("    begin\n")
        f.write("        case to_integer(addr) is\n")

        for i, angle_rad, fixed_value in atan_values:
            comma_comment = (
                f"-- atan(2^-{i}) = {angle_rad:.12f} rad, "
                f"fixed = {fixed_value}"
            )

            f.write(
                f"            when {i:2d} => "
                f"atan_value <= to_signed({fixed_value:6d}, {ANGLE_WIDTH}); "
                f"{comma_comment}\n"
            )

        f.write("            when others => atan_value <= (others => '0');\n")
        f.write("        end case;\n")
        f.write("    end process;\n\n")

        f.write(f"end architecture rtl;\n")

    print("VHDL atan LUT generated successfully.")
    print(f"Output file      : {os.path.abspath(OUTPUT_FILE)}")
    print(f"Entity name      : {ENTITY_NAME}")
    print(f"Iterations       : {ITERATIONS}")
    print(f"Address width    : {addr_width} bit")
    print(f"Angle width      : {ANGLE_WIDTH} bit")
    print(f"Angle format     : Q{ANGLE_WIDTH - ANGLE_FRAC}.{ANGLE_FRAC}")
    print(f"Last LUT element : atan(2^-{ITERATIONS-1})")


if __name__ == "__main__":
    main()