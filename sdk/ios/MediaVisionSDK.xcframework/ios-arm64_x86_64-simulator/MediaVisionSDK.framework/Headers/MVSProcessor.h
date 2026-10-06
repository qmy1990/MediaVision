#import <CoreVideo/CoreVideo.h>
#import <Foundation/Foundation.h>
#include "sdk.h"
NS_ASSUME_NONNULL_BEGIN
/** MediaPipe is the measured default on iPhone 8 Plus. Vision/Core ML modes are
 * opt-in; measure quality and sustained frame rate on the target device. */
typedef NS_ENUM(NSInteger, MVSPersonSegmentationQuality) {
  MVSPersonSegmentationMediaPipe = 0,
  MVSPersonSegmentationVisionFast,
  MVSPersonSegmentationVisionBalanced,
  MVSPersonSegmentationVisionAccurate,
  /** These select allowed Core ML devices, not proof of ANE execution.
   * Requires model 101 in the encrypted package. Face478 retains MediaPipe
   * with its existing GPU preference and CPU fallback. CPU+NE requires iOS 16. */
  MVSPersonSegmentationCoreMLAll,
  MVSPersonSegmentationCoreMLCPUAndGPU,
  MVSPersonSegmentationCoreMLCPUOnly,
  MVSPersonSegmentationCoreMLCPUAndNeuralEngine
};
typedef struct MVSFrameTimings {
  double segmentationMilliseconds;
  double faceMilliseconds;
  double analysisMilliseconds;  // Wall time, including overlapping model work.
  double renderingMilliseconds;
  MvsPerformance core;
  double inferenceQueueMilliseconds;
  double endToEndMilliseconds;
  NSUInteger faceLandmarkCount;
  MvsBackend backend;
  uint32_t maskWidth, maskHeight;
  double maskComparisonMeanError, maskComparisonIoU;
} MVSFrameTimings;
typedef void (^MVSProcessingCompletion)(CVPixelBufferRef _Nullable output, MVSFrameTimings timings,
                                        NSError *_Nullable error);
/** Camera SDK adapter with serial synchronous processing or a bounded async
 * pipeline. Supply one encrypted package containing the required models. */
@interface MVSProcessor : NSObject
@property(nonatomic, readonly, copy) NSString *inferenceDescription;
@property(nonatomic, readonly) double inferenceMilliseconds;
@property(nonatomic, readonly) NSUInteger faceLandmarkCount;
@property(nonatomic, readonly) MVSFrameTimings frameTimings;
- (nullable instancetype)initWithModelPackagePath:(NSString *)packagePath
                                          backend:(MvsBackend)backend
                                            error:(NSError **)error;
/** A failing Vision request falls back to MediaPipe for the same input frame.
 * The encrypted person and face models remain required for that fallback. */
- (nullable instancetype)initWithModelPackagePath:(NSString *)packagePath
                                          backend:(MvsBackend)backend
                        personSegmentationQuality:(MVSPersonSegmentationQuality)quality
                                            error:(NSError **)error;
- (BOOL)configure:(MvsOptions)options error:(NSError **)error;
- (MvsBackend)backend;
- (nullable CVPixelBufferRef)newPixelBufferByProcessing:(CVPixelBufferRef)input
                                  timestampMilliseconds:(int64_t)timestamp
                                                  error:(NSError **)error CF_RETURNS_RETAINED;
/** Bounded two-stage camera pipeline, at most three frames in flight. NO means busy, closed or
 * invalid input. Each output uses its own input's analysis. Output is borrowed for the callback,
 * delivered on the render queue; retain it to use it after the callback returns.
 * Use either synchronous or asynchronous processing for a processor, not both. */
- (BOOL)submitPixelBuffer:(CVPixelBufferRef)input
    timestampMilliseconds:(int64_t)timestamp
                  options:(MvsOptions)options
               completion:(MVSProcessingCompletion)completion;
- (BOOL)setBackground:(CVPixelBufferRef)background error:(NSError **)error;
- (BOOL)setMesh:(MvsAccessory)slot
       vertices:(const MvsVertex *)vertices
          count:(uint32_t)vertexCount
        indices:(const uint32_t *)indices
          count:(uint32_t)indexCount
          error:(NSError **)error;
- (void)reset;
- (void)close;
@end
NS_ASSUME_NONNULL_END
