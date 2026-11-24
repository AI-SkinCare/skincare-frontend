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
    public void testNewSurveyUsesPreviousBasicsAndClearsReportedSymptoms() throws Exception {
        MainActivity app=getActivity();
        var prior=new JSONObject().put("gender","female").put("ageBand","30s").put("skinType","dry")
                .put("captureView","side").put("sleepHours",7).put("concerns",new org.json.JSONArray().put("dryness"))
                .put("avoidIngredients",new org.json.JSONArray().put("향료"))
                .put("symptomProfile",new JSONObject().put("itch","occasional"));
        var defaults=MainActivity.class.getDeclaredMethod("applyDefaults",JSONObject.class);
        var open=MainActivity.class.getDeclaredMethod("survey");
        defaults.setAccessible(true); open.setAccessible(true);
        onUi(()->{
            try { defaults.invoke(app,prior); open.invoke(app); }
            catch (ReflectiveOperationException error) { throw new AssertionError(error); }
            assertTrue(button("여성").isSelected()); assertTrue(button("건성").isSelected());
            click("다음");
            assertTrue(button("건조·각질").isSelected()); assertFalse(button("가끔").isSelected());
            assertTrue(button("분석 시작").isEnabled());
        });
        assertTrue(hasText("7")); assertTrue(hasText("향료"));
    }

    public void testFramingGateChecksBothSidesAndDistance() {
        android.graphics.RectF guide=new android.graphics.RectF(0,0,300,400);
        android.graphics.RectF face=new android.graphics.RectF(60,80,240,320);
        assertTrue(FaceFrame.aligned(face,guide,45,0,true));
        assertTrue(FaceFrame.aligned(face,guide,-45,0,true));
        assertFalse(FaceFrame.aligned(face,guide,0,0,true));
        assertFalse(FaceFrame.aligned(face,guide,45,0,false));
        face.offset(90,0);
        assertFalse(FaceFrame.aligned(face,guide,45,0,true));
    }
    public void testSharedSideResultShowsUntimedCare() throws Exception {
        JSONObject item;
        try (var stream = getInstrumentation().getContext().getAssets().open("parity-side-result.json");
             var reader = new java.util.Scanner(stream, "UTF-8").useDelimiter("\\A")) {
            item = new JSONObject(reader.next());
        }
        MainActivity app = getActivity();
        onUi(() -> app.openReport(item));
        await("측면 사진 · 시험 기능", 3000);
        await("79%", 3000);
        onUi(() -> click("추천 자세히 보기"));
        await("글리세린", 3000);
        await("세라마이드", 3000);
        onUi(() -> click("글리세린 근거 보기  ＋"));
        await("이번 추천에 연결된 근거", 3000);
        await("근거의 한계", 3000);
        await("Breternitz et al. 2008, glycerol-based emollient in atopic dermatitis", 3000);
        onUi(() -> click("세라마이드 근거 보기  ＋"));
        await("이 결과에는 성분별 출처가 저장되어 있지 않아요.", 3000);
        await("일반 참고자료", 3000);
        await("Spada et al. 2021, ceramide-dominant cream and cleanser regimen", 3000);
        await("이 분류에는 별도의 식습관 자료가 없어 일반 식생활 지침을 표시해요.", 3000);
        await("시간대 무관", 3000);
        await("자극이 생기면 사용을 중단한다.", 3000);
        assertFalse(hasText("아침"));
        assertFalse(hasText("주간 관리"));
    }
    public void testSideFaceAcceptsEitherDirectionAndRejectsFrontal() throws Exception {
        try (var side = getInstrumentation().getContext().getAssets().open("fictional-side-face.jpg")) {
            Bitmap bitmap = android.graphics.BitmapFactory.decodeStream(side);
            for (int direction : new int[]{1, -1}) {
                android.graphics.Matrix transform = new android.graphics.Matrix();
                transform.setScale(direction, 1);
                Bitmap image = Bitmap.createBitmap(bitmap, 0, 0, bitmap.getWidth(), bitmap.getHeight(), transform, true);
                var encoded = new java.io.ByteArrayOutputStream();
                image.compress(Bitmap.CompressFormat.JPEG, 90, encoded);
                Photo.decode(android.graphics.ImageDecoder.createSource(java.nio.ByteBuffer.wrap(encoded.toByteArray()))).requireSideFace();
            }
        }
        try (var front = getInstrumentation().getContext().getAssets().open("fictional-frontal-face.jpg")) {
            var data = new java.io.ByteArrayOutputStream();
            byte[] buffer = new byte[8192];
            int count;
            while ((count = front.read(buffer)) != -1) data.write(buffer, 0, count);
            Photo face = Photo.decode(android.graphics.ImageDecoder.createSource(java.nio.ByteBuffer.wrap(data.toByteArray())));
            face.requireOneFace();
            try { face.requireSideFace(); fail("Frontal photo accepted as side"); }
            catch (IllegalArgumentException expected) { assertTrue(expected.getMessage().contains("정면")); }
        }
    }

    public void testCatalogRequiresIngredientAndKnownExclusions() throws Exception {
        var catalog = new CareGuide(getInstrumentation().getTargetContext());
        var names = new org.json.JSONArray().put(new JSONObject().put("name", "Zinc Oxide"));
        assertEquals(1, catalog.products(names, new org.json.JSONArray()).size());
        assertEquals(1, catalog.products(names, new org.json.JSONArray().put("향료")).size());
        assertTrue(catalog.products(names, null).isEmpty());
        assertTrue(catalog.products(names, new org.json.JSONArray().put("GLYCERIN")).isEmpty());
        assertTrue(catalog.products(names, new org.json.JSONArray().put("알 수 없는 성분")).isEmpty());
        assertTrue(catalog.products(new org.json.JSONArray(), new org.json.JSONArray()).isEmpty());
    }

    public void testDailyDiaryEditsGapAndAccountIsolation() throws Exception {
        var context = getInstrumentation().getTargetContext();
        var settings = context.getSharedPreferences("MainActivity", 0);
        String previousServer = settings.getString("spring", null);
        settings.edit().putString("spring", "http://10.0.2.2:1/api/v1").commit();
        var app = getActivity();
        var owner = new JSONObject().put("id", 87234101);
        var other = new JSONObject().put("id", 87234102);
        String earlier = java.time.LocalDate.now().minusDays(3).toString();
        try {
            onUi(() -> {
                app.signedIn("diary@example.invalid", owner);
                app.journal().edit().clear().putString(earlier, "{\"score\":4,\"product\":\"\"}").commit();
                click("매일 피부 기록");
                views(Spinner.class).get(0).setSelection(8);
                views(EditText.class).get(0).setText("샘플 보습제");
                click("오늘 기록 저장");
            });
            await(earlier + " 대비 3점 상승", 4000);
            await("7점 − 4점 = 3점", 4000);
            await("사용 제품 · 샘플 보습제", 4000);
            onUi(() -> { views(Spinner.class).get(0).setSelection(4); click("오늘 기록 수정"); });
            await(earlier + " 대비 1점 하락", 4000);
            await("3점 − 4점 = -1점", 4000);
            assertEquals(2, app.journal().getAll().size());
            onUi(() -> { app.signedIn("other@example.invalid", other); click("매일 피부 기록"); });
            await("첫 기록부터 날짜별로 쌓여요.", 4000);
            onUi(() -> { app.signedIn("diary@example.invalid", owner); click("매일 피부 기록"); });
            await(earlier + " 대비 1점 하락", 4000);
        } finally {
            onUi(() -> { app.signedIn("diary@example.invalid", owner); app.journal().edit().clear().commit(); });
            settings.edit().putString("spring", previousServer).commit();
        }
    }

    public void testResultShowsCareDietAndMatchedProductOnlyAfterGeneration() throws Exception {
        var input = new JSONObject().put("status", "COMPLETED").put("recommendationStatus", "generated")
                .put("disease", new JSONObject().put("label", "여드름").put("uncertain", false))
                .put("survey", new JSONObject().put("avoidIngredients", new org.json.JSONArray()))
                .put("recommendation", new JSONObject().put("ingredients", new org.json.JSONArray()
                        .put(new JSONObject().put("name", "징크옥사이드"))));
        var app = getActivity();
        onUi(() -> { app.openReport(input); click("추천 자세히 보기"); });
        await("일상 관리", 2000);
        await("식습관 메모", 2000);
        await("일치한 추천 성분 · 징크옥사이드", 2000);
        await("제조사 표기 · zinc oxide", 2000);
        await("사진의 ‘여드름’ 분류에 연결한 자료예요. 설문에는 식사 기록이 없어요.", 2000);
        await("제조사 성분표", 2000);
        input.put("generation", new JSONObject().put("origin", "not_generated"));
        onUi(() -> app.openReport(input));
        assertFalse(hasText("추천 자세히 보기"));
        assertFalse(hasText("제조사 성분표"));
    }
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
                java.lang.reflect.Field field=CaptureDialog.class.getDeclaredField("camera");
                field.setAccessible(true);
                var camera=(android.hardware.Camera)field.get(dialog.get());
                if(camera!=null){
                    SystemClock.sleep(800);
                    onUi(()->{
                        List<Button> buttons=new ArrayList<>();
                        collect(dialog.get().getWindow().getDecorView(),Button.class,buttons);
                        for(Button b:buttons) if("사진 촬영".contentEquals(b.getContentDescription()))
                            assertFalse("No face in virtual camera scene",b.isEnabled());
                        // Verify sensor JPEG delivery independently of the no-face shutter interlock.
                        camera.takePicture(null,null,(bytes,source)->jpeg.set(bytes));
                    });
                    break;
                }
                SystemClock.sleep(200);
            }
            while(jpeg.get()==null && problem.get()==null && SystemClock.elapsedRealtime()<end) SystemClock.sleep(100);
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
    public void testLocalSpringFlow() throws Exception { checkLocalSpringFlow(false); }

    public void testLocalKnowledgeSearch() throws Exception {
        assertEquals("http://10.0.2.2:3000/api/v1", BuildConfig.SPRING_URL);
        getActivity();
        String email = "knowledge-" + UUID.randomUUID() + "@example.invalid";
        String password = UUID.randomUUID() + "a1!";
        SpringClient account = new SpringClient(BuildConfig.SPRING_URL);
        account.signup(email, password, "자료검색", new JSONObject().put("terms",true).put("privacy",true)
                .put("imageProcessing",true).put("over14",true));
        try {
            onUi(() -> {
                List<EditText> fields = views(EditText.class);
                fields.get(0).setText(email); fields.get(1).setText(password); click("로그인");
            });
            await("피부 자료 검색", 15000);
            onUi(() -> { click("피부 자료 검색"); views(EditText.class).get(0).setText("나트륨 영양표시"); click("검색"); });
            await("답변 출처 · 식품의약품안전처 · 식품안전나라", 20000);
            onUi(() -> { views(Spinner.class).get(0).setSelection(1); views(EditText.class).get(0).setText("세라마이드"); });
            onUi(() -> click("검색"));
            await("미국 국립의학도서관 · PubMed", 15000);
            onUi(() -> { views(Spinner.class).get(0).setSelection(2); views(EditText.class).get(0).setText("징크옥사이드"); });
            onUi(() -> click("검색"));
            await("미국 제품 라벨 · openFDA", 15000);
            onUi(() -> { views(EditText.class).get(0).setText("기차시간표"); click("검색"); });
            await("선택한 자료에서 질문에 맞는 근거를 찾지 못했어요. 성분명이나 다른 검색어로 찾아보세요.", 12000);
            onUi(() -> { getActivity().onBackPressed(); click("매일 피부 기록"); click("점수 계산 근거"); });
            await("답변 출처 · SkinCare · 앱 계산 방식", 20000);
            onUi(() -> getActivity().onBackPressed());
            await("날짜별 변화", 3000);
        } finally { account.login(email, password); account.deleteAccount(); }
    }
    public void testLocalSpringSideFlow() throws Exception { checkLocalSpringFlow(true); }
    private void checkLocalSpringFlow(boolean side) throws Exception {
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
            if (side) onUi(()->click("측면"));
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
            String assetName=side ? "fictional-side-face.jpg" : "fictional-frontal-face.jpg";
            try(java.io.InputStream asset=getInstrumentation().getContext().getAssets().open(assetName);
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
            await("얼굴 위치 맞추기",12000);
            getInstrumentation().waitForIdleSync();
            onUi(()->click("이 사진 사용"));
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
                assertFalse(button("분석 시작").isEnabled());
                for (String field : new String[]{"수면 시간","물 섭취량","햇빛 노출","스트레스","사용 중인 제품"}) {
                    boolean found = false;
                    for (Button b : views(Button.class)) {
                        if ((field+" · 잘 모르겠어요").contentEquals(b.getContentDescription()==null?"":b.getContentDescription())) {
                            b.performClick(); found=true; break;
                        }
                    }
                    assertTrue(field,found);
                }
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
                if (hasText("저녁")) onUi(()->{ click("저녁"); assertTrue(button("저녁").isSelected()); });
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
            assertEquals(side ? "side":"front",detail.getJSONObject("survey").getString("captureView"));
            if (side) {
                assertEquals("dinov2_linear_875acf74c4",detail.getJSONObject("disease").getString("modelVersion"));
                assertEquals("generated",detail.getString("recommendationStatus"));
            }
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
            onUi(()->click("기록 삭제"));
            var automation=getInstrumentation().getUiAutomation();
            android.view.accessibility.AccessibilityNodeInfo confirm=null;
            for(int attempt=0;attempt<30 && confirm==null;attempt++) {
                var dialog=automation.getRootInActiveWindow();
                if (dialog!=null) for(var node:dialog.findAccessibilityNodeInfosByText("삭제"))
                    if ("삭제".contentEquals(node.getText()==null ? "" : node.getText()) && node.isClickable()) confirm=node;
                if(confirm==null) SystemClock.sleep(100);
            }
            assertNotNull("history deletion confirmation",confirm);
            assertTrue(confirm.performAction(android.view.accessibility.AccessibilityNodeInfo.ACTION_CLICK));
            await("아직 분석 기록이 없어요.",10000);
            assertEquals(0,account.history(1).getJSONArray("items").length());
            var saved=new RefreshStore(app,BuildConfig.SPRING_URL);
            assertTrue(saved.hasSession());
            SpringClient reopened=new SpringClient(BuildConfig.SPRING_URL,saved);
            assertEquals(email,reopened.restore().getString("email"));
            reopened.logout();
            assertFalse(saved.hasSession());
        } finally {
            if(input.exists()) assertTrue(input.delete());
            account.login(email,password);
            account.deleteAccount();
            new RefreshStore(app,BuildConfig.SPRING_URL).clear();
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
