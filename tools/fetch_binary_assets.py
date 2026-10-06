#!/usr/bin/env python3
"""Fetch manifest-listed LFS assets for a GitHub source ZIP checkout."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import urllib.parse
import urllib.request
from verify_distribution import ROOT, digest

def fetch(root, ref):
    manifest = json.loads((root / 'manifest/files.json').read_text(encoding='utf-8'))
    for item in manifest['files']:
        if not item.get('lfs'): continue
        relative = Path(item['path'])
        if relative.is_absolute() or '..' in relative.parts: raise ValueError('Unsafe path')
        target = root / relative
        if target.is_file() and target.stat().st_size == item['size'] and digest(target) == item['sha256']:
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_name(target.name + '.download')
        url = ('https://media.githubusercontent.com/media/qmy1990/MediaVision/'
               + urllib.parse.quote(ref, safe='') + '/' + urllib.parse.quote(relative.as_posix(), safe='/'))
        h = hashlib.sha256(); size = 0
        try:
            with urllib.request.urlopen(url, timeout=120) as response, temporary.open('wb') as output:
                while True:
                    block = response.read(1024 * 1024)
                    if not block: break
                    h.update(block); size += len(block); output.write(block)
            if size != item['size'] or h.hexdigest() != item['sha256']:
                raise ValueError(f'Checksum mismatch: {relative}')
            os.replace(temporary, target)
            print('Downloaded:', relative)
        except Exception:
            temporary.unlink(missing_ok=True)
            raise

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, default=ROOT)
    p.add_argument('--ref', default='main', help='Branch or immutable release tag matching your source tree')
    a = p.parse_args(); fetch(a.root.resolve(), a.ref)
