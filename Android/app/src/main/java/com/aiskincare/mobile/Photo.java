package com.aiskincare.mobile;

import android.graphics.Bitmap;
import android.graphics.ImageDecoder;
import java.io.ByteArrayOutputStream;
import java.io.IOException;

final class Photo {
    final Bitmap preview;
    final byte[] jpeg;
    private Photo(Bitmap preview, byte[] jpeg) { this.preview = preview; this.jpeg = jpeg; }

    // Run on the photo worker after EXIF orientation correction, before advancing to the survey.
    void requireOneFace() {
        float ratio=Math.min(1f,640f/Math.max(preview.getWidth(),preview.getHeight()));
        int w=Math.max(2,Math.round(preview.getWidth()*ratio) & ~1);
        int h=Math.max(2,Math.round(preview.getHeight()*ratio));
        Bitmap scan=Bitmap.createBitmap(w,h,Bitmap.Config.RGB_565);
        try {
            new android.graphics.Canvas(scan).drawBitmap(preview,null,new android.graphics.Rect(0,0,w,h),
                    new android.graphics.Paint(android.graphics.Paint.FILTER_BITMAP_FLAG));
            android.media.FaceDetector.Face[] faces=new android.media.FaceDetector.Face[2];
            int count=new android.media.FaceDetector(w,h,faces.length).findFaces(scan,faces);
            if(count!=1 || faces[0].eyesDistance()<w*.065f)
                throw new IllegalArgumentException("한 사람의 얼굴이 잘 보이는 정면 사진으로 다시 시도해 주세요.");
        } finally { scan.recycle(); }
    }

    static Photo decode(ImageDecoder.Source source) throws IOException {
        Bitmap image = ImageDecoder.decodeBitmap(source, (decoder, info, ignored) -> {
            int w = info.getSize().getWidth(), h = info.getSize().getHeight();
            if (Math.min(w, h) < 720) throw new IllegalArgumentException("짧은 변이 720픽셀 이상인 사진을 골라 주세요.");
            float scale = Math.min(1f, 1600f / Math.max(w, h));
            decoder.setTargetSize(Math.max(1, Math.round(w * scale)), Math.max(1, Math.round(h * scale)));
            decoder.setAllocator(ImageDecoder.ALLOCATOR_SOFTWARE);
        });
        Bitmap grid=Bitmap.createScaledBitmap(image,24,24,true);
        int[] pixels=new int[24*24];
        grid.getPixels(pixels,0,24,0,0,24,24);
        boolean uniform=true;
        for(int shift:new int[]{16,8,0}) {
            int lo=255, hi=0;
            for(int pixel:pixels) {
                int v=(pixel>>shift)&255; lo=Math.min(lo,v); hi=Math.max(hi,v);
            }
            if(hi-lo>2) { uniform=false; break; }
        }
        if(uniform) throw new IllegalArgumentException("사진 전체가 단색에 가까워요. 얼굴과 주변이 보이게 다시 찍어 주세요.");
        ByteArrayOutputStream out = new ByteArrayOutputStream();
        if (!image.compress(Bitmap.CompressFormat.JPEG, 90, out) || out.size() > 10 * 1024 * 1024)
            throw new IOException("사진을 업로드 크기로 변환하지 못했어요.");
        return new Photo(image, out.toByteArray());
    }
}
