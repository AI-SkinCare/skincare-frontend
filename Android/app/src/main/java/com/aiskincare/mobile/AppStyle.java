package com.aiskincare.mobile;

import android.content.Context;
import android.content.res.ColorStateList;
import android.graphics.BitmapFactory;
import android.graphics.Canvas;
import android.graphics.Paint;
import android.graphics.PathEffect;
import android.graphics.DashPathEffect;
import android.graphics.Typeface;
import android.graphics.drawable.GradientDrawable;
import android.graphics.drawable.RippleDrawable;
import android.view.Gravity;
import android.view.View;
import android.widget.Button;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;

import java.io.IOException;

/** Shared values and assets from the application's SwiftUI design system. */
final class AppStyle {
    static final int WHITE = 0xffffffff;
    static final int INK = 0xff141414;
    static final int SOFT = 0xfff3f3f3;
    static final int FIELD = 0xfff0f0f0;
    static final int LINE = 0xffe0e0e0;
    static final int MUTED = 0xff707070;
    static final int BLUE = 0xff0066ff;
    static final int NEGATIVE = 0xffee6a1f;

    private final Context context;
    private final Typeface regular, medium, semibold, bold, light;

    AppStyle(Context context) {
        this.context = context;
        regular = font("Regular");
        medium = font("Medium");
        semibold = font("SemiBold");
        bold = font("Bold");
        light = font("Light");
    }

    private Typeface font(String weight) {
        return Typeface.createFromAsset(context.getAssets(), "Pretendard-" + weight + ".otf");
    }

    int dp(float value) { return Math.round(value * context.getResources().getDisplayMetrics().density); }

    void type(TextView view, int size, int color, int weight) {
        view.setTypeface(weight >= 700 ? bold : weight >= 600 ? semibold : weight >= 500 ? medium :
                weight <= 300 ? light : regular);
        view.setTextSize(size);
        view.setTextColor(color);
        view.setIncludeFontPadding(false);
        view.setLineSpacing(dp(3), 1);
    }

    TextView text(String label, int size, int color, int weight) {
        TextView view = new TextView(context);
        type(view, size, color, weight);
        view.setText(label);
        return view;
    }

    LinearLayout column() {
        LinearLayout view = new LinearLayout(context);
        view.setOrientation(LinearLayout.VERTICAL);
        return view;
    }

    LinearLayout row() {
        LinearLayout view = new LinearLayout(context);
        view.setGravity(Gravity.CENTER_VERTICAL);
        return view;
    }

    GradientDrawable surface(int color, int radius, boolean outline) {
        GradientDrawable shape = new GradientDrawable();
        shape.setColor(color);
        shape.setCornerRadius(dp(radius));
        if (outline) shape.setStroke(dp(1), LINE);
        return shape;
    }

    void actionSurface(View view, int color, int radius, boolean outline) {
        view.setBackground(new RippleDrawable(ColorStateList.valueOf(color == INK ? 0x26ffffff : 0x18000000),
                surface(color, radius, outline), surface(WHITE, radius, false)));
    }

    Button button(String title, int height) {
        Button button = new Button(context);
        button.setAllCaps(false);
        button.setStateListAnimator(null);
        button.setMinWidth(0);
        button.setMinimumWidth(0);
        button.setMinHeight(dp(height));
        button.setMinimumHeight(dp(height));
        button.setPadding(dp(12), dp(5), dp(12), dp(5));
        button.setGravity(Gravity.CENTER);
        type(button, 16, INK, 600);
        button.setText(title);
        return button;
    }

    void primary(Button button, boolean enabled) {
        button.setEnabled(enabled);
        button.setTextColor(enabled ? WHITE : MUTED);
        actionSurface(button, enabled ? INK : FIELD, 28, false);
    }

    ImageView brand(int size) {
        ImageView image = new ImageView(context);
        try (var input = context.getAssets().open("BrandMark.png")) {
            image.setImageBitmap(BitmapFactory.decodeStream(input));
        } catch (IOException missing) {
            throw new IllegalStateException("Missing shared brand asset", missing);
        }
        image.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        image.setScaleType(ImageView.ScaleType.CENTER_CROP);
        int radius = Math.round(size * .3f);
        image.setBackground(surface(WHITE, radius, false));
        image.setForeground(surface(0x00000000, radius, true));
        image.setClipToOutline(true);
        return image;
    }

    View glyph(String name, int color) {
        View view = new View(context) {
            final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
            @Override protected void onDraw(Canvas canvas) {
                super.onDraw(canvas);
                float size = Math.min(getWidth() - getPaddingLeft() - getPaddingRight(),
                        getHeight() - getPaddingTop() - getPaddingBottom());
                if (size <= 0) return;
                canvas.save();
                canvas.translate((getWidth() - size) / 2, (getHeight() - size) / 2);
                canvas.scale(size / 24, size / 24);
                paint.setColor(color);
                paint.setStrokeWidth(1.6f);
                paint.setStrokeCap(Paint.Cap.ROUND);
                paint.setStrokeJoin(Paint.Join.ROUND);
                paint.setStyle(Paint.Style.STROKE);
                switch (name) {
                    case "home":
                        canvas.drawLine(3, 11, 12, 3, paint);
                        canvas.drawLine(12, 3, 21, 11, paint);
                        canvas.drawRoundRect(5, 10, 19, 21, 1, 1, paint);
                        canvas.drawLine(10, 21, 10, 15, paint);
                        canvas.drawLine(10, 15, 14, 15, paint);
                        canvas.drawLine(14, 15, 14, 21, paint);
                        break;
                    case "history":
                        canvas.drawCircle(12, 12, 8.5f, paint);
                        canvas.drawLine(12, 7, 12, 12, paint);
                        canvas.drawLine(12, 12, 15.5f, 14, paint);
                        break;
                    case "my":
                        canvas.drawCircle(12, 8, 3.5f, paint);
                        canvas.drawArc(4, 14, 20, 27, 180, 180, false, paint);
                        break;
                    case "sun":
                        canvas.drawCircle(12, 12, 4, paint);
                        for (int i = 0; i < 8; i++) {
                            canvas.drawLine(12, 3, 12, 5, paint);
                            canvas.rotate(45, 12, 12);
                        }
                        break;
                    case "glasses":
                        canvas.drawCircle(7, 12, 4, paint);
                        canvas.drawCircle(17, 12, 4, paint);
                        canvas.drawLine(11, 12, 13, 12, paint);
                        break;
                    case "comb":
                        canvas.rotate(-35, 12, 12);
                        canvas.drawLine(4, 8, 20, 8, paint);
                        for (int x = 4; x <= 20; x += 4) canvas.drawLine(x, 8, x, 15, paint);
                        break;
                    case "camera":
                        canvas.drawRoundRect(3, 7, 21, 20, 2, 2, paint);
                        canvas.drawCircle(12, 13.5f, 3, paint);
                        canvas.drawLine(9, 4, 15, 4, paint);
                        break;
                    case "scan":
                        canvas.drawRoundRect(4, 4, 20, 20, 3, 3, paint);
                        canvas.drawLine(8, 12, 16, 12, paint);
                        break;
                    default:
                        canvas.drawRoundRect(6, 4, 18, 20, 2, 2, paint);
                        canvas.drawLine(9, 9, 15, 9, paint);
                        canvas.drawLine(9, 13, 15, 13, paint);
                }
                canvas.restore();
            }
        };
        view.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        return view;
    }

    View faceGuide() {
        View guide = new View(context) {
            final Paint paint = new Paint(Paint.ANTI_ALIAS_FLAG);
            final PathEffect dash = new DashPathEffect(new float[] {dp(7), dp(5)}, 0);
            @Override protected void onDraw(Canvas canvas) {
                float w = getWidth(), h = getHeight();
                paint.setColor(0xffb1b1b1);
                paint.setStyle(Paint.Style.STROKE);
                paint.setStrokeWidth(dp(1.5f));
                paint.setPathEffect(dash);
                canvas.drawOval(w * .22f, h * .16f, w * .78f, h * .84f, paint);
                paint.setPathEffect(null);
                float x = w * .5f, y = h * .5f;
                canvas.drawCircle(x, y - dp(9), dp(8), paint);
                canvas.drawArc(x - dp(16), y + dp(3), x + dp(16), y + dp(27), 187, 166, false, paint);
            }
        };
        guide.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        return guide;
    }
}
