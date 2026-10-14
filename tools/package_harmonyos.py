#!/usr/bin/env python3
"""Package the published HarmonyOS binaries, examples and encrypted models.

Only public distribution files are copied; no proprietary build or signing
configuration is required. Run after git lfs pull when cloning the repository.
"""
import argparse
import hashlib
import json
from pathlib import Path
import zipfile

ROOT = Path(__file__).resolve().parents[1]
DIRECTORIES = ('sdk/harmonyos', 'models/harmonyos', 'installers/harmonyos',
               'include/mvs', 'demos/harmonyos', 'demos/harmonyos-native', 'licenses')
FILES = ('LICENSE.md', 'CHANGELOG.md', 'docs/API.md', 'docs/HARMONYOS.md',
         'tools/build_harmonyos_demo.py', 'tools/convert_harmonyos_models.py',
         'tools/fix_harmonyos_prelu.py', 'tools/package_harmonyos.py')
SKIP_DIRS = {'build', '.hvigor', 'oh_modules', 'node_modules', '.git', '__pycache__', 'xcuserdata'}
FORBIDDEN = {'.metal', '.glsl', '.vert', '.frag', '.comp', '.spv', '.air', '.p12',
             '.pem', '.p7b', '.cer', '.mobileprovision', '.keystore', '.jks', '.ms', '.tflite'}
README = """# MediaVision HarmonyOS 0.4.3

最低 HarmonyOS 6.0.0 / API20。SDK可免费商用。

- SDK：sdk/harmonyos（ARM64/x86_64，共享库、静态核心及ArkTS HAR）。
- 公共接口：include/mvs/harmonyos.h；C/C++示例：demos/harmonyos-native。
- 相机实时Demo：demos/harmonyos；模型：models/harmonyos/mediavision.mvsmodels。
- HAP：installers/harmonyos/MediaVisionDemo-api20-unsigned.hap，安装前必须配置自己的签名。
- 接入与构建、模型和padding接口：docs/HARMONYOS.md。

使用最新官方DevEco Studio与配套SDK/Hvigor/Node，运行tools/build_harmonyos_demo.py准备完整Demo构建目录；该工具使用发布二进制。再在DevEco Studio打开生成的目录、配置自己的设备签名并运行。

模型采用系统MindSpore Lite/NNRT加速器，效果采用Vulkan。已在ADA-AL00 / HarmonyOS6.1.0.135 / API24验证；x86_64和最低API20为编译支持范围。

Minimum HarmonyOS 6.0.0 / API20. The SDK is free for commercial integration. Native ARM64/x86_64 libraries, HAR, public C/C++ APIs, live-camera demo, encrypted models and an unsigned HAP are included. Build the demo with official DevEco Studio tools and configure your own signing credentials. Models use strict NNRT/NPU and effects use Vulkan. Device testing covers ARM64/API24.

File checksums are listed in PACKAGE-MANIFEST.json. Verify extracted contents:

```bash
python3 -c 'import json,hashlib,pathlib; m=json.load(open("PACKAGE-MANIFEST.json")); assert all(hashlib.sha256(pathlib.Path(f["path"]).read_bytes()).hexdigest()==f["sha256"] for f in m["files"]); print("PASS")'
```

Repository: https://github.com/qmy1990/MediaVision
"""


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path,
                        default=ROOT/'packages/harmonyos/MediaVision-harmonyos-0.4.3.zip')
    args = parser.parse_args()
    paths = {ROOT/p for p in FILES}
    for directory in DIRECTORIES:
        paths.update(p for p in (ROOT/directory).rglob('*') if p.is_file())
    content = {'README.md': README.encode()}
    for p in sorted(paths):
        relative = p.relative_to(ROOT)
        if any(part in SKIP_DIRS for part in relative.parts) or p.name in {'.DS_Store', 'local.properties'}:
            continue
        if p.is_symlink() or p.suffix in FORBIDDEN:
            raise RuntimeError('Unexpected private file: '+str(relative))
        data = p.read_bytes()
        if data.startswith(b'version https://git-lfs.github.com/spec/v1'):
            raise RuntimeError('Run git lfs pull first: '+str(relative))
        content[relative.as_posix()] = data
    model = content['models/harmonyos/mediavision.mvsmodels']
    validation = json.loads(content['models/harmonyos/conversion-validation-2.7.json'])
    assert hashlib.sha256(model).hexdigest() == validation['encrypted_package_sha256']
    entries = [{'path': p, 'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
               for p, data in sorted(content.items())]
    content['PACKAGE-MANIFEST.json'] = (json.dumps({'sdk': 'com.moon.mediavision', 'version': '0.4.3',
        'min_api': 20, 'files': entries}, ensure_ascii=False, indent=2)+'\n').encode()
    output = args.output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name, data in sorted(content.items()):
            info = zipfile.ZipInfo('MediaVision-harmonyos-0.4.3/'+name, date_time=(2026, 10, 15, 0, 0, 0))
            info.external_attr = (0o100755 if name.endswith('.py') else 0o100644) << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, data)
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
        for entry in entries:
            assert hashlib.sha256(archive.read('MediaVision-harmonyos-0.4.3/'+entry['path'])).hexdigest() == entry['sha256']
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(digest+'  '+output.name+'\n')
    print(f'PASS: {len(entries)} files; {output.stat().st_size} bytes; SHA256 {digest}')


if __name__ == '__main__':
    main()
