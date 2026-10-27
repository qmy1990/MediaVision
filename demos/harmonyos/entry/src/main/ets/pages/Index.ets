import { common, abilityAccessCtrl } from '@kit.AbilityKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { VisionOptions, VisionCameraFrame, BackgroundMode, BlushMode, BlushColors, BlushPreset } from '@moon/mediavision';
import { LiveCamera, LiveMeasurement } from '../camera/LiveCamera';
interface BlushSelectOption { value: string; }
interface IrisPreset { name: string; rgb: number; }
// Demo presets only; VisionOptions.irisColor remains a custom 0xRRGGBB value.
const IrisColors: IrisPreset[] = [
  {name:'纯黑色',rgb:0x000000},
  {name:'深棕色',rgb:0x3B2418},
  {name:'巧克力棕',rgb:0x5E3A25},
  {name:'自然棕',rgb:0x8C623E},
  {name:'浅棕色',rgb:0xB0825A},
  {name:'焦糖棕',rgb:0xA66B3D},
  {name:'蜂蜜棕',rgb:0xC69445},
  {name:'奶茶棕',rgb:0xA58A72},
  {name:'灰棕色',rgb:0x8A7A70},
  {name:'冷棕色',rgb:0x6E625E},
  {name:'暖棕色',rgb:0x9B684C},
  {name:'琥珀棕',rgb:0xB38B51},
  {name:'金棕色',rgb:0xB88A42},
  {name:'灰色',rgb:0x88959D},
  {name:'浅灰色',rgb:0xB6BCC4},
  {name:'蓝灰色',rgb:0x628DA8},
  {name:'绿灰色',rgb:0x7C9690},
  {name:'紫色',rgb:0x9381AC},
  {name:'香芋紫',rgb:0xB7A0CB},
  {name:'粉色',rgb:0xD58BA6},
  {name:'樱花粉',rgb:0xF2B4C8},
  {name:'蓝色',rgb:0x447DB8},
  {name:'深海蓝',rgb:0x1F466A},
  {name:'绿色',rgb:0x4F8867},
  {name:'橄榄绿',rgb:0x7C8961},
  {name:'酒红',rgb:0x6F283D},
  {name:'墨绿',rgb:0x204B3F},
  {name:'湖蓝',rgb:0x419EAE},
  {name:'白色',rgb:0xFFFFFF}
];
@Entry
@Component
struct Index {
  @StorageLink('cameraForeground') @Watch('foregroundChanged') foreground: boolean = true;
  @State picture: image.PixelMap | undefined = undefined;
  @State label: string = '启动相机…';
  @State selected: string = '磨皮';
  @State strength: number = 55;
  @State beautyOn: boolean = true;
  @State meshOn: boolean = false;
  @State pointsOn: boolean = false;
  @State front: boolean = true;
  @State resolution: number = 480;
  @State starting: boolean = false;
  @State colorName: string = '苹果红';
  @State irisColorName: string = '自然棕';
  @State catchlightName: string = '自然光';
  @State previewWidth: number = 0;
  @State previewHeight: number = 0;
  @State frameWidth: number = 480;
  @State frameHeight: number = 854;
  private visible: boolean = true;
  private permission: boolean = false;
  private live: LiveCamera | undefined = undefined;
  private options: VisionOptions = new VisionOptions();
  private retired: image.PixelMap[] = [];
  private measurements: LiveMeasurement[] = [];
  private hasBackground: boolean = false;
  private restartWanted: boolean = false;
  private previewController: XComponentController = new XComponentController();
  private surfaceReady: boolean = false;
  private effects: string[] = ['背景虚化','磨皮','祛痘','美白','锐化','大眼','瘦脸','小头','鼻翼','眼间距','颧骨','口红','腮红','眉毛','美瞳','眼神光','人中长短','换背景','Mask'];
  private context(): common.UIAbilityContext {return this.getUIContext().getHostContext() as common.UIAbilityContext;}
  aboutToAppear(): void {
    this.options.beauty=.55;this.options.whitening=.25;this.options.blemishRemoval=.35;
    this.live=new LiveCamera(this.context(),(frame:VisionCameraFrame)=>{
      if(!this.visible || !this.foreground){frame.pixelMap.release();return;}
      if(this.picture)this.retired.push(this.picture);
      this.picture=frame.pixelMap;
      // Keep two previous images alive across ArkUI's asynchronous drawing.
      while(this.retired.length>2)this.retired.shift()!.release();
    },(m:LiveMeasurement)=>{
      this.label=`${m.fps.toFixed(1)}FPS ${m.width}×${m.height}`;
      if(m.width>0 && m.height>0){this.frameWidth=m.width;this.frameHeight=m.height;}
      this.measurements.push(m);if(this.measurements.length>30)this.measurements.shift();
      try {
        const f=fileIo.openSync(this.context().filesDir+'/camera-runtime.json',fileIo.OpenMode.CREATE|fileIo.OpenMode.WRITE_ONLY|fileIo.OpenMode.TRUNC);
        try{fileIo.writeSync(f.fd,JSON.stringify(this.measurements,null,2));}finally{fileIo.closeSync(f);}
      } catch(e){hilog.warn(0x1234,'MVSCamera','METRICS_SAVE %{public}s',(e as Error).message);}
    },(message:string)=>{this.label=message;hilog.error(0x1234,'MVSCamera','ERROR %{public}s',message);});
    this.live.setOptions(this.options,this.beautyOn);
    this.requestCamera();
  }
  private async requestCamera(): Promise<void> {
    try {
      const result=await abilityAccessCtrl.createAtManager().requestPermissionsFromUser(this.context(),['ohos.permission.CAMERA']);
      this.permission=result.authResults[0]===0;
      if(!this.permission){this.label='请在设置中允许相机访问';return;}
      await this.restart();
    } catch(e){this.label=(e as Error).message;}
  }
  private async restart(): Promise<void> {
    if(!this.permission || !this.live || !this.visible || !this.foreground || !this.surfaceReady)return;
    if(this.starting){this.restartWanted=true;return;}
    this.starting=true;this.label='启动相机…';
    try {await this.live.start(this.front,this.resolution);}catch(e){this.label=(e as Error).message;}
    finally {this.starting=false;if(this.restartWanted){this.restartWanted=false;this.restart();}}
  }
  private foregroundChanged(): void {
    if(!this.foreground){this.stopPreview();}
    else if(this.visible && this.permission && !this.live?.isRunning())this.restart();
  }
  onPageHide(): void {this.visible=false;this.stopPreview();}
  onPageShow(): void {this.visible=true;if(this.permission && !this.live?.isRunning())this.restart();}
  private stopPreview(): void {
    this.live?.stop();
    if(this.picture){this.retired.push(this.picture);this.picture=undefined;}
    for(const pixels of this.retired)pixels.release();this.retired=[];
  }
  aboutToDisappear(): void {this.visible=false;this.stopPreview();this.live?.release();}
  private changed(): void {this.live?.setOptions(this.options,this.beautyOn);}
  private async switchCamera(): Promise<void> {this.front=!this.front;await this.restart();}
  private async switchResolution(): Promise<void> {
    this.resolution=this.resolution===480?720:this.resolution===720?1080:480;await this.restart();
  }
  private async chooseBackground(): Promise<void> {
    const picker=new photoAccessHelper.PhotoViewPicker();
    const selected=await picker.select({MIMEType:photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,maxSelectNumber:1});
    if(selected.photoUris.length===0)return;
    const fd=fileIo.openSync(selected.photoUris[0],fileIo.OpenMode.READ_ONLY);
    let source: image.ImageSource | undefined;let pixels: image.PixelMap | undefined;
    try {
      source=image.createImageSource(fd.fd);const info=await source.getImageInfo();
      const scale=Math.min(1,1080/info.size.width,1920/info.size.height);
      pixels=await source.createPixelMap({desiredPixelFormat:image.PixelMapFormat.RGBA_8888,
        desiredDynamicRange:image.DecodingDynamicRange.SDR,desiredSize:{width:Math.max(1,Math.round(info.size.width*scale)),height:Math.max(1,Math.round(info.size.height*scale))}});
      const bytes=new ArrayBuffer(pixels.getPixelBytesNumber());await pixels.readPixelsToBuffer(bytes);
      const size=(await pixels.getImageInfo()).size;await this.live?.setBackground(bytes,size.width,size.height);
      this.hasBackground=true;this.options.background=BackgroundMode.REPLACE;this.strength=100;this.changed();
    } catch(e){this.label=(e as Error).message;}
    finally{pixels?.release();source?.release();fileIo.closeSync(fd);}
  }
  private value(key: string): number {
    switch(key) {
      case '背景虚化':return this.options.background===BackgroundMode.BLUR?Math.round(this.options.blurRadius/28.8*100):0;
      case '磨皮':return this.options.beauty*100;case '祛痘':return this.options.blemishRemoval*100;
      case '美白':return this.options.whitening*100;case '锐化':return this.options.sharpen*100;
      case '大眼':return this.options.eyeEnlarge*100;case '瘦脸':return this.options.faceSlim*100;
      case '小头':return this.options.smallHead*100;case '鼻翼':return this.options.noseSlim*100;
      case '眼间距':return this.options.eyeSpacing*100;case '颧骨':return this.options.cheekboneReduce*100;
      case '口红':return this.options.lipstick*100;case '腮红':return this.options.blush*100;
      case '美瞳':return this.options.iris*100;case '眼神光':return this.options.catchlight*100;
      case '人中长短':return this.options.philtrumLength*100;
      case '眉毛':return this.options.eyebrowDarkening*100;
      case '换背景':return this.options.background===BackgroundMode.REPLACE?100:0;
      default:return this.options.background===BackgroundMode.MASK?100:0;
    }
  }
  private update(value: number): void {
    const v=value/100;
    switch(this.selected) {
      case '背景虚化':this.options.background=v>0?BackgroundMode.BLUR:BackgroundMode.ORIGINAL;this.options.blurRadius=Math.max(1,28.8*v);break;
      case '磨皮':this.options.beauty=v;break;case '祛痘':this.options.blemishRemoval=v;break;
      case '美白':this.options.whitening=v;break;case '锐化':this.options.sharpen=v;break;
      case '大眼':this.options.eyeEnlarge=v;break;case '瘦脸':this.options.faceSlim=v;break;
      case '小头':this.options.smallHead=v;break;case '鼻翼':this.options.noseSlim=v;break;
      case '眼间距':this.options.eyeSpacing=v;break;case '颧骨':this.options.cheekboneReduce=v;break;
      case '口红':this.options.lipstick=v;break;case '腮红':this.options.blush=v;break;
      case '美瞳':this.options.iris=v;break;case '眼神光':this.options.catchlight=v;break;
      case '人中长短':this.options.philtrumLength=v;break;
      case '眉毛':this.options.eyebrowDarkening=v;break;
      case '换背景':this.options.background=v>.5 && this.hasBackground?BackgroundMode.REPLACE:BackgroundMode.ORIGINAL;break;
      case 'Mask':this.options.background=v>.5?BackgroundMode.MASK:BackgroundMode.ORIGINAL;break;
    }
    this.changed();
  }
  build() {
    Column() {
      Row({space:5}) {
        Text(this.label).fontSize(9).minFontSize(8).maxFontSize(9).fontColor('#FFFFFF').layoutWeight(1).maxLines(1);
        Button('切换').fontSize(11).width(42).height(30).padding(0).borderRadius(8).enabled(!this.starting).onClick(()=>this.switchCamera());
        Button(`${this.resolution}P`).fontSize(11).width(52).height(30).padding(0).borderRadius(8).enabled(!this.starting).onClick(()=>this.switchResolution());
        Button(this.pointsOn?'点开':'点关').fontSize(11).width(42).height(30).padding(0).borderRadius(8)
          .onClick(()=>{this.pointsOn=!this.pointsOn;this.options.debugLandmarks=this.pointsOn?1:0;this.changed();});
        Button(this.meshOn?'网格开':'网格关').fontSize(11).width(48).height(30).padding(0).borderRadius(8)
          .onClick(()=>{this.meshOn=!this.meshOn;this.options.debugFaceMesh=this.meshOn?1:0;this.changed();});
        Button(this.beautyOn?'美颜开':'美颜关').fontSize(11).width(48).height(30).padding(0).borderRadius(8)
          .onClick(()=>{this.beautyOn=!this.beautyOn;this.changed();});
      }.width('100%').height(40).padding({left:8,right:8});
      Stack() {
        XComponent({id:'mediavision-preview',type:XComponentType.SURFACE,controller:this.previewController})
          .width('100%')
          .height(this.previewWidth>0?this.previewWidth*this.frameHeight/this.frameWidth:'100%')
          .onLoad(()=>{this.surfaceReady=true;this.live?.setPreviewSurface(this.previewController.getXComponentSurfaceId());this.restart();})
          .onDestroy(()=>{this.surfaceReady=false;this.stopPreview();});
        if(this.picture){Image(this.picture).objectFit(ImageFit.Contain).width('100%')
          .height(this.previewWidth>0?this.previewWidth*this.frameHeight/this.frameWidth:'100%');}
        if(this.starting){LoadingProgress().width(32).height(32);}
        if(this.selected==='美瞳') {
          Select(IrisColors.map((p:IrisPreset):BlushSelectOption=>({value:p.name})))
            .value(this.irisColorName).font({size:12}).width(110).height(28).align(Alignment.Bottom)
            .onSelect((i:number)=>{if(i<0 || i>=IrisColors.length)return;this.irisColorName=IrisColors[i].name;this.options.irisColor=IrisColors[i].rgb;this.changed();});
        }
        if(this.selected==='眼神光') {
          Select([{value:'自然光'},{value:'窗格光'},{value:'月牙光'}])
            .value(this.catchlightName).font({size:12}).width(110).height(28).align(Alignment.Bottom)
            .onSelect((i:number)=>{const names:string[]=['自然光','窗格光','月牙光'];this.catchlightName=names[i];this.options.catchlightStyle=i;this.changed();});
        }
        if(this.selected==='腮红') {
          Row({space:8}) {
            Button(this.options.blushMode===BlushMode.CHEEKS?'脸颊':'脸颊＋鼻尖').fontSize(12).height(28)
              .onClick(()=>{this.options.blushMode=this.options.blushMode===BlushMode.CHEEKS?BlushMode.CHEEKS_AND_NOSE:BlushMode.CHEEKS;this.changed();});
            Select(BlushColors.map((p:BlushPreset):BlushSelectOption=>({value:p.name}))).value(this.colorName)
              .onSelect((i:number)=>{this.options.blushColor=BlushColors[i].rgb;this.colorName=BlushColors[i].name;this.changed();});
          }.height(36).padding({left:8,right:8}).backgroundColor('#C0071326').align(Alignment.Bottom);
        }
        if(this.selected==='换背景'){Button('选择背景图片').fontSize(12).height(28).align(Alignment.Bottom).onClick(()=>this.chooseBackground());}
      }.width('100%').layoutWeight(1).backgroundColor('#000000')
        .onAreaChange((oldArea: Area,newArea: Area)=>{this.previewWidth=Number(newArea.width);this.previewHeight=Number(newArea.height);});
      Row({space:8}) {
        Text(`${this.selected} ${Math.round(this.strength)}`).fontColor('#FFFFFF').fontSize(12);
        Slider({value:this.strength,min:0,max:100,step:1}).layoutWeight(1)
          .onChange((v:number,mode:SliderChangeMode)=>{this.strength=v;this.update(v);});
      }.height(28).padding({left:12,right:12});
      Scroll() {
        Row({space:5}) {ForEach(this.effects,(key:string)=>{
          Button(key).fontSize(12).height(28).borderRadius(8).backgroundColor(this.selected===key?'#416DB9':'#11203B')
            .onClick(()=>{this.selected=key;this.strength=this.value(key);});
        },(key:string)=>key);}
      }.scrollable(ScrollDirection.Horizontal).height(34).padding({left:8,right:8});
    }.width('100%').height('100%').backgroundColor('#071326');
  }
}
