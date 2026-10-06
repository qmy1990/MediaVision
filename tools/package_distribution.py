#!/usr/bin/env python3
"""Create a complete binary SDK ZIP from verified public files; no private code."""
import argparse
from pathlib import Path
import zipfile
from verify_distribution import ROOT, verify

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--output', type=Path, default=ROOT / 'distribution-output/MediaVision-0.4.0.zip')
    a = p.parse_args()
    manifest = verify()
    a.output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(a.output, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for item in manifest['files']:
            archive.write(ROOT / item['path'], 'MediaVision/' + item['path'])
        archive.write(ROOT / 'manifest/files.json', 'MediaVision/manifest/files.json')
    print('Created:', a.output.resolve())
