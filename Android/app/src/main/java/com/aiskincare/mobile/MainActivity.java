package com.aiskincare.mobile;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.graphics.ImageDecoder;
import android.graphics.Typeface;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.text.InputType;
import android.view.View;
import android.view.WindowManager;
import android.widget.*;
import org.json.JSONArray;
import org.json.JSONObject;
import java.nio.ByteBuffer;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Consumer;

public final class MainActivity extends Activity {
    private SpringClient api;
    private String server;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private static final int INK = 0xff193b37, MUTED = 0xff49625d, GREEN = 0xff176554;
    private LinearLayout page;
    private String screen;
    private int version;
    private boolean rear, busy;
    private Photo photo;
    private long pollStart;
    private boolean foreground;
    private String pendingReport;
    private CaptureDialog camera;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        server = canChooseServer() ? getPreferences(MODE_PRIVATE).getString("spring",BuildConfig.SPRING_URL) : BuildConfig.SPRING_URL;
        api = new SpringClient(server);
        auth(false);
    }
    private int dp(int v) { return Math.round(v * getResources().getDisplayMetrics().density); }
    private void page(String id, String title) {
        version++; pendingReport=null; main.removeCallbacksAndMessages(null); busy = false; screen = id;
        ScrollView scroll = new ScrollView(this);
        scroll.setFillViewport(true); scroll.setBackgroundColor(0xfff6f8f4);
        scroll.setOnApplyWindowInsetsListener((v, i) -> {
            v.setPadding(i.getSystemWindowInsetLeft(), i.getSystemWindowInsetTop(),
                         i.getSystemWindowInsetRight(), i.getSystemWindowInsetBottom()); return i;
        });
        page = new LinearLayout(this); page.setOrientation(LinearLayout.VERTICAL);
        page.setPadding(dp(24), dp(28), dp(24), dp(32)); scroll.addView(page);
        setContentView(scroll);
        text(title, 30, true);
    }
    private TextView text(String s, int size, boolean heading) {
        TextView t = new TextView(this); t.setText(s); t.setTextSize(size);
        t.setTextColor(heading ? INK : MUTED);
        if (heading) t.setTypeface(Typeface.create("sans-serif-medium", Typeface.NORMAL));
        t.setPadding(0, dp(8), 0, dp(6)); page.addView(t); return t;
    }
    private Button button(String title, boolean primary, Runnable action) {
        Button b = new Button(this); b.setText(title); b.setAllCaps(false); b.setTextSize(16);
        b.setMinHeight(dp(48)); b.setTextColor(primary ? Color.WHITE : INK);
        b.setBackgroundTintList(android.content.res.ColorStateList.valueOf(primary ? GREEN : 0xffdfebe5));
        page.addView(b); b.setOnClickListener(v -> { if (!busy) action.run(); }); return b;
    }
    private CheckBox check(String title) {
        CheckBox box = new CheckBox(this); box.setText(title); page.addView(box); return box;
    }
    private EditText field(String hint, int type) {
        EditText e = new EditText(this); e.setHint(hint); e.setSingleLine(true); e.setInputType(type);
        e.setSaveEnabled(false); page.addView(e); return e;
    }
    private Spinner choices(String title, String... labels) {
        text(title, 16, true);
        Spinner s = new Spinner(this); s.setContentDescription(title);
        ArrayAdapter<String> a = new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, labels);
        s.setAdapter(a); s.setMinimumHeight(dp(48)); page.addView(s); return s;
    }
    private void notice(String message) {
        new AlertDialog.Builder(this).setMessage(message).setPositiveButton("확인", null).show();
    }
    private <T> void task(Callable<T> job, Consumer<T> result) { task(job, result, null); }
    private <T> void task(Callable<T> job, Consumer<T> result, Runnable retry) {
        if (busy) return;
        busy = true; int owner = version;
        ProgressBar progress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progress.setIndeterminate(true); page.addView(progress, 1);
        worker.submit(() -> {
            try {
                T value = job.call();
                main.post(() -> {
                    if (owner != version || isDestroyed()) return;
                    busy = false; page.removeView(progress); result.accept(value);
                });
            } catch (Exception ex) {
                main.post(() -> {
                    if (owner != version || isDestroyed()) return;
                    busy = false; page.removeView(progress);
                    boolean expired = ex instanceof SpringClient.Failure && ((SpringClient.Failure) ex).status == 401;
                    if (expired && !"login".equals(screen)) { reset(); auth(false); }
                    String message = ex instanceof SpringClient.Failure || ex instanceof IllegalArgumentException
                            ? ex.getMessage() : "요청을 완료하지 못했어요. 서버 연결이나 사진을 확인해 주세요.";
                    if (retry != null && !expired)
                        new AlertDialog.Builder(this).setMessage(message).setPositiveButton("다시 조회", (d,w) -> retry.run())
                                .setNegativeButton("이력으로", (d,w) -> history(1)).show();
                    else if ("survey".equals(screen) && ex instanceof java.io.IOException && !(ex instanceof SpringClient.Failure))
                        new AlertDialog.Builder(this).setMessage("접수 응답을 받지 못했어요. 다시 보내기 전에 이력에서 접수 여부를 확인해 주세요.")
                                .setPositiveButton("지난 분석 보기",(dialog,which)->history(1)).setNegativeButton("닫기",null).show();
                    else notice(message);
                });
            }
        });
    }
    private void auth(boolean signup) {
        page(signup ? "signup" : "login", signup ? "계정 만들기" : "스킨케어");
        if (!signup) text("로그인하고 촬영 기록과 관리 루틴을 확인하세요.", 17, false);
        if (!signup && !server.isEmpty()) text("연결 서버  ·  "+Uri.parse(server).getAuthority(),14,false);
        EditText mail = field("이메일", InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS);
        EditText pass = field(signup ? "비밀번호 · 영문·숫자·특수문자 중 2종, 8~64자" : "비밀번호",
                InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        if (signup) {
            EditText nick = field("닉네임 · 2~20자", InputType.TYPE_CLASS_TEXT);
            String[] keys = {"terms","privacy","imageProcessing","over14"};
            CheckBox[] agreements = {check("서비스 이용약관 동의"), check("계정과 분석 이력의 수집·이용 동의"),
                    check("얼굴 사진을 서버로 보내 분석하는 데 동의"), check("만 14세 이상입니다")};
            button("가입하기", true, () -> {
                JSONObject consent = new JSONObject();
                for (int i=0;i<keys.length;i++) {
                    if (!agreements[i].isChecked()) { notice("가입에 필요한 네 항목을 확인해 주세요."); return; }
                    put(consent, keys[i], true);
                }
                String email = mail.getText().toString().trim(), password = pass.getText().toString(), name = nick.getText().toString().trim();
                task(() -> { api.signup(email,password,name,consent); return true; }, ok -> { auth(false); notice("가입했어요. 로그인해 주세요."); });
            });
            button("로그인으로", false, () -> auth(false));
        } else {
            button("로그인", true, () -> {
                String email = mail.getText().toString().trim(), password = pass.getText().toString();
                task(() -> { api.login(email,password); return true; }, ok -> capture());
            });
            button("계정 만들기", false, () -> auth(true));
            if (canChooseServer()) button("서버 연결 설정",false,this::serverSettings);
        }
    }
    private boolean canChooseServer() { return BuildConfig.DEBUG || BuildConfig.SPRING_URL.isEmpty(); }
    private void serverSettings() {
        EditText entry = new EditText(this); entry.setSingleLine(); entry.setSaveEnabled(false);
        entry.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_URI);
        entry.setHint("https://서버주소/api/v1"); entry.setText(server);
        AlertDialog dialog=new AlertDialog.Builder(this).setTitle("Spring 백엔드 주소")
                .setMessage("팀에서 받은 HTTPS 주소를 입력하세요. 비우면 기본 주소를 사용해요.")
                .setView(entry).setNegativeButton("취소",null).setPositiveButton("저장",null).create();
        dialog.setOnShowListener(ignored->dialog.getButton(AlertDialog.BUTTON_POSITIVE).setOnClickListener(v->{
            String url=entry.getText().toString().trim();
            if (url.isEmpty()) url=BuildConfig.SPRING_URL;
            if (url.isEmpty() || (!url.equals(BuildConfig.SPRING_URL) && !validServer(url))) {
                entry.setError("HTTPS 주소와 /api/v1 경로를 확인해 주세요."); return;
            }
            getPreferences(MODE_PRIVATE).edit().putString("spring",url).apply();
            server=url; api=new SpringClient(server); dialog.dismiss(); auth(false);
        }));
        dialog.show();
    }
    static boolean validServer(String raw) {
        try {
            java.net.URI u=new java.net.URI(raw);
            return "https".equals(u.getScheme()) && u.getHost()!=null && u.getUserInfo()==null
                    && u.getQuery()==null && u.getFragment()==null && "/api/v1".equals(u.getRawPath())
                    && u.getPort()!=0 && u.getPort()<=65535;
        } catch(java.net.URISyntaxException invalid) {return false;}
    }
    private void capture() {
        page("capture", "정면 사진"); text("눈높이에서 양쪽 볼이 보이도록 찍어 주세요. 필터를 끄고 밝기가 고른 곳을 선택하세요.",17,false);
        text("사진에 보이지 않는 부위는 평가하기 어려워요.",15,false);
        if (photo != null) {
            ImageView iv = new ImageView(this); iv.setImageBitmap(photo.preview);
            iv.setContentDescription("전송할 정면 사진"); iv.setScaleType(ImageView.ScaleType.FIT_CENTER);
            page.addView(iv, -1, dp(200)); button("이 사진으로 설문 작성", true, this::survey);
        }
        button("셀프 촬영 · 전면 카메라", photo == null, () -> camera(false));
        button("다른 사람이 촬영 · 후면 카메라", false, () -> camera(true));
        button("앨범에서 선택", false, () -> {
            Intent pick = new Intent(Intent.ACTION_OPEN_DOCUMENT).setType("image/*").addCategory(Intent.CATEGORY_OPENABLE);
            startActivityForResult(pick, 20);
        });
        button("지난 분석 보기", false, () -> history(1));
        button("로그아웃", false, () -> task(() -> {
            try { api.logout(); return true; } catch (Exception ex) { return false; }
        }, ok -> { reset(); auth(false); if (!ok) notice("이 기기에서 로그아웃했어요. 서버 세션 종료는 확인하지 못했어요."); }));
        button("회원 탈퇴", false, () -> new AlertDialog.Builder(this)
                .setMessage("계정과 저장한 분석 이력을 모두 삭제할까요? 삭제 후 복구할 수 없어요.")
                .setNegativeButton("취소",null).setPositiveButton("계정 삭제",(dialog,which) ->
                    task(() -> { api.deleteAccount(); return true; }, ok -> { reset(); auth(false); })).show());
    }
    private void reset() { photo = null; }
    private void camera(boolean rearLens) {
        rear = rearLens;
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.CAMERA}, 21); return;
        }
        camera = new CaptureDialog(this, rear, bytes -> decode(ImageDecoder.createSource(ByteBuffer.wrap(bytes))), this::notice);
        camera.show();
    }
    @Override public void onRequestPermissionsResult(int req, String[] p, int[] results) {
        super.onRequestPermissionsResult(req,p,results);
        if (req != 21) return;
        if (results.length > 0 && results[0] == PackageManager.PERMISSION_GRANTED) camera(rear);
        else notice("촬영에는 카메라 권한이 필요해요. 앨범에서 사진을 고를 수도 있어요.");
    }
    @Override protected void onActivityResult(int req, int res, Intent data) {
        super.onActivityResult(req,res,data);
        if (req == 20 && res == RESULT_OK && data != null && data.getData() != null)
            decode(ImageDecoder.createSource(getContentResolver(), data.getData()));
    }
    private void decode(ImageDecoder.Source source) {
        photo=null; capture();
        task(() -> {
            Photo selected=Photo.decode(source);
            selected.requireOneFace();
            return selected;
        }, selected -> { photo = selected; capture(); });
    }
    private static void put(JSONObject o, String key, Object value) {
        try { o.put(key, value); } catch (org.json.JSONException e) { throw new IllegalArgumentException(key, e); }
    }
    private static void selected(JSONObject o, String key, Spinner s, Object... values) {
        int i = s.getSelectedItemPosition() - 1;
        if (i >= 0) put(o,key,values[i]);
    }
    private List<CheckBox> multi(String title, String... names) {
        text(title,16,true); List<CheckBox> boxes = new ArrayList<>();
        for (String name : names) boxes.add(check(name)); return boxes;
    }
    private LinearLayout optionalFields(String title) {
        LinearLayout parent=page;
        LinearLayout fields=new LinearLayout(this); fields.setOrientation(LinearLayout.VERTICAL);
        Button toggle=button(title+" 열기",false,()->{});
        toggle.setOnClickListener(v->{
            boolean open=fields.getVisibility()!=View.VISIBLE;
            fields.setVisibility(open ? View.VISIBLE : View.GONE);
            toggle.setText(title+(open?" 닫기":" 열기"));
        });
        fields.setVisibility(View.GONE); parent.addView(fields); page=fields;
        return parent;
    }
    private static JSONArray checked(List<CheckBox> boxes, String... codes) {
        JSONArray values = new JSONArray();
        for (int i=0;i<boxes.size();i++) if (boxes.get(i).isChecked()) values.put(codes[i]); return values;
    }
    private void survey() {
        page("survey", "오늘의 설문");
        Spinner gender = choices("성별 · 필수","선택해 주세요","여성","남성");
        Spinner age = choices("연령대 · 필수","선택해 주세요","10대","20대","30대","40대","50대","60대","70대");
        Spinner skin = choices("피부 타입","미응답","건성","중성","지성","복합성");
        List<CheckBox> concerns = multi("관리하고 싶은 고민 · 최대 3개","피부 톤·잡티","모공","주름","트러블","붉은기","건조·각질","탄력","민감함");
        EditText avoid = field("피하고 싶은 성분 · 쉼표로 구분",InputType.TYPE_CLASS_TEXT);
        LinearLayout form=optionalFields("최근 피부 상태");
        text("이번 촬영의 자가 응답으로 기록해요. 현재 이미지 분류에는 사진만 사용해요.",15,false);
        Spinner itch = choices("가려움","미응답","없음","가끔","자주");
        Spinner flake = choices("각질","미응답","없음","건조함","기름짐","둘 다");
        Spinner red = choices("반복되는 붉은기","미응답","아니요","예");
        Spinner plugs = choices("눈에 보이는 면포","미응답","아니요","예");
        Spinner onset = choices("처음 알아차린 시점","미응답","1주 미만","1~4주","4주 넘음");
        List<CheckBox> areas = multi("신경 쓰이는 부위","이마","머리카락 경계·두피","눈썹 주변","코 주변","볼","턱");
        page=form;
        optionalFields("생활 습관과 사용 제품");
        EditText hours=field("평균 수면 시간 · 0~14시간",InputType.TYPE_CLASS_NUMBER);
        Spinner water=choices("물 섭취량","미응답","적음","보통","많음");
        Spinner sun=choices("햇빛 노출","미응답","적음","보통","많음");
        Spinner stress=choices("스트레스","미응답","낮음","보통","높음");
        EditText products=field("사용 제품 · 최대 5개, 쉼표로 구분",InputType.TYPE_CLASS_TEXT);
        EditText note=field("추가로 전할 내용 · 300자 이내",InputType.TYPE_CLASS_TEXT);
        page=form;
        button("사진과 설문 제출", true, () -> {
            JSONObject answer = new JSONObject(), symptoms = new JSONObject();
            selected(answer,"gender",gender,"female","male");
            selected(answer,"ageBand",age,"10s","20s","30s","40s","50s","60s","70s");
            if (!answer.has("gender") || !answer.has("ageBand")) { notice("성별과 연령대를 선택해 주세요."); return; }
            selected(answer,"skinType",skin,"dry","normal","oily","combination");
            JSONArray goals = checked(concerns,"pigmentation","pore","wrinkle","acne","redness","dryness","sagging","sensitivity");
            if (goals.length()>3) { notice("고민은 최대 3개까지 선택할 수 있어요."); return; }
            if (goals.length()>0) put(answer,"concerns",goals);
            JSONArray exclusions = new JSONArray();
            for (String part : avoid.getText().toString().split(",")) {
                String name=part.trim(); if (name.isEmpty()) continue;
                if (name.length()>100 || exclusions.length()>=30) { notice("회피 성분은 30개까지, 이름은 100자 이내로 입력해 주세요."); return; }
                exclusions.put(name);
            }
            if (exclusions.length()>0) put(answer,"avoidIngredients",exclusions);
            selected(symptoms,"itch",itch,"none","occasional","frequent");
            selected(symptoms,"flaking",flake,"none","dry","greasy","both");
            selected(symptoms,"recurringRedness",red,false,true);
            selected(symptoms,"visiblePlugs",plugs,false,true);
            selected(symptoms,"onset",onset,"under_one_week","one_to_four_weeks","over_four_weeks");
            JSONArray sites = checked(areas,"forehead","hairline_scalp","eyebrows","around_nose","cheeks","jaw_chin");
            if (sites.length()>0) put(symptoms,"areas",sites);
            if (symptoms.length()>0) put(answer,"symptomProfile",symptoms);
            selected(answer,"waterIntakeLevel",water,"low","medium","high");
            selected(answer,"sunExposureLevel",sun,"low","medium","high");
            selected(answer,"stressLevel",stress,"low","medium","high");
            String sleep=hours.getText().toString().trim();
            if(!sleep.isEmpty()) {
                if(!sleep.matches("[0-9]{1,2}") || Integer.parseInt(sleep)>14) {notice("수면 시간은 0~14시간으로 입력해 주세요.");return;}
                put(answer,"sleepHours",Integer.parseInt(sleep));
            }
            JSONArray used=new JSONArray();
            for(String item:products.getText().toString().split(",")) {
                String product=item.trim(); if(product.isEmpty()) continue;
                if(product.length()>30 || used.length()>=5) {notice("제품은 5개까지, 이름은 30자 이내로 입력해 주세요.");return;}
                used.put(product);
            }
            if(used.length()>0) put(answer,"currentProducts",used);
            String extra=note.getText().toString().trim();
            if(extra.length()>300) {notice("추가 내용은 300자 이내로 입력해 주세요.");return;}
            if(!extra.isEmpty()) put(answer,"note",extra);
            byte[] jpeg = photo.jpeg;
            task(() -> api.submit(jpeg,answer), report -> { photo=null; openReport(report); });
        });
        button("사진으로 돌아가기",false,this::capture);
    }
    private void history(int index) {
        page("history","지난 분석"); button("사진 촬영으로",false,this::capture);
        task(() -> api.history(index), list -> {
            JSONArray rows = list.optJSONArray("items");
            if (rows == null || rows.length()==0) text("아직 분석 기록이 없어요.",17,false);
            else for (int i=0;i<rows.length();i++) {
                JSONObject row=rows.optJSONObject(i); if (row==null) continue;
                String id=row.optString("analysisId"), date=row.optString("createdAt").split("T")[0];
                JSONObject disease=row.optJSONObject("disease");
                button(date+"   "+(disease==null?"":disease.optString("label"))+"   "+stateName(row.optString("status")),
                        false,()->task(()->api.detail(id),this::openReport));
            }
            if (index>1) button("이전 페이지",false,()->history(index-1));
            JSONObject bounds=list.optJSONObject("page");
            if (bounds!=null && index<bounds.optInt("totalPages")) button("다음 페이지",false,()->history(index+1));
        }, ()->history(index));
    }
    private static String stateName(String status) {
        switch(status) {
            case "QUEUED": return "접수"; case "GENERATING": return "추천 작성 중";
            case "COMPLETED": return "완료"; case "WITHHELD": return "추천 보류"; case "FAILED": return "처리 실패";
            default: return "상태 확인 필요";
        }
    }
    private void openReport(JSONObject value) { pollStart=SystemClock.elapsedRealtime(); report(value); }
    static boolean showRecommendation(JSONObject r) {
        JSONObject meta=r.optJSONObject("generation");
        return "COMPLETED".equals(r.optString("status")) && "generated".equals(r.optString("recommendationStatus"))
                && r.optJSONObject("recommendation")!=null && (meta==null || !("not_generated".equals(meta.optString("origin"))
                || "withheld".equals(meta.optString("qualityStatus")) || "withheld".equals(meta.optString("evidenceStatus"))));
    }
    private void lines(JSONArray values) {
        if (values!=null) for(int i=0;i<values.length();i++) text(values.optString(i),16,false);
    }
    private void report(JSONObject value) {
        page("report","분석 결과");
        JSONObject d=value.optJSONObject("disease");
        if (d!=null) {
            text(d.optString("label")+"   ·   모델 분류 점수 "+Math.round(d.optDouble("confidence",0)*100)+"%",21,true);
            text("이미지 분류 참고 결과이며 의학적 진단이 아닙니다.",15,false);
            if (d.optBoolean("uncertain")) text("분류 점수가 낮아 결과가 불확실해요.",16,false);
            android.graphics.Bitmap map = heatmap(d);
            if (map != null) {
                ImageView image = new ImageView(this); image.setImageBitmap(map);
                image.setContentDescription("분류기가 참고한 영역"); page.addView(image, -1, dp(144));
                text("밝은 부분은 분류기가 더 많이 참고한 영역이에요. 병변의 경계를 표시한 그림은 아니에요.",14,false);
            }
        }
        String status=value.optString("status"), id=value.optString("analysisId");
        text(stateName(status),19,true); lines(value.optJSONArray("guidance"));
        if (showRecommendation(value)) {
            JSONObject rec=value.optJSONObject("recommendation"), meta=value.optJSONObject("generation");
            if (meta!=null) {
                String origin=meta.optString("origin");
                if ("source_cards".equals(origin)) text("근거 카드로 구성한 안내",15,false);
                if ("rule_fallback".equals(origin)) text("기본 관리 규칙으로 구성한 안내",15,false);
            }
            if (!rec.isNull("answer")) text(rec.optString("answer"),16,false);
            JSONArray ingredients=rec.optJSONArray("ingredients");
            if (ingredients!=null && ingredients.length()>0) text("추천 성분",21,true);
            if (ingredients!=null) for(int i=0;i<ingredients.length();i++) {
                JSONObject item=ingredients.optJSONObject(i); if(item!=null) text(item.optString("name")+
                        (item.isNull("purpose") ? "" : "  ·  "+item.optString("purpose")),16,false);
            }
            JSONArray steps=rec.optJSONArray("routine");
            if(steps!=null && steps.length()>0) text("관리 루틴",21,true);
            if(steps!=null) for(int i=0;i<steps.length();i++){
                JSONObject s=steps.optJSONObject(i);
                if(s!=null) text(timeLabel(s.optString("time"))+"   "+s.optString("action"),16,false);
            }
            if(!rec.isNull("disclaimer")) text(rec.optString("disclaimer"),14,false);
        } else if ("WITHHELD".equals(status) || "COMPLETED".equals(status)) {
            String reason=value.optString("recommendationStatus");
            String message="이번 분석에서는 성분 추천을 제공하지 않아요.";
            if ("uncertain".equals(reason)) message="사진 분류가 불확실해 추천을 보류했어요.";
            if ("no_concern".equals(reason)) message="정상으로 분류됐고 선택한 고민이 없어 추천을 생략했어요.";
            if ("quality_rejected".equals(reason)) message="추천이 근거·품질 기준을 충족하지 않아 보류했어요.";
            text(message,16,false);
        } else if ("FAILED".equals(status)) {
            button("추천 다시 요청",true,()->task(()->api.retry(id),this::openReport));
        } else if ("QUEUED".equals(status) || "GENERATING".equals(status)) {
            long elapsed=SystemClock.elapsedRealtime()-pollStart;
            if(elapsed>=150000) text("추천이 지연되고 있어요. 지난 분석에서 이어서 확인할 수 있어요.",16,false);
            if(elapsed<1800000) {
                pendingReport=id;
                if (foreground) main.postDelayed(()->poll(id),elapsed<180000?3000:10000);
            }
            else button("상태 다시 확인",false,()->{pollStart=SystemClock.elapsedRealtime();poll(id);});
        }
        button("지난 분석 보기",false,()->history(1)); button("새 사진 분석",false,this::capture);
    }
    private void poll(String id) {
        if (!foreground || busy || !"report".equals(screen)) return;
        pendingReport=null; task(()->api.detail(id),this::report,()->poll(id));
    }
    private static android.graphics.Bitmap heatmap(JSONObject disease) {
        JSONObject e = disease.optJSONObject("explanation");
        if (e == null || !e.optBoolean("available") || !"grad_cam".equals(e.optString("method"))
                || !e.optString("targetLabel").equals(disease.optString("label"))
                || disease.isNull("modelVersion") || !e.optString("modelVersion").equals(disease.optString("modelVersion"))) return null;
        String encoded=e.optString("heatmapPngBase64","");
        if (encoded.isEmpty() || encoded.length()>120000) return null;
        try {
            byte[] bytes=android.util.Base64.decode(encoded,android.util.Base64.DEFAULT);
            if(bytes.length<33 || bytes.length>90000 || bytes[24]!=8 || bytes[25]!=0) return null;
            android.graphics.BitmapFactory.Options bounds=new android.graphics.BitmapFactory.Options();
            bounds.inJustDecodeBounds=true;
            android.graphics.BitmapFactory.decodeByteArray(bytes,0,bytes.length,bounds);
            if(!"image/png".equals(bounds.outMimeType) || bounds.outWidth!=256 || bounds.outHeight!=256) return null;
            return android.graphics.BitmapFactory.decodeByteArray(bytes,0,bytes.length);
        } catch(IllegalArgumentException invalid) {return null;}
    }
    private static String timeLabel(String time) {
        switch (time) {
            case "morning":return "아침"; case "evening":return "저녁"; case "daily":return "매일";
            case "weekly":return "매주"; default:return "일상 관리";
        }
    }
    @Override public void onBackPressed() {
        if (busy) return;
        switch (screen) {
            case "signup": auth(false); break;
            case "survey": case "history": case "report": capture(); break;
            default: super.onBackPressed();
        }
    }
    @Override protected void onResume() {
        super.onResume(); foreground=true;
        if (pendingReport!=null) poll(pendingReport);
    }
    @Override protected void onPause() {
        foreground=false;
        if(camera!=null && camera.isShowing()) camera.dismiss();
        super.onPause();
    }
    @Override protected void onDestroy() {
        version++; main.removeCallbacksAndMessages(null); worker.shutdownNow(); reset(); super.onDestroy();
    }
}
