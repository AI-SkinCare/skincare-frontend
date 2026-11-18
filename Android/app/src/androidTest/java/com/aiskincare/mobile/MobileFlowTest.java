package com.aiskincare.mobile;

import android.app.Activity;
import android.content.Intent;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.net.Uri;
import android.os.SystemClock;
import android.test.ActivityInstrumentationTestCase2;
import android.view.View;
import android.view.ViewGroup;
import android.widget.*;
import org.json.JSONObject;
import java.io.File;
import java.io.FileOutputStream;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.atomic.AtomicReference;

@SuppressWarnings("deprecation")
public final class MobileFlowTest extends ActivityInstrumentationTestCase2<MainActivity> {
    public MobileFlowTest() { super(MainActivity.class); }
    public void testAlternateBackendRequiresHttpsAndApiPath() {
        assertTrue(MainActivity.validServer("https://backend.example.org:9443/api/v1"));
        assertFalse(MainActivity.validServer("http://backend.example.org/api/v1"));
        assertFalse(MainActivity.validServer("https://backend.example.org"));
        assertFalse(MainActivity.validServer("https://other@backend.example.org/api/v1"));
        assertFalse(MainActivity.validServer("https://backend.example.org/api/v1?token=x"));
    }

    public void testRearCameraReturnsFullSizeJpeg() throws Exception { checkCapture(true); }
    public void testFrontCameraReturnsFullSizeJpeg() throws Exception { checkCapture(false); }
    private void checkCapture(boolean rear) throws Exception {
        MainActivity activity=getActivity();
        AtomicReference<CaptureDialog> dialog=new AtomicReference<>();
        AtomicReference<byte[]> jpeg=new AtomicReference<>();
        AtomicReference<String> problem=new AtomicReference<>();
        onUi(()->{
            CaptureDialog d=new CaptureDialog(activity,rear,jpeg::set,problem::set);
            dialog.set(d); d.show();
        });
        try {
            long end=SystemClock.elapsedRealtime()+15000;
            while(SystemClock.elapsedRealtime()<end && jpeg.get()==null && problem.get()==null) {
                onUi(()->{
                    List<Button> buttons=new ArrayList<>();
                    collect(dialog.get().getWindow().getDecorView(),Button.class,buttons);
                    for(Button b:buttons) if("사진 촬영".contentEquals(b.getText()) && b.isEnabled()) b.performClick();
                });
                SystemClock.sleep(200);
            }
            assertNull(problem.get());
            assertNotNull("No full-size capture from camera",jpeg.get());
            Photo photo=Photo.decode(android.graphics.ImageDecoder.createSource(java.nio.ByteBuffer.wrap(jpeg.get())));
            assertTrue(photo.jpeg.length>0);
        } finally { onUi(()->dialog.get().dismiss()); }
    }

    public void testWithheldNeverRendersStaleIngredients() throws Exception {
        JSONObject report=new JSONObject().put("status","COMPLETED").put("recommendationStatus","generated")
                .put("recommendation",new JSONObject());
        assertTrue(MainActivity.showRecommendation(report));
        report.put("generation",new JSONObject().put("origin","not_generated"));
        assertFalse(MainActivity.showRecommendation(report));
        report.put("generation",new JSONObject().put("qualityStatus","withheld"));
        assertFalse(MainActivity.showRecommendation(report));
        report.put("generation",JSONObject.NULL).put("status","WITHHELD");
        assertFalse(MainActivity.showRecommendation(report));
    }

    // Run only against a disposable localhost Spring database with the real or fixture AI attached.
    public void testLocalSpringFlow() throws Exception {
        assertEquals("http://10.0.2.2:3000/api/v1", BuildConfig.SPRING_URL);
        MainActivity app=getActivity();
        String email="android-"+UUID.randomUUID()+"@example.invalid";
        String password=UUID.randomUUID()+"a1!";
        SpringClient account=new SpringClient(BuildConfig.SPRING_URL);
        account.signup(email,password,"연동시험",new JSONObject().put("terms",true).put("privacy",true)
                .put("imageProcessing",true).put("over14",true));
        File input=new File(app.getCacheDir(),"fictional-face-test.jpg");
        try {
            onUi(()->{
                List<EditText> fields=views(EditText.class);
                fields.get(0).setText(email); fields.get(1).setText(password); click("로그인");
            });
            await("정면 사진",20000);
            Bitmap sample=Bitmap.createBitmap(840,800,Bitmap.Config.ARGB_8888);
            sample.eraseColor(0xffb9cecd);
            java.io.ByteArrayOutputStream flat=new java.io.ByteArrayOutputStream();
            sample.compress(Bitmap.CompressFormat.PNG,100,flat);
            try {
                Photo.decode(android.graphics.ImageDecoder.createSource(java.nio.ByteBuffer.wrap(flat.toByteArray())));
                fail("A solid frame must be rejected before upload");
            } catch(IllegalArgumentException expected) { assertTrue(expected.getMessage().contains("단색")); }
            android.graphics.Paint paint=new android.graphics.Paint(); paint.setColor(0xff426a70);
            new Canvas(sample).drawRect(0,0,275,800,paint);
            flat.reset(); sample.compress(Bitmap.CompressFormat.PNG,100,flat);
            assertFaceRejected(flat.toByteArray());
            byte[] portrait;
            try(java.io.InputStream asset=getInstrumentation().getContext().getAssets().open("fictional-frontal-face.jpg");
                java.io.ByteArrayOutputStream loaded=new java.io.ByteArrayOutputStream()) {
                byte[] chunk=new byte[8192]; int n;
                while((n=asset.read(chunk))!=-1) loaded.write(chunk,0,n);
                portrait=loaded.toByteArray();
            }
            Bitmap person=android.graphics.BitmapFactory.decodeByteArray(portrait,0,portrait.length);
            Bitmap pair=Bitmap.createBitmap(1600,800,Bitmap.Config.ARGB_8888);
            Canvas canvas=new Canvas(pair);
            canvas.drawBitmap(person,null,new android.graphics.Rect(0,0,800,800),null);
            canvas.drawBitmap(person,null,new android.graphics.Rect(800,0,1600,800),null);
            flat.reset(); pair.compress(Bitmap.CompressFormat.JPEG,90,flat);
            assertFaceRejected(flat.toByteArray());
            try(FileOutputStream f=new FileOutputStream(input)){ f.write(portrait); }
            onUi(()->app.onActivityResult(20,Activity.RESULT_OK,new Intent().setData(Uri.fromFile(input))));
            await("이 사진으로 설문 작성",10000);
            captureScreen("capture");
            onUi(()->click("이 사진으로 설문 작성"));
            await("오늘의 설문",3000);
            onUi(()->{
                List<Spinner> spinners=views(Spinner.class);
                spinners.get(0).setSelection(1); spinners.get(1).setSelection(3);
                for(CheckBox box:views(CheckBox.class)) if(box.getText().toString().equals("건조·각질")) box.setChecked(true);
            });
            captureScreen("survey");
            onUi(()->click("사진과 설문 제출"));
            await("분석 결과",65000);
            long limit=SystemClock.elapsedRealtime()+180000;
            while(!hasText("완료") && !hasText("추천 보류") && SystemClock.elapsedRealtime()<limit) {
                assertFalse(hasText("처리 실패")); SystemClock.sleep(500);
            }
            assertTrue(hasText("완료") || hasText("추천 보류"));
            captureScreen("report");
            onUi(()->click("지난 분석 보기")); await("지난 분석",5000);
            account.login(email,password);
            JSONObject item=account.history(1).getJSONArray("items").getJSONObject(0);
            JSONObject detail=account.detail(item.getString("analysisId"));
            assertTrue(detail.getJSONObject("disease").has("confidence"));
            assertEquals("30s",detail.getJSONObject("survey").getString("ageBand"));
            if("COMPLETED".equals(detail.getString("status"))) assertTrue(MainActivity.showRecommendation(detail));
            else assertEquals("WITHHELD",detail.getString("status"));
            android.util.Log.i("SkinCareTest","status="+detail.getString("status")+"; recommendation="+detail.optString("recommendationStatus"));
        } finally {
            if(input.exists()) assertTrue(input.delete());
            account.login(email,password);
            account.deleteAccount();
        }
    }
    private void assertFaceRejected(byte[] image) throws Exception {
        Photo photo=Photo.decode(android.graphics.ImageDecoder.createSource(java.nio.ByteBuffer.wrap(image)));
        try { photo.requireOneFace(); fail("Expected framing rejection"); }
        catch(IllegalArgumentException expected) {assertTrue(expected.getMessage().contains("한 사람"));}
    }
    private void onUi(Runnable work) { getInstrumentation().runOnMainSync(work); }
    private <T> List<T> views(Class<T> type) {
        List<T> found=new ArrayList<>();
        collect(getActivity().getWindow().getDecorView(),type,found); return found;
    }
    private <T> void collect(View v,Class<T> type,List<T> found) {
        if(type.isInstance(v)) found.add(type.cast(v));
        if(v instanceof ViewGroup) {
            ViewGroup group=(ViewGroup)v;
            for(int i=0;i<group.getChildCount();i++) collect(group.getChildAt(i),type,found);
        }
    }
    private void click(String label) {
        for(Button b:views(Button.class)) if(label.contentEquals(b.getText())) { b.performClick(); return; }
        throw new AssertionError("Missing button "+label);
    }
    private boolean hasText(String text) {
        AtomicReference<Boolean> found=new AtomicReference<>(false);
        onUi(()->{for(TextView t:views(TextView.class)) if(text.contentEquals(t.getText())) found.set(true);});
        return found.get();
    }
    private void await(String label,long timeout) {
        long end=SystemClock.elapsedRealtime()+timeout;
        while(SystemClock.elapsedRealtime()<end) { if(hasText(label)) return; SystemClock.sleep(150); }
        fail("Missing screen element "+label);
    }
    private void captureScreen(String name) throws Exception {
        getInstrumentation().waitForIdleSync();
        AtomicReference<Bitmap> image=new AtomicReference<>();
        onUi(()->{
            View root=getActivity().getWindow().getDecorView().findViewById(android.R.id.content);
            Bitmap b=Bitmap.createBitmap(root.getWidth(),root.getHeight(),Bitmap.Config.ARGB_8888);
            root.draw(new Canvas(b)); image.set(b);
        });
        try(FileOutputStream f=new FileOutputStream(new File(getActivity().getCacheDir(),"mentor-"+name+".png"))) {
            image.get().compress(Bitmap.CompressFormat.PNG,100,f);
        }
    }
}
