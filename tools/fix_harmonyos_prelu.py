#!/usr/bin/env python3
"""Repair TFLite per-channel PReLU metadata in MindSpore Lite 2.7 MindIR Lite.

Uses flatc and the matching open-source MindSpore schema, never tensor
arithmetic or model inference. Constant weight bytes remain unchanged.
Device task-accuracy validation is still required after conversion.
"""
import argparse, hashlib, json, math, subprocess, tempfile
from pathlib import Path


def repair(src: Path, dst: Path, flatc: Path, schema: Path):
    original = src.read_bytes()
    with tempfile.TemporaryDirectory(prefix='mvs-prelu-') as folder:
        work = Path(folder)
        binary = work / 'model.ms'
        binary.write_bytes(original)
        subprocess.run([str(flatc), '-t', '--strict-json', '--defaults-json', '--raw-binary',
                        '-o', str(work), str(schema), '--', str(binary)], check=True,
                       stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        text = work / 'model.json'
        model = json.loads(text.read_text())
        changes = []
        for node in model['nodes']:
            primitive = node['primitive']
            if primitive['value_type'] != 'PReLUFusion':
                continue
            if len(node['inputIndex']) != 2:
                raise ValueError('PReLU must have input and slope tensors')
            slope = model['allTensors'][node['inputIndex'][1]]
            dims = slope['dims']
            channels = math.prod(dims)
            if channels <= 1:
                continue
            # A vector of slopes is per-channel. Leading singleton dimensions
            # from TFLite broadcasting must not become a shared scalar in NNRT.
            if sum(d != 1 for d in dims) != 1 or not slope.get('data'):
                raise ValueError('Only constant per-channel PReLU slopes can be repaired')
            if not primitive['value'].get('channel_shared') and dims == [channels]:
                continue
            changes.append({'node': node['name'], 'previous_shape': dims,
                            'previous_shared': primitive['value'].get('channel_shared'),
                            'shape': [channels], 'shared': False})
            slope['dims'] = [channels]
            primitive['value']['channel_shared'] = False
        if changes:
            text.write_text(json.dumps(model, separators=(',', ':')))
            subprocess.run([str(flatc), '-b', '--strict-json', '--filename-ext', 'ms',
                            '-o', str(work), str(schema), str(text)], check=True,
                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
            result = binary.read_bytes()
        else:
            result = original
        dst.parent.mkdir(parents=True, exist_ok=True)
        dst.write_bytes(result)
    return {'source_sha256': hashlib.sha256(original).hexdigest(),
            'sha256': hashlib.sha256(result).hexdigest(), 'bytes': len(result),
            'repaired_nodes': len(changes), 'changes': changes,
            'validation_status': 'device_accuracy_validation_required'}


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--input', type=Path, required=True)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--flatc', type=Path, required=True)
    p.add_argument('--schema', type=Path, required=True, help='Matching schema/model.fbs')
    a = p.parse_args()
    report = repair(a.input.resolve(), a.output.resolve(), a.flatc.resolve(), a.schema.resolve())
    a.output.with_suffix('.prelu-fix.json').write_text(json.dumps(report, indent=2)+'\n')
    print('PReLU repaired:', report['repaired_nodes'])

if __name__ == '__main__':
    main()
