package com.moon.mediavision.demo;

import android.content.Context;
import android.os.SystemClock;
import java.io.File;
import java.io.FileWriter;
import java.util.Arrays;
import java.util.Locale;

/** Aggregated Debug evidence even on firmware that suppresses logcat. */
final class FrameMetrics {
  private final File file;
  private long tick = SystemClock.elapsedRealtime();
  private long lastToken = -1;
  private final long[] times = new long[240];
  private int count;
  private int unique;

  FrameMetrics(Context context) {
    file = new File(context.getFilesDir(), "frame-metrics.csv");
    if (BuildConfig.DEBUG) {
      write(
          "event,elapsed_ms,size,frames,unique_frames,fps,unique_fps,p50_ms,p95_ms,max_ms,inference_ms,path,options\n");
    }
  }

  void record(long duration, long token, long inference, String size, String path, String options) {
    if (!BuildConfig.DEBUG) {
      return;
    }
    if (count < times.length) {
      times[count++] = duration;
    }
    if (token >= 0 && token != lastToken) {
      unique++;
      lastToken = token;
    }
    long now = SystemClock.elapsedRealtime();
    long elapsed = now - tick;
    if (elapsed < 1000 || count == 0) {
      return;
    }
    long[] ordered = Arrays.copyOf(times, count);
    Arrays.sort(ordered);
    write(
        String.format(
            Locale.US,
            "frame,%d,%s,%d,%d,%.3f,%.3f,%d,%d,%d,%d,%s,%s\n",
            now,
            size,
            count,
            unique,
            count * 1000.0 / elapsed,
            unique * 1000.0 / elapsed,
            ordered[count / 2],
            ordered[Math.min(count - 1, (int) Math.ceil(count * .95) - 1)],
            ordered[count - 1],
            inference,
            path,
            options));
    count = unique = 0;
    tick = now;
  }

  void error(Throwable error) {
    if (BuildConfig.DEBUG) {
      write(
          "error,"
              + SystemClock.elapsedRealtime()
              + ","
              + error.toString().replace('\n', ' ')
              + '\n');
    }
  }

  private void write(String text) {
    try (FileWriter writer = new FileWriter(file, true)) {
      writer.write(text);
    } catch (Exception ignored) {
    }
  }
}
