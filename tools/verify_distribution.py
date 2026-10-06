#!/usr/bin/env python3
"""Verify published file integrity and the binary-only SDK boundary."""
import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FORBIDDEN_SUFFIXES = {'.metal', '.glsl', '.vert', '.frag', '.comp', '.spv', '.air',
                      '.p12', '.pem', '.mobileprovision', '.keystore', '.jks', '.pdb'}
SOURCE_SUFFIXES = {'.c', '.cpp', '.mm', '.m', '.java', '.py', '.sh', '.ps1', '.bat'}

def digest(path):
    h = hashlib.sha256()
    with path.open('rb') as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b''):
            h.update(block)
    return h.hexdigest()

def verify(root=ROOT):
    manifest = json.loads((root / 'manifest/files.json').read_text(encoding='utf-8'))
    errors = []
    for item in manifest['files']:
        relative = Path(item['path'])
        if relative.is_absolute() or '..' in relative.parts:
            errors.append('Unsafe manifest path'); continue
        path = root / relative
        if not path.is_file():
            errors.append(f'Missing: {relative}'); continue
        if path.suffix in FORBIDDEN_SUFFIXES:
            errors.append(f'Forbidden source/signing file: {relative}')
        if path.suffix in SOURCE_SUFFIXES and relative.parts[0] not in {'demos', 'tools'}:
            errors.append(f'Implementation source outside integration trees: {relative}')
        with path.open('rb') as stream:
            pointer = stream.read(128).startswith(b'version https://git-lfs.github.com/spec/v1')
        if pointer:
            errors.append(f'LFS pointer: {relative}; run git lfs pull or tools/fetch_binary_assets.py'); continue
        if path.stat().st_size != item['size'] or digest(path) != item['sha256']:
            errors.append(f'Integrity mismatch: {relative}')
    for folder in ('src', 'source', 'shaders', 'native', 'platforms'):
        if (root / folder).exists(): errors.append(f'Private source directory: {folder}')
    if errors:
        raise RuntimeError('\n'.join(errors))
    print(f"PASS: {len(manifest['files'])} files verified; binary SDK with public integration source only.")
    return manifest

if __name__ == '__main__':
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--root', type=Path, default=ROOT)
    verify(p.parse_args().root.resolve())
