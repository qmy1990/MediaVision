import { common } from '@kit.AbilityKit';
import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { fileIo } from '@kit.CoreFileKit';
import { display } from '@kit.ArkUI';
import { colorSpaceManager } from '@kit.ArkGraphics2D';
import { deviceInfo } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { VisionSdk, VisionConfig, VisionOptions, VisionCameraFrame, VisionSurfaceFrame, YuvColorSpace } from '@moon/mediavision';

export class LiveMeasurement {
  time: number = 0;
  width: number = 0;
  height: number = 0;
  fps: number = 0;
  processedFrames: number = 0;
  arrivalEvents: number = 0;
  faceFrames: number = 0;
  maskFrames: number = 0;
  nativeMs: number = 0;
  analysisMs: number = 0;
  effectsMs: number = 0;
  conversionMs: number = 0;
  analysisFeaturesMs: number = 0; analysisWorkMs: number = 0; analysisAgeMs: number = 0; analysisMaxAgeMs: number = 0;
  analysisUpdates: number = 0; analysisFps: number = 0; asyncAnalysis: number = 0;
  personInferenceMs: number = 0; detectorInferenceMs: number = 0; landmarkInferenceMs: number = 0;
  maskRefineMs: number = 0; featureMs: number = 0; renderMs: number = 0; outputMs: number = 0;
  pixelMapMs: number = 0; inputCopyMs: number = 0; consumeMs: number = 0; readMs: number = 0;
  backend: string = '';
  cameraPosition: string = '';
  effectsEnabled: boolean = true;
  blurRadius: number = 0;
  backgroundMode: number = 0;
  debugMesh: number = 0;
  beautyStrength: number = 0; whiteningStrength: number = 0; blemishStrength: number = 0;
  geometryEnabled: boolean = false; lipstickStrength: number = 0; blushStrength: number = 0;
  pipeline: string = ''; acquireMs: number = 0; analysisReadbackBytes: number = 0;
  analysisWidth: number = 0; analysisHeight: number = 0; presentedSequence: number = 0;
  queueAgeMs: number = 0; queueMaxAgeMs: number = 0; captureToSubmitMs: number = 0;
}
export class LiveCamera {
  private sdk: VisionSdk | undefined = undefined;
  private previewSurface: string = '';
  private nativeSurface: boolean = false;
  private receiver: image.ImageReceiver | undefined = undefined;
  private input: camera.CameraInput | undefined = undefined;
  private preview: camera.VideoOutput | camera.PreviewOutput | undefined = undefined;
  private previewMode: boolean = true;
  private session: camera.VideoSession | undefined = undefined;
  private operation: Promise<void> = Promise.resolve();
  private frame: Promise<void> | undefined = undefined;
  private prefetched: image.Image | undefined = undefined;
  private prefetching: Promise<void> | undefined = undefined;
  private running: boolean = false;
  private desiredRunning: boolean = false;
  private busy: boolean = false;
  private pending: boolean = false;
  private generation: number = 0;
  private revision: number = 0;
  private lastAnalysisSequence: number = 0;
  private appliedRevision: number = -1;
  private options: VisionOptions = new VisionOptions();
  private effectsEnabled: boolean = true;
  private front: boolean = true;
  private rotation: number = 0;
  private colorSpace: YuvColorSpace = YuvColorSpace.BT709_LIMITED;
  private windowStart: number = 0;
  private measurement: LiveMeasurement = new LiveMeasurement();
  private context: common.UIAbilityContext;
  private onFrame: (frame: VisionCameraFrame) => void;
  private onMeasurement: (result: LiveMeasurement) => void;
  private onError: (message: string) => void;
  constructor(context: common.UIAbilityContext,onFrame: (frame: VisionCameraFrame) => void,
    onMeasurement: (result: LiveMeasurement) => void,onError: (message: string) => void) {
    this.context=context;this.onFrame=onFrame;this.onMeasurement=onMeasurement;this.onError=onError;
  }
  isRunning(): boolean {return this.running;}
  setPreviewSurface(surfaceId: string): void {this.previewSurface=surfaceId;}
  setOptions(options: VisionOptions, enabled: boolean): void {
    this.options=options;this.effectsEnabled=enabled;this.revision++;
    this.windowStart=Date.now();this.measurement=new LiveMeasurement();
  }
  private async initialize(): Promise<void> {
    if(this.sdk)return;
    const models=await this.context.resourceManager.getRawFileContent('mediavision.mvsmodels');
    const config=new VisionConfig();config.enableFp16=0;config.cacheDir=this.context.cacheDir+'/mediavision-gpu';
    this.sdk=await VisionSdk.create(models.buffer.slice(models.byteOffset,models.byteOffset+models.byteLength),config);
    await this.sdk.setRealtime(true,33);
  }
  start(front: boolean, shortSide: number): Promise<void> {
    this.desiredRunning=true;
    const next=this.operation.catch(()=>{}).then(()=>this.startInternal(front,shortSide));
    this.operation=next;return next;
  }
  stop(): Promise<void> {
    // Invalidate callbacks immediately, including while startup is pending.
    this.desiredRunning=false;this.running=false;this.generation++;
    const next=this.operation.catch(()=>{}).then(()=>this.stopInternal());
    this.operation=next;return next;
  }
  async release(): Promise<void> {
    await this.stop();if(this.sdk){await this.sdk.release();this.sdk=undefined;}
  }
  async setBackground(data: ArrayBuffer,width: number,height: number): Promise<void> {
    await this.initialize();await this.sdk!.setBackgroundRgba(data,width,height);
  }
  private async stopInternal(): Promise<void> {
    this.running=false;this.generation++;this.pending=false;
    const receiver=this.receiver,input=this.input,preview=this.preview,session=this.session;
    this.receiver=undefined;this.input=undefined;this.preview=undefined;this.session=undefined;
    if(receiver)receiver.off('imageArrival');
    if(preview)await preview.stop().catch(()=>{});
    if(session)await session.stop().catch(()=>{});
    if(this.frame)await this.frame.catch(()=>{});
    if(this.prefetching)await this.prefetching.catch(()=>{});
    if(this.prefetched){await this.prefetched.release().catch(()=>{});this.prefetched=undefined;}
    if(preview)await preview.release().catch(()=>{});
    if(input)await input.close().catch(()=>{});
    if(session)await session.release().catch(()=>{});
    if(receiver)await receiver.release().catch(()=>{});
    if(this.nativeSurface){await this.sdk?.closeSurface().catch(()=>{});this.nativeSurface=false;}
    this.busy=false;
  }
  private async startInternal(front: boolean, shortSide: number): Promise<void> {
    await this.stopInternal();await this.initialize();await this.sdk!.reset();
    if(!this.desiredRunning)return;
    const generation=++this.generation;this.front=front;this.appliedRevision=-1;
    const manager=camera.getCameraManager(this.context);
    const devices=manager.getSupportedCameras();
    const position=front?camera.CameraPosition.CAMERA_POSITION_FRONT:camera.CameraPosition.CAMERA_POSITION_BACK;
    const device=devices.find((d:camera.CameraDevice)=>d.cameraPosition===position);
    if(!device)throw new Error(front?'没有可用的前置相机':'没有可用的后置相机');
    const capability=manager.getSupportedOutputCapability(device,camera.SceneMode.NORMAL_VIDEO);
    const profiles: camera.Profile[] = this.previewMode?
      capability.previewProfiles.filter((p:camera.Profile)=>p.format===camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP):
      capability.videoProfiles.filter((p:camera.VideoProfile)=>p.format===camera.CameraFormat.CAMERA_FORMAT_YUV_420_SP && p.frameRateRange.min<=30 && p.frameRateRange.max>=30);
    if(profiles.length===0)throw new Error('相机未提供 SDR NV21 预览流');
    profiles.sort((a:camera.Profile,b:camera.Profile)=>this.profileScore(a,shortSide)-this.profileScore(b,shortSide));
    const profile=profiles[0];
    hilog.info(0x1234,'MVSCamera','CONFIG %{public}s',JSON.stringify({front:front,sensor:device.cameraOrientation,
      width:profile.size.width,height:profile.size.height,available:profiles.map((p:camera.Profile)=>p.size)}));
    try {
      // API23+ removes the format argument; API20 retains the original receiver API.
      let surface: string = '';
      if(this.previewSurface.length>0) {
        try {
          surface=await this.sdk!.openSurface(this.previewSurface,profile.size.width,profile.size.height);
          // ADA-AL00 preview writes tightly packed NV21 even when the native
          // allocator advertises 64-byte padded rows. Measured on OS6.1.0.135.
          // Scope the workaround to this producer; other cameras keep native layout.
          if(this.previewMode && deviceInfo.productModel==='ADA-AL00' && deviceInfo.displayVersion.includes('6.1.0.135') && profile.size.width%64!==0) {
            const row=profile.size.width,uv=row*profile.size.height;
            await this.sdk!.setSurfaceInputLayout({yOffset:0,yRowStride:row,yPixelStride:1,
              uOffset:uv+1,uRowStride:row,uPixelStride:2,vOffset:uv,vRowStride:row,vPixelStride:2});
          }
          this.nativeSurface=true;
        }
        catch(e){await this.sdk!.closeSurface().catch(()=>{});hilog.warn(0x1234,'MVSCamera','NATIVE_FALLBACK %{public}s',(e as Error).message);}
      }
      if(!this.nativeSurface) {
        const receiver=deviceInfo.sdkApiVersion>=23?image.createImageReceiver({size:profile.size,capacity:3}):image.createImageReceiver(profile.size,image.ImageFormat.JPEG,3);
        if(!receiver)throw new Error('相机帧接收器创建失败');this.receiver=receiver;surface=await receiver.getReceivingSurfaceId();
      }
      this.input=manager.createCameraInput(device);await this.input.open();
      if(!this.desiredRunning){await this.stopInternal();return;}
      this.preview=this.previewMode?manager.createPreviewOutput(profile,surface):manager.createVideoOutput(profile as camera.VideoProfile,surface);
      this.preview.on('error',(e)=>this.onError(`相机预览错误：${e.code}`));
      this.session=manager.createSession(camera.SceneMode.NORMAL_VIDEO) as camera.VideoSession;
      this.session.beginConfig();this.session.addInput(this.input);this.session.addOutput(this.preview);
      const spaces=this.session.getSupportedColorSpaces();
      if(spaces.includes(colorSpaceManager.ColorSpace.BT709_LIMIT))this.session.setColorSpace(colorSpaceManager.ColorSpace.BT709_LIMIT);
      else if(spaces.includes(colorSpaceManager.ColorSpace.BT601_EBU_LIMIT))this.session.setColorSpace(colorSpaceManager.ColorSpace.BT601_EBU_LIMIT);
      await this.session.commitConfig();
      if(!this.desiredRunning){await this.stopInternal();return;}
      const screen=display.getDefaultDisplaySync().rotation;
      // The output is associated with its camera only after session commit.
      this.rotation=(device.cameraOrientation+(front?screen*90:-screen*90)+360)%360;
      const active=this.session.getActiveColorSpace();
      this.colorSpace=active===colorSpaceManager.ColorSpace.BT709_LIMIT?YuvColorSpace.BT709_LIMITED:
        active===colorSpaceManager.ColorSpace.BT709?YuvColorSpace.BT709_FULL:
        active===colorSpaceManager.ColorSpace.BT601_EBU_LIMIT || active===colorSpaceManager.ColorSpace.BT601_SMPTE_C_LIMIT?
          YuvColorSpace.BT601_LIMITED:YuvColorSpace.BT601_FULL;
      const rates=this.preview.getSupportedFrameRates();
      if(rates.some((r:camera.FrameRateRange)=>r.min<=60 && r.max>=60))this.preview.setFrameRate(60,60);
      else if(rates.some((r:camera.FrameRateRange)=>r.min<=30 && r.max>=30))this.preview.setFrameRate(30,30);
      hilog.info(0x1234,'MVSCamera','RATES %{public}s',JSON.stringify({supported:rates,active:this.preview.getActiveFrameRate()}));
      const config=fileIo.openSync(this.context.filesDir+'/camera-config.json',fileIo.OpenMode.CREATE|fileIo.OpenMode.WRITE_ONLY|fileIo.OpenMode.TRUNC);
      try{fileIo.writeSync(config.fd,JSON.stringify({outputType:this.previewMode?'preview':'video',front:front,profile:profile,rotation:this.rotation,colorSpace:active,sensor:device.cameraOrientation,frameRates:rates,activeFrameRate:this.preview.getActiveFrameRate()}));}
      finally{fileIo.closeSync(config);}
      const swapped=this.rotation===90 || this.rotation===270;
      await this.sdk!.warmup(swapped?profile.size.height:profile.size.width,swapped?profile.size.width:profile.size.height,
        this.effectsEnabled?this.options:new VisionOptions()).catch((e:Error)=>hilog.warn(0x1234,'MVSCamera','PREWARM %{public}s',e.message));
      this.windowStart=Date.now();this.measurement=new LiveMeasurement();this.running=true;
      this.receiver?.on('imageArrival',()=>{
        if(!this.running || generation!==this.generation)return;
        this.measurement.arrivalEvents++;this.pending=true;
        if(this.busy)this.prefetch(generation);else this.kick(generation);
      });
      await this.session.start();if(!this.previewMode)await this.preview.start();
      if(this.nativeSurface)this.frame=this.consumeSurface(generation);
      hilog.info(0x1234,'MVSCamera','START rotation=%{public}d colorSpace=%{public}d',this.rotation,active);
    } catch(e) {await this.stopInternal();throw new Error((e as Error).message);}
  }
  private async consumeSurface(generation: number): Promise<void> {
    const sdk=this.sdk;if(!sdk)return;
    try {
      while(this.running && generation===this.generation) {
        const began=Date.now();
        if(this.appliedRevision!==this.revision) {
          const revision=this.revision;const settings=this.effectsEnabled?this.options:new VisionOptions();
          if(!this.effectsEnabled){settings.debugFaceMesh=this.options.debugFaceMesh;settings.debugLandmarks=this.options.debugLandmarks;}
          await sdk.configure(settings);this.appliedRevision=revision;
        }
        const frame=await sdk.processSurface(this.rotation,this.front,this.colorSpace);
        if(!this.running || generation!==this.generation)return;
        if(frame.presented!==1)continue;
        this.measurement.arrivalEvents++;this.measurement.acquireMs+=frame.acquireMs;
        this.measurement.analysisReadbackBytes=frame.analysisReadbackBytes;
        this.measurement.analysisWidth=frame.analysisWidth;this.measurement.analysisHeight=frame.analysisHeight;
        this.measurement.presentedSequence=frame.sequence;
        this.measurement.queueAgeMs+=frame.queueAgeMs;this.measurement.queueMaxAgeMs=Math.max(this.measurement.queueMaxAgeMs,frame.queueAgeMs);
        this.measurement.captureToSubmitMs+=frame.captureToSubmitMs;
        this.record(frame,Date.now()-began,frame.acquireMs);
      }
    } catch(e){if(this.running && generation===this.generation){this.running=false;this.onError((e as Error).message);}}
  }
  private profileScore(p: camera.Profile,shortSide: number): number {
    const short=Math.min(p.size.width,p.size.height),long=Math.max(p.size.width,p.size.height);
    // Keep the original camera pixels. Prefer the requested short side and
    // the available aspect closest to 16:9, including 864x480 and 768x480.
    const aspect=16/9;
    return Math.abs(short-shortSide)*4+Math.abs(long/short-aspect)*shortSide;
  }
  private prefetch(generation: number): void {
    const receiver=this.receiver;
    if(this.prefetching || !receiver || !this.running || generation!==this.generation)return;
    this.prefetching=this.readAhead(receiver,generation).finally(()=>{this.prefetching=undefined;});
  }
  private async readAhead(receiver: image.ImageReceiver,generation: number): Promise<void> {
    let next: image.Image | undefined = undefined;
    try {
      next=await receiver.readLatestImage();
      if(!this.running || generation!==this.generation)return;
      const old=this.prefetched;this.prefetched=next;next=undefined;
      if(old)await old.release().catch(()=>{});
    } catch(e) { /* A missing look-ahead frame falls back to the normal read. */ }
    finally {if(next)await next.release().catch(()=>{});}
  }
  private kick(generation: number): void {
    if(this.busy || !this.running || !this.pending || generation!==this.generation)return;
    this.busy=true;this.pending=false;
    this.frame=this.consume(generation).finally(()=>{
      this.busy=false;
      if(this.running && this.pending && generation===this.generation)this.kick(generation);
    });
  }
  private async consume(generation: number): Promise<void> {
    const receiver=this.receiver,sdk=this.sdk;
    if(!receiver || !sdk)return;
    const began=Date.now();let readMs=0;
    let source: image.Image | undefined = undefined;
    try {
      if(this.prefetching)await this.prefetching;
      source=this.prefetched;this.prefetched=undefined;
      if(!source)source=await receiver.readLatestImage();
      if(!this.running || generation!==this.generation)return;
      if(source.format!==25)throw new Error(`预览帧格式不支持：${source.format}`);
      if(this.appliedRevision!==this.revision) {
        const revision=this.revision;
        const settings=this.effectsEnabled?this.options:new VisionOptions();
        if(!this.effectsEnabled){settings.debugFaceMesh=this.options.debugFaceMesh;settings.debugLandmarks=this.options.debugLandmarks;}
        await sdk.configure(settings);this.appliedRevision=revision;
      }
      let bytes: ArrayBuffer;let stride: number;
      if(deviceInfo.sdkApiVersion>=23) {
        const data=source.getBufferData();if(!data)throw new Error('相机数据读取失败');
        bytes=data.byteBuffer;stride=data.rowStride[0];
      } else {
        const component=await source.getComponent(image.ComponentType.JPEG);
        bytes=component.byteBuffer;stride=component.rowStride;
      }
      if(!stride)stride=source.size.width;readMs=Date.now()-began;
      // Native enqueue copies the NV21 bytes synchronously. Release the camera
      // image immediately afterwards, so inference never holds a producer buffer.
      const result=sdk.processNv21(bytes,source.size.width,source.size.height,stride,this.rotation,this.front,this.colorSpace);
      await source.release().catch(()=>{});source=undefined;
      const frame=await result;
      if(!this.running || generation!==this.generation){await frame.pixelMap.release();return;}
      this.onFrame(frame);this.record(frame,Date.now()-began,readMs);
    } catch(e) {
      if(this.running && generation===this.generation)this.onError((e as Error).message);
    } finally {if(source)await source.release().catch(()=>{});}
  }
  private record(frame: VisionCameraFrame | VisionSurfaceFrame,consumeMs: number,readMs: number): void {
    const m=this.measurement;m.processedFrames++;m.width=frame.width;m.height=frame.height;
    m.nativeMs+=frame.stats.totalMs;m.analysisMs+=frame.stats.analysisMs;m.effectsMs+=frame.stats.effectsMs;
    const s=frame.stats;
    m.analysisFeaturesMs+=s.analysisFeaturesMs;m.analysisWorkMs+=s.analysisWorkMs;m.analysisAgeMs+=s.analysisAgeMs;m.analysisMaxAgeMs=Math.max(m.analysisMaxAgeMs,s.analysisAgeMs);
    if(s.analysisSequence>0 && s.analysisSequence!==this.lastAnalysisSequence){m.analysisUpdates++;this.lastAnalysisSequence=s.analysisSequence;}
    m.asyncAnalysis=s.asyncAnalysis;m.personInferenceMs+=s.personInferenceMs;m.detectorInferenceMs+=s.detectorInferenceMs;m.landmarkInferenceMs+=s.landmarkInferenceMs;
    m.maskRefineMs+=s.maskRefineMs;m.featureMs+=s.featureMs;m.renderMs+=s.renderMs;m.outputMs+=s.outputMs;
    m.pixelMapMs+=s.pixelMapMs;m.inputCopyMs+=s.inputCopyMs;m.consumeMs+=consumeMs;m.readMs+=readMs;
    m.conversionMs+=frame.conversionMs;m.backend=frame.stats.inferenceBackend;
    if(frame.stats.landmarkCount===478)m.faceFrames++;
    if(frame.stats.maskWidth>0)m.maskFrames++;
    const now=Date.now(),elapsed=now-this.windowStart;
    if(elapsed<2000)return;
    m.time=now;m.fps=m.processedFrames*1000/elapsed;
    m.analysisFps=m.analysisUpdates*1000/elapsed;
    m.analysisFeaturesMs/=m.processedFrames;m.analysisWorkMs/=m.processedFrames;m.analysisAgeMs/=m.processedFrames;
    m.personInferenceMs/=m.processedFrames;m.detectorInferenceMs/=m.processedFrames;m.landmarkInferenceMs/=m.processedFrames;
    m.maskRefineMs/=m.processedFrames;m.featureMs/=m.processedFrames;m.renderMs/=m.processedFrames;m.outputMs/=m.processedFrames;
    m.pixelMapMs/=m.processedFrames;m.inputCopyMs/=m.processedFrames;m.consumeMs/=m.processedFrames;m.readMs/=m.processedFrames;
    m.nativeMs/=m.processedFrames;m.analysisMs/=m.processedFrames;m.effectsMs/=m.processedFrames;m.conversionMs/=m.processedFrames;
    m.cameraPosition=this.front?'front':'back';m.effectsEnabled=this.effectsEnabled;
    m.pipeline=this.nativeSurface?'native-buffer-vulkan-window':'nv21-cpu-pixelmap';m.acquireMs/=m.processedFrames;
    m.queueAgeMs/=m.processedFrames;m.captureToSubmitMs/=m.processedFrames;
    m.backgroundMode=this.options.background;m.blurRadius=this.options.blurRadius;m.debugMesh=this.options.debugFaceMesh;
    m.beautyStrength=this.options.beauty;m.whiteningStrength=this.options.whitening;m.blemishStrength=this.options.blemishRemoval;
    m.geometryEnabled=this.options.philtrumLength!==.5 || this.options.smallHead>0 || this.options.eyeEnlarge>0 || this.options.faceSlim>0 || this.options.noseSlim>0 || this.options.eyeSpacing!==.5 || this.options.cheekboneReduce!==.5;
    m.lipstickStrength=this.options.lipstick;m.blushStrength=this.options.blush;
    this.onMeasurement(m);hilog.info(0x1234,'MVSCamera','METRICS %{public}s',JSON.stringify(m));
    this.measurement=new LiveMeasurement();this.windowStart=now;
  }
}
