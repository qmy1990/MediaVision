#!/usr/bin/env python3
"""Deploy an already encrypted runtime package without exposing its codec/key."""
import argparse
import shutil
from pathlib import Path
from verify_distribution import ROOT, verify

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--platform', choices=['android', 'ios', 'windows', 'linux'], required=True)
    p.add_argument('--output', type=Path, required=True, help='Destination mediavision.mvsmodels file')
    a = p.parse_args()
    verify()
    source = ROOT / 'models' / a.platform / 'mediavision.mvsmodels'
    if source.read_bytes()[:8] != b'MVSMDL01': raise ValueError('Not an encrypted SDK model package')
    a.output.parent.mkdir(parents=True, exist_ok=True)
    if a.output.resolve() != source.resolve(): shutil.copy2(source, a.output)
    print('Deployed:', a.output.resolve())
