package com.aiskincare.mobile;

import android.content.Context;
import android.graphics.*;
import android.view.MotionEvent;
import android.view.ScaleGestureDetector;
import android.view.View;
import com.google.mlkit.vision.face.Face;

/** The drawn guide, validation, and crop all use the same upright image coordinates. */
final class FaceCropView extends View {
    private final Bitmap photo;
    private final Face face;
    private final boolean side;
    private final java.util.function.Consumer<Boolean> readiness;
    private final Paint paint=new Paint(Paint.ANTI_ALIAS_FLAG|Paint.FILTER_BITMAP_FLAG);
    private final ScaleGestureDetector pinch;
    private float scale, base, x, y, lastX, lastY;
    private Rect defaultSideCrop;
    private boolean userAdjusted;

    FaceCropView(Context context, Bitmap photo, Face face, boolean side, java.util.function.Consumer<Boolean> readiness) {
        super(context); this.photo=photo; this.face=face; this.side=side; this.readiness=readiness;
        setContentDescription("얼굴 위치 조정. 사진을 이동하거나 두 손가락으로 크기를 조절하세요.");
        pinch=new ScaleGestureDetector(context,new ScaleGestureDetector.SimpleOnScaleGestureListener(){
            @Override public boolean onScale(ScaleGestureDetector d){
                userAdjusted = true;
                float next=Math.max(base*.3f,Math.min(base*4f,scale*d.getScaleFactor()));
                x=d.getFocusX()-(d.getFocusX()-x)*next/scale;
                y=d.getFocusY()-(d.getFocusY()-y)*next/scale;
                scale=next; changed(); return true;
            }
        });
    }
    @Override protected void onSizeChanged(int w,int h,int oldW,int oldH){
        RectF guide=FaceFrame.guide(w,h), box=new RectF(face.getBoundingBox());
        base=(float)(.60*Math.sqrt(guide.width()*guide.height()/(box.width()*box.height())));
        defaultSideCrop = null;
        userAdjusted = false;
        if (side) {
            Rect candidate = FaceFrame.centeredSideCrop(photo.getWidth(), photo.getHeight());
            RectF bounds = new RectF(candidate);
            if (candidate.width() >= 720 && bounds.contains(box) && FaceFrame.aligned(box, bounds,
                    face.getHeadEulerAngleY(), face.getHeadEulerAngleZ(), true)) {
                defaultSideCrop = candidate;
                base = FaceFrame.cropArea(guide, true).width() / candidate.width();
                box = bounds;
            }
        }
        scale=base; x=guide.centerX()-scale*box.centerX(); y=guide.centerY()-scale*box.centerY(); changed();
    }
    private Rect cropRect(){
        if (defaultSideCrop != null && !userAdjusted) return defaultSideCrop;
        RectF r=FaceFrame.cropArea(FaceFrame.guide(getWidth(),getHeight()), side);
        r.offset(-x,-y);
        Rect crop=new Rect((int)Math.floor(r.left/scale),(int)Math.floor(r.top/scale),
                (int)Math.ceil(r.right/scale),(int)Math.ceil(r.bottom/scale));
        if (!crop.intersect(0,0,photo.getWidth(),photo.getHeight())) crop.setEmpty();
        return crop;
    }
    Bitmap crop(){ Rect r=cropRect(); return Bitmap.createBitmap(photo,r.left,r.top,r.width(),r.height()); }
    private void changed(){
        if (defaultSideCrop != null && !userAdjusted) {
            readiness.accept(true);
            invalidate();
            return;
        }
        RectF box=new RectF(face.getBoundingBox()); box.set(x+box.left*scale,y+box.top*scale,x+box.right*scale,y+box.bottom*scale);
        Rect crop=cropRect();
        RectF guide = FaceFrame.guide(getWidth(), getHeight());
        RectF framing = side ? FaceFrame.cropArea(guide, true) : guide;
        readiness.accept(Math.min(crop.width(),crop.height())>=720
                && (!side || new RectF(crop).contains(new RectF(face.getBoundingBox())))
                && FaceFrame.aligned(box, framing, face.getHeadEulerAngleY(), face.getHeadEulerAngleZ(), side));
        invalidate();
    }
    @Override protected void onDraw(Canvas canvas){
        canvas.drawColor(Color.BLACK); paint.setStyle(Paint.Style.FILL);
        canvas.drawBitmap(photo,null,new RectF(x,y,x+scale*photo.getWidth(),y+scale*photo.getHeight()),paint);
        paint.setColor(Color.WHITE); paint.setStyle(Paint.Style.STROKE); paint.setStrokeWidth(4);
        RectF guide = FaceFrame.guide(getWidth(),getHeight());
        if (side) canvas.drawRect(FaceFrame.cropArea(guide, true), paint);
        else canvas.drawOval(guide, paint);
    }
    @Override public boolean performClick(){ super.performClick(); return true; }
    @Override public boolean onTouchEvent(MotionEvent e){
        getParent().requestDisallowInterceptTouchEvent(true);
        pinch.onTouchEvent(e);
        if(e.getActionMasked()==MotionEvent.ACTION_MOVE && !pinch.isInProgress() && e.getPointerCount()==1){
            userAdjusted = true;
            x+=e.getX()-lastX; y+=e.getY()-lastY; changed();
        }
        int pointer=e.getActionMasked()==MotionEvent.ACTION_POINTER_UP && e.getActionIndex()==0 ? 1:0;
        lastX=e.getX(pointer); lastY=e.getY(pointer);
        if(e.getActionMasked()==MotionEvent.ACTION_UP) performClick();
        return true;
    }
}
