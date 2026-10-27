import { image } from '@kit.ImageKit';
export interface NativeHandle { readonly minApi: number; }
export interface NativeStats {
  effectsBackend: number; landmarkCount: number; maskWidth: number; maskHeight: number;
  asyncAnalysis: number; analysisSequence: number; analysisTimestampMs: number; analysisAgeMs: number;
  analysisFeaturesMs: number; analysisWorkMs: number; personInferenceMs: number; detectorInferenceMs: number; landmarkInferenceMs: number;
  packingMs: number; maskRefineMs: number; featureMs: number; renderMs: number; outputMs: number; pixelMapMs: number; inputCopyMs: number;
  analysisMs: number; effectsMs: number; totalMs: number; inferenceBackend: string;
}
export interface NativeFrame { rgba: ArrayBuffer; stats: NativeStats; }
export interface NativeImage { pixelMap: image.PixelMap; stats: NativeStats; }
export interface NativeCameraFrame extends NativeImage { width: number; height: number; conversionMs: number; }
export interface NativeSurfaceFrame {
  presented: number; width: number; height: number; sequence: number; stats: NativeStats;
  analysisWidth: number; analysisHeight: number; acquireMs: number; conversionMs: number; analysisReadbackBytes: number;
  queueAgeMs: number; captureToSubmitMs: number;
}
export interface NativeYuvPlane { data: ArrayBuffer; offset: number; rowStride: number; pixelStride: number; }
export interface NativeYuv420Frame {
  width: number; height: number; y: NativeYuvPlane; u: NativeYuvPlane; v: NativeYuvPlane;
  rotation: number; mirror: number; colorSpace: number; timestamp: number;
}
export interface NativeYuvLayout {
  yOffset: number; yRowStride: number; yPixelStride: number;
  uOffset: number; uRowStride: number; uPixelStride: number;
  vOffset: number; vRowStride: number; vPixelStride: number;
}
export interface NativeConfig {
  cacheDir?: string;
  effectsBackend: number; inferenceBackend: number; threads: number; enableFp16: number; acceleratorBudgetMs: number;
}
export interface NativeOptions {
  iris?: number; catchlight?: number; philtrumLength?: number; philtrumWidth?: number; irisColor?: number; catchlightStyle?: number;
  beauty: number; whitening: number; sharpen: number; blemishRemoval: number; eyeEnlarge: number; faceSlim: number;
  smallHead: number; noseSlim: number; eyeSpacing: number; cheekboneReduce: number; lipstick: number; lipstickColor: number;
  blush: number; blushColor: number; blushMode: number; eyebrowDarkening: number; background: number; blurRadius: number;
  skinTone: number; maskSmoothing: number; debugLandmarks: number; debugFaceMesh: number;
}
export const create: (models: ArrayBuffer | undefined, config: NativeConfig) => Promise<NativeHandle>;
export const configure: (handle: NativeHandle, options: NativeOptions) => Promise<void>;
export const processRgba: (handle: NativeHandle, data: ArrayBuffer, width: number, height: number, stride: number, timestamp: number) => Promise<NativeFrame>;
export const processPixelMap: (handle: NativeHandle, image: image.PixelMap, timestamp: number) => Promise<NativeImage>;
export const processNv21: (handle: NativeHandle, data: ArrayBuffer, width: number, height: number, stride: number,
  rotation: number, mirror: number, colorSpace: number, timestamp: number) => Promise<NativeCameraFrame>;
export const processYuv420: (handle: NativeHandle, frame: NativeYuv420Frame) => Promise<NativeCameraFrame>;
export const setSurfaceInputLayout: (handle: NativeHandle, layout: NativeYuvLayout | undefined) => Promise<void>;
export const warmup: (handle: NativeHandle, width: number, height: number, options: NativeOptions) => Promise<void>;
export const openSurface: (handle: NativeHandle, surfaceId: string, width: number, height: number, outputWidth?: number, outputHeight?: number) => Promise<string>;
export const processSurface: (handle: NativeHandle, rotation: number, mirror: number, colorSpace: number, timestamp: number) => Promise<NativeSurfaceFrame>;
export const closeSurface: (handle: NativeHandle) => Promise<void>;
export const setRealtime: (handle: NativeHandle, enabled: number, maxAgeMs: number) => Promise<void>;
export const reset: (handle: NativeHandle) => Promise<void>;
export const setBackground: (handle: NativeHandle, rgba: ArrayBuffer | undefined, width: number, height: number, stride: number) => Promise<void>;
export const close: (handle: NativeHandle) => Promise<void>;
