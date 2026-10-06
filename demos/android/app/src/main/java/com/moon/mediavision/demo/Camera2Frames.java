package com.moon.mediavision.demo;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.ImageFormat;
import android.hardware.HardwareBuffer;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCaptureSession;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraDevice;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CaptureRequest;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.media.Image;
import android.media.ImageReader;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Process;
import android.os.SystemClock;
import android.util.Log;
import android.util.Range;
import android.util.Size;
import java.util.Collections;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.Executor;
import java.util.concurrent.RejectedExecutionException;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicBoolean;
import java.util.concurrent.atomic.AtomicLong;

/** Camera2 producer: ImageReader owns camera buffers until SDK processing finishes. */
final class Camera2Frames implements AutoCloseable {
  interface Listener {
    void onFrame(Image image, int rotationDegrees, boolean mirrorX);

    void onError(Exception error);
  }

  private final Context context;
  private final Listener listener;
  private final Executor processing;
  private HandlerThread cameraThread;
  private Handler handler;
  private volatile CameraDevice device;
  private volatile CameraCaptureSession session;
  private volatile ImageReader reader;
  private volatile boolean closed;
  private volatile CountDownLatch deviceClosed;
  // ImageReader owns an Image until Image.close().  The old implementation
  // queued every acquired Image on a single-thread executor; at 1080p the
  // consumer occasionally fell behind and exhausted maxImages permanently.
  // Keep one frame in flight and drain newer frames immediately while it is
  // busy.  The next camera callback supplies the freshest frame.
  private final AtomicBoolean frameInFlight = new AtomicBoolean();
  // One replaceable waiting image avoids a full 33 ms idle interval when a
  // render finishes just after the next camera callback. Never queue
  // historical frames: at most the active image and the newest image exist.
  private final Object latestLock = new Object();
  private Image latestWaiting;
  private boolean latestRunning;
  private boolean useLatestSlot;
  private final AtomicLong callbacks = new AtomicLong();
  private final AtomicLong dropped = new AtomicLong();
  private final AtomicLong processed = new AtomicLong();
  private final AtomicLong recoveries = new AtomicLong();
  private volatile long lastStatsMs;
  private int rotationDegrees;
  private boolean mirrorX;
  private Size cameraSize;

  Camera2Frames(Context context, Executor processing, Listener listener) {
    this.context = context;
    this.processing = processing;
    this.listener = listener;
  }

  @SuppressLint("MissingPermission")
  void start(boolean front, int portraitWidth, int portraitHeight) throws CameraAccessException {
    close();
    closed = false;
    frameInFlight.set(false);
    useLatestSlot =
        Build.VERSION.SDK_INT >= 31
            && (("MT6858".equalsIgnoreCase(Build.SOC_MODEL)
                    && Math.min(portraitWidth, portraitHeight) <= 720
                    && Math.max(portraitWidth, portraitHeight) <= 1280)
                || (("MT6991".equalsIgnoreCase(Build.SOC_MODEL)
                        || "SM8550".equalsIgnoreCase(Build.SOC_MODEL))
                    && Math.min(portraitWidth, portraitHeight) <= 1080
                    && Math.max(portraitWidth, portraitHeight) <= 1920));
    mirrorX = front;
    cameraThread = new HandlerThread("MvsCamera2", Process.THREAD_PRIORITY_DISPLAY);
    cameraThread.start();
    handler = new Handler(cameraThread.getLooper());
    CameraManager manager = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);
    Size requestedSize = new Size(portraitHeight, portraitWidth);
    String cameraId = null;
    CameraCharacteristics characteristics = null;
    for (String id : manager.getCameraIdList()) {
      CameraCharacteristics c = manager.getCameraCharacteristics(id);
      Integer facing = c.get(CameraCharacteristics.LENS_FACING);
      StreamConfigurationMap candidate =
          c.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
      if (candidate != null
          && facing != null
          && facing
              == (front
                  ? CameraCharacteristics.LENS_FACING_FRONT
                  : CameraCharacteristics.LENS_FACING_BACK)) {
        Size selected =
            closestSize(candidate.getOutputSizes(ImageFormat.YUV_420_888), requestedSize);
        if (selected != null) {
          cameraId = id;
          characteristics = c;
          cameraSize = selected;
          break;
        }
      }
    }
    if (cameraId == null || characteristics == null) {
      throw new IllegalStateException("Camera unavailable");
    }
    final CameraCharacteristics selectedCharacteristics = characteristics;
    int orientation = characteristics.get(CameraCharacteristics.SENSOR_ORIENTATION);
    // Camera2's ImageReader buffers are in the sensor's unrotated landscape coordinates.
    rotationDegrees = ((orientation % 360) + 360) % 360;
    StreamConfigurationMap map =
        characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
    if (Build.VERSION.SDK_INT >= 29) {
      long usage = HardwareBuffer.USAGE_GPU_SAMPLED_IMAGE | HardwareBuffer.USAGE_CPU_READ_OFTEN;
      reader =
          ImageReader.newInstance(
              cameraSize.getWidth(), cameraSize.getHeight(), ImageFormat.YUV_420_888, 6, usage);
    } else {
      reader =
          ImageReader.newInstance(
              cameraSize.getWidth(), cameraSize.getHeight(), ImageFormat.YUV_420_888, 6);
    }
    reader.setOnImageAvailableListener(
        r -> {
          Image image = null;
          try {
            callbacks.incrementAndGet();
            if (useLatestSlot) {
              image = r.acquireLatestImage();
              if (image != null) {
                offerLatest(image);
                image = null;
              }
              return;
            }
            if (closed || !frameInFlight.compareAndSet(false, true)) {
              // Drain the reader so the camera producer never runs out of
              // buffers, but do not retain a frame behind slow work.
              image = r.acquireLatestImage();
              if (image != null) {
                dropped.incrementAndGet();
              }
              logStats();
              return;
            }
            image = r.acquireLatestImage();
            if (image == null) {
              frameInFlight.set(false);
              return;
            }
            final Image frame = image;
            image = null;
            try {
              processing.execute(
                  () -> {
                    long started = SystemClock.elapsedRealtime();
                    try {
                      if (!closed) {
                        listener.onFrame(frame, rotationDegrees, mirrorX);
                      }
                    } catch (Exception error) {
                      if (!closed) {
                        listener.onError(error);
                      }
                    } finally {
                      frame.close();
                      frameInFlight.set(false);
                      processed.incrementAndGet();
                      if (BuildConfig.DEBUG && SystemClock.elapsedRealtime() - started > 80) {
                        Log.w(
                            "MediaVisionCamera",
                            "slow_frame_ms=" + (SystemClock.elapsedRealtime() - started));
                      }
                      logStats();
                    }
                  });
            } catch (RejectedExecutionException error) {
              frame.close();
              frameInFlight.set(false);
              throw error;
            }
          } catch (IllegalStateException error) {
            frameInFlight.set(false);
            // Some Camera2 providers briefly report maxImages while a
            // just-closed buffer is returning to the HAL.  The next callback
            // recovers; do not replace the live preview status with a stale
            // permanent error.
            recoveries.incrementAndGet();
            if (BuildConfig.DEBUG) {
              Log.w("MediaVisionCamera", "ImageReader recovered", error);
            }
          } catch (Exception error) {
            frameInFlight.set(false);
            if (!closed) {
              listener.onError(error);
            }
          } finally {
            if (image != null) {
              image.close();
            }
          }
        },
        handler);
    manager.openCamera(
        cameraId,
        new CameraDevice.StateCallback() {
          @Override
          public void onOpened(CameraDevice c) {
            if (closed) {
              c.close();
              return;
            }
            device = c;
            try {
              c.createCaptureSession(
                  Collections.singletonList(reader.getSurface()),
                  new CameraCaptureSession.StateCallback() {
                    @Override
                    public void onConfigured(CameraCaptureSession s) {
                      if (closed) {
                        s.close();
                        return;
                      }
                      session = s;
                      try {
                        CaptureRequest.Builder b =
                            c.createCaptureRequest(CameraDevice.TEMPLATE_PREVIEW);
                        b.addTarget(reader.getSurface());
                        b.set(
                            CaptureRequest.CONTROL_AF_MODE,
                            CaptureRequest.CONTROL_AF_MODE_CONTINUOUS_VIDEO);
                        Range<Integer> fps = chooseThirtyFps(selectedCharacteristics);
                        if (fps != null) {
                          b.set(CaptureRequest.CONTROL_AE_TARGET_FPS_RANGE, fps);
                        }
                        s.setRepeatingRequest(b.build(), null, handler);
                      } catch (CameraAccessException error) {
                        listener.onError(error);
                      }
                    }

                    @Override
                    public void onConfigureFailed(CameraCaptureSession s) {
                      listener.onError(
                          new IllegalStateException("Camera2 session configuration failed"));
                    }
                  },
                  handler);
            } catch (CameraAccessException error) {
              listener.onError(error);
            }
          }

          @Override
          public void onDisconnected(CameraDevice c) {
            c.close();
            device = null;
            if (!closed) {
              listener.onError(new IllegalStateException("Camera2 disconnected"));
            }
          }

          @Override
          public void onError(CameraDevice c, int error) {
            c.close();
            device = null;
            if (!closed) {
              listener.onError(new IllegalStateException(cameraErrorMessage(error)));
            }
          }

          @Override
          public void onClosed(CameraDevice c) {
            CountDownLatch latch = deviceClosed;
            if (latch != null) {
              latch.countDown();
            }
          }
        },
        handler);
  }

  private void offerLatest(Image image) {
    synchronized (latestLock) {
      if (closed) {
        image.close();
        return;
      }
      if (latestRunning) {
        if (latestWaiting != null) {
          latestWaiting.close();
          dropped.incrementAndGet();
        }
        latestWaiting = image;
        return;
      }
      latestRunning = true;
      try {
        processing.execute(() -> processLatest(image));
      } catch (RejectedExecutionException error) {
        latestRunning = false;
        image.close();
        throw error;
      }
    }
  }

  private void processLatest(Image first) {
    Image frame = first;
    while (frame != null) {
      try {
        if (!closed) {
          listener.onFrame(frame, rotationDegrees, mirrorX);
        }
      } catch (Exception error) {
        if (!closed) {
          listener.onError(error);
        }
      } finally {
        frame.close();
        processed.incrementAndGet();
        logStats();
      }
      synchronized (latestLock) {
        frame = latestWaiting;
        latestWaiting = null;
        if (closed && frame != null) {
          frame.close();
          frame = null;
        }
        if (frame == null) {
          latestRunning = false;
        }
      }
    }
  }

  private static Range<Integer> chooseThirtyFps(CameraCharacteristics characteristics) {
    Range<Integer>[] ranges =
        characteristics.get(CameraCharacteristics.CONTROL_AE_AVAILABLE_TARGET_FPS_RANGES);
    if (ranges == null) {
      return null;
    }
    Range<Integer> best = null;
    for (Range<Integer> range : ranges) {
      if (!range.contains(30)) {
        continue;
      }
      // Prefer a fixed 30 Hz request, then the range with the highest
      // lower bound.  Avoid selecting 60 Hz and overfilling the renderer.
      if (range.getLower() == 30 && range.getUpper() == 30) {
        return range;
      }
      if (range.getUpper() > 30) {
        continue;
      }
      if (best == null || range.getLower() > best.getLower()) {
        best = range;
      }
    }
    if (best != null) {
      return best;
    }
    for (Range<Integer> range : ranges)
      if (range.contains(30) && (best == null || range.getLower() > best.getLower())) {
        best = range;
      }
    return best;
  }

  private static Size closestSize(Size[] choices, Size requested) {
    if (choices == null || choices.length == 0) {
      return null;
    }
    Size best = null;
    double bestScore = Double.POSITIVE_INFINITY;
    double targetAspect = requested.getWidth() / (double) requested.getHeight();
    double targetArea = (double) requested.getWidth() * requested.getHeight();
    for (Size size : choices) {
      if (size.getWidth() < size.getHeight()) {
        continue;
      }
      double aspect = size.getWidth() / (double) size.getHeight();
      double area = (double) size.getWidth() * size.getHeight();
      double score =
          Math.abs(Math.log(aspect / targetAspect)) * 8.0 + Math.abs(Math.log(area / targetArea));
      if (score < bestScore) {
        bestScore = score;
        best = size;
      }
    }
    return best;
  }

  private static String cameraErrorMessage(int error) {
    switch (error) {
      case CameraDevice.StateCallback.ERROR_CAMERA_IN_USE:
        return "Camera2 error 1: camera in use";
      case CameraDevice.StateCallback.ERROR_MAX_CAMERAS_IN_USE:
        return "Camera2 error 2: too many cameras";
      case CameraDevice.StateCallback.ERROR_CAMERA_DISABLED:
        return "Camera2 error 3: camera disabled";
      case CameraDevice.StateCallback.ERROR_CAMERA_DEVICE:
        return "Camera2 error 4: camera device needs reopen";
      case CameraDevice.StateCallback.ERROR_CAMERA_SERVICE:
        return "Camera2 error 5: camera service needs reopen";
      default:
        return "Camera2 error " + error;
    }
  }

  private void logStats() {
    if (!BuildConfig.DEBUG) {
      return;
    }
    long now = SystemClock.elapsedRealtime();
    if (now - lastStatsMs < 1000) {
      return;
    }
    lastStatsMs = now;
    Log.d(
        "MediaVisionCamera",
        "callbacks="
            + callbacks.get()
            + " processed="
            + processed.get()
            + " dropped="
            + dropped.get()
            + " recoveries="
            + recoveries.get()
            + " in_flight="
            + frameInFlight.get()
            + " size="
            + cameraSize);
  }

  /**
   * Stops the camera producer immediately, without destroying an ImageReader buffer that may still
   * be owned by the render thread. This is intentionally cheap enough for Activity.onPause():
   * several vivo Camera HAL versions report ERROR_CAMERA_DEVICE when the device is left active
   * while the display powers down and is only closed after a long GPU/model operation.
   */
  void stopCapture() {
    closed = true;
    synchronized (latestLock) {
      if (latestWaiting != null) {
        latestWaiting.close();
        latestWaiting = null;
      }
    }
    ImageReader currentReader = reader;
    if (currentReader != null) {
      currentReader.setOnImageAvailableListener(null, null);
    }
    CameraCaptureSession currentSession = session;
    session = null;
    if (currentSession != null) {
      try {
        currentSession.stopRepeating();
        currentSession.abortCaptures();
      } catch (Exception ignored) {
      }
      currentSession.close();
    }
    CameraDevice closing = device;
    device = null;
    if (closing != null) {
      CountDownLatch latch = new CountDownLatch(1);
      deviceClosed = latch;
      closing.close();
    }
  }

  @Override
  public void close() {
    stopCapture();
    CountDownLatch latch = deviceClosed;
    if (latch != null) {
      try {
        latch.await(700, TimeUnit.MILLISECONDS);
      } catch (InterruptedException e) {
        Thread.currentThread().interrupt();
      }
    }
    deviceClosed = null;
    if (reader != null) {
      reader.close();
      reader = null;
    }
    frameInFlight.set(false);
    if (cameraThread != null) {
      HandlerThread old = cameraThread;
      old.quitSafely();
      if (Thread.currentThread() != old) {
        try {
          old.join(300);
        } catch (InterruptedException e) {
          Thread.currentThread().interrupt();
        }
      }
      cameraThread = null;
      handler = null;
    }
  }
}
