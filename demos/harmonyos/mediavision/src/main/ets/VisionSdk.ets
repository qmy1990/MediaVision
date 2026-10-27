import native from 'libmediavision.so';
import { NativeHandle, NativeStats, NativeFrame, NativeImage, NativeCameraFrame, NativeSurfaceFrame, NativeOptions, NativeConfig, NativeYuv420Frame, NativeYuvLayout } from 'libmediavision.so';
import { image } from '@kit.ImageKit';
export enum EffectsBackend { AUTO = 0, CPU = 1, VULKAN = 2 }
export enum InferenceBackend { AUTO = 0, CPU = 1, NNRT = 2, GPU = 3 }
export enum BackgroundMode { ORIGINAL = 0, BLUR = 1, REPLACE = 2, MASK = 3 }
export enum BlushMode { CHEEKS = 0, CHEEKS_AND_NOSE = 1 }
export enum YuvColorSpace { BT601_LIMITED = 0, BT709_LIMITED = 1, BT601_FULL = 2, BT709_FULL = 3 }
export class VisionConfig implements NativeConfig {
  cacheDir: string = '';
  effectsBackend: number = EffectsBackend.AUTO;
  inferenceBackend: number = InferenceBackend.AUTO;
  threads: number = 2;
  enableFp16: number = 1;
  acceleratorBudgetMs: number = 18;
}
export class VisionOptions implements NativeOptions {
  iris: number = 0; catchlight: number = 0; philtrumLength: number = .5;
  get philtrumWidth(): number { return this.philtrumLength; }
  set philtrumWidth(value: number) { this.philtrumLength = value; }
  irisColor: number = 0x8C623E; catchlightStyle: number = 0;
  beauty: number = 0; whitening: number = 0; sharpen: number = 0; blemishRemoval: number = 0;
  eyeEnlarge: number = 0; faceSlim: number = 0; smallHead: number = 0; noseSlim: number = 0;
  eyeSpacing: number = .5; cheekboneReduce: number = .5;
  lipstick: number = 0; lipstickColor: number = 0xB52A3A;
  blush: number = 0; blushColor: number = 0xEB5263; blushMode: number = BlushMode.CHEEKS;
  eyebrowDarkening: number = 0; background: number = BackgroundMode.ORIGINAL;
  blurRadius: number = 24; skinTone: number = 0; maskSmoothing: number = .55;
  debugLandmarks: number = 0; debugFaceMesh: number = 0;
}
export interface VisionStats extends NativeStats {}
export interface VisionFrame extends NativeFrame {}
export interface VisionImage extends NativeImage {}
export interface VisionCameraFrame extends NativeCameraFrame {}
export interface VisionSurfaceFrame extends NativeSurfaceFrame {}
export class BlushPreset {
  name: string;
  rgb: number;
  constructor(name: string, rgb: number) { this.name=name; this.rgb=rgb; }
}
export const BlushColors: BlushPreset[] = [
  new BlushPreset('樱花粉',0xF3A6BA),new BlushPreset('蜜桃粉',0xF4A18F),new BlushPreset('玫瑰粉',0xD96D8F),
  new BlushPreset('芭比粉',0xEA70AA),new BlushPreset('冷调粉',0xD982B3),new BlushPreset('蜜桃橘',0xF29D68),
  new BlushPreset('珊瑚橘',0xF18373),new BlushPreset('杏色',0xDEA281),new BlushPreset('苹果红',0xEB5263),
  new BlushPreset('草莓红',0xE65D7D),new BlushPreset('浆果红',0xAE4E78),new BlushPreset('裸杏',0xC79380),
  new BlushPreset('奶茶',0xBE907C),new BlushPreset('豆沙',0xB97983)];
export class VisionSdk {
  static readonly MIN_API: number = 20;
  private timestamp: number = -1;
  private closed: boolean = false;
  private processing: boolean = false;
  private handle: NativeHandle;
  private constructor(handle: NativeHandle) { this.handle=handle; }
  static async create(models?: ArrayBuffer, config: VisionConfig = new VisionConfig()): Promise<VisionSdk> {
    return new VisionSdk(await native.create(models,config));
  }
  private checkOpen(): void { if(this.closed) throw new Error('MediaVision 已释放'); }
  private nextTime(time?: number): number {
    const next = time === undefined ? Math.max(Date.now(),this.timestamp+1) : time;
    if(!Number.isSafeInteger(next) || next < 0 || next <= this.timestamp) throw new Error('时间戳必须严格递增');
    this.timestamp=next;return next;
  }
  async configure(options: VisionOptions): Promise<void> {this.checkOpen();await native.configure(this.handle,options);}
  async processRgba(data: ArrayBuffer,width: number,height: number,stride: number = width*4,time?: number): Promise<VisionFrame> {
    this.checkOpen();if(this.processing)throw new Error('上一帧正在处理，请等待完成或丢弃新帧');this.processing=true;
    try {return await native.processRgba(this.handle,data,width,height,stride,this.nextTime(time));} finally {this.processing=false;}
  }
  async processPixelMap(input: image.PixelMap,time?: number): Promise<VisionImage> {
    this.checkOpen();if(this.processing)throw new Error('上一帧正在处理，请等待完成或丢弃新帧');this.processing=true;
    try {return await native.processPixelMap(this.handle,input,this.nextTime(time));} finally {this.processing=false;}
  }
  async processNv21(data: ArrayBuffer,width: number,height: number,stride: number,rotation: number = 0,
    mirror: boolean = false,colorSpace: YuvColorSpace = YuvColorSpace.BT709_LIMITED,time?: number): Promise<VisionCameraFrame> {
    this.checkOpen();if(this.processing)throw new Error('上一帧正在处理，请等待完成或丢弃新帧');this.processing=true;
    try {return await native.processNv21(this.handle,data,width,height,stride,rotation,mirror?1:0,colorSpace,this.nextTime(time));}
    finally {this.processing=false;}
  }
  async warmup(width: number,height: number,options: VisionOptions = new VisionOptions()): Promise<void> {
    this.checkOpen();if(this.processing)throw new Error('请等待当前帧结束再预热');
    await native.warmup(this.handle,width,height,options);
  }
  async processYuv420(frame: NativeYuv420Frame): Promise<VisionCameraFrame> {
    this.checkOpen();if(this.processing)throw new Error('上一帧正在处理');this.processing=true;
    try {frame.timestamp=this.nextTime(frame.timestamp);return await native.processYuv420(this.handle,frame);}
    finally {this.processing=false;}
  }
  async setSurfaceInputLayout(layout?: NativeYuvLayout): Promise<void> {
    this.checkOpen();if(this.processing)throw new Error('请等待当前帧结束');await native.setSurfaceInputLayout(this.handle,layout);
  }
  async openSurface(surfaceId: string,width: number,height: number,outputWidth: number = 0,outputHeight: number = 0): Promise<string> {
    this.checkOpen();if(this.processing)throw new Error('请等待当前帧结束');return await native.openSurface(this.handle,surfaceId,width,height,outputWidth,outputHeight);
  }
  async processSurface(rotation: number,mirror: boolean,colorSpace: YuvColorSpace,time?: number): Promise<VisionSurfaceFrame> {
    this.checkOpen();if(this.processing)throw new Error('上一帧正在处理');this.processing=true;
    try{return await native.processSurface(this.handle,rotation,mirror?1:0,colorSpace,this.nextTime(time));}finally{this.processing=false;}
  }
  async closeSurface(): Promise<void> {this.checkOpen();await native.closeSurface(this.handle);}
  async setRealtime(enabled: boolean, maxAgeMs: number = 100): Promise<void> {
    this.checkOpen();if(this.processing)throw new Error('请等待当前帧结束再调整流水线');
    await native.setRealtime(this.handle,enabled?1:0,maxAgeMs);this.timestamp=-1;
  }
  async reset(): Promise<void> {
    this.checkOpen();if(this.processing)throw new Error('请等待当前帧结束再重置');
    await native.reset(this.handle);this.timestamp=-1;
  }
  async setBackgroundRgba(data: ArrayBuffer,width: number,height: number,stride: number = width*4): Promise<void> {
    this.checkOpen();await native.setBackground(this.handle,data,width,height,stride);
  }
  async clearBackground(): Promise<void> {this.checkOpen();await native.setBackground(this.handle,undefined,0,0,0);}
  async release(): Promise<void> {if(this.closed)return;this.closed=true;await native.close(this.handle);}
}
