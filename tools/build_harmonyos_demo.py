#!/usr/bin/env python3
"""Build the binary-SDK HarmonyOS HAR and demo. Public SDK mode is compile-only."""
import argparse,json,os,shutil,subprocess
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
def main():
 p=argparse.ArgumentParser();p.add_argument('--hvigor',type=Path,required=True);p.add_argument('--node',type=Path,default=Path('node'))
 p.add_argument('--sdk-home',type=Path,required=True);p.add_argument('--public-sdk',action='store_true');p.add_argument('--native-libs',type=Path)
 p.add_argument('--models',type=Path);p.add_argument('--output',type=Path,default=ROOT/'build/harmonyos-demo');a=p.parse_args()
 source=ROOT/'demos/harmonyos';dest=a.output.resolve()
 existing={}
 if (dest/'build-profile.json5').exists():existing=json.loads((dest/'build-profile.json5').read_text()).get('app',{})
 shutil.copytree(source,dest,dirs_exist_ok=True,ignore=shutil.ignore_patterns('build','.hvigor','oh_modules','node_modules','local.properties'))
 if a.public_sdk:
  profile=dest/'build-profile.json5';d=json.loads(profile.read_text());d['app']['products'][0].update(compileSdkVersion=20,compatibleSdkVersion=20,targetSdkVersion=20,runtimeOS='OpenHarmony');profile.write_text(json.dumps(d,indent=2)+'\n')
  for name in ['entry','mediavision']:
   f=dest/name/'src/main/module.json5';d=json.loads(f.read_text());d['module']['deviceTypes']=['default','tablet','2in1'];f.write_text(json.dumps(d,indent=2)+'\n')
 else:
  profile=dest/'build-profile.json5';d=json.loads(profile.read_text())
  # Recent DevEco versions use their bundled compile SDK; minimum/target stay20.
  d['app']['products'][0].pop('compileSdkVersion',None)
  if existing.get('signingConfigs'):
   d['app']['signingConfigs']=existing['signingConfigs']
   for product in d['app']['products']:
    old=next((p for p in existing.get('products',[]) if p.get('name')==product['name']),{})
    if old.get('signingConfig'):product['signingConfig']=old['signingConfig']
  profile.write_text(json.dumps(d,indent=2)+'\n')
 libs=a.native_libs or (ROOT/'sdk/harmonyos' if (ROOT/'sdk/harmonyos').exists() else ROOT/'dist/harmonyos')
 for abi in ['arm64-v8a','x86_64']:
  target=dest/'mediavision/libs'/abi;target.mkdir(parents=True,exist_ok=True)
  for name in ['libmvs_sdk.so','libmvs_harmony.so','libmediavision.so','libc++_shared.so']:
   shutil.copy2(libs/abi/'shared/lib'/name,target/name)
 models=a.models or (ROOT/'models/harmonyos/mediavision.mvsmodels' if (ROOT/'models/harmonyos').exists() else ROOT/'models/runtime/harmonyos/mediavision.mvsmodels')
 raw=dest/'entry/src/main/resources/rawfile';raw.mkdir(parents=True,exist_ok=True);shutil.copy2(models,raw/'mediavision.mvsmodels')
 hvigor=a.hvigor.resolve();bundled=hvigor.parents[2]
 if (bundled/'hvigor-ohos-plugin').exists():
  modules=dest/'.build-tool-modules';scope=modules/'@ohos';scope.mkdir(parents=True,exist_ok=True)
  for name in ['hvigor','hvigor-ohos-plugin']:
   q=scope/name
   if q.is_symlink():q.unlink()
   if not q.exists():q.symlink_to(bundled/name,target_is_directory=True)
 else:modules=hvigor.parents[3]
 link=dest/'node_modules'
 if link.is_symlink():link.unlink()
 if not link.exists():link.symlink_to(modules,target_is_directory=True)
 for q,t in [(dest/'mediavision/oh_modules/libmediavision.so',dest/'mediavision/src/main/cpp/types/libmediavision'),(dest/'entry/oh_modules/@moon/mediavision',dest/'mediavision')]:
  q.parent.mkdir(parents=True,exist_ok=True)
  if q.is_symlink():q.unlink()
  if not q.exists():q.symlink_to(t.resolve(),target_is_directory=True)
 env=dict(os.environ);env['NODE_HOME']=str(a.node.resolve().parent.parent);env['PATH']=str(a.node.resolve().parent)+os.pathsep+env.get('PATH','')
 env['NODE_PATH']=str(modules.resolve())+os.pathsep+env.get('NODE_PATH','')
 env['OHOS_BASE_SDK_HOME' if a.public_sdk else 'DEVECO_SDK_HOME']=str(a.sdk_home.resolve())
 for module,task in [('mediavision','assembleHar'),('entry','assembleHap')]:
  with (dest/(task+'.log')).open('w') as log:
   subprocess.run([str(a.node),str(a.hvigor),'--mode','module','-p','product=default','-p','module='+module+'@default','-p','buildMode=release',task,'--no-daemon'],cwd=dest,env=env,check=True,stdout=log,stderr=subprocess.STDOUT)
  print(task,'PASS',flush=True)
 print('Build mode:', 'public OpenHarmony API20 compatibility compilation' if a.public_sdk else 'official HarmonyOS SDK, minimum API20')
 print('HAR:',dest/'mediavision/build/default/outputs/default/mediavision.har')
 print('HAP:',dest/'entry/build/default/outputs/default/entry-default-unsigned.hap')
if __name__=='__main__':main()
