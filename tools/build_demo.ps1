param([ValidateSet('android','cpp')][string]$Platform='android', [string]$SdkRoot='')
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
if ($Platform -eq 'android') {
  & "$Root/demos/android/gradlew.bat" -p "$Root/demos/android" :app:assembleDebug
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
} else {
  $Arguments=@('-S',$Root,'-B',"$Root/build/demo")
  if ($SdkRoot) { $Arguments += "-DMEDIAVISION_SDK_ROOT=$SdkRoot" }
  & cmake @Arguments
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
  & cmake --build "$Root/build/demo" --config Release
  if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}
