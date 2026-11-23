#!/usr/bin/env python3
"""Compile using an installed Garmin Connect IQ SDK and the device library."""
import argparse
import os
import subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--sdk", default=os.environ.get("CONNECT_IQ_SDK"), required=not os.environ.get("CONNECT_IQ_SDK"))
    parser.add_argument("--key", type=Path, required=True, help="RSA PKCS8 DER developer signing key")
    parser.add_argument("--device", default="fr245", choices=["fr245", "fr245m"])
    parser.add_argument("--tests", action="store_true")
    parser.add_argument("--package", action="store_true")
    args = parser.parse_args()
    sdk = Path(args.sdk).resolve()
    compiler = sdk / "bin" / ("monkeyc.bat" if os.name == "nt" else "monkeyc")
    target_dir = ROOT / "build"
    target_dir.mkdir(exist_ok=True)
    stem = "LcdHr245" if args.device == "fr245" else "LcdHr245Music"
    if args.tests:
        stem += "Tests"
    output = target_dir / (stem + (".iq" if args.package else ".prg"))
    cmd = [str(compiler), "-f", "test.jungle" if args.tests else "monkey.jungle",
           "-o", str(output), "-y", str(args.key.resolve()), "-w", "-l", "1"]
    if args.package:
        cmd += ["-e", "-r"]
    else:
        cmd += ["-d", args.device]
        cmd += ["-t"] if args.tests else ["-r"]
    subprocess.run(cmd, cwd=ROOT, check=True)
    print(output)


if __name__ == "__main__":
    main()
