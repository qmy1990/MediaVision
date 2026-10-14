#!/usr/bin/env python3
"""Convert the three MediaVision TFLite models on Linux x86_64.

Conversion is separate from private encryption/packaging and device acceptance.
Output files are candidates until numerical validation on Linux and OHOS passes.
"""
import argparse
import hashlib
import json
import os
import platform
import subprocess
from pathlib import Path

ROLES = ('portrait', 'detector', 'landmarker')


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--tool-root', type=Path, required=True)
    p.add_argument('--inputs', type=Path, required=True,
                   help='Directory containing portrait/detector/landmarker.tflite')
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--config', type=Path,
                   help='Optional fusion config; Huawei requires a source build for disabling Clip conversion')
    p.add_argument('--tool-version', default='2.7.0')
    p.add_argument('--nnrt-prelu-fix', action='store_true',
                   help='Repair per-channel PReLU metadata after conversion (recommended for NNRT)')
    p.add_argument('--flatc', type=Path)
    p.add_argument('--schema', type=Path, help='Matching MindSpore schema/model.fbs')
    a = p.parse_args()
    if a.nnrt_prelu_fix and (not a.flatc or not a.schema):
        p.error('--nnrt-prelu-fix requires --flatc and --schema')
    if platform.system() != 'Linux' or platform.machine() != 'x86_64':
        p.error('The downloaded converter requires Linux x86_64 (a VM is supported).')
    root = a.tool_root.resolve()
    exe = root / 'tools/converter/converter/converter_lite'
    if not exe.is_file():
        p.error('converter_lite not found in tool-root')
    out = a.output.resolve()
    out.mkdir(parents=True, exist_ok=True)
    env = dict(os.environ, LD_LIBRARY_PATH=str(root / 'tools/converter/lib') +
               ':' + os.environ.get('LD_LIBRARY_PATH', ''))
    help_result = subprocess.run([str(exe), '--help'], env=env, capture_output=True, text=True)
    if help_result.returncode:
        raise RuntimeError(help_result.stderr)
    (out / 'converter-help.txt').write_text(help_result.stdout + help_result.stderr)
    manifest = {'converter': 'MindSpore Lite', 'version': a.tool_version,
                'converter_sha256': hashlib.sha256(exe.read_bytes()).hexdigest(),
                'system': platform.platform(), 'architecture': platform.machine(),
                'format': 'MINDIR_LITE', 'validation_status': 'not_run_by_converter_script',
                'models': []}
    for role in ROLES:
        src = a.inputs.resolve() / (role + '.tflite')
        if not src.is_file():
            raise FileNotFoundError(src)
        cmd = [str(exe), '--fmk=TFLITE', '--modelFile=' + str(src),
               '--outputFile=' + str(out / role), '--saveType=MINDIR_LITE',
               '--inputDataFormat=NHWC', '--outputDataFormat=NHWC',
               '--optimize=general', '--fp16=off', '--infer=true']
        if a.config:
            cmd.append('--configFile=' + str(a.config.resolve()))
        run = subprocess.run(cmd, env=env, capture_output=True, text=True)
        (out / (role + '.conversion.log')).write_text(run.stdout + run.stderr)
        dst = out / (role + '.ms')
        if run.returncode or 'CONVERT RESULT SUCCESS:0' not in run.stdout + run.stderr or not dst.is_file():
            raise RuntimeError(f'{role} conversion failed; inspect conversion log')
        repair_report = None
        if a.nnrt_prelu_fix:
            from fix_harmonyos_prelu import repair
            repair_report = repair(dst, dst, a.flatc.resolve(), a.schema.resolve())
            (out / (role + '.prelu-fix.json')).write_text(json.dumps(repair_report, indent=2)+'\n')
        manifest['models'].append({'role': role, 'command': cmd,
                                  'source_sha256': hashlib.sha256(src.read_bytes()).hexdigest(),
                                  'sha256': hashlib.sha256(dst.read_bytes()).hexdigest(),
                                  'bytes': dst.stat().st_size, 'nnrt_prelu_fix': repair_report})
        print(f'{role}: converted {dst.stat().st_size} bytes', flush=True)
    (out / 'conversion.json').write_text(json.dumps(manifest, indent=2) + '\n')


if __name__ == '__main__':
    main()
