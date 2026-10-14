import { UIAbility } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
export default class EntryAbility extends UIAbility {
  onForeground(): void {AppStorage.setOrCreate('cameraForeground',true);}
  onBackground(): void {AppStorage.setOrCreate('cameraForeground',false);}
  onWindowStageCreate(stage: window.WindowStage): void {
    AppStorage.setOrCreate('cameraForeground',true);
    stage.getMainWindowSync().setPreferredOrientation(window.Orientation.PORTRAIT);
    stage.loadContent('pages/Index');
  }
}
