package com.aiskincare.mobile;

import android.graphics.RectF;

final class FaceFrame {
    static RectF guide(int w, int h) {
        float width=Math.min(w*.68f,h*.56f);
        float height=width*4/3;
        return new RectF((w-width)/2,h*.46f-height/2,(w+width)/2,h*.46f+height/2);
    }

    static boolean aligned(RectF face, RectF guide, float yaw, float roll, boolean side) {
        if (guide.isEmpty() || face.isEmpty() || Math.abs(roll)>15) return false;
        if (side ? Math.abs(yaw)<20 : Math.abs(yaw)>20) return false;
        double ratio=Math.sqrt(face.width()*face.height()/(guide.width()*guide.height()));
        double dx=2*(face.centerX()-guide.centerX())/guide.width();
        double dy=2*(face.centerY()-guide.centerY())/guide.height();
        RectF boundary=new RectF(guide);
        boundary.inset(-guide.width()*.12f,-guide.height()*.12f);
        return ratio>=.42 && ratio<=.9 && Math.hypot(dx,dy)<=.28 && boundary.contains(face);
    }
}
