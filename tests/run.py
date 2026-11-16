"""Run the reference and supplementary RTL testbenches with GHDL."""

import shutil
import subprocess
from pathlib import Path
from tempfile import TemporaryDirectory


TESTS = (
    ("tb_reference.vhd", "project_tb"),
    ("tb1_empty.vhd", "project_tb_empty_cases"),
    ("tb2_insert.vhd", "project_tb_insert"),
    ("tb3_pop.vhd", "project_tb_pop"),
    ("tb4_dec.vhd", "project_tb_age"),
    ("tb5_clear.vhd", "project_tb_clear"),
    ("tb6_reset.vhd", "project_tb_reset"),
    ("tb7_handshake.vhd", "project_tb_handshake"),
    ("tb8_combined.vhd", "project_tb_combined_sequences"),
    ("tb9_stress.vhd", "project_tb_stress_near_full"),
)


def main():
    ghdl = shutil.which("ghdl")
    if ghdl is None:
        raise SystemExit("GHDL non trovato nel PATH.")

    tests_dir = Path(__file__).resolve().parent
    rtl = tests_dir.parent / "src" / "project_reti_logiche.vhd"
    sources = [rtl, tests_dir / "tb_utils_pkg.vhd"]
    sources.extend(tests_dir / filename for filename, _ in TESTS)
    settings = ["--std=08", "-frelaxed-rules"]

    with TemporaryDirectory(prefix="reti-logiche-ghdl-") as work_dir:
        subprocess.run([ghdl, "-a", *settings, *map(str, sources)], cwd=work_dir, check=True)

        for number, (filename, entity) in enumerate(TESTS):
            subprocess.run([ghdl, "-e", *settings, entity], cwd=work_dir, check=True)
            result = subprocess.run(
                [ghdl, "-r", *settings, entity, "--assert-level=error", "--stop-time=10ms"],
                cwd=work_dir,
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                encoding="utf-8",
                errors="replace",
            )
            # The original benches deliberately end with a failing assertion.
            marker = f"TESTBENCH {number} PASSED" if number else "TEST PASSATO (EXAMPLE)"
            if f"(assertion failure): Simulation Ended! {marker}" not in result.stdout:
                print(result.stdout, end="")
                raise SystemExit(f"{filename}: test fallito o incompleto.")

            print(f"{filename}: OK", flush=True)

    print(f"{len(TESTS)} testbench superati.")


if __name__ == "__main__":
    main()
