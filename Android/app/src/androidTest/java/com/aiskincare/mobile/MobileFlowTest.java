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
                    for(Button b:buttons) if("사진 촬영".contentEquals(b.getContentDescription()) && b.isEnabled()) b.performClick();
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
            await("피부 분석 시작",20000);
            onUi(()->click("피부 분석 시작"));
            if (hasText("촬영 화면으로")) onUi(()->click("촬영 화면으로"));
            await("얼굴 사진을 준비해 주세요.",5000);
            onUi(()->assertFalse(button("다음").isEnabled()));
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
            await("이 사진으로 분석할게요.",10000);
            captureScreen("capture");
            onUi(()->click("다음"));
            await("기본 정보를 알려 주세요.",3000);
            getInstrumentation().waitForIdleSync();
            onUi(()->{
                Button lastAge = button("70대");
                assertEquals("Empty grid cells must not stretch the age row",
                        lastAge.getHeight(), ((View) lastAge.getParent()).getHeight());
                assertFalse(button("다음").isEnabled());
                click("여성");
                click("30대");
                click("중성");
                assertTrue(button("다음").isEnabled());
            });
            captureScreen("survey");
            onUi(()->click("다음"));
            await("피부 상태와 생활 습관",4000);
            onUi(()->{
                click("가끔");
                click("건조함");
                click("1~4주");
                click("볼");
                click("건조·각질");
                getActivity().onBackPressed();
                assertTrue(button("여성").isSelected());
                assertTrue(button("30대").isSelected());
                click("다음");
                assertTrue(button("가끔").isSelected());
                assertTrue(button("볼").isSelected());
                click("분석 시작");
            });
            await("분석 결과",65000);
            long limit=SystemClock.elapsedRealtime()+180000;
            while(!hasText("완료") && !hasText("추천 보류") && SystemClock.elapsedRealtime()<limit) {
                assertFalse(hasText("처리 실패")); SystemClock.sleep(500);
            }
            assertTrue(hasText("완료") || hasText("추천 보류"));
            captureScreen("report");
            if (hasText("완료")) {
                onUi(()->click("추천 자세히 보기"));
                await("추천 성분",5000);
                if (hasText("관리 루틴")) onUi(()->{ click("저녁"); assertTrue(button("저녁").isSelected()); });
                onUi(()->getActivity().onBackPressed());
                await("분석 결과",5000);
            }
            onUi(()->click("지난 분석 보기")); await("이력",5000);
            account.login(email,password);
            java.lang.reflect.Field accessToken = SpringClient.class.getDeclaredField("access");
            accessToken.setAccessible(true);
            accessToken.set(account, "expired-for-refresh-test");
            JSONObject item=account.history(1).getJSONArray("items").getJSONObject(0);
            JSONObject detail=account.detail(item.getString("analysisId"));
            assertTrue(detail.getJSONObject("disease").has("confidence"));
            assertEquals("30s",detail.getJSONObject("survey").getString("ageBand"));
            JSONObject symptom = detail.getJSONObject("survey").getJSONObject("symptomProfile");
            assertEquals("occasional", symptom.getString("itch"));
            assertEquals("dry", symptom.getString("flaking"));
            assertEquals("one_to_four_weeks", symptom.getString("onset"));
            assertEquals("cheeks", symptom.getJSONArray("areas").getString(0));
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
    private Button button(String label) {
        for(Button b:views(Button.class)) if(label.contentEquals(b.getText())) return b;
        throw new AssertionError("Missing button "+label);
    }
    private void click(String label) {
        Button button = button(label);
        assertTrue("Disabled button " + label, button.isEnabled());
        button.performClick();
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
