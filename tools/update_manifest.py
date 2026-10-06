#!/usr/bin/env python3
"""Record hashes of public distribution files after a binary release update."""
import json
import subprocess
from pathlib import Path
from verify_distribution import ROOT, digest, FORBIDDEN_SUFFIXES, SOURCE_SUFFIXES

SKIP_DIRS = {'.git', 'build', '.gradle', '.cxx', '__pycache__', 'Pods', 'DerivedData',
             'xcuserdata', 'distribution-output'}
SKIP_FILES = {'.DS_Store', 'local.properties'}

if __name__ == '__main__':
    files = []
    for path in sorted(ROOT.rglob('*')):
        relative = path.relative_to(ROOT)
        if not path.is_file() or any(part in SKIP_DIRS for part in relative.parts): continue
        if path.name in SKIP_FILES or path.suffix in {'.pyc', '.log', '.tmp', '.download'}: continue
        if relative.as_posix() == 'manifest/files.json': continue
        if path.suffix in FORBIDDEN_SUFFIXES: raise RuntimeError(f'Forbidden file: {relative}')
        if path.suffix in SOURCE_SUFFIXES and relative.parts[0] not in {'demos','tools'}:
            raise RuntimeError(f'Unexpected implementation: {relative}')
        attr = subprocess.check_output(['git', '-C', str(ROOT), 'check-attr', 'filter', '--', str(relative)], text=True)
        files.append(dict(path=relative.as_posix(), size=path.stat().st_size,
                          sha256=digest(path), lfs=attr.strip().endswith(': lfs')))
    (ROOT/'manifest').mkdir(exist_ok=True)
    (ROOT/'manifest/files.json').write_text(json.dumps(dict(
        schema=1, sdk='com.moon.mediavision', version='0.4.0', files=files),
        ensure_ascii=False, indent=2)+'\n', encoding='utf-8')
    print('Recorded', len(files), 'public files.')
