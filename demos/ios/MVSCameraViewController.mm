#import "MVSCameraViewController.h"
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>
#import <CoreImage/CoreImage.h>
#import <MediaVisionSDK/MVSProcessor.h>
#import <MetalKit/MetalKit.h>
#include <algorithm>
#include <atomic>
#include <cmath>
#include <cstring>
#include <vector>

namespace {
constexpr NSInteger kEffectCount = 19;
const char *kNames[] = {"磨皮", "祛痘", "肤色", "增强", "大眼", "小头", "瘦脸", "鼻翼",    "眼距",
                        "颧骨", "口红", "晒红", "眉毛", "道具", "头饰", "首饰", "背景虚化", "Mask", "换背景"};
// 83 preserves the previous radius 24. Maximum is round(24 * 1.2) = 29.
constexpr float kDefaultBlurStrength = 83;
const float kDefaults[] = {
    55, 35, 25, 45, 25, 35, 28, 18, 65, 50, 30, 20, 25, 100, 100, 100, kDefaultBlurStrength, 100, 100};
uint32_t BlurRadius(float strength) {
  return std::max(1u, uint32_t(lroundf(24.f * 1.2f * std::clamp(strength, 0.f, 100.f) / 100.f)));
}
float Neutral(NSInteger index) { return index == 8 || index == 9 ? 50 : 0; }
float Value(const MvsOptions &o, NSInteger index, float blurStrength) {
  if (index == 16) return o.background == MVS_BACKGROUND_BLUR ? blurStrength : 0;
  if (index == 17) return o.background == MVS_BACKGROUND_MASK ? 100 : 0;
  if (index == 18) return o.background == MVS_BACKGROUND_REPLACE ? 100 : 0;
  const float values[] = {
      o.beauty,        o.blemish_removal, o.whitening,         o.sharpen,     o.eye_enlarge,
      o.small_head,    o.face_slim,       o.nose_slim,         o.eye_spacing, o.cheekbone_reduce,
      o.lipstick,      o.blush,           o.eyebrow_darkening, float(o.prop), float(o.headwear),
      float(o.jewelry)};
  return values[index] * 100;
}
void SetValue(MvsOptions &o, NSInteger index, float value) {
  float v = std::clamp(value / 100, 0.f, 1.f);
  switch (index) {
    case 0:
      o.beauty = v;
      break;
    case 1:
      o.blemish_removal = v;
      break;
    case 2:
      o.whitening = v;
      break;
    case 3:
      o.sharpen = v;
      break;
    case 4:
      o.eye_enlarge = v;
      break;
    case 5:
      o.small_head = v;
      break;
    case 6:
      o.face_slim = v;
      break;
    case 7:
      o.nose_slim = v;
      break;
    case 8:
      o.eye_spacing = v;
      break;
    case 9:
      o.cheekbone_reduce = v;
      break;
    case 10:
      o.lipstick = v;
      break;
    case 11:
      o.blush = v;
      break;
    case 12:
      o.eyebrow_darkening = v;
      break;
    case 13:
      o.prop = v > 0;
      break;
    case 14:
      o.headwear = v > 0;
      break;
    case 15:
      o.jewelry = v > 0;
      break;
  }
}
const uint32_t kLipColors[] = {MVS_LIP_CLASSIC_RED, MVS_LIP_CORAL,          MVS_LIP_ROSE,
                               MVS_LIP_BEAN_PASTE,  MVS_LIP_ORANGE_RED,     MVS_LIP_NUDE,
                               MVS_LIP_PINK,        MVS_LIP_PEACH,          MVS_LIP_GRAPEFRUIT,
                               MVS_LIP_SAKURA_PINK, MVS_LIP_STRAWBERRY_RED, MVS_LIP_WATER_GLOSS};
UIColor *PanelColor(CGFloat alpha) {
  return [UIColor colorWithRed:12 / 255. green:25 / 255. blue:54 / 255. alpha:alpha];
}
}  // namespace

@interface MVSCameraViewController () <AVCaptureVideoDataOutputSampleBufferDelegate,
                                       MTKViewDelegate>
@end
@implementation MVSCameraViewController {
  AVCaptureSession *_session;
  dispatch_queue_t _cameraQueue;
  dispatch_queue_t _captureQueue;
  BOOL _usePipeline;
  MVSProcessor *_processor;
  MTKView *_preview;
  CIContext *_context;
  CIContext *_captureContext;
  id<MTLCommandQueue> _renderQueue;
  UILabel *_status;
  UILabel *_effectLabel;
  UISlider *_effectSlider;
  UISwitch *_effectSwitch;
  UIButton *_allBeautyButton;
  UIButton *_cameraButton;
  UIButton *_resolutionButton;
  UIButton *_landmarkButton;
  UIButton *_meshButton;
  UIButton *_colorButton;
  NSArray<UIButton *> *_effectButtons;
  NSInteger _selectedEffect;
  NSInteger _lipColorIndex;
  NSInteger _resolutionTier;  // Main thread; captured into the serial camera queue.
  NSInteger _captureTier;
  BOOL _captureFront;
  float _remembered[kEffectCount];
  float _blurStrength;
  float _blurStrengthBeforeDrag;
  BOOL _allBeautyEnabled;
  CVPixelBufferRef _displayed;
  CVPixelBufferPoolRef _capturePool;
  size_t _captureWidth, _captureHeight;
  std::vector<uint8_t> _scaleScratch;
  CGColorSpaceRef _previewColorSpace;
  CIImage *_benchmarkPortrait;
  BOOL _benchmarkMotion;
  CFTimeInterval _portraitMotionStart;
  CVPixelBufferRef _portraitBuffer;
  MvsOptions _options;  // Read and written under @synchronized(self).
  BOOL _front;
  BOOL _displayMirror;
  CFTimeInterval _fpsStart, _lastStatusTick;
  NSUInteger _presentedFrames;
  double _fps;
  BOOL _benchmark;
  BOOL _recordOutput;
  dispatch_queue_t _recordQueue;
  std::atomic<bool> _recordPending;
  AVAssetWriter *_movieWriter;
  AVAssetWriterInput *_movieInput;
  AVAssetWriterInputPixelBufferAdaptor *_movieAdaptor;
  size_t _movieWidth, _movieHeight;
  CFTimeInterval _movieStart;
  NSUInteger _movieFrames;
  BOOL _movieFinished;
  NSUInteger _benchmarkFrames;
  double _scaleTotal, _segmentTotal, _faceTotal, _analysisTotal, _coreTotal, _submitTotal,
      _processTotal;
  double _packTotal, _maskTotal, _prepareTotal, _renderTotal, _outputTotal;
  double _queueTotal, _latencyTotal;
  std::atomic<bool> _pending;
  std::atomic<bool> _visible;
  std::atomic<uint64_t> _generation;
  std::atomic<unsigned> _sensorWidth, _sensorHeight;
  uint64_t _captureSeenGeneration;
  unsigned _captureWarmupFrames;
  CFTimeInterval _captureWarmupStarted;
  AVCaptureDevice *_captureDevice;  // Published under @synchronized(self).
}
- (UIButton *)button:(NSString *)title action:(SEL)action identifier:(NSString *)identifier {
  UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem];
  [button setTitle:title forState:UIControlStateNormal];
  [button setTitleColor:UIColor.whiteColor forState:UIControlStateNormal];
  button.titleLabel.font = [UIFont systemFontOfSize:12];
  button.backgroundColor = [UIColor colorWithRed:48 / 255.
                                           green:86 / 255.
                                            blue:156 / 255.
                                           alpha:.8];
  button.layer.cornerRadius = 7;
  button.contentEdgeInsets = UIEdgeInsetsMake(0, 7, 0, 7);
  button.accessibilityIdentifier = identifier;
  if (action) {
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
  }
  return button;
}
- (void)viewDidLoad {
  [super viewDidLoad];
  self.view.backgroundColor = UIColor.blackColor;
  self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
  _front = _captureFront = YES;
  _benchmark = [NSProcessInfo.processInfo.environment[@"MVS_BENCHMARK"] boolValue];
  _recordOutput =
      _benchmark && [NSProcessInfo.processInfo.environment[@"MVS_RECORD_OUTPUT"] boolValue];
  _recordPending = false;
  if (_recordOutput)
    _recordQueue = dispatch_queue_create("com.moon.mediavision.video-evidence", DISPATCH_QUEUE_SERIAL);
  _usePipeline = ![NSProcessInfo.processInfo.environment[@"MVS_SYNC_PIPELINE"] boolValue];
  if (_benchmark && [NSProcessInfo.processInfo.environment[@"MVS_BENCH_PORTRAIT"] boolValue]) {
    NSURL *portrait = [NSBundle.mainBundle URLForResource:@"portrait" withExtension:@"jpg"];
    if (portrait) _benchmarkPortrait = [CIImage imageWithContentsOfURL:portrait];
    _benchmarkMotion = [NSProcessInfo.processInfo.environment[@"MVS_BENCH_MOTION"] boolValue];
  }
  _allBeautyEnabled = YES;
  _pending = false;
  _visible = false;
  _generation = 0;
  _captureSeenGeneration = UINT64_MAX;
  _options = mvs_default_options();
  // Same startup strengths and neutral values as the Android demo.
  _options.beauty = .55f;
  _options.blemish_removal = .35f;
  _options.whitening = .25f;
  _options.sharpen = .45f;
  _options.eye_enlarge = .25f;
  _options.face_slim = .28f;
  _options.nose_slim = .18f;
  _options.lipstick = .22f;
  _options.blush = .12f;
  _options.eyebrow_darkening = .18f;
  _options.background = MVS_BACKGROUND_BLUR;
  _options.blur_radius = 24;
  _blurStrength = kDefaultBlurStrength;
  _options.mask_smoothing = .65f;
  if (_benchmark && [NSProcessInfo.processInfo.environment[@"MVS_BENCH_SMALL_HEAD"] boolValue])
    _options.small_head = 1;
  if (_benchmark && [NSProcessInfo.processInfo.environment[@"MVS_BENCH_CHEEK"] boolValue])
    _options.cheekbone_reduce = 1;
  for (NSInteger i = 0; i < kEffectCount; ++i) {
    _remembered[i] = kDefaults[i];
  }
  _cameraQueue = dispatch_queue_create("com.moon.mediavision.camera", DISPATCH_QUEUE_SERIAL);
  _captureQueue = dispatch_queue_create("com.moon.mediavision.capture", DISPATCH_QUEUE_SERIAL);
  id<MTLDevice> device = MTLCreateSystemDefaultDevice();
  _preview = [[MTKView alloc] initWithFrame:CGRectZero device:device];
  _preview.contentScaleFactor = UIScreen.mainScreen.nativeScale;
  _preview.autoResizeDrawable = NO;
  _previewColorSpace = CGColorSpaceCreateDeviceRGB();
  _preview.framebufferOnly = NO;
  _preview.paused = YES;
  _preview.enableSetNeedsDisplay = YES;
  _preview.delegate = self;
  _preview.accessibilityIdentifier = @"cameraPreview";
  _preview.isAccessibilityElement = YES;
  _preview.accessibilityLabel = @"相机预览";
  _context = [CIContext contextWithMTLDevice:device];
  _captureContext = [CIContext contextWithMTLDevice:device];
  _renderQueue = [device newCommandQueue];
  _preview.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:_preview];
  UILayoutGuide *safe = self.view.safeAreaLayoutGuide;
  [NSLayoutConstraint activateConstraints:@[
    [_preview.topAnchor constraintEqualToAnchor:safe.topAnchor constant:40],
    [_preview.bottomAnchor constraintEqualToAnchor:safe.bottomAnchor],
    [_preview.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [_preview.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
  ]];
  [self buildTopOverlay];
  [self buildEffectOverlay];
  [self syncEffectEditor];
  [NSNotificationCenter.defaultCenter addObserver:self
                                         selector:@selector(pauseCapture)
                                             name:UIApplicationDidEnterBackgroundNotification
                                           object:nil];
  [NSNotificationCenter.defaultCenter addObserver:self
                                         selector:@selector(resumeCapture)
                                             name:UIApplicationWillEnterForegroundNotification
                                           object:nil];
}
- (void)buildTopOverlay {
  _status = [[UILabel alloc] init];
  _status.textColor = UIColor.whiteColor;
  _status.font = [UIFont monospacedDigitSystemFontOfSize:10 weight:UIFontWeightMedium];
  _status.numberOfLines = 1;
  _status.adjustsFontSizeToFitWidth = YES;
  _status.minimumScaleFactor = .8;
  _status.text = @"0 FPS · —×—";
  _status.accessibilityIdentifier = @"performanceStatus";
  [_status setContentHuggingPriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  [_status setContentCompressionResistancePriority:UILayoutPriorityDefaultLow forAxis:UILayoutConstraintAxisHorizontal];
  _allBeautyButton = [self button:@"美颜开" action:@selector(toggleAllBeauty) identifier:@"allBeautyButton"];
  _allBeautyButton.accessibilityLabel = @"美颜总开关";
  _allBeautyButton.accessibilityValue = @"开";
  _cameraButton = [self button:@"切换" action:@selector(flipCamera) identifier:@"cameraButton"];
  _cameraButton.accessibilityLabel = @"切换前后摄像头";
  _cameraButton.accessibilityValue = @"前置";
  _resolutionButton = [self button:@"480P" action:@selector(cycleResolution) identifier:@"resolutionButton"];
  _landmarkButton = [self button:@"点关" action:@selector(toggleLandmarks) identifier:@"landmarkButton"];
  _meshButton = [self button:@"网格关" action:@selector(toggleMesh) identifier:@"meshButton"];
  _landmarkButton.accessibilityLabel = @"显示全部人脸关键点";
  _meshButton.accessibilityLabel = @"显示人脸网格";
  NSArray<UIButton *> *buttons = @[_cameraButton, _resolutionButton, _landmarkButton, _meshButton, _allBeautyButton];
  NSArray<NSNumber *> *widths = @[@40, @44, @32, @44, @46];
  UIStackView *top = [[UIStackView alloc] initWithArrangedSubviews:@[_status]];
  top.accessibilityIdentifier = @"topControls";
  for (NSInteger i = 0; i < buttons.count; ++i) {
    UIButton *button = buttons[i];
    button.titleLabel.font = [UIFont systemFontOfSize:10 weight:UIFontWeightSemibold];
    button.contentEdgeInsets = UIEdgeInsetsMake(0, 2, 0, 2);
    [button.widthAnchor constraintEqualToConstant:widths[i].doubleValue].active = YES;
    [button.heightAnchor constraintEqualToConstant:32].active = YES;
    [top addArrangedSubview:button];
  }
  top.alignment = UIStackViewAlignmentCenter;
  top.spacing = 4;
  top.layoutMargins = UIEdgeInsetsMake(4, 6, 4, 6);
  top.layoutMarginsRelativeArrangement = YES;
  top.backgroundColor = PanelColor(.43);
  top.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:top];
  [NSLayoutConstraint activateConstraints:@[
    [top.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor],
    [top.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [top.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
    [top.heightAnchor constraintEqualToConstant:40]
  ]];
}
- (void)buildEffectOverlay {
  _effectSwitch = [[UISwitch alloc] init];
  _effectSwitch.accessibilityIdentifier = @"effectSwitch";
  [_effectSwitch addTarget:self
                    action:@selector(toggleEffect)
          forControlEvents:UIControlEventValueChanged];
  _effectLabel = [[UILabel alloc] init];
  _effectLabel.font = [UIFont systemFontOfSize:12];
  _effectLabel.textColor = UIColor.whiteColor;
  [_effectLabel.widthAnchor constraintEqualToConstant:55].active = YES;
  _effectSlider = [[UISlider alloc] init];
  _effectSlider.maximumValue = 100;
  _effectSlider.accessibilityIdentifier = @"effectSlider";
  [_effectSlider addTarget:self
                    action:@selector(changeStrength)
          forControlEvents:UIControlEventValueChanged];
  [_effectSlider addTarget:self
                    action:@selector(beginStrengthChange)
          forControlEvents:UIControlEventTouchDown];
  [_effectSlider addTarget:self
                    action:@selector(finishStrengthChange)
          forControlEvents:UIControlEventTouchUpInside | UIControlEventTouchUpOutside |
                           UIControlEventTouchCancel];
  _colorButton = [self button:@"经典红 ▾" action:nil identifier:@"colorButton"];
  _colorButton.showsMenuAsPrimaryAction = YES;
  NSLayoutConstraint *colorWidth = [_colorButton.widthAnchor constraintEqualToConstant:96];
  colorWidth.priority = 999;  // UIStackView gives hidden arranged views a zero width.
  colorWidth.active = YES;
  UIStackView *editor = [[UIStackView alloc] initWithArrangedSubviews:@[
    _effectLabel, _effectSwitch, _effectSlider, _colorButton
  ]];
  editor.spacing = 6;
  editor.alignment = UIStackViewAlignmentCenter;
  [editor.heightAnchor constraintEqualToConstant:44].active = YES;
  UIScrollView *scroll = [[UIScrollView alloc] init];
  scroll.showsHorizontalScrollIndicator = NO;
  scroll.accessibilityIdentifier = @"effectList";
  UIStackView *items = [[UIStackView alloc] init];
  items.spacing = 5;
  items.translatesAutoresizingMaskIntoConstraints = NO;
  [scroll addSubview:items];
  NSMutableArray *buttons = [NSMutableArray array];
  for (NSInteger i = 0; i < kEffectCount; ++i) {
    UIButton *button = [self button:@""
                             action:@selector(selectEffect:)
                         identifier:[NSString stringWithFormat:@"effect%ld", (long)i]];
    button.tag = i;
    [button.widthAnchor constraintGreaterThanOrEqualToConstant:76].active = YES;
    if (i == 16)
      [items insertArrangedSubview:button atIndex:0];
    else
      [items addArrangedSubview:button];
    [buttons addObject:button];
  }
  _effectButtons = buttons;
  [NSLayoutConstraint activateConstraints:@[
    [items.topAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.topAnchor],
    [items.bottomAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.bottomAnchor],
    [items.leadingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.leadingAnchor],
    [items.trailingAnchor constraintEqualToAnchor:scroll.contentLayoutGuide.trailingAnchor],
    [items.heightAnchor constraintEqualToAnchor:scroll.frameLayoutGuide.heightAnchor],
    [scroll.heightAnchor constraintEqualToConstant:48]
  ]];
  UIStackView *bottom = [[UIStackView alloc] initWithArrangedSubviews:@[ editor, scroll ]];
  bottom.axis = UILayoutConstraintAxisVertical;
  bottom.spacing = 4;
  bottom.layoutMargins = UIEdgeInsetsMake(4, 8, 5, 8);
  bottom.layoutMarginsRelativeArrangement = YES;
  bottom.backgroundColor = PanelColor(.62);
  bottom.translatesAutoresizingMaskIntoConstraints = NO;
  [self.view addSubview:bottom];
  [NSLayoutConstraint activateConstraints:@[
    [bottom.bottomAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.bottomAnchor],
    [bottom.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
    [bottom.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
  ]];
}
- (void)syncColorMenu {
  BOOL skin = _selectedEffect == 2;
  NSArray *names = skin ? @[ @"自然白", @"冷白皮", @"红润白", @"美黑" ] : @[
    @"经典红", @"珊瑚", @"玫瑰", @"豆沙", @"橘红", @"裸色", @"粉红色", @"蜜桃色", @"西柚色",
    @"樱花粉", @"草莓红", @"水光唇釉"
  ];
  NSInteger selected = skin ? _options.skin_tone : _lipColorIndex;
  NSMutableArray *actions = [NSMutableArray array];
  __weak MVSCameraViewController *weakSelf = self;
  for (NSInteger i = 0; i < names.count; ++i) {
    UIAction *action = [UIAction actionWithTitle:names[i]
                                           image:nil
                                      identifier:nil
                                         handler:^(UIAction *a) {
                                           MVSCameraViewController *owner = weakSelf;
                                           if (!owner) {
                                             return;
                                           }
                                           @synchronized(owner) {
                                             if (skin) {
                                               owner->_options.skin_tone = (MvsSkinTone)i;
                                             } else {
                                               owner->_lipColorIndex = i;
                                               owner->_options.lipstick_color = kLipColors[i];
                                             }
                                           }
                                           [owner syncColorMenu];
                                         }];
    action.state = selected == i ? UIMenuElementStateOn : UIMenuElementStateOff;
    [actions addObject:action];
  }
  _colorButton.menu = [UIMenu menuWithChildren:actions];
  [_colorButton setTitle:[names[selected] stringByAppendingString:@" ▾"]
                forState:UIControlStateNormal];
}
- (void)syncEffectEditor {
  MvsOptions options;
  @synchronized(self) {
    options = _options;
  }
  for (NSInteger i = 0; i < kEffectCount; ++i) {
    int value = (int)lroundf(Value(options, i, _blurStrength));
    NSString *name = [NSString stringWithUTF8String:kNames[i]];
    BOOL boolean = (i >= 13 && i <= 15) || i >= 17;
    [_effectButtons[i]
        setTitle:boolean ? [NSString stringWithFormat:@"%@(%@)", name, value ? @"开" : @"关"]
                         : [NSString stringWithFormat:@"%@(%d)", name, value]
        forState:UIControlStateNormal];
    _effectButtons[i].backgroundColor = i == _selectedEffect ? [UIColor colorWithRed:.18
                                                                               green:.43
                                                                                blue:.85
                                                                               alpha:.95]
                                                             : PanelColor(.65);
  }
  float value = Value(options, _selectedEffect, _blurStrength);
  if (fabsf(value - Neutral(_selectedEffect)) >= .5) {
    _remembered[_selectedEffect] = value;
  }
  _effectLabel.text = [NSString stringWithUTF8String:kNames[_selectedEffect]];
  _effectSwitch.on = fabsf(value - Neutral(_selectedEffect)) >= .5;
  _effectSwitch.accessibilityLabel = [_effectLabel.text stringByAppendingString:@"开关"];
  _effectSlider.value = value;
  _effectSlider.hidden = (_selectedEffect >= 13 && _selectedEffect <= 15) || _selectedEffect >= 17;
  _effectSlider.accessibilityLabel = [_effectLabel.text stringByAppendingString:@"强度"];
  _colorButton.hidden = _selectedEffect != 2 && _selectedEffect != 10;
  if (!_colorButton.hidden) {
    [self syncColorMenu];
  }
}
- (void)selectEffect:(UIButton *)sender {
  _selectedEffect = sender.tag;
  if (_selectedEffect >= 17) {
    @synchronized(self) { [self setSelectedEffectValue:100]; }
  }
  [self syncEffectEditor];
}
- (void)changeStrength {
  @synchronized(self) {
    [self setSelectedEffectValue:roundf(_effectSlider.value)];
  }
  [self syncEffectEditor];
}
- (void)beginStrengthChange {
  if (_selectedEffect == 16)
    _blurStrengthBeforeDrag = _blurStrength > 0 ? _blurStrength : _remembered[16];
}
- (void)finishStrengthChange {
  if (_selectedEffect == 16 && _blurStrength == 0) _remembered[16] = _blurStrengthBeforeDrag;
}
- (void)toggleEffect {
  float value = _effectSwitch.on ? _remembered[_selectedEffect] : Neutral(_selectedEffect);
  @synchronized(self) {
    [self setSelectedEffectValue:value];
  }
  [self syncEffectEditor];
}
- (void)setSelectedEffectValue:(float)value {
  if (_selectedEffect == 16) {
    _blurStrength = std::clamp(value, 0.f, 100.f);
    _options.blur_radius = BlurRadius(_blurStrength);
    _options.background = _blurStrength > 0 ? MVS_BACKGROUND_BLUR : MVS_BACKGROUND_NONE;
  } else if (_selectedEffect >= 17) {
    MvsBackground mode = _selectedEffect == 17 ? MVS_BACKGROUND_MASK : MVS_BACKGROUND_REPLACE;
    if (value > 0) _options.background = mode;
    else if (_options.background == mode) _options.background = MVS_BACKGROUND_NONE;
  } else {
    SetValue(_options, _selectedEffect, value);
  }
}
- (void)toggleAllBeauty {
  @synchronized(self) {
    _allBeautyEnabled = !_allBeautyEnabled;
  }
  [_allBeautyButton setTitle:_allBeautyEnabled ? @"美颜开" : @"美颜关" forState:UIControlStateNormal];
  _allBeautyButton.accessibilityValue = _allBeautyEnabled ? @"开" : @"关";
}
- (void)toggleLandmarks {
  @synchronized(self) {
    _options.debug_landmarks = !_options.debug_landmarks;
  }
  [_landmarkButton setTitle:_options.debug_landmarks ? @"点开" : @"点关"
                   forState:UIControlStateNormal];
  _landmarkButton.accessibilityValue = _options.debug_landmarks ? @"开" : @"关";
}
- (void)toggleMesh {
  @synchronized(self) {
    _options.debug_face_mesh = !_options.debug_face_mesh;
  }
  [_meshButton setTitle:_options.debug_face_mesh ? @"网格开" : @"网格关"
               forState:UIControlStateNormal];
  _meshButton.accessibilityValue = _options.debug_face_mesh ? @"开" : @"关";
}
- (void)resetDisplay {
  _generation.fetch_add(1);
  _fpsStart = 0;
  _lastStatusTick = 0;
  _fps = 0;
  _presentedFrames = 0;
  if (_displayed) {
    CVPixelBufferRelease(_displayed);
    _displayed = nullptr;
  }
  _status.text = @"0 FPS · —×—";
  [_preview draw];
}
- (void)cycleResolution {
  _resolutionTier = (_resolutionTier + 2) % 3;
  [_resolutionButton setTitle:@[ @"480P", @"720P", @"1080P" ][_resolutionTier]
                     forState:UIControlStateNormal];
  [self restartCamera];
}
- (void)flipCamera {
  _front = !_front;
  _cameraButton.accessibilityValue = _front ? @"前置" : @"后置";
  [self restartCamera];
}
- (void)restartCamera {
  [self resetDisplay];
  BOOL front = _front;
  NSInteger tier = _resolutionTier;
  dispatch_async(_cameraQueue, ^{
    [self->_session stopRunning];
    self->_session = nil;
    self->_captureFront = front;
    self->_captureTier = tier;
    [self->_processor reset];
    if (self->_visible) {
      [self startCamera];
    }
  });
}
- (void)viewDidAppear:(BOOL)animated {
  [super viewDidAppear:animated];
  _visible = true;
  UIApplication.sharedApplication.idleTimerDisabled = YES;
  [self resumeCapture];
}
- (void)viewWillDisappear:(BOOL)animated {
  _visible = false;
  [self pauseCapture];
  UIApplication.sharedApplication.idleTimerDisabled = NO;
  [super viewWillDisappear:animated];
}
- (void)showError:(NSError *)error {
  NSLog(@"MediaVision: %@", error.localizedDescription ?: @"处理失败");
  dispatch_async(dispatch_get_main_queue(), ^{
    self->_status.text = error.localizedDescription ?: @"处理失败";
  });
}
- (void)resumeCapture {
  if (!_visible) {
    return;
  }
  _fpsStart = 0;
  _presentedFrames = 0;
  [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo
                           completionHandler:^(BOOL granted) {
                             if (!granted) {
                               [self showError:[NSError errorWithDomain:@"Camera"
                                                                   code:1
                                                               userInfo:@{
                                                                 NSLocalizedDescriptionKey :
                                                                     @"请在设置中允许相机权限"
                                                               }]];
                               return;
                             }
                             dispatch_async(self->_cameraQueue, ^{
                               if (self->_visible) {
                                 [self startCamera];
                               }
                             });
                           }];
}
- (void)pauseCapture {
  dispatch_async(_cameraQueue, ^{
    [self->_session stopRunning];
  });
}
- (void)startCamera {
  NSError *error = nil;
  if (!_processor) {
    NSString *package = [NSBundle.mainBundle pathForResource:@"mediavision" ofType:@"mvsmodels"];
    MVSPersonSegmentationQuality quality = MVSPersonSegmentationMediaPipe;
    if ([NSProcessInfo.processInfo.environment[@"MVS_BENCHMARK"] boolValue]) {
      NSString *vision = NSProcessInfo.processInfo.environment[@"MVS_VISION_PERSON"];
      if ([vision isEqualToString:@"fast"])
        quality = MVSPersonSegmentationVisionFast;
      else if ([vision isEqualToString:@"balanced"])
        quality = MVSPersonSegmentationVisionBalanced;
      else if ([vision isEqualToString:@"accurate"])
        quality = MVSPersonSegmentationVisionAccurate;
      NSString *coreML = NSProcessInfo.processInfo.environment[@"MVS_COREML_PERSON"];
      if ([coreML isEqualToString:@"all"])
        quality = MVSPersonSegmentationCoreMLAll;
      else if ([coreML isEqualToString:@"cpu-gpu"])
        quality = MVSPersonSegmentationCoreMLCPUAndGPU;
      else if ([coreML isEqualToString:@"cpu"])
        quality = MVSPersonSegmentationCoreMLCPUOnly;
      else if ([coreML isEqualToString:@"cpu-ne"])
        quality = MVSPersonSegmentationCoreMLCPUAndNeuralEngine;
    }
    _processor = [[MVSProcessor alloc] initWithModelPackagePath:package
                                                        backend:MVS_METAL
                                      personSegmentationQuality:quality
                                                          error:&error];
    if (!_processor) {
      [self showError:error];
      return;
    }
    // Same generated replacement background as Android; no external asset required.
    CVPixelBufferRef background = nullptr;
    if (CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32BGRA, nullptr,
                            &background) == kCVReturnSuccess) {
      CVPixelBufferLockBaseAddress(background, 0);
      auto *bytes = static_cast<uint8_t *>(CVPixelBufferGetBaseAddress(background));
      size_t stride = CVPixelBufferGetBytesPerRow(background);
      for (int y = 0; y < 64; ++y) {
        for (int x = 0; x < 64; ++x) {
          uint8_t *p = bytes + y * stride + x * 4;
          p[0] = 110 + y;
          p[1] = 60 + y;
          p[2] = 30 + x;
          p[3] = 255;
        }
      }
      CVPixelBufferUnlockBaseAddress(background, 0);
      [_processor setBackground:background error:&error];
      CVPixelBufferRelease(background);
    }
    if (error) {
      [self showError:error];
      return;
    }
  }
  if (!_session) {
    AVCaptureSession *session = [[AVCaptureSession alloc] init];
    [session beginConfiguration];
    AVCaptureDevice *device =
        [AVCaptureDevice defaultDeviceWithDeviceType:AVCaptureDeviceTypeBuiltInWideAngleCamera
                                           mediaType:AVMediaTypeVideo
                                            position:_captureFront ? AVCaptureDevicePositionFront
                                                                   : AVCaptureDevicePositionBack];
    AVCaptureDeviceInput *input = [AVCaptureDeviceInput deviceInputWithDevice:device error:&error];
    if (!input || ![session canAddInput:input]) {
      [session commitConfiguration];
      [self showError:error];
      return;
    }
    [session addInput:input];
    AVCaptureSessionPreset preset =
        _captureTier == 2 ? AVCaptureSessionPreset1920x1080 : AVCaptureSessionPreset1280x720;
    // Preserve the same 16:9 480x854 output while asking the ISP for fewer
    // excess pixels. Some cameras do not support this preset; retain 720P there.
    if (_captureTier == 0 && [session canSetSessionPreset:AVCaptureSessionPresetiFrame960x540])
      preset = AVCaptureSessionPresetiFrame960x540;
    if (![session canSetSessionPreset:preset]) {
      [session commitConfiguration];
      [self showError:[NSError errorWithDomain:@"Camera"
                                          code:2
                                      userInfo:@{
                                        NSLocalizedDescriptionKey :
                                            @"当前摄像头不支持该分辨率，请切换档位"
                                      }]];
      return;
    }
    session.sessionPreset = preset;
    AVCaptureVideoDataOutput *output = [[AVCaptureVideoDataOutput alloc] init];
    output.alwaysDiscardsLateVideoFrames = YES;
    output.videoSettings = @{(id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA)};
    [output setSampleBufferDelegate:self queue:_usePipeline ? _captureQueue : _cameraQueue];
    if (![session canAddOutput:output]) {
      [session commitConfiguration];
      return;
    }
    [session addOutput:output];
    AVCaptureConnection *connection = [output connectionWithMediaType:AVMediaTypeVideo];
    if (connection.isVideoOrientationSupported) {
      connection.videoOrientation = AVCaptureVideoOrientationPortrait;
    }
    if (connection.isVideoMirroringSupported) {
      connection.automaticallyAdjustsVideoMirroring = NO;
      connection.videoMirrored = NO;
    }
    [session commitConfiguration];
    // 720P targets 25 fps to keep headroom for matched-frame inference/rendering
    // and reduce sustained GPU load. The other tiers retain 30 fps capture.
    int targetFPS = _captureTier == 1 ? 25 : 30;
    for (AVFrameRateRange *range in device.activeFormat.videoSupportedFrameRateRanges) {
      if (range.minFrameRate <= targetFPS && range.maxFrameRate >= targetFPS &&
          [device lockForConfiguration:&error]) {
        device.activeVideoMinFrameDuration = CMTimeMake(1, targetFPS);
        device.activeVideoMaxFrameDuration = CMTimeMake(1, targetFPS);
        [device unlockForConfiguration];
        break;
      }
    }
    _session = session;
    @synchronized(self) {
      _captureDevice = device;
    }
  }
  if (!_session.running) {
    [_session startRunning];
  }
}
- (CVPixelBufferRef)newCaptureBuffer:(CVPixelBufferRef)input {
  size_t iw = CVPixelBufferGetWidth(input), ih = CVPixelBufferGetHeight(input);
  size_t shortSide = _captureTier == 2 ? 1080 : _captureTier == 1 ? 720 : 480;
  size_t w = iw < ih ? shortSide : size_t(lround(double(iw) * shortSide / ih / 2)) * 2;
  size_t h = ih < iw ? shortSide : size_t(lround(double(ih) * shortSide / iw / 2)) * 2;
  if (iw == w && ih == h && !_benchmarkPortrait) {
    CVPixelBufferRetain(input);
    return input;
  }
  if (!_capturePool || _captureWidth != w || _captureHeight != h) {
    if (_portraitBuffer) {
      CVPixelBufferRelease(_portraitBuffer);
      _portraitBuffer = nullptr;
    }
    if (_capturePool) {
      CVPixelBufferPoolRelease(_capturePool);
      _capturePool = nullptr;
    }
    NSDictionary *attrs = @{
      (id)kCVPixelBufferPixelFormatTypeKey : @(kCVPixelFormatType_32BGRA),
      (id)kCVPixelBufferWidthKey : @(w),
      (id)kCVPixelBufferHeightKey : @(h),
      (id)kCVPixelBufferMetalCompatibilityKey : @YES,
      (id)kCVPixelBufferIOSurfacePropertiesKey : @{}
    };
    if (CVPixelBufferPoolCreate(kCFAllocatorDefault, nullptr, (__bridge CFDictionaryRef)attrs,
                                &_capturePool) != kCVReturnSuccess) {
      return nullptr;
    }
    _captureWidth = w;
    _captureHeight = h;
  }
  CVPixelBufferRef scaled = nullptr;
  if (CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _capturePool, &scaled) !=
      kCVReturnSuccess) {
    return nullptr;
  }
  CVReturn sourceLock = CVPixelBufferLockBaseAddress(input, kCVPixelBufferLock_ReadOnly);
  CVReturn destinationLock = CVPixelBufferLockBaseAddress(scaled, 0);
  vImage_Error result = kvImageInvalidParameter;
  if (sourceLock == kCVReturnSuccess && destinationLock == kCVReturnSuccess) {
    vImage_Buffer source{CVPixelBufferGetBaseAddress(input), ih, iw,
                         CVPixelBufferGetBytesPerRow(input)};
    vImage_Buffer destination{CVPixelBufferGetBaseAddress(scaled), h, w,
                              CVPixelBufferGetBytesPerRow(scaled)};
    vImage_Error bytes =
        vImageScale_ARGB8888(&source, &destination, nullptr, kvImageGetTempBufferSize);
    if (bytes >= 0) {
      if (_scaleScratch.size() < size_t(bytes)) _scaleScratch.resize(size_t(bytes));
      result = vImageScale_ARGB8888(&source, &destination,
                                    _scaleScratch.empty() ? nullptr : _scaleScratch.data(),
                                    kvImageNoFlags);
    }
  }
  if (destinationLock == kCVReturnSuccess) CVPixelBufferUnlockBaseAddress(scaled, 0);
  if (sourceLock == kCVReturnSuccess)
    CVPixelBufferUnlockBaseAddress(input, kCVPixelBufferLock_ReadOnly);
  if (result != kvImageNoError) {
    CIImage *image = [[CIImage imageWithCVPixelBuffer:input]
        imageByApplyingTransform:CGAffineTransformMakeScale(double(w) / iw, double(h) / ih)];
    [_captureContext render:image toCVPixelBuffer:scaled];
  }
  if (_benchmarkPortrait) {
    if (!_portraitBuffer &&
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, _capturePool, &_portraitBuffer) ==
            kCVReturnSuccess) {
      CGRect extent = _benchmarkPortrait.extent;
      CGFloat scale = MAX(w / extent.size.width, h / extent.size.height);
      CIImage *portrait =
          [_benchmarkPortrait imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
      portrait = [portrait imageByApplyingTransform:CGAffineTransformMakeTranslation(
                                                        (w - portrait.extent.size.width) / 2 -
                                                            portrait.extent.origin.x,
                                                        (h - portrait.extent.size.height) / 2 -
                                                            portrait.extent.origin.y)];
      [_captureContext render:portrait toCVPixelBuffer:_portraitBuffer];
    }
    if (_portraitBuffer && _benchmarkMotion) {
      if (!_portraitMotionStart) _portraitMotionStart = CACurrentMediaTime();
      double phase = (CACurrentMediaTime() - _portraitMotionStart) * 2 * M_PI / 4;
      CIImage *moving = [[CIImage imageWithCVPixelBuffer:_portraitBuffer] imageByClampingToExtent];
      moving = [moving
          imageByApplyingTransform:CGAffineTransformMakeTranslation(w * .04 * std::sin(phase),
                                                                    h * .015 * std::cos(phase))];
      [_captureContext render:moving toCVPixelBuffer:scaled];
    } else if (_portraitBuffer) {
      CVPixelBufferLockBaseAddress(_portraitBuffer, kCVPixelBufferLock_ReadOnly);
      CVPixelBufferLockBaseAddress(scaled, 0);
      const auto *source =
          static_cast<const uint8_t *>(CVPixelBufferGetBaseAddress(_portraitBuffer));
      auto *destination = static_cast<uint8_t *>(CVPixelBufferGetBaseAddress(scaled));
      for (size_t y = 0; y < h; ++y)
        std::memcpy(destination + y * CVPixelBufferGetBytesPerRow(scaled),
                    source + y * CVPixelBufferGetBytesPerRow(_portraitBuffer), w * 4);
      CVPixelBufferUnlockBaseAddress(scaled, 0);
      CVPixelBufferUnlockBaseAddress(_portraitBuffer, kCVPixelBufferLock_ReadOnly);
    }
  }
  return scaled;
}
- (void)presentOutput:(CVPixelBufferRef)processed
              timings:(MVSFrameTimings)timings
    scaleMilliseconds:(double)scaleMilliseconds
              elapsed:(double)ms
           generation:(uint64_t)generation
               mirror:(BOOL)mirror
                 tier:(NSInteger)tier
          diagnostics:(BOOL)showDiagnostics {
  double inference = timings.analysisMilliseconds;
  NSUInteger landmarkCount = timings.faceLandmarkCount;
  dispatch_block_t display = ^{
    if (generation != self->_generation.load() || !self->_visible) {
      CVPixelBufferRelease(processed);
      self->_pending = false;
      return;
    }
    if (self->_displayed) {
      CVPixelBufferRelease(self->_displayed);
    }
    self->_displayed = processed;
    self->_displayMirror = mirror;
    // The camera's processed image already bounds available detail. Render
    // that detail once, then let the layer scale to the full preview bounds.
    // Keep the drawable's aspect equal to the view so aspect-fit bars match.
    CGSize bounds = self->_preview.bounds.size;
    if (bounds.width > 0 && bounds.height > 0) {
      double density = std::min(double(UIScreen.mainScreen.nativeScale),
                                std::max(CVPixelBufferGetWidth(processed) / bounds.width,
                                         CVPixelBufferGetHeight(processed) / bounds.height));
      CGSize drawable =
          CGSizeMake(std::ceil(bounds.width * density), std::ceil(bounds.height * density));
      if (!CGSizeEqualToSize(self->_preview.drawableSize, drawable))
        self->_preview.drawableSize = drawable;
    }
    CFTimeInterval submissionStarted = CACurrentMediaTime();
    [self->_preview draw];
    if (self->_recordOutput) [self recordOutput:processed];
    double submissionMilliseconds = (CACurrentMediaTime() - submissionStarted) * 1000;
    CFTimeInterval now = CACurrentMediaTime();
    if (!self->_fpsStart) {
      self->_fpsStart = now;
      self->_presentedFrames = 0;
    } else {
      self->_presentedFrames++;
    }
    double elapsed = now - self->_fpsStart;
    if (elapsed >= 1) {
      self->_fps = self->_presentedFrames / elapsed;
      self->_presentedFrames = 0;
      self->_fpsStart = now;
    }
    if (now - self->_lastStatusTick >= .25) {
      self->_lastStatusTick = now;
      self->_status.text = [NSString stringWithFormat:@"%.1f FPS · %zu×%zu", self->_fps,
          CVPixelBufferGetWidth(processed), CVPixelBufferGetHeight(processed)];
    }
    if (self->_benchmark) {
      self->_benchmarkFrames++;
      self->_scaleTotal += scaleMilliseconds;
      self->_segmentTotal += timings.segmentationMilliseconds;
      self->_faceTotal += timings.faceMilliseconds;
      self->_analysisTotal += timings.analysisMilliseconds;
      self->_coreTotal += timings.renderingMilliseconds;
      self->_submitTotal += submissionMilliseconds;
      self->_processTotal += ms;
      self->_packTotal += timings.core.packing_ms;
      self->_maskTotal += timings.core.mask_ms;
      self->_prepareTotal += timings.core.preparation_ms;
      self->_renderTotal += timings.core.rendering_ms;
      self->_outputTotal += timings.core.output_ms;
      self->_queueTotal += timings.inferenceQueueMilliseconds;
      self->_latencyTotal += timings.endToEndMilliseconds;
      NSDictionary *metrics = @{
        @"frames" : @(self->_benchmarkFrames),
        @"precisionSamples" : @(timings.core.precision_samples),
        @"precisionMax" : @(timings.core.precision_max_error),
        @"precisionMAE" : @(timings.core.precision_mean_error),
        @"maskWidth" : @(timings.maskWidth),
        @"maskHeight" : @(timings.maskHeight),
        @"maskMAE" : @(timings.maskComparisonMeanError),
        @"maskIoU" : @(timings.maskComparisonIoU),
        @"queue" : @(self->_queueTotal),
        @"latency" : @(self->_latencyTotal),
        @"pack" : @(self->_packTotal),
        @"mask" : @(self->_maskTotal),
        @"prepare" : @(self->_prepareTotal),
        @"render" : @(self->_renderTotal),
        @"output" : @(self->_outputTotal),
        @"time" : @(now),
        @"fps" : @(self->_fps),
        @"scale" : @(self->_scaleTotal),
        @"segment" : @(self->_segmentTotal),
        @"analysis" : @(self->_analysisTotal),
        @"face" : @(self->_faceTotal),
        @"core" : @(self->_coreTotal),
        @"submit" : @(self->_submitTotal),
        @"process" : @(self->_processTotal),
        @"width" : @(CVPixelBufferGetWidth(processed)),
        @"height" : @(CVPixelBufferGetHeight(processed)),
        @"captureWidth" : @(self->_sensorWidth.load()),
        @"captureHeight" : @(self->_sensorHeight.load()),
        @"landmarks" : @(landmarkCount),
        @"thermal" : @(NSProcessInfo.processInfo.thermalState),
        @"inference" : self->_processor.inferenceDescription
      };
      NSData *json = [NSJSONSerialization dataWithJSONObject:metrics options:0 error:nil];
      self->_status.accessibilityValue = [[NSString alloc] initWithData:json
                                                               encoding:NSUTF8StringEncoding];
    }
    self->_pending = false;
  };
  if (_usePipeline)
    dispatch_sync(dispatch_get_main_queue(), display);
  else
    dispatch_async(dispatch_get_main_queue(), display);
}
- (void)captureOutput:(AVCaptureOutput *)output
    didOutputSampleBuffer:(CMSampleBufferRef)sample
           fromConnection:(AVCaptureConnection *)connection {
  if (!_visible) return;
  CVPixelBufferRef sensor = CMSampleBufferGetImageBuffer(sample);
  _sensorWidth = unsigned(CVPixelBufferGetWidth(sensor));
  _sensorHeight = unsigned(CVPixelBufferGetHeight(sensor));
  uint64_t generation = _generation.load();
  if (generation != _captureSeenGeneration) {
    _captureSeenGeneration = generation;
    _captureWarmupFrames = 3;
    _captureWarmupStarted = CACurrentMediaTime();
  }
  // The sensor can deliver initial black frames after changing formats.
  // Discard those samples before submitting them to processing and preview.
  if (_captureWarmupFrames) {
    --_captureWarmupFrames;
    return;
  }
  if (_captureWarmupStarted) {
    double elapsed = CACurrentMediaTime() - _captureWarmupStarted;
    AVCaptureDevice *device;
    @synchronized(self) {
      device = _captureDevice;
    }
    // The first three frames can be non-black but badly underexposed.
    // Wait briefly for native exposure/white balance to settle on startup
    // or a format change. Bound the wait; normal live exposure stays automatic.
    if (elapsed < .30 ||
        (elapsed < 1.0 && (device.isAdjustingExposure || device.isAdjustingWhiteBalance)))
      return;
    _captureWarmupStarted = 0;
  }
  if (!_usePipeline && _pending.exchange(true)) return;
  @autoreleasepool {
    NSError *error = nil;
    MvsOptions options;
    @synchronized(self) {
      options = _options;
      if (!_allBeautyEnabled) {
        for (NSInteger i = 0; i < 13; ++i) SetValue(options, i, Neutral(i));
      }
    }
    CFTimeInterval started = CACurrentMediaTime();
    int64_t timestamp =
        (int64_t)(CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sample)) * 1000);
    CVPixelBufferRef input = [self newCaptureBuffer:CMSampleBufferGetImageBuffer(sample)];
    double scaleMilliseconds = (CACurrentMediaTime() - started) * 1000;
    if (!input) {
      _pending = false;
      return;
    }
    BOOL mirror = _captureFront;
    NSInteger tier = _captureTier;
    BOOL showDiagnostics = options.debug_landmarks || options.debug_face_mesh;
    if (_usePipeline) {
      [_processor submitPixelBuffer:input
              timestampMilliseconds:timestamp
                            options:options
                         completion:^(CVPixelBufferRef processed, MVSFrameTimings timings,
                                      NSError *processingError) {
                           if (processed) {
                             CVPixelBufferRetain(processed);
                             [self presentOutput:processed
                                           timings:timings
                                 scaleMilliseconds:scaleMilliseconds
                                           elapsed:(CACurrentMediaTime() - started) * 1000
                                        generation:generation
                                            mirror:mirror
                                              tier:tier
                                       diagnostics:showDiagnostics];
                           } else if (processingError && generation == self->_generation.load()) {
                             [self showError:processingError];
                           }
                         }];
      CVPixelBufferRelease(input);
      return;
    }
    if (![_processor configure:options error:&error]) {
      CVPixelBufferRelease(input);
      _pending = false;
      [self showError:error];
      return;
    }
    CVPixelBufferRef processed = [_processor newPixelBufferByProcessing:input
                                                  timestampMilliseconds:timestamp
                                                                  error:&error];
    CVPixelBufferRelease(input);
    if (!processed) {
      _pending = false;
      [self showError:error];
      return;
    }
    [self presentOutput:processed
                  timings:_processor.frameTimings
        scaleMilliseconds:scaleMilliseconds
                  elapsed:(CACurrentMediaTime() - started) * 1000
               generation:generation
                   mirror:mirror
                     tier:tier
              diagnostics:showDiagnostics];
  }
}
- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}
- (void)recordOutput:(CVPixelBufferRef)buffer {
  size_t w = CVPixelBufferGetWidth(buffer), h = CVPixelBufferGetHeight(buffer);
  if ((w != 480 && w != 720) || _recordPending.exchange(true)) return;
  CVPixelBufferRetain(buffer);
  CFTimeInterval now = CACurrentMediaTime();
  dispatch_async(_recordQueue, ^{
    @autoreleasepool {
      NSString *directory =
          NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)
              .firstObject;
      NSString *stem = [NSString
          stringWithFormat:self->_benchmarkMotion ? @"blur-motion-%zux%zu" : @"blur-%zux%zu", w, h];
      if (w != self->_movieWidth || h != self->_movieHeight) {
        self->_movieWidth = w;
        self->_movieHeight = h;
        self->_movieStart = now;
        self->_movieFrames = 0;
        self->_movieFinished = NO;
        NSURL *url = [NSURL fileURLWithPath:[directory stringByAppendingPathComponent:
                                                           [stem stringByAppendingString:@".mp4"]]];
        [NSFileManager.defaultManager removeItemAtURL:url error:nil];
        NSError *error = nil;
        self->_movieWriter = [[AVAssetWriter alloc] initWithURL:url
                                                       fileType:AVFileTypeMPEG4
                                                          error:&error];
        self->_movieInput =
            [AVAssetWriterInput assetWriterInputWithMediaType:AVMediaTypeVideo
                                               outputSettings:@{
                                                 AVVideoCodecKey : AVVideoCodecTypeH264,
                                                 AVVideoWidthKey : @(w),
                                                 AVVideoHeightKey : @(h),
                                                 AVVideoCompressionPropertiesKey :
                                                     @{AVVideoAverageBitRateKey : @4000000}
                                               }];
        self->_movieInput.expectsMediaDataInRealTime = YES;
        self->_movieAdaptor = [AVAssetWriterInputPixelBufferAdaptor
            assetWriterInputPixelBufferAdaptorWithAssetWriterInput:self->_movieInput
                                       sourcePixelBufferAttributes:nil];
        if ([self->_movieWriter canAddInput:self->_movieInput]) {
          [self->_movieWriter addInput:self->_movieInput];
          if ([self->_movieWriter startWriting])
            [self->_movieWriter startSessionAtSourceTime:kCMTimeZero];
        }
      }
      double elapsed = now - self->_movieStart;
      if (!self->_movieFinished && self->_movieWriter.status == AVAssetWriterStatusWriting) {
        if (elapsed < 10 && self->_movieInput.readyForMoreMediaData) {
          if ([self->_movieAdaptor appendPixelBuffer:buffer
                                withPresentationTime:CMTimeMakeWithSeconds(elapsed, 60000)])
            self->_movieFrames++;
        } else if (elapsed >= 10) {
          self->_movieFinished = YES;
          [self->_movieInput markAsFinished];
          AVAssetWriter *writer = self->_movieWriter;
          NSDictionary *metadata = @{
            @"width" : @(w),
            @"height" : @(h),
            @"frames" : @(self->_movieFrames),
            @"seconds" : @(elapsed)
          };
          NSString *json =
              [directory stringByAppendingPathComponent:[stem stringByAppendingString:@".json"]];
          [writer finishWritingWithCompletionHandler:^{
            NSMutableDictionary *result = [metadata mutableCopy];
            result[@"success"] = @(writer.status == AVAssetWriterStatusCompleted);
            NSData *data = [NSJSONSerialization dataWithJSONObject:result
                                                           options:NSJSONWritingPrettyPrinted
                                                             error:nil];
            [data writeToFile:json atomically:YES];
          }];
        }
      }
      CVPixelBufferRelease(buffer);
      self->_recordPending = false;
    }
  });
}
- (void)drawInMTKView:(MTKView *)view {
  id<CAMetalDrawable> drawable = view.currentDrawable;
  if (!drawable) {
    return;
  }
  CIImage *image = _displayed ? [CIImage imageWithCVPixelBuffer:_displayed]
                              : [CIImage imageWithColor:CIColor.blackColor];
  CGSize target = view.drawableSize;
  if (_displayed) {
    if (_displayMirror) {
      image = [image
          imageByApplyingTransform:CGAffineTransformMake(-1, 0, 0, 1, image.extent.size.width, 0)];
    }
    CGFloat scale =
        MIN(target.width / image.extent.size.width, target.height / image.extent.size.height);
    image = [image imageByApplyingTransform:CGAffineTransformMakeScale(scale, scale)];
    image = [image imageByApplyingTransform:CGAffineTransformMakeTranslation(
                                                (target.width - image.extent.size.width) / 2,
                                                target.height - image.extent.size.height)];
    image = [image imageByCompositingOverImage:[CIImage imageWithColor:CIColor.blackColor]];
  }
  id<MTLCommandBuffer> command = [_renderQueue commandBuffer];
  [_context render:image
       toMTLTexture:drawable.texture
      commandBuffer:command
             bounds:CGRectMake(0, 0, target.width, target.height)
         colorSpace:_previewColorSpace];
  CVPixelBufferRef displayed = _displayed ? CVPixelBufferRetain(_displayed) : nullptr;
  [command addCompletedHandler:^(id<MTLCommandBuffer> finished) {
    if (displayed) CVPixelBufferRelease(displayed);
  }];
  [command presentDrawable:drawable];
  [command commit];
}
- (void)dealloc {
  if (_portraitBuffer) CVPixelBufferRelease(_portraitBuffer);
  if (_previewColorSpace) CGColorSpaceRelease(_previewColorSpace);
  [NSNotificationCenter.defaultCenter removeObserver:self];
  if (_displayed) {
    CVPixelBufferRelease(_displayed);
  }
  if (_capturePool) {
    CVPixelBufferPoolRelease(_capturePool);
  }
}
@end
