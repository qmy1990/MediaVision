package com.moon.mediavision.demo;

import android.content.Context;
import android.util.AttributeSet;
import android.view.SurfaceView;

/** Keeps the camera target at 9:16 so a 1080x1920 buffer is never stretched. */
final class AspectSurfaceView extends SurfaceView {
  AspectSurfaceView(Context c) {
    super(c);
  }

  AspectSurfaceView(Context c, AttributeSet a) {
    super(c, a);
  }

  @Override
  protected void onMeasure(int wSpec, int hSpec) {
    int w = MeasureSpec.getSize(wSpec);
    int h = MeasureSpec.getSize(hSpec);
    if (w <= 0 || h <= 0) {
      super.onMeasure(wSpec, hSpec);
      return;
    }
    int targetH = w * 16 / 9;
    if (targetH > h) {
      w = h * 9 / 16;
      targetH = h;
    }
    setMeasuredDimension(w, targetH);
  }
}
