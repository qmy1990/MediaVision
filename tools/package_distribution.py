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
    with zipfile.ZipFile(a.output, 'w', zipfile.ZIP_DEFLATED, compresslevel=1) as archive:
        for item in manifest['files']:
            path = ROOT / item['path']
            # Encryptions and existing archives/videos gain little from recompression.
            compression = (zipfile.ZIP_STORED if path.suffix in
                           {'.mvsmodels', '.aar', '.apk', '.ipa', '.mp4', '.jar', '.zip'}
                           else zipfile.ZIP_DEFLATED)
            archive.write(path, 'MediaVision/' + item['path'], compress_type=compression)
        archive.write(ROOT / 'manifest/files.json', 'MediaVision/manifest/files.json')
    print('Created:', a.output.resolve())
