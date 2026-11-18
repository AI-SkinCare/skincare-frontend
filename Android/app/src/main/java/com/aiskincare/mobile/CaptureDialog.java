package com.aiskincare.mobile;

import android.app.Activity;
import android.app.Dialog;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.DashPathEffect;
import android.graphics.Paint;
import android.graphics.Path;
import android.hardware.Camera;
import android.view.Gravity;
import android.view.SurfaceHolder;
import android.view.SurfaceView;
import android.view.View;
import android.view.WindowManager;
import android.widget.Button;
import android.widget.FrameLayout;
import android.widget.TextView;
import java.util.Comparator;
import java.util.List;
import java.util.function.Consumer;

/** In-app preview and JPEG callback. Capture never writes the original to the gallery or disk. */
@SuppressWarnings("deprecation")
final class CaptureDialog extends Dialog implements SurfaceHolder.Callback {
    private final Activity host;
    private final int facing;
    private final Consumer<byte[]> onPhoto;
    private final Consumer<String> onError;
    private final SurfaceView preview;
    private final Button shutter;
    private Camera camera;
    private int cameraId = -1;

    CaptureDialog(Activity host, boolean rear, Consumer<byte[]> onPhoto, Consumer<String> onError) {
        super(host, android.R.style.Theme_Material_NoActionBar_Fullscreen);
        this.host = host;
        this.facing = rear ? Camera.CameraInfo.CAMERA_FACING_BACK : Camera.CameraInfo.CAMERA_FACING_FRONT;
        this.onPhoto = onPhoto;
        this.onError = onError;
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        AppStyle style = new AppStyle(host);
        FrameLayout frame = new FrameLayout(host);
        frame.setBackgroundColor(Color.BLACK);
        preview = new SurfaceView(host);
        frame.addView(preview);
        frame.addView(new View(host) {
            final Paint pen = new Paint(Paint.ANTI_ALIAS_FLAG);
            final Path mask = new Path();
            @Override protected void onDraw(Canvas canvas) {
                float w = Math.min(getWidth() * .66f, getHeight() * .48f), h = w * 1.32f;
                float x = getWidth() / 2f, y = getHeight() / 2f;
                mask.reset();
                mask.setFillType(Path.FillType.EVEN_ODD);
                mask.addRect(0, 0, getWidth(), getHeight(), Path.Direction.CW);
                mask.addOval(x-w/2, y-h/2, x+w/2, y+h/2, Path.Direction.CW);
                pen.setPathEffect(null);
                pen.setStyle(Paint.Style.FILL);
                pen.setColor(0x70000000);
                canvas.drawPath(mask, pen);
                pen.setStyle(Paint.Style.STROKE);
                pen.setColor(Color.WHITE);
                pen.setStrokeWidth(style.dp(2));
                pen.setPathEffect(new DashPathEffect(new float[]{style.dp(7), style.dp(5)}, 0));
                canvas.drawOval(x-w/2, y-h/2, x+w/2, y+h/2, pen);
            }
        });
        TextView hint = style.text("양쪽 볼이 보이게 정면을 맞춰 주세요", 16, Color.WHITE, 500);
        hint.setGravity(Gravity.CENTER);
        hint.setPadding(style.dp(56), style.dp(24), style.dp(56), style.dp(16));
        frame.addView(hint, new FrameLayout.LayoutParams(-1,-2,Gravity.TOP));
        Button close = style.button("×", 48);
        style.type(close, 26, Color.WHITE, 400);
        style.actionSurface(close, 0x44000000, 24, false);
        close.setContentDescription("닫기");
        close.setOnClickListener(v -> dismiss());
        FrameLayout.LayoutParams closePlacement = new FrameLayout.LayoutParams(style.dp(48), style.dp(48), Gravity.TOP | Gravity.END);
        closePlacement.setMargins(0, style.dp(12), style.dp(12), 0);
        frame.addView(close, closePlacement);
        shutter = style.button("", 68);
        shutter.setContentDescription("사진 촬영");
        shutter.setEnabled(false);
        style.actionSurface(shutter, Color.WHITE, 34, false);
        FrameLayout.LayoutParams bottom = new FrameLayout.LayoutParams(style.dp(68), style.dp(68), Gravity.BOTTOM | Gravity.CENTER_HORIZONTAL);
        bottom.bottomMargin = style.dp(48);
        frame.addView(shutter, bottom);
        shutter.setOnClickListener(v -> {
            shutter.setEnabled(false);
            try {
                camera.takePicture(null, null, (data, source) -> {
                    if (!isShowing()) return;
                    dismiss();
                    if (data != null) onPhoto.accept(data);
                    else onError.accept("촬영한 사진을 읽을 수 없어요.");
                });
            } catch (RuntimeException e) { fail(); }
        });
        preview.getHolder().addCallback(this);
        setContentView(frame);
    }

    @Override public void surfaceCreated(SurfaceHolder holder) {
        Camera.CameraInfo info = new Camera.CameraInfo();
        try {
            for (int i=0; i<Camera.getNumberOfCameras(); i++) {
                Camera.getCameraInfo(i, info);
                if (info.facing == facing) { cameraId = i; break; }
            }
            if (cameraId < 0) { fail(); return; }
            camera = Camera.open(cameraId);
            int degrees = host.getWindowManager().getDefaultDisplay().getRotation() * 90;
            boolean front = facing == Camera.CameraInfo.CAMERA_FACING_FRONT;
            int rotation = (info.orientation + (front ? degrees : -degrees) + 360) % 360;
            camera.setDisplayOrientation(front ? (360 - rotation) % 360 : rotation);
            Camera.Parameters params = camera.getParameters();
            List<Camera.Size> sizes = params.getSupportedPictureSizes();
            Camera.Size photo = sizes.stream().filter(s -> Math.min(s.width,s.height) >= 720)
                    .min(Comparator.comparingLong(s -> Math.abs((long)s.width*s.height - 2_100_000L)))
                    .orElseThrow(IllegalStateException::new);
            params.setPictureSize(photo.width, photo.height);
            params.setRotation(rotation); params.setJpegQuality(90);
            List<String> modes = params.getSupportedFocusModes();
            if (modes != null && modes.contains(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE))
                params.setFocusMode(Camera.Parameters.FOCUS_MODE_CONTINUOUS_PICTURE);
            Camera.Size size = params.getSupportedPreviewSizes().stream().min(Comparator.comparingDouble(s ->
                    Math.abs((double)s.width/s.height - (double)photo.width/photo.height)
                    + Math.abs(s.width - 1280) * .00001)).get();
            params.setPreviewSize(size.width, size.height);
            camera.setParameters(params);
            FrameLayout parent = (FrameLayout) preview.getParent();
            int w = rotation % 180 == 0 ? size.width : size.height;
            int h = rotation % 180 == 0 ? size.height : size.width;
            float scale = Math.min((float)parent.getWidth()/w,(float)parent.getHeight()/h);
            preview.setLayoutParams(new FrameLayout.LayoutParams(Math.round(w*scale),Math.round(h*scale),Gravity.CENTER));
            camera.setPreviewDisplay(holder);
            camera.startPreview();
            shutter.setEnabled(true);
        } catch (Exception error) { fail(); }
    }
    private void fail() {
        dismiss(); onError.accept("선택한 카메라를 열지 못했어요. 다른 카메라나 앨범을 이용해 주세요.");
    }
    @Override public void surfaceChanged(SurfaceHolder holder, int format, int w, int h) {}
    @Override public void surfaceDestroyed(SurfaceHolder holder) { release(); }
    @Override public void dismiss() { release(); super.dismiss(); }
    private void release() {
        shutter.setEnabled(false);
        if (camera != null) { camera.release(); camera = null; }
    }
}
