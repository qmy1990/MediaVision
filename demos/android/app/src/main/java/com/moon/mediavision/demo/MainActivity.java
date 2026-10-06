package com.moon.mediavision.demo;

import android.Manifest;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.Process;
import android.os.SystemClock;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.widget.*;
import androidx.activity.ComponentActivity;
import androidx.activity.result.ActivityResultLauncher;
import androidx.activity.result.contract.ActivityResultContracts;
import androidx.core.content.ContextCompat;
import androidx.recyclerview.widget.LinearLayoutManager;
import androidx.recyclerview.widget.RecyclerView;
import com.moon.mediavision.*;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.*;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicLong;
import java.util.function.IntConsumer;
import java.util.function.IntSupplier;

public final class MainActivity extends ComponentActivity {
  private final ExecutorService worker =
      Executors.newSingleThreadExecutor(
          r ->
              new Thread(
                  () -> {
                    Process.setThreadPriority(Process.THREAD_PRIORITY_DISPLAY);
                    r.run();
                  },
                  "MvsRender"));
  private final AtomicBoolean pending = new AtomicBoolean();
  private final AtomicLong cameraGeneration = new AtomicLong();
  private final AtomicBoolean cameraRetryScheduled = new AtomicBoolean();
  private final AtomicInteger cameraRetryAttempts = new AtomicInteger();
  private final Handler mainHandler = new Handler(Looper.getMainLooper());
  private SurfaceView preview;
  private SurfaceHolder surfaceHolder;
  private TextView status;
  private SeekBar effectSlider;
  private Switch effectSwitch;
  private Button allBeautyButton;
  private Spinner lipstickColorSpinner;
  private Spinner skinToneSpinner;
  private RecyclerView effectList;
  private EffectAdapter effectAdapter;
  private final List<EffectControl> effects = new ArrayList<>();
  private int selectedEffect;
  // 83 retains the old radius 24; 100 maps to round(24 * 1.2) = 29.
  private static final int DEFAULT_BLUR_STRENGTH = 83;
  private int blurStrength = DEFAULT_BLUR_STRENGTH;
  private int blurStrengthBeforeDrag = DEFAULT_BLUR_STRENGTH;
  private boolean syncingEffectUi;
  private VisionSdk sdk;
  private volatile Camera2Frames camera2;
  private VisionOptions configuredOptions;
  private long displayedFrames;
  private long lastFpsTick;
  private int displayFps;
  private FrameMetrics metrics;
  private long uniqueFrames;
  private long lastPresentedToken = -1;
  private int uniqueFps;
  private long lastStatusTick;
  private volatile boolean destroyed = false;
  private volatile boolean surfaceReady = false;
  private volatile boolean resumed = false;
  private volatile VisionOptions options =
      new VisionOptions.Builder()
          .beauty(.55f)
          .whitening(.25f)
          .sharpen(.45f)
          .background(VisionOptions.BLUR)
          .blurRadius(24)
          .maskSmoothing(0)
          .eyeEnlarge(.25f)
          .faceSlim(.28f)
          .blemishRemoval(.35f)
          .lipstick(.22f)
          .blush(.12f)
          .noseSlim(.18f)
          .eyebrowDarkening(.18f)
          .cheekboneReduce(.5f)
          .eyeSpacing(.5f)
          .build();

  /** UI-only master switch. The slider values are retained while disabled. */
  private volatile boolean allBeautyEnabled = true;

  private boolean front = true;
  // 0 = 480P, 1 = 720P, 2 = 1080P. The initial tier follows the SoC class;
  // the button still lets the integrator exercise every capture profile.
  private int resolutionTier;
  private final ActivityResultLauncher<String> permission =
      registerForActivityResult(
          new ActivityResultContracts.RequestPermission(),
          granted -> {
            if (granted) {
              bindCamera();
            } else if (status != null) {
              status.setText("需要相机权限。点击重试授权。");
            }
          });

  @Override
  public void onCreate(Bundle saved) {
    super.onCreate(saved);
    getWindow().addFlags(android.view.WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON);
    if (BuildConfig.DEBUG && getIntent().getBooleanExtra("benchmark_lock", false)) {
      getWindow().addFlags(android.view.WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE);
    }
    if (BuildConfig.DEBUG) {
      applyDebugEffectOverrides();
    }
    resolutionTier = recommendedResolutionTier();
    if (BuildConfig.DEBUG && getIntent().hasExtra("resolution_tier")) {
      resolutionTier =
          Math.max(0, Math.min(2, getIntent().getIntExtra("resolution_tier", resolutionTier)));
    }
    if (BuildConfig.DEBUG) {
      metrics = new FrameMetrics(this);
    }
    FrameLayout root = new FrameLayout(this);
    root.setBackgroundColor(Color.BLACK);
    preview = new AspectSurfaceView(this);
    preview.setContentDescription("相机预览");
    surfaceHolder = preview.getHolder();
    surfaceHolder.addCallback(
        new SurfaceHolder.Callback() {
          @Override
          public void surfaceCreated(SurfaceHolder holder) {
            surfaceReady = true;
            configureSurface();
            if (resumed
                && sdk != null
                && ContextCompat.checkSelfPermission(MainActivity.this, Manifest.permission.CAMERA)
                    == android.content.pm.PackageManager.PERMISSION_GRANTED) {
              bindCamera();
            }
          }

          @Override
          public void surfaceChanged(SurfaceHolder holder, int format, int width, int height) {
            surfaceReady = true;
            configureSurface();
          }

          @Override
          public void surfaceDestroyed(SurfaceHolder holder) {
            surfaceReady = false;
            VisionSdk current = sdk;
            if (current != null) {
              try {
                current.setOutputSurface(null);
              } catch (Throwable ignored) {
              }
            }
          }
        });
    FrameLayout.LayoutParams previewParams = new FrameLayout.LayoutParams(
        -1, -1, android.view.Gravity.TOP | android.view.Gravity.CENTER_HORIZONTAL);
    previewParams.topMargin = dp(40);
    root.addView(preview, previewParams);
    buildCompactOverlay(root);
    setContentView(root);
    root.setOnApplyWindowInsetsListener(
        (v, insets) -> {
          v.setPadding(0, insets.getSystemWindowInsetTop(), 0, insets.getSystemWindowInsetBottom());
          return insets;
        });
    worker.execute(
        () -> {
          try {
            sdk = new VisionSdk(this, VisionSdk.AUTO, SegmentationProfile.AUTO);
            ByteBuffer background = ByteBuffer.allocateDirect(64 * 64 * 4);
            for (int y = 0; y < 64; y++) {
              for (int x = 0; x < 64; x++) {
                background
                    .put((byte) (30 + x))
                    .put((byte) (60 + y))
                    .put((byte) (110 + y))
                    .put((byte) 255);
              }
            }
            background.rewind();
            sdk.setBackground(background, 64, 64, 64 * 4);
            // Compile and warm the selected model delegates before opening
            // Camera2. This avoids presenting a low-FPS preview while a GPU
            // delegate is creating kernels after the first camera frame.
            VisionOptions initial = options;
            sdk.configure(initial);
            configuredOptions = initial;
            runOnUiThread(
                () -> {
                  if (!destroyed) {
                    configureSurface();
                    permission.launch(Manifest.permission.CAMERA);
                  }
                });
          } catch (Exception e) {
            showError(e);
          }
        });
  }

  /** Deterministic screenshot/performance presets for connected-device QA. */
  private void applyDebugEffectOverrides() {
    android.content.Intent intent = getIntent();
    VisionOptions.Builder b = options.toBuilder();
    if (BuildConfig.DEBUG) {
      // Reproduce jaw defects with all other effects disabled, while
      // retaining the requested background mode for matte alignment QA.
      if (intent.getBooleanExtra("neutral_effects", false)) {
        b = new VisionOptions.Builder();
      }
      if (intent.hasExtra("small_head")) {
        b.smallHead(clampUnit(intent.getFloatExtra("small_head", 0f)));
      }
      if (intent.hasExtra("face_slim")) {
        b.faceSlim(clampUnit(intent.getFloatExtra("face_slim", 0f)));
      }
      if (intent.hasExtra("cheekbone")) {
        b.cheekboneReduce(clampUnit(intent.getFloatExtra("cheekbone", .5f)));
      }
      if (intent.hasExtra("nose_slim")) {
        b.noseSlim(clampUnit(intent.getFloatExtra("nose_slim", 0f)));
      }
      if (intent.hasExtra("blemish")) {
        b.blemishRemoval(clampUnit(intent.getFloatExtra("blemish", 0f)));
      }
    }
    if (intent.hasExtra("beauty")) {
      b.beauty(clampUnit(intent.getFloatExtra("beauty", options.beauty)));
    }
    if (intent.hasExtra("whitening")) {
      b.whitening(clampUnit(intent.getFloatExtra("whitening", options.whitening)));
    }
    if (intent.hasExtra("skin_tone")) {
      b.skinTone(
          Math.max(
              VisionOptions.SKIN_NATURAL_WHITE,
              Math.min(VisionOptions.SKIN_TAN, intent.getIntExtra("skin_tone", options.skinTone))));
    }
    if (intent.hasExtra("background")) {
      b.background(
          Math.max(
              VisionOptions.NONE,
              Math.min(VisionOptions.MASK, intent.getIntExtra("background", options.background))));
    }
    if (intent.hasExtra("debug_landmarks")) {
      b.debugLandmarks(intent.getBooleanExtra("debug_landmarks", false));
    }
    if (intent.hasExtra("debug_mesh")) {
      b.debugFaceMesh(intent.getBooleanExtra("debug_mesh", false));
    }
    options = b.build();
  }

  private static float clampUnit(float value) {
    return Math.max(0f, Math.min(1f, value));
  }

  private void buildCompactOverlay(FrameLayout root) {
    LinearLayout top = new LinearLayout(this);
    top.setGravity(android.view.Gravity.CENTER_VERTICAL);
    top.setPadding(dp(6), dp(4), dp(6), dp(4));
    top.setBackgroundColor(Color.argb(110, 12, 25, 54));
    status = new TextView(this);
    status.setTextColor(Color.WHITE);
    status.setTextSize(10);
    status.setSingleLine(true);
    status.setGravity(android.view.Gravity.CENTER_VERTICAL);
    status.setText("0 FPS · —×—");
    status.setContentDescription("帧率与分辨率");
    top.addView(status, new LinearLayout.LayoutParams(0, dp(32), 1));
    allBeautyButton = compactButton("美颜开");
    allBeautyButton.setContentDescription("美颜总开关，已开启");
    Button switchCamera = compactButton("切换");
    switchCamera.setContentDescription("切换前后摄像头，当前前置");
    Button resolutionButton = compactButton(resolutionLabel());
    resolutionButton.setContentDescription("切换分辨率");
    Button landmarkButton = compactButton(options.debugLandmarks ? "点开" : "点关");
    landmarkButton.setContentDescription("显示全部人脸关键点");
    Button meshButton = compactButton(options.debugFaceMesh ? "网格开" : "网格关");
    meshButton.setContentDescription("显示人脸网格");
    Button[] buttons = {switchCamera, resolutionButton, landmarkButton, meshButton, allBeautyButton};
    int[] widths = {40, 44, 32, 44, 46};
    for (int i = 0; i < buttons.length; i++) {
      buttons[i].setTextSize(10);
      LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(dp(widths[i]), dp(32));
      params.leftMargin = dp(4);
      top.addView(buttons[i], params);
    }
    root.addView(top, new FrameLayout.LayoutParams(-1, dp(40), android.view.Gravity.TOP));
    switchCamera.setOnClickListener(
        v -> {
          cameraRetryAttempts.set(0);
          front = !front;
          switchCamera.setContentDescription("切换前后摄像头，当前" + (front ? "前置" : "后置"));
          if (ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
              == android.content.pm.PackageManager.PERMISSION_GRANTED) {
            bindCamera();
          } else {
            permission.launch(Manifest.permission.CAMERA);
          }
        });
    resolutionButton.setOnClickListener(
        v -> {
          cameraRetryAttempts.set(0);
          resolutionTier = (resolutionTier + 2) % 3;
          resolutionButton.setText(resolutionLabel());
          configureSurface();
          bindCamera();
        });
    landmarkButton.setOnClickListener(
        v -> {
          boolean enabled = !options.debugLandmarks;
          options = options.toBuilder().debugLandmarks(enabled).build();
          landmarkButton.setText(enabled ? "点开" : "点关");
          configuredOptions = null;
        });
    meshButton.setOnClickListener(
        v -> {
          boolean enabled = !options.debugFaceMesh;
          options = options.toBuilder().debugFaceMesh(enabled).build();
          meshButton.setText(enabled ? "网格开" : "网格关");
          configuredOptions = null;
        });
    allBeautyButton.setOnClickListener(
        button -> {
          allBeautyEnabled = !allBeautyEnabled;
          allBeautyButton.setText(allBeautyEnabled ? "美颜开" : "美颜关");
          allBeautyButton.setContentDescription(allBeautyEnabled ? "美颜总开关，已开启" : "美颜总开关，已关闭");
          configuredOptions = null;
        });

    buildEffectControls();
    selectedEffect = findEffect("磨皮");
    LinearLayout bottom = new LinearLayout(this);
    bottom.setOrientation(LinearLayout.VERTICAL);
    bottom.setPadding(dp(8), dp(4), dp(8), dp(5));
    bottom.setBackgroundColor(Color.argb(158, 12, 25, 54));
    LinearLayout editor = new LinearLayout(this);
    editor.setGravity(android.view.Gravity.CENTER_VERTICAL);
    effectSwitch = new Switch(this);
    effectSwitch.setTextColor(Color.WHITE);
    effectSwitch.setTextSize(11);
    editor.addView(effectSwitch, new LinearLayout.LayoutParams(dp(76), dp(44)));
    effectSlider = new SeekBar(this);
    effectSlider.setMax(100);
    editor.addView(effectSlider, new LinearLayout.LayoutParams(0, dp(44), 1));
    String[] lipstickNames = {
      "经典红", "珊瑚", "玫瑰", "豆沙", "橘红", "裸色", "粉红色", "蜜桃色", "西柚色", "樱花粉", "草莓红", "水光唇釉"
    };
    lipstickColorSpinner = compactSpinner(lipstickNames);
    LinearLayout.LayoutParams lipstickParams = new LinearLayout.LayoutParams(dp(102), dp(38));
    lipstickParams.leftMargin = dp(4);
    editor.addView(lipstickColorSpinner, lipstickParams);
    lipstickColorSpinner.setOnItemSelectedListener(
        new AdapterView.OnItemSelectedListener() {
          public void onNothingSelected(AdapterView<?> parent) {}

          public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
            if (syncingEffectUi) {
              return;
            }
            int[] colors = lipstickColors();
            if (position >= 0
                && position < colors.length
                && options.lipstickColor != colors[position]) {
              options = options.toBuilder().lipstickColor(colors[position]).build();
              if (effectAdapter != null) {
                effectAdapter.notifyItemChanged(findEffect("口红"));
              }
            }
          }
        });
    String[] skinToneNames = {"自然白", "冷白皮", "红润白", "美黑"};
    skinToneSpinner = compactSpinner(skinToneNames);
    LinearLayout.LayoutParams skinToneParams = new LinearLayout.LayoutParams(dp(102), dp(38));
    skinToneParams.leftMargin = dp(4);
    editor.addView(skinToneSpinner, skinToneParams);
    skinToneSpinner.setOnItemSelectedListener(
        new AdapterView.OnItemSelectedListener() {
          public void onNothingSelected(AdapterView<?> parent) {}

          public void onItemSelected(AdapterView<?> parent, View view, int position, long id) {
            if (syncingEffectUi) {
              return;
            }
            int[] tones = skinTones();
            if (position >= 0 && position < tones.length && options.skinTone != tones[position]) {
              options = options.toBuilder().skinTone(tones[position]).build();
              if (effectAdapter != null) {
                effectAdapter.notifyItemChanged(findEffect("肤色"));
              }
            }
          }
        });
    bottom.addView(editor, new LinearLayout.LayoutParams(-1, dp(44)));
    effectList = new RecyclerView(this);
    effectList.setOverScrollMode(View.OVER_SCROLL_NEVER);
    effectList.setLayoutManager(new LinearLayoutManager(this, RecyclerView.HORIZONTAL, false));
    effectList.setItemViewCacheSize(8);
    effectList.addItemDecoration(new RecyclerView.ItemDecoration() {
      @Override
      public void getItemOffsets(android.graphics.Rect outRect, View view,
          RecyclerView parent, RecyclerView.State state) {
        int position = parent.getChildAdapterPosition(view);
        // Exactly one 5dp gap per adjacent pair, without a trailing gutter.
        outRect.right = position >= 0 && position < state.getItemCount() - 1 ? dp(5) : 0;
      }
    });
    effectAdapter = new EffectAdapter();
    effectList.setAdapter(effectAdapter);
    LinearLayout.LayoutParams listParams = new LinearLayout.LayoutParams(-1, dp(48));
    listParams.topMargin = dp(4);
    bottom.addView(effectList, listParams);
    root.addView(bottom, new FrameLayout.LayoutParams(-1, dp(105), android.view.Gravity.BOTTOM));
    effectSlider.setOnSeekBarChangeListener(
        new SeekBar.OnSeekBarChangeListener() {
          public void onStartTrackingTouch(SeekBar bar) {
            EffectControl effect = effects.get(selectedEffect);
            if ("背景虚化".equals(effect.name)) {
              blurStrengthBeforeDrag = effect.value() > 0 ? effect.value() : effect.lastNonNeutral;
            }
          }

          public void onStopTrackingTouch(SeekBar bar) {
            EffectControl effect = effects.get(selectedEffect);
            // A drag to zero must remember its starting strength, not the
            // incidental 1/2/... values encountered just before zero.
            if ("背景虚化".equals(effect.name) && effect.value() == 0) {
              effect.lastNonNeutral = blurStrengthBeforeDrag;
            }
          }

          public void onProgressChanged(SeekBar bar, int value, boolean fromUser) {
            if (!fromUser || syncingEffectUi) {
              return;
            }
            EffectControl effect = effects.get(selectedEffect);
            if (effect.booleanOnly) {
              return;
            }
            effect.set(value);
            if (value != effect.neutral) {
              effect.lastNonNeutral = value;
            }
            effectAdapter.notifyDataSetChanged();
            syncEffectEditor();
          }
        });
    effectSwitch.setOnCheckedChangeListener(
        (button, on) -> {
          if (syncingEffectUi) {
            return;
          }
          EffectControl effect = effects.get(selectedEffect);
          if (on) {
            int value =
                effect.lastNonNeutral == effect.neutral
                    ? effect.defaultValue
                    : effect.lastNonNeutral;
            effect.set(value);
          } else if (effect.allowDisable) {
            effect.set(effect.neutral);
          }
          effectAdapter.notifyDataSetChanged();
          syncEffectEditor();
        });
    syncEffectEditor();
  }

  private Button compactButton(String text) {
    Button button = new Button(this);
    button.setAllCaps(false);
    button.setText(text);
    button.setTextColor(Color.WHITE);
    button.setTextSize(12);
    button.setPadding(dp(4), 0, dp(4), 0);
    button.setMinHeight(0);
    button.setMinWidth(0);
    GradientDrawable background = new GradientDrawable();
    background.setColor(Color.argb(185, 64, 111, 203));
    background.setStroke(dp(1), Color.argb(210, 30, 69, 145));
    background.setCornerRadius(dp(7));
    button.setBackground(background);
    return button;
  }

  private Spinner compactSpinner(String[] values) {
    Spinner spinner = new Spinner(this, Spinner.MODE_DROPDOWN);
    ArrayAdapter<String> adapter =
        new ArrayAdapter<String>(this, android.R.layout.simple_spinner_dropdown_item, values) {
          private TextView style(View view, boolean dropdown) {
            TextView text = (TextView) view;
            text.setTextSize(12);
            text.setTextColor(dropdown ? Color.rgb(24, 32, 48) : Color.WHITE);
            text.setPadding(dp(10), 0, dp(8), 0);
            return text;
          }

          @Override
          public View getView(int position, View convertView, android.view.ViewGroup parent) {
            return style(super.getView(position, convertView, parent), false);
          }

          @Override
          public View getDropDownView(
              int position, View convertView, android.view.ViewGroup parent) {
            return style(super.getDropDownView(position, convertView, parent), true);
          }
        };
    spinner.setAdapter(adapter);
    GradientDrawable background = new GradientDrawable();
    background.setColor(Color.argb(205, 48, 86, 156));
    background.setStroke(dp(1), Color.argb(220, 30, 69, 145));
    background.setCornerRadius(dp(7));
    spinner.setBackground(background);
    return spinner;
  }

  private void buildEffectControls() {
    effects.clear();
    effects.add(
        strength(
            "背景虚化",
            0,
            DEFAULT_BLUR_STRENGTH,
            () -> options.background == VisionOptions.BLUR ? blurStrength : 0,
            this::setBackgroundBlur));
    effects.add(
        strength(
            "磨皮",
            0,
            55,
            () -> pct(options.beauty),
            v -> options = options.toBuilder().beauty(v / 100f).build()));
    effects.add(
        strength(
            "祛痘",
            0,
            35,
            () -> pct(options.blemishRemoval),
            v -> options = options.toBuilder().blemishRemoval(v / 100f).build()));
    effects.add(
        strength(
            "肤色",
            0,
            25,
            () -> pct(options.whitening),
            v -> options = options.toBuilder().whitening(v / 100f).build()));
    effects.add(
        strength(
            "增强",
            0,
            45,
            () -> pct(options.sharpen),
            v -> options = options.toBuilder().sharpen(v / 100f).build()));
    effects.add(
        strength(
            "大眼",
            0,
            25,
            () -> pct(options.eyeEnlarge),
            v -> options = options.toBuilder().eyeEnlarge(v / 100f).build()));
    effects.add(
        strength(
            "小头",
            0,
            35,
            () -> pct(options.smallHead),
            v -> options = options.toBuilder().smallHead(v / 100f).build()));
    effects.add(
        strength(
            "瘦脸",
            0,
            28,
            () -> pct(options.faceSlim),
            v -> options = options.toBuilder().faceSlim(v / 100f).build()));
    effects.add(
        strength(
            "鼻翼",
            0,
            18,
            () -> pct(options.noseSlim),
            v -> options = options.toBuilder().noseSlim(v / 100f).build()));
    effects.add(
        strength(
            "眼距",
            50,
            65,
            () -> pct(options.eyeSpacing),
            v -> options = options.toBuilder().eyeSpacing(v / 100f).build()));
    effects.add(
        strength(
            "颧骨",
            50,
            50,
            () -> pct(options.cheekboneReduce),
            v -> options = options.toBuilder().cheekboneReduce(v / 100f).build()));
    effects.add(
        strength(
            "口红",
            0,
            30,
            () -> pct(options.lipstick),
            v -> options = options.toBuilder().lipstick(v / 100f).build()));
    effects.add(
        strength(
            "晒红",
            0,
            20,
            () -> pct(options.blush),
            v -> options = options.toBuilder().blush(v / 100f).build()));
    effects.add(
        strength(
            "眉毛",
            0,
            25,
            () -> pct(options.eyebrowDarkening),
            v -> options = options.toBuilder().eyebrowDarkening(v / 100f).build()));
    effects.add(
        toggle(
            "道具",
            () -> options.prop ? 100 : 0,
            v -> options = options.toBuilder().prop(v > 0).build()));
    effects.add(
        toggle(
            "头饰",
            () -> options.headwear ? 100 : 0,
            v -> options = options.toBuilder().headwear(v > 0).build()));
    effects.add(
        toggle(
            "首饰",
            () -> options.jewelry ? 100 : 0,
            v -> options = options.toBuilder().jewelry(v > 0).build()));
    effects.add(new EffectControl("Mask", true, 0, 100,
        () -> options.background == VisionOptions.MASK ? 100 : 0,
        v -> setBackgroundMode(VisionOptions.MASK, v), true, true));
    effects.add(new EffectControl("换背景", true, 0, 100,
        () -> options.background == VisionOptions.REPLACE ? 100 : 0,
        v -> setBackgroundMode(VisionOptions.REPLACE, v), true, true));
  }

  private static int[] lipstickColors() {
    return new int[] {
      VisionOptions.LIP_CLASSIC_RED,
      VisionOptions.LIP_CORAL,
      VisionOptions.LIP_ROSE,
      VisionOptions.LIP_BEAN_PASTE,
      VisionOptions.LIP_ORANGE_RED,
      VisionOptions.LIP_NUDE,
      VisionOptions.LIP_PINK,
      VisionOptions.LIP_PEACH,
      VisionOptions.LIP_GRAPEFRUIT,
      VisionOptions.LIP_SAKURA_PINK,
      VisionOptions.LIP_STRAWBERRY_RED,
      VisionOptions.LIP_WATER_GLOSS
    };
  }

  private void setBackgroundMode(int mode, int enabled) {
    if (enabled > 0) {
      options = options.toBuilder().background(mode).build();
    } else if (options.background == mode) {
      options = options.toBuilder().background(VisionOptions.NONE).build();
    }
  }

  private void setBackgroundBlur(int strength) {
    blurStrength = Math.max(0, Math.min(100, strength));
    int radius = Math.max(1, Math.round(24f * 1.2f * blurStrength / 100f));
    options =
        options.toBuilder()
            .blurRadius(radius)
            .background(blurStrength > 0 ? VisionOptions.BLUR : VisionOptions.NONE)
            .build();
  }

  private static String lipstickColorName(int color) {
    int[] colors = lipstickColors();
    String[] names = {
      "经典红", "珊瑚", "玫瑰", "豆沙", "橘红", "裸色", "粉红色", "蜜桃色", "西柚色", "樱花粉", "草莓红", "水光唇釉"
    };
    for (int i = 0; i < colors.length; i++)
      if (colors[i] == color) {
        return names[i];
      }
    return "自定义";
  }

  private static int lipstickColorIndex(int color) {
    int[] values = lipstickColors();
    for (int i = 0; i < values.length; i++)
      if (values[i] == color) {
        return i;
      }
    return 0;
  }

  private static int[] skinTones() {
    return new int[] {
      VisionOptions.SKIN_NATURAL_WHITE,
      VisionOptions.SKIN_COOL_WHITE,
      VisionOptions.SKIN_ROSY_WHITE,
      VisionOptions.SKIN_TAN
    };
  }

  private static String skinToneName(int tone) {
    String[] names = {"自然白", "冷白皮", "红润白", "美黑"};
    return tone >= 0 && tone < names.length ? names[tone] : "自然白";
  }

  private int findEffect(String name) {
    for (int i = 0; i < effects.size(); i++)
      if (name.equals(effects.get(i).name)) {
        return i;
      }
    return 0;
  }

  private EffectControl strength(
      String name, int neutral, int defaultValue, IntSupplier getter, IntConsumer setter) {
    return new EffectControl(name, false, neutral, defaultValue, getter, setter);
  }

  private EffectControl toggle(String name, IntSupplier getter, IntConsumer setter) {
    return new EffectControl(name, true, 0, 100, getter, setter);
  }

  private static int pct(float value) {
    return Math.max(0, Math.min(100, Math.round(value * 100)));
  }

  private void syncEffectEditor() {
    if (effects.isEmpty()) {
      return;
    }
    EffectControl effect = effects.get(selectedEffect);
    int value = effect.value();
    if (value != effect.neutral) {
      effect.lastNonNeutral = value;
    }
    syncingEffectUi = true;
    effectSwitch.setContentDescription(effect.name + "开关");
    effectSlider.setContentDescription(effect.name + "强度");
    effectSlider.setProgress(value);
    effectSlider.setVisibility(effect.booleanOnly ? View.INVISIBLE : View.VISIBLE);
    boolean lipstick = "口红".equals(effect.name);
    lipstickColorSpinner.setVisibility(lipstick ? View.VISIBLE : View.GONE);
    if (lipstick) {
      lipstickColorSpinner.setSelection(lipstickColorIndex(options.lipstickColor), false);
    }
    boolean skinTone = "肤色".equals(effect.name);
    skinToneSpinner.setVisibility(skinTone ? View.VISIBLE : View.GONE);
    if (skinTone) {
      skinToneSpinner.setSelection(options.skinTone, false);
    }
    boolean enabled = value != effect.neutral;
    effectSwitch.setChecked(enabled);
    effectSwitch.setText(enabled ? "开" : "关");
    effectSwitch.setEnabled(effect.allowDisable || !enabled);
    syncingEffectUi = false;
  }

  /**
   * Returns the options actually sent to the native renderer. Background, mask and accessory
   * controls intentionally remain active so the master switch isolates beauty retouching without
   * hiding the selected scene.
   */
  private VisionOptions effectiveOptions() {
    VisionOptions value = options;
    if (allBeautyEnabled) {
      return value;
    }
    return value.toBuilder()
        .beauty(0)
        .whitening(0)
        .sharpen(0)
        .eyeEnlarge(0)
        .faceSlim(0)
        .smallHead(0)
        .blemishRemoval(0)
        .lipstick(0)
        .blush(0)
        .noseSlim(0)
        .eyebrowDarkening(0)
        .cheekboneReduce(.5f)
        .eyeSpacing(.5f)
        .build();
  }

  private final class EffectAdapter extends RecyclerView.Adapter<EffectHolder> {
    EffectAdapter() {
      setHasStableIds(true);
    }

    @Override
    public long getItemId(int position) {
      return position;
    }

    @Override
    public EffectHolder onCreateViewHolder(android.view.ViewGroup parent, int viewType) {
      TextView item = new TextView(MainActivity.this);
      item.setTextSize(14);
      item.setGravity(android.view.Gravity.CENTER);
      item.setPadding(dp(13), 0, dp(13), 0);
      item.setSingleLine(true);
      item.setLayoutParams(new RecyclerView.LayoutParams(-2, -1));
      return new EffectHolder(item);
    }

    @Override
    public void onBindViewHolder(EffectHolder holder, int position) {
      EffectControl effect = effects.get(position);
      holder.text.setText(displayLabel(effect));
      holder.text.setContentDescription(effect.name + "，当前值 " + effect.value());
      holder.text.setTextColor(Color.WHITE);
      GradientDrawable background = new GradientDrawable();
      background.setCornerRadius(dp(6));
      background.setColor(
          position == selectedEffect ? Color.argb(235, 70, 111, 196) : Color.argb(105, 12, 25, 54));
      if (position == selectedEffect) {
        background.setStroke(dp(1), Color.rgb(150, 190, 255));
      }
      holder.text.setBackground(background);
      holder.text.setOnClickListener(
          v -> {
            int old = selectedEffect;
            selectedEffect = holder.getBindingAdapterPosition();
            if (selectedEffect < 0) {
              return;
            }
            EffectControl selected = effects.get(selectedEffect);
            if (selected.activateOnSelect) {
              selected.set(selected.defaultValue);
            }
            notifyDataSetChanged();
            syncEffectEditor();
          });
    }

    @Override
    public int getItemCount() {
      return effects.size();
    }
  }

  private String displayLabel(EffectControl effect) {
    if ("口红".equals(effect.name)) {
      return "口红-" + lipstickColorName(options.lipstickColor) + "-" + effect.value();
    }
    if ("肤色".equals(effect.name)) {
      return "肤色-" + skinToneName(options.skinTone) + "-" + effect.value();
    }
    return effect.label();
  }

  private static final class EffectHolder extends RecyclerView.ViewHolder {
    final TextView text;

    EffectHolder(TextView item) {
      super(item);
      text = item;
    }
  }

  private static final class EffectControl {
    final String name;
    final boolean booleanOnly;
    final int neutral;
    final int defaultValue;
    final IntSupplier getter;
    final IntConsumer setter;
    final boolean allowDisable;
    final boolean activateOnSelect;
    int lastNonNeutral;

    EffectControl(
        String n, boolean b, int neutralValue, int defaultOn, IntSupplier g, IntConsumer s) {
      this(n, b, neutralValue, defaultOn, g, s, true, false);
    }

    EffectControl(
        String n,
        boolean b,
        int neutralValue,
        int defaultOn,
        IntSupplier g,
        IntConsumer s,
        boolean canDisable,
        boolean activate) {
      name = n;
      booleanOnly = b;
      neutral = neutralValue;
      defaultValue = defaultOn;
      getter = g;
      setter = s;
      allowDisable = canDisable;
      activateOnSelect = activate;
      lastNonNeutral = defaultOn;
    }

    int value() {
      return Math.max(0, Math.min(100, getter.getAsInt()));
    }

    void set(int value) {
      setter.accept(Math.max(0, Math.min(100, value)));
    }

    String label() {
      int value = value();
      return booleanOnly ? name + (value != neutral ? "(开)" : "(关)") : name + "(" + value + ")";
    }
  }

  private int dp(int value) {
    return Math.round(value * getResources().getDisplayMetrics().density);
  }

  private String resolutionLabel() {
    return resolutionTier == 2 ? "1080P" : resolutionTier == 1 ? "720P" : "480P";
  }

  private static int recommendedResolutionTier() {
    String soc = (Build.VERSION.SDK_INT >= 31 ? Build.SOC_MODEL : Build.HARDWARE);
    if (soc == null) {
      soc = "";
    }
    soc = soc.toUpperCase(java.util.Locale.ROOT);
    // High-end Android SoCs released in roughly the last four years.
    String[] high = {
      "SM8450",
      "SM8475",
      "SM8550",
      "SM8650",
      "SM8750",
      "SM8850",
      "MT6983",
      "MT6985",
      "MT6989",
      "MT6991",
      "DIMENSITY 9000",
      "DIMENSITY 9200",
      "DIMENSITY 9300",
      "DIMENSITY 9400",
      "DIMENSITY 9500"
    };
    for (String value : high)
      if (soc.contains(value)) {
        return 2;
      }
    // Recent upper-mid/mid chips: Snapdragon 7/7+/7s and Dimensity
    // 8000-series parts start at the requested 720P tier.
    String[] mid = {
      "SM7325",
      "SM7350",
      "SM7435",
      "SM7450",
      "SM7475",
      "SM7550",
      "SM7635",
      "SM7675",
      "SM7750",
      "MT6858",
      "MT6893",
      "MT6895",
      "MT6896",
      "MT6897",
      "MT6899",
      "DIMENSITY 8000",
      "DIMENSITY 8100",
      "DIMENSITY 8200",
      "DIMENSITY 8300",
      "DIMENSITY 8400"
    };
    for (String value : mid)
      if (soc.contains(value)) {
        return 1;
      }
    // Lower and unknown tiers start at 480P. The user can still cycle to
    // 720P/1080P, and future SoCs can be added after a device benchmark.
    return 0;
  }

  private static String compactDelegate(String value) {
    if (value == null) {
      return "模型初始化中";
    }
    return value
        .replace("MediaPipeSelfieW8A8/", "Mask W8/")
        .replace("MediaPipeSelfie256/", "Mask MP256/")
        .replace("+FaceMediaPipe478GPUTrack", " · Face478/GPU")
        .replace("+FaceMediaPipe478NNAPI(auto)Track", " · Face478/NNAPI")
        .replace("+FaceMediaPipe478NNAPITrack", " · Face478/NNAPI")
        .replace("+FaceCPUTrack", " · Face478/CPU");
  }

  private void configureSurface() {
    if (surfaceHolder == null || !surfaceReady) {
      return;
    }
    // The native renderer sets the ANativeWindow buffer geometry to the
    // current camera frame. Calling setFixedSize during a 720p/1080p switch
    // destroys the Surface while an old frame may still be posting and can
    // leave the producer connected to a stale window.
    VisionSdk current = sdk;
    if (current != null) {
      try {
        current.setOutputSurface(surfaceHolder.getSurface());
      } catch (Exception e) {
        showError(e);
      }
    }
  }

  private void bindCamera() {
    if (destroyed || !resumed || !surfaceReady) {
      return;
    }
    final long generation = cameraGeneration.incrementAndGet();
    final boolean requestedFront = front;
    final int requestedWidth = resolutionTier == 2 ? 1080 : resolutionTier == 1 ? 720 : 480;
    final int requestedHeight = resolutionTier == 2 ? 1920 : resolutionTier == 1 ? 1280 : 854;
    worker.execute(
        () -> {
          try {
            Camera2Frames old = camera2;
            camera2 = null;
            if (old != null) {
              old.close();
            }
            pending.set(false);
            if (destroyed
                || !resumed
                || !surfaceReady
                || generation != cameraGeneration.get()
                || sdk == null) {
              return;
            }
            sdk.reset();
            Camera2Frames next =
                new Camera2Frames(
                    this,
                    worker,
                    new Camera2Frames.Listener() {
                      @Override
                      public void onFrame(
                          android.media.Image image, int rotation, boolean mirrorX) {
                        if (generation == cameraGeneration.get()) {
                          cameraRetryAttempts.set(0);
                          analyze(image, rotation, mirrorX);
                        }
                      }

                      @Override
                      public void onError(Exception error) {
                        if (generation == cameraGeneration.get()) {
                          scheduleCameraRetry(generation, error);
                        }
                      }
                    });
            camera2 = next;
            next.start(requestedFront, requestedWidth, requestedHeight);
          } catch (Exception e) {
            if (generation == cameraGeneration.get()) {
              showError(e);
            }
          }
        });
  }

  private void scheduleCameraRetry(long failedGeneration, Exception error) {
    if (destroyed || !resumed || !surfaceReady || failedGeneration != cameraGeneration.get()) {
      return;
    }
    int attempt = cameraRetryAttempts.incrementAndGet();
    if (attempt > 6) {
      showError(error);
      return;
    }
    if (!cameraRetryScheduled.compareAndSet(false, true)) {
      return;
    }
    long delay = Math.min(2000L, 250L * (1L << Math.min(3, attempt - 1)));
    runOnUiThread(() -> status.setText("相机正在恢复（" + attempt + "/6）…"));
    mainHandler.postDelayed(
        () -> {
          cameraRetryScheduled.set(false);
          if (!destroyed && resumed && surfaceReady && failedGeneration == cameraGeneration.get()) {
            bindCamera();
          }
        },
        delay);
  }

  @Override
  protected void onResume() {
    super.onResume();
    resumed = true;
    if (sdk != null
        && surfaceReady
        && ContextCompat.checkSelfPermission(this, Manifest.permission.CAMERA)
            == android.content.pm.PackageManager.PERMISSION_GRANTED) {
      configureSurface();
      bindCamera();
    }
  }

  @Override
  protected void onPause() {
    resumed = false;
    cameraRetryScheduled.set(false);
    cameraRetryAttempts.set(0);
    cameraGeneration.incrementAndGet();
    // Release the CameraDevice before waiting for any in-flight inference.
    // ImageReader destruction remains serialized after that frame finishes.
    Camera2Frames camera = camera2;
    camera2 = null;
    if (camera != null) {
      camera.stopCapture();
    }
    worker.execute(
        () -> {
          if (camera != null) {
            camera.close();
          }
          pending.set(false);
          VisionSdk current = sdk;
          if (current != null) {
            try {
              current.setOutputSurface(null);
            } catch (Throwable ignored) {
            }
            try {
              current.reset();
            } catch (Throwable ignored) {
            }
          }
        });
    super.onPause();
  }

  private void analyze(android.media.Image image, int rotation, boolean mirrorX) {
    if (destroyed || sdk == null || !surfaceReady || !pending.compareAndSet(false, true)) {
      return;
    }
    try {
      long started = SystemClock.elapsedRealtime();
      VisionOptions current = effectiveOptions();
      if (configuredOptions == null || !configuredOptions.equals(current)) {
        sdk.configure(current);
        configuredOptions = current;
      }
      long converted = SystemClock.elapsedRealtime();
      boolean applied;
      if (Build.VERSION.SDK_INT >= 29) {
        // GPU import requires camera producer completion, but no CPU
        // pixel mapping. Public SyncFence is available from API 33.
        if (Build.VERSION.SDK_INT >= 33) {
          try (android.hardware.SyncFence fence = image.getFence()) {
            if (fence.isValid() && !fence.await(java.time.Duration.ofMillis(500))) {
              throw new IllegalStateException("Camera acquire fence timed out");
            }
          }
        } else {
          // Older Java ImageReader APIs do not expose the acquire
          // fence. Mapping planes performs the framework fence wait.
          image.getPlanes();
        }
        android.hardware.HardwareBuffer hardware = image.getHardwareBuffer();
        if (hardware == null) {
          throw new IllegalStateException("ImageReader did not provide HardwareBuffer");
        }
        try {
          applied =
              sdk.processHardwareBuffer(
                  hardware,
                  image.getWidth(),
                  image.getHeight(),
                  rotation,
                  mirrorX,
                  image.getTimestamp() / 1_000_000);
        } finally {
          hardware.close();
        }
      } else {
        android.media.Image.Plane[] planes = image.getPlanes();
        applied =
            sdk.processYuv(
                planes[0].getBuffer(),
                planes[1].getBuffer(),
                planes[2].getBuffer(),
                image.getWidth(),
                image.getHeight(),
                planes[0].getRowStride(),
                planes[1].getRowStride(),
                planes[2].getRowStride(),
                planes[1].getPixelStride(),
                planes[2].getPixelStride(),
                rotation,
                image.getTimestamp() / 1_000_000);
      }
      String dimensions =
          ((rotation % 180) == 0
              ? image.getWidth() + "x" + image.getHeight()
              : image.getHeight() + "x" + image.getWidth());
      long processed = SystemClock.elapsedRealtime();
      long elapsed = processed - started;
      long conversionMs = converted - started;
      long sdkMs = processed - converted;
      String backend = sdk.renderPath();
      String delegate = sdk.inferenceBackend();
      int[] nativePixel = BuildConfig.DEBUG ? sdk.surfaceDiagnostic() : null;
      String nativeStatus =
          nativePixel == null ? "" : " native=" + java.util.Arrays.toString(nativePixel);
      long submitted = sdk.submittedInferences();
      long completed = sdk.completedInferences();
      displayedFrames++;
      long outputToken = sdk.presentedTimestampMs();
      if (sdk.isPassThrough()) {
        outputToken = image.getTimestamp() / 1_000_000;
      }
      if (outputToken >= 0 && outputToken != lastPresentedToken) {
        uniqueFrames++;
        lastPresentedToken = outputToken;
      }
      long now = SystemClock.elapsedRealtime();
      if (lastFpsTick == 0) {
        lastFpsTick = now;
      }
      if (now - lastFpsTick >= 1000) {
        displayFps = (int) (displayedFrames * 1000 / (now - lastFpsTick));
        uniqueFps = (int) (uniqueFrames * 1000 / (now - lastFpsTick));
        uniqueFrames = 0;
        displayedFrames = 0;
        lastFpsTick = now;
      }
      boolean updateStatus = now - lastStatusTick >= 250;
      if (updateStatus) {
        lastStatusTick = now;
      }
      if (BuildConfig.DEBUG) {
        android.util.Log.d(
            "MediaVisionPerf",
            "frame="
                + elapsed
                + "ms camera_copy="
                + conversionMs
                + "ms output=surface sdk="
                + sdkMs
                + "ms applied="
                + applied
                + " backend="
                + backend
                + " delegate="
                + delegate
                + " submitted="
                + submitted
                + " completed="
                + completed
                + " fps="
                + displayFps);
      }
      if (updateStatus) {
        final String text = uniqueFps + " FPS · " + dimensions;
        runOnUiThread(
            () -> {
              if (!destroyed) {
                status.setText(text);
              }
            });
      }
      if (metrics != null) {
        metrics.record(
            elapsed,
            outputToken,
            sdk.pairedInferenceLatencyMs(),
            dimensions,
            backend,
            "beauty="
                + current.beauty
                + " blemish="
                + current.blemishRemoval
                + " sharpen="
                + current.sharpen
                + " small_head="
                + current.smallHead
                + " face_slim="
                + current.faceSlim
                + " cheekbone="
                + current.cheekboneReduce
                + " nose_slim="
                + current.noseSlim
                + " background="
                + current.background
                + " mesh="
                + current.prop
                + "/"
                + current.headwear
                + "/"
                + current.jewelry);
      }
    } catch (Exception e) {
      showError(e);
    } finally {
      pending.set(false);
    }
  }

  private void showError(Exception e) {
    if (metrics != null) {
      metrics.error(e);
    }
    if (BuildConfig.DEBUG) {
      android.util.Log.e("MediaVision", "Processing failed", e);
    }
    runOnUiThread(
        () -> {
          if (!destroyed) {
            status.setText("错误：" + e.getMessage());
          }
        });
  }

  @Override
  protected void onDestroy() {
    destroyed = true;
    mainHandler.removeCallbacksAndMessages(null);
    cameraGeneration.incrementAndGet();
    VisionSdk current = sdk;
    worker.execute(
        () -> {
          Camera2Frames camera = camera2;
          camera2 = null;
          if (camera != null) {
            camera.close();
          }
          if (current == null) {
            return;
          }
          try {
            current.setOutputSurface(null);
          } catch (Throwable ignored) {
          }
          current.close();
        });
    worker.shutdown();
    super.onDestroy();
  }
}
