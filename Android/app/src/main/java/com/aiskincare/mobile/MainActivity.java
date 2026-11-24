package com.aiskincare.mobile;

import android.Manifest;
import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.ImageDecoder;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.os.SystemClock;
import android.provider.MediaStore;
import android.text.InputType;
import android.view.Gravity;
import android.view.View;
import android.view.WindowInsets;
import android.view.WindowManager;
import android.view.inputmethod.InputMethodManager;
import android.widget.*;
import org.json.JSONArray;
import org.json.JSONObject;
import java.nio.ByteBuffer;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.format.DateTimeFormatter;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.concurrent.Callable;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.function.Consumer;

import static com.aiskincare.mobile.AppStyle.*;

public final class MainActivity extends Activity {
    private SpringClient api;
    private String server;
    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private AppStyle style;
    private LinearLayout root;
    private LinearLayout page;
    private ScrollView scroll;
    private String screen;
    private int version;
    private boolean rear, busy;
    private boolean side;
    private boolean loadedDefaults;
    private long userId;
    private Photo photo;
    private long pollStart;
    private boolean foreground;
    private String pendingReport;
    private CaptureDialog camera;
    private String nickname = "", email = "";
    private JSONObject draft = new JSONObject();
    private final java.util.Map<String, String> draftText = new java.util.HashMap<>();
    private String reportBack = "home";
    private int historyPage = 1;
    private JSONObject currentReport;

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        getWindow().getDecorView().setSystemUiVisibility(View.SYSTEM_UI_FLAG_LIGHT_STATUS_BAR |
                View.SYSTEM_UI_FLAG_LIGHT_NAVIGATION_BAR);
        style = new AppStyle(this);
        server = canChooseServer() ? getPreferences(MODE_PRIVATE).getString("spring",BuildConfig.SPRING_URL) : BuildConfig.SPRING_URL;
        connect();
    }
    private void connect() {
        RefreshStore store = new RefreshStore(this, server);
        api = new SpringClient(server, store);
        if (!store.hasSession()) { auth(false); return; }
        page("restore", "로그인 확인 중");
        SpringClient client = api;
        task(() -> {
            try { return client.restore(); } catch (Exception unavailable) { return null; }
        }, user -> {
            if (user == null) auth(false);
            else signedIn(user.optString("email"), user);
        });
    }
    private int dp(int v) { return style.dp(v); }
    private void page(String id, String title) {
        if (getCurrentFocus() instanceof EditText) {
            getSystemService(InputMethodManager.class).hideSoftInputFromWindow(getCurrentFocus().getWindowToken(), 0);
        }
        version++; pendingReport=null; main.removeCallbacksAndMessages(null); busy = false; screen = id;
        if (!"report".equals(id) && !"recommendation".equals(id)) currentReport = null;
        root = style.column();
        root.setBackgroundColor(WHITE);
        root.setOnApplyWindowInsetsListener((v, i) -> {
            int bottom = i.getSystemWindowInsetBottom();
            if (android.os.Build.VERSION.SDK_INT >= 30) {
                bottom = Math.max(bottom, i.getInsets(WindowInsets.Type.ime()).bottom);
            }
            v.setPadding(i.getSystemWindowInsetLeft(), i.getSystemWindowInsetTop(),
                         i.getSystemWindowInsetRight(), bottom);
            return i;
        });
        scroll = new ScrollView(this);
        scroll.setFillViewport(true);
        scroll.setVerticalScrollBarEnabled(false);
        page = style.column();
        page.setPadding(dp(20), dp(8), dp(20), dp(24));
        scroll.addView(page);
        root.addView(scroll, new LinearLayout.LayoutParams(-1, 0, 1));
        setContentView(root);
        if (title != null) label(page, title, 30, INK, 700, 6, 16);
    }

    private TextView label(LinearLayout parent, String value, int size, int color, int weight, int before, int after) {
        TextView view = style.text(value, size, color, weight);
        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(-1, -2);
        params.setMargins(0, dp(before), 0, dp(after));
        parent.addView(view, params);
        return view;
    }

    private TextView text(String s, int size, boolean heading) {
        return label(page, s, size, heading ? INK : MUTED, heading ? 600 : 400, 5, 6);
    }

    private void hero(String title, String subtitle) {
        label(page, title, 28, INK, 700, 6, 7);
        label(page, subtitle, 16, MUTED, 400, 0, 18);
    }

    private LinearLayout card(LinearLayout parent, boolean outline, int padding) {
        LinearLayout card = style.column();
        card.setBackground(style.surface(outline ? WHITE : SOFT, 24, outline));
        card.setPadding(dp(padding), dp(padding), dp(padding), dp(padding));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.bottomMargin = dp(12);
        parent.addView(card, lp);
        return card;
    }

    private void separator(LinearLayout owner) {
        View line = new View(this);
        line.setBackgroundColor(LINE);
        owner.addView(line, -1, dp(1));
    }

    private Button action(String title, boolean primary, Runnable action) {
        Button b = style.button(title, 52);
        if (primary) style.primary(b, true);
        else style.actionSurface(b, WHITE, 28, true);
        b.setOnClickListener(v -> { if (!busy) action.run(); });
        return b;
    }

    private Button addAction(LinearLayout owner, String title, boolean primary, Runnable click) {
        Button b = action(title, primary, click);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.topMargin = dp(8);
        owner.addView(b, lp);
        return b;
    }

    private Button button(String title, boolean primary, Runnable action) {
        return addAction(page, title, primary, action);
    }

    private Button footer(String title, Runnable click) {
        LinearLayout bar = style.column();
        separator(bar);
        LinearLayout inset = style.column();
        inset.setPadding(dp(20), 0, dp(20), dp(10));
        bar.addView(inset);
        root.addView(bar, -1, -2);
        return addAction(inset, title, true, click);
    }

    private void toolbar(String title, Runnable back, String backLabel, Runnable close) {
        LinearLayout row = style.row();
        row.setMinimumHeight(dp(52));
        root.addView(row, 0, new LinearLayout.LayoutParams(-1, -2));
        toolbarButton(row, "‹", backLabel, back);
        TextView name = style.text(title, 17, INK, 600);
        name.setGravity(Gravity.CENTER);
        row.addView(name, new LinearLayout.LayoutParams(0, -2, 1));
        toolbarButton(row, "×", "닫기", close);
    }

    private void toolbarButton(LinearLayout row, String mark, String name, Runnable click) {
        if (click == null) { row.addView(new View(this), dp(52), dp(48)); return; }
        Button button = style.button(mark, 48);
        style.type(button, 26, INK, 400);
        style.actionSurface(button, WHITE, 24, false);
        button.setContentDescription(name);
        button.setOnClickListener(v -> { if (!busy) click.run(); });
        row.addView(button, dp(52), dp(48));
    }

    private void tabs(String selectedTab) {
        LinearLayout bar = style.column();
        separator(bar);
        LinearLayout row = style.row();
        bar.addView(row, -1, -2);
        String[] ids = {"home", "history", "my"};
        String[] titles = {"홈", "이력", "마이"};
        Runnable[] callbacks = {this::home, () -> history(1), this::myPage};
        for (int i = 0; i < ids.length; i++) {
            boolean active = ids[i].equals(selectedTab);
            int color = active ? INK : MUTED;
            LinearLayout tab = style.column();
            tab.setGravity(Gravity.CENTER);
            tab.setContentDescription(titles[i]);
            tab.setSelected(active);
            tab.setFocusable(true);
            tab.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_YES);
            style.actionSurface(tab, WHITE, 12, false);
            tab.addView(style.glyph(ids[i], color), dp(22), dp(22));
            TextView name = style.text(titles[i], 11, color, active ? 600 : 400);
            name.setGravity(Gravity.CENTER);
            name.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
            name.setPadding(0, dp(4), 0, 0);
            tab.addView(name);
            Runnable callback = callbacks[i];
            tab.setOnClickListener(view -> { if (!active && !busy) callback.run(); });
            row.addView(tab, new LinearLayout.LayoutParams(0, dp(57), 1));
        }
        root.addView(bar);
    }

    private CheckBox check(String title) {
        CheckBox box = new CheckBox(this);
        style.type(box, 15, INK, 400);
        box.setText(title);
        box.setMinHeight(dp(48));
        page.addView(box);
        return box;
    }

    private EditText field(String hint, int type) {
        EditText e = new EditText(this);
        e.setHint(hint); e.setSingleLine(true); e.setInputType(type);
        style.type(e, 16, INK, 400);
        e.setHintTextColor(MUTED);
        e.setMinHeight(dp(54));
        e.setBackground(style.surface(FIELD, 16, false));
        e.setPadding(dp(16), dp(12), dp(16), dp(12));
        e.setSaveEnabled(false);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.bottomMargin = dp(8);
        page.addView(e, lp);
        return e;
    }
    private void notice(String message) {
        new AlertDialog.Builder(this).setMessage(message).setPositiveButton("확인", null).show();
    }
    private <T> void task(Callable<T> job, Consumer<T> result) { task(job, result, null); }
    private <T> void task(Callable<T> job, Consumer<T> result, Runnable retry) {
        if (busy) return;
        busy = true; int owner = version;
        LinearLayout ownerPage = page;
        ProgressBar progress = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        progress.setIndeterminate(true);
        progress.setIndeterminateTintList(android.content.res.ColorStateList.valueOf(INK));
        if (!"report".equals(screen) || retry == null)
            ownerPage.addView(progress, 0, new LinearLayout.LayoutParams(-1, dp(4)));
        worker.submit(() -> {
            try {
                T value = job.call();
                main.post(() -> {
                    if (owner != version || isDestroyed()) return;
                    busy = false; ownerPage.removeView(progress); result.accept(value);
                });
            } catch (Exception ex) {
                main.post(() -> {
                    if (owner != version || isDestroyed()) return;
                    busy = false; ownerPage.removeView(progress);
                    boolean expired = ex instanceof SpringClient.Failure && ((SpringClient.Failure) ex).status == 401;
                    if (expired && !"login".equals(screen)) { reset(); auth(false); }
                    String message = ex instanceof SpringClient.Failure || ex instanceof IllegalArgumentException
                            ? ex.getMessage() : "요청을 완료하지 못했어요. 서버 연결이나 사진을 확인해 주세요.";
                    if (retry != null && !expired)
                        new AlertDialog.Builder(this).setMessage(message).setPositiveButton("다시 조회", (d,w) -> retry.run())
                                .setNegativeButton("이력으로", (d,w) -> history(1)).show();
                    else if ("optional".equals(screen) && ex instanceof java.io.IOException && !(ex instanceof SpringClient.Failure))
                        new AlertDialog.Builder(this).setMessage("접수 응답을 받지 못했어요. 다시 보내기 전에 이력에서 접수 여부를 확인해 주세요.")
                                .setPositiveButton("지난 분석 보기",(dialog,which)->history(1)).setNegativeButton("닫기",null).show();
                    else notice(message);
                });
            }
        });
    }
    private void auth(boolean signup) {
        page(signup ? "signup" : "login", null);
        if (signup) {
            toolbar("", () -> auth(false), "로그인으로", null);
            hero("계정을 만들어요.", "분석 결과와 추천을 기록으로 모아 볼 수 있어요.");
            text("이메일", 14, true);
        } else {
            page.addView(new View(this), new LinearLayout.LayoutParams(-1, dp(12), 1));
            ImageView brand = style.brand(72);
            LinearLayout.LayoutParams logo = new LinearLayout.LayoutParams(dp(72), dp(72));
            logo.gravity = Gravity.CENTER_HORIZONTAL;
            logo.bottomMargin = dp(23);
            page.addView(brand, logo);
            label(page, "피부 사진으로 시작해요.", 28, INK, 700, 0, 10).setGravity(Gravity.CENTER);
            label(page, "사진 한 장으로 피부 이미지를 분류하고\n맞는 성분과 관리법을 추천해요.",
                    17, MUTED, 300, 0, 34).setGravity(Gravity.CENTER);
        }
        EditText mail = field("이메일", InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_EMAIL_ADDRESS);
        if (signup) text("비밀번호", 14, true);
        EditText pass = field("비밀번호", InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
        if (signup) {
            label(page, "영문·숫자·특수문자 중 2종 이상, 8~64자", 12, MUTED, 400, 0, 8);
            text("닉네임", 14, true);
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
        } else {
            Button login = button("로그인", true, () -> {
                String email = mail.getText().toString().trim(), password = pass.getText().toString();
                task(() -> api.login(email, password), session -> signedIn(email, session.optJSONObject("user")));
            });
            LinearLayout links = style.row();
            links.setGravity(Gravity.CENTER);
            links.addView(style.text("처음이신가요?", 14, MUTED, 400));
            Button signupLink = link("회원가입", () -> auth(true));
            signupLink.setTextColor(INK);
            signupLink.setPaintFlags(signupLink.getPaintFlags() | android.graphics.Paint.UNDERLINE_TEXT_FLAG);
            links.addView(signupLink);
            page.addView(links);
            page.addView(new View(this), new LinearLayout.LayoutParams(-1, dp(18), 1));
            label(page, "사진은 분석에만 쓰고 저장하지 않아요.", 12, MUTED, 400, 0, 4).setGravity(Gravity.CENTER);
            if (canChooseServer()) {
                Button settings = link("서버 연결 설정", this::serverSettings);
                LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(-2, -2);
                p.gravity = Gravity.CENTER;
                page.addView(settings, p);
            }
            android.text.TextWatcher formState = new android.text.TextWatcher() {
                @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
                @Override public void onTextChanged(CharSequence s, int start, int before, int count) {
                    style.primary(login, !mail.getText().toString().trim().isEmpty() && pass.length() > 0);
                }
                @Override public void afterTextChanged(android.text.Editable edit) {}
            };
            mail.addTextChangedListener(formState);
            pass.addTextChangedListener(formState);
            style.primary(login, false);
        }
    }

    private Button link(String title, Runnable callback) {
        Button action = style.button(title, 48);
        style.type(action, 14, BLUE, 600);
        style.actionSurface(action, WHITE, 16, false);
        action.setOnClickListener(v -> { if (!busy) callback.run(); });
        return action;
    }

    private void home() {
        page("home", null);
        LinearLayout heading = style.row();
        TextView title = style.text("홈", 30, INK, 700);
        heading.addView(title, new LinearLayout.LayoutParams(0, -2, 1));
        heading.addView(style.brand(32), dp(32), dp(32));
        page.addView(heading, -1, dp(47));
        String date = LocalDate.now().format(DateTimeFormatter.ofPattern("M월 d일 EEEE", Locale.KOREAN));
        label(page, date, 14, MUTED, 400, 15, 6);
        String greeting = nickname.isEmpty() ? "오늘 피부는 어떤가요." : nickname + "님, 오늘 피부는 어떤가요.";
        label(page, greeting, 24, INK, 700, 0, 20);
        LinearLayout start = card(page, false, 20);
        View symbol = style.glyph("camera", INK);
        symbol.setPadding(dp(12), dp(12), dp(12), dp(12));
        symbol.setBackground(style.surface(WHITE, 24, false));
        start.addView(symbol, dp(46), dp(46));
        label(start, "사진 한 장이면 충분해요.", 24, INK, 700, 14, 5);
        label(start, "정면 또는 측면 사진과 간단한 설문으로 피부 이미지를\n분류하고 맞는 성분을 추천해요.",
                14, MUTED, 400, 0, 12);
        addAction(start, "피부 분석 시작", true, this::startCapture);
        if (userId > 0) button("매일 피부 기록", false, this::diary);

        LinearLayout recentHeader = style.row();
        recentHeader.addView(style.text("최근 결과", 20, INK, 700), new LinearLayout.LayoutParams(0, -2, 1));
        recentHeader.addView(link("전체 보기", () -> history(1)));
        page.addView(recentHeader);
        LinearLayout recent = style.column();
        page.addView(recent);
        LinearLayout placeholder = card(recent, true, 17);
        label(placeholder, "최근 분석 결과를 불러오고 있어요.", 14, MUTED, 400, 2, 2);
        label(page, "이렇게 분석해요", 20, INK, 700, 13, 12);
        LinearLayout guide = card(page, true, 14);
        infoRow(guide, "camera", "사진 촬영", "정면이나 한쪽 볼이 보이는 사진을 준비해 주세요.");
        separator(guide);
        infoRow(guide, "scan", "피부 이미지 분류", "정상 포함 여섯 가지 유형의 분류 점수를 확인해요.");
        separator(guide);
        infoRow(guide, "list", "맞춤 성분 추천", "설문과 분석 결과를 바탕으로 관리법을 추천해요.");
        tabs("home");
        final int owner = version;
        worker.submit(() -> {
            JSONObject response;
            try { response = api.history(1); } catch (Exception unavailable) { response = null; }
            JSONObject result = response;
            main.post(() -> {
                if (owner != version || isDestroyed()) return;
                recent.removeAllViews();
                JSONArray entries = result == null ? null : result.optJSONArray("items");
                JSONObject item = entries == null ? null : entries.optJSONObject(0);
                if (item == null) {
                    label(card(recent, true, 17), result == null ? "최근 결과는 이력에서 다시 확인해 주세요."
                            : "아직 분석 결과가 없어요.", 14, MUTED, 400, 2, 2);
                } else historyRow(recent, item, "home");
            });
        });
    }

    void signedIn(String address, JSONObject user) {
        email = address;
        nickname = user == null ? "" : user.optString("nickname");
        userId = user == null ? 0 : user.optLong("id");
        home();
    }

    android.content.SharedPreferences journal() {
        if (userId <= 0) throw new IllegalStateException("로그인 후 기록할 수 있어요.");
        String account = android.util.Base64.encodeToString(server.getBytes(java.nio.charset.StandardCharsets.UTF_8),
                android.util.Base64.URL_SAFE | android.util.Base64.NO_WRAP);
        return getSharedPreferences("diary-" + account + "-" + userId, MODE_PRIVATE);
    }

    private void diary() {
        page("diary", null);
        toolbar("매일 피부 기록", this::home, "홈", null);
        LocalDate today = LocalDate.now();
        var prefs = journal();
        var entries = new java.util.TreeMap<String, JSONObject>(java.util.Comparator.reverseOrder());
        for (var item : prefs.getAll().entrySet()) {
            try { entries.put(item.getKey(), new JSONObject((String) item.getValue())); }
            catch (org.json.JSONException ignored) { /* Skip an unreadable entry. */ }
        }
        JSONObject saved = entries.get(today.toString());
        hero("오늘 피부는 얼마나 편안했나요?", "0점은 매우 불편, 10점은 매우 편안이에요. 매일 비슷한 시간에 직접 기록해 보세요.");
        String[] scores = new String[12];
        scores[0] = "오늘의 점수 선택";
        for (int i = 0; i <= 10; i++) scores[i + 1] = i + "점";
        Spinner score = new Spinner(this);
        var choices = new ArrayAdapter<>(this, android.R.layout.simple_spinner_dropdown_item, scores);
        score.setAdapter(choices);
        score.setContentDescription("오늘의 피부 편안함 점수");
        score.setSelection(saved == null ? 0 : saved.optInt("score") + 1);
        page.addView(score, -1, dp(50));
        EditText product = field("오늘 쓴 제품 (선택)", InputType.TYPE_CLASS_TEXT);
        product.setFilters(new android.text.InputFilter[]{new android.text.InputFilter.LengthFilter(100)});
        if (saved != null) product.setText(saved.optString("product"));
        button(saved == null ? "오늘 기록 저장" : "오늘 기록 수정", true, () -> {
            if (!today.equals(LocalDate.now())) { diary(); notice("날짜가 바뀌었어요. 오늘 기록을 확인해 주세요."); return; }
            int selected = score.getSelectedItemPosition() - 1;
            if (selected < 0) { notice("오늘 느낀 점수를 선택해 주세요."); return; }
            JSONObject entry = new JSONObject();
            put(entry, "score", selected); put(entry, "product", product.getText().toString().trim());
            prefs.edit().putString(today.toString(), entry.toString()).apply(); diary();
        });
        label(page, "날짜별 변화", 20, INK, 700, 15, 3);
        label(page, "점수는 내가 느낀 편안함이에요. 이 기기의 내 계정에 저장됩니다.", 14, MUTED, 400, 0, 9);
        if (entries.isEmpty()) label(page, "첫 기록부터 날짜별로 쌓여요.", 15, MUTED, 400, 6, 10);
        for (var item : entries.entrySet()) {
            JSONObject entry = item.getValue();
            var previous = entries.higherEntry(item.getKey());
            int points = entry.optInt("score");
            String change = "첫 기록";
            if (previous != null) {
                int diff = points - previous.getValue().optInt("score");
                change = previous.getKey() + " 대비 " + (diff == 0 ? "같음" : Math.abs(diff) + "점 " + (diff > 0 ? "상승" : "하락"));
            }
            LinearLayout row = card(page, true, 12);
            label(row, item.getKey() + "   " + points + "/10", 17, INK, 600, 0, 2);
            meter(row, points / 10.0);
            label(row, change, 14, MUTED, 400, 0, 2);
            if (!entry.optString("product").isEmpty()) label(row, "사용 제품 · " + entry.optString("product"), 14, INK, 400, 1, 0);
            row.addView(link("기록 삭제", () -> new AlertDialog.Builder(this).setMessage(item.getKey() + " 기록을 지울까요?")
                    .setNegativeButton("취소", null).setPositiveButton("삭제", (dialog, which) -> {
                        prefs.edit().remove(item.getKey()).apply(); diary();
                    }).show()));
        }
    }

    private void infoRow(LinearLayout owner, String icon, String title, String detail) {
        LinearLayout row = style.row();
        row.setPadding(0, dp(10), 0, dp(10));
        row.addView(iconBadge(icon, SOFT, 44), dp(44), dp(44));
        LinearLayout words = style.column();
        words.setPadding(dp(12), 0, 0, 0);
        label(words, title, 16, INK, 600, 0, 4);
        label(words, detail, 13, MUTED, 400, 0, 0);
        row.addView(words, new LinearLayout.LayoutParams(0, -2, 1));
        owner.addView(row, -1, -2);
    }

    private View iconBadge(String icon, int background, int size) {
        View badge = style.glyph(icon, INK);
        int inset = dp((size - 22) / 2);
        badge.setPadding(inset, inset, inset, inset);
        badge.setBackground(style.surface(background, size / 2, false));
        return badge;
    }

    private void myPage() {
        page("my", "마이");
        LinearLayout profile = style.row();
        String initial = nickname.trim().isEmpty() ? "" : nickname.substring(0, nickname.offsetByCodePoints(0, 1));
        TextView avatar = style.text(initial, 24, WHITE, 700);
        avatar.setGravity(Gravity.CENTER);
        avatar.setBackground(style.surface(INK, 28, false));
        avatar.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        profile.addView(avatar, dp(56), dp(56));
        LinearLayout nameAndEmail = style.column();
        nameAndEmail.setPadding(dp(13), 0, 0, 0);
        label(nameAndEmail, initial.isEmpty() ? "내 계정" : nickname + "님", 24, INK, 700, 0, 6);
        label(nameAndEmail, email, 14, MUTED, 400, 0, 0);
        profile.addView(nameAndEmail, new LinearLayout.LayoutParams(0, -2, 1));
        LinearLayout.LayoutParams profilePosition = new LinearLayout.LayoutParams(-1, -2);
        profilePosition.bottomMargin = dp(24);
        page.addView(profile, profilePosition);
        LinearLayout stats = style.row();
        card(page, false, 15).addView(stats, -1, -2);
        TextView count = profileStat(stats, "누적 분석");
        View divider = new View(this);
        divider.setBackgroundColor(LINE);
        stats.addView(divider, dp(1), dp(32));
        TextView since = profileStat(stats, "함께한 날");
        label(page, "설정", 20, INK, 700, 12, 3);
        LinearLayout menu = card(page, true, 14);
        label(menu, "개인정보 처리방침   ·   준비 중", 14, MUTED, 400, 9, 10);
        separator(menu);
        LinearLayout body = page;
        page = menu;
        CheckBox hide = check("촬영 가이드 건너뛰기");
        hide.setChecked(getPreferences(MODE_PRIVATE).getBoolean("hideGuide", false));
        hide.setOnCheckedChangeListener((button, checked) ->
                getPreferences(MODE_PRIVATE).edit().putBoolean("hideGuide", checked).apply());
        page = body;
        separator(menu);
        profileAction(menu, "로그아웃", INK, () -> new AlertDialog.Builder(this).setMessage("로그아웃할까요?")
                .setNegativeButton("취소", null).setPositiveButton("로그아웃", (dialog, which) -> task(() -> {
                    try { api.logout(); return true; } catch (Exception ex) { return false; }
                }, ok -> { reset(); auth(false); if (!ok) notice("이 기기에서 로그아웃했어요. 서버 세션 종료는 확인하지 못했어요."); }))
                .show());
        separator(menu);
        profileAction(menu, "회원 탈퇴", NEGATIVE, () -> new AlertDialog.Builder(this)
                .setMessage("계정과 저장한 분석 이력을 모두 삭제할까요? 삭제 후 복구할 수 없어요.")
                .setNegativeButton("취소", null).setPositiveButton("계정 삭제", (dialog, which) ->
                    task(() -> { api.deleteAccount(); return true; }, ok -> { if (userId > 0) journal().edit().clear().apply(); reset(); auth(false); })).show());
        label(page, "스킨케어 " + BuildConfig.VERSION_NAME, 12, MUTED, 400, 0, 4).setGravity(Gravity.CENTER);
        tabs("my");
        int owner = version;
        worker.submit(() -> {
            try {
                JSONObject account = api.me();
                main.post(() -> {
                    if (version != owner || isDestroyed()) return;
                    if (account.has("analysisCount")) count.setText(account.optInt("analysisCount") + "회");
                    String created = account.optString("createdAt");
                    if (created.length() >= 10) since.setText(created.substring(0, 10));
                });
            } catch (Exception unavailable) { /* Account totals can remain unavailable. */ }
        });
    }

    private TextView profileStat(LinearLayout row, String title) {
        LinearLayout column = style.column();
        TextView value = label(column, "—", 16, INK, 600, 2, 4);
        value.setGravity(Gravity.CENTER);
        label(column, title, 12, MUTED, 400, 0, 0).setGravity(Gravity.CENTER);
        row.addView(column, new LinearLayout.LayoutParams(0, -2, 1));
        return value;
    }

    private void profileAction(LinearLayout menu, String title, int color, Runnable click) {
        Button row = style.button(title, 48);
        style.type(row, 15, color, 500);
        row.setGravity(Gravity.CENTER_VERTICAL | Gravity.START);
        row.setPadding(0, 0, 0, 0);
        style.actionSurface(row, WHITE, 10, false);
        row.setOnClickListener(v -> { if (!busy) click.run(); });
        menu.addView(row, -1, -2);
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
            server=url; dialog.dismiss(); connect();
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
    private void startCapture() {
        clearCapture();
        rear = false;
        side = false;
        if (getPreferences(MODE_PRIVATE).getBoolean("hideGuide", false)) capture();
        else guide();
    }

    private void closeCapture() { clearCapture(); home(); }

    private void guide() {
        page("guide", null);
        toolbar("", null, "", this::closeCapture);
        hero("이렇게 찍어 주세요.", "정확한 분석을 위한 네 가지예요.");
        LinearLayout rules = card(page, true, 14);
        infoRow(rules, "scan", "정면·측면을 선택해 주세요", "측면은 얼굴 전체 윤곽과 한쪽 볼이 보이게 찍어요.");
        separator(rules);
        infoRow(rules, "sun", "자연광에서 찍어 주세요", "그늘이나 역광을 피하고 밝은 곳에서 찍어요.");
        separator(rules);
        infoRow(rules, "glasses", "화장과 안경은 벗어 주세요", "맨얼굴일 때 더 정확하게 분석돼요.");
        separator(rules);
        infoRow(rules, "comb", "앞머리를 넘겨 주세요", "이마가 가려지지 않게 정리해요.");
        CheckBox hide = check("다음부터 보지 않기");
        footer("촬영 화면으로", () -> {
            getPreferences(MODE_PRIVATE).edit().putBoolean("hideGuide", hide.isChecked()).apply();
            capture();
        });
    }

    private void stepIndicator(boolean survey) {
        LinearLayout steps = style.row();
        steps.setContentDescription(survey ? "2단계 중 2단계, 설문" : "2단계 중 1단계, 촬영");
        for (int i = 0; i < 2; i++) {
            View bar = new View(this);
            bar.setBackground(style.surface(i == 0 || survey ? INK : SOFT, 4, false));
            LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(0, dp(4), 1);
            if (i == 0) p.rightMargin = dp(8);
            steps.addView(bar, p);
        }
        LinearLayout.LayoutParams p = new LinearLayout.LayoutParams(-1, dp(4));
        p.bottomMargin = dp(14);
        page.addView(steps, p);
    }

    private void capture() {
        page("capture", null);
        boolean showGuide = !getPreferences(MODE_PRIVATE).getBoolean("hideGuide", false);
        toolbar("", showGuide ? this::guide : null, "촬영 가이드", this::closeCapture);
        stepIndicator(false);
        hero("얼굴 사진을 준비해 주세요.", photo == null
                ? "촬영 각도를 고른 뒤 사진 한 장을 준비해 주세요." : "이 사진으로 분석할게요.");
        segment(page, "정면", "측면", side, value -> {
            if (side != value) { side = value; photo = null; capture(); }
        });

        FrameLayout preview = new FrameLayout(this) {
            @Override protected void onMeasure(int width, int height) {
                int h = Math.min(dp(480), Math.round(View.MeasureSpec.getSize(width) * 1.25f));
                super.onMeasure(width, View.MeasureSpec.makeMeasureSpec(h, View.MeasureSpec.EXACTLY));
            }
        };
        preview.setBackground(style.surface(SOFT, 16, false));
        preview.setClipToOutline(true);
        if (photo == null) preview.addView(style.faceGuide(), -1, -1);
        else {
            ImageView picture = new ImageView(this);
            picture.setImageBitmap(photo.preview);
            picture.setContentDescription("선택한 얼굴 사진 미리보기");
            picture.setScaleType(ImageView.ScaleType.CENTER_CROP);
            preview.addView(picture, -1, -1);
        }
        page.addView(preview, -1, -2);
        segment(page, "셀프 촬영", "다른 사람이 촬영", rear, value -> rear = value);
        label(page, side ? "한쪽 볼과 코 윤곽이 보이게 30~60도 돌려 주세요. 측면 분류는 시험 기능이며 실제 환자에서 정확도 검증이 필요해요." : "눈높이에서 양쪽 볼이 보이게 정면을 찍어 주세요.",
                14, MUTED, 400, 1, 12);
        LinearLayout sources = style.row();
        pair(sources, action(photo == null ? "촬영하기" : "다시 찍기", false, () -> camera(rear)),
                action(photo == null ? "앨범에서 선택" : "다른 사진", false, this::pickPhoto), 8);
        page.addView(sources);
        style.primary(footer("다음", this::enterSurvey), photo != null);
    }

    private void enterSurvey() {
        task(() -> {
            if (side) api.requireSideModel();
            if (loadedDefaults) return null;
            try {
                JSONObject recent = api.history(1).getJSONArray("items").optJSONObject(0);
                return recent == null ? null : api.detail(recent.getString("analysisId")).optJSONObject("survey");
            } catch (SpringClient.Failure e) {
                if (e.status == 401) throw e;
                return null;
            } catch (Exception unavailable) { return null; }
        }, previous -> {
            if (previous != null) applyDefaults(previous);
            loadedDefaults = true;
            survey();
        });
    }

    private void applyDefaults(JSONObject previous) {
        copyChoice(previous, "gender", "male", "female");
        copyChoice(previous, "ageBand", "10s", "20s", "30s", "40s", "50s", "60s", "70s");
        copyChoice(previous, "skinType", "dry", "normal", "oily", "combination");
        for (String key : new String[]{"stressLevel", "sunExposureLevel", "waterIntakeLevel"})
            copyChoice(previous, key, "low", "medium", "high");
        JSONArray concerns = previous.optJSONArray("concerns");
        JSONArray known = new JSONArray();
        List<String> allowed = java.util.Arrays.asList("pigmentation","pore","wrinkle","acne","redness","dryness","sagging","sensitivity");
        for (int i=0; concerns != null && i<concerns.length() && known.length()<3; i++)
            if (allowed.contains(concerns.optString(i))) known.put(concerns.optString(i));
        if (known.length()>0) put(draft, "concerns", known);
        int hours = previous.optInt("sleepHours", -1);
        if (hours >= 0 && hours <= 14) draftText.put("sleep", String.valueOf(hours));
        if (!previous.isNull("note")) draftText.put("note", previous.optString("note"));
        for (String key : new String[]{"currentProducts","avoidIngredients"}) {
            JSONArray items = previous.optJSONArray(key);
            if (items != null && items.length()>0) {
                put(draft, key, items);
                draftText.put(key.equals("currentProducts") ? "products" : "avoid", listText(items));
            }
        }
    }

    private void copyChoice(JSONObject previous, String key, String... allowed) {
        String value = previous.optString(key);
        if (java.util.Arrays.asList(allowed).contains(value)) put(draft, key, value);
    }
    private static String listText(JSONArray items) {
        List<String> names = new ArrayList<>();
        for (int i = 0; i < items.length(); i++) names.add(items.optString(i));
        return String.join(", ", names);
    }

    private void pickPhoto() {
        if (android.os.Build.VERSION.SDK_INT >= 33) {
            try {
                startActivityForResult(new Intent(MediaStore.ACTION_PICK_IMAGES).setType("image/*"), 20);
                return;
            } catch (android.content.ActivityNotFoundException unavailable) {
                // Android builds without the system photo picker can still select a document.
            }
        }
        Intent pick = new Intent(Intent.ACTION_OPEN_DOCUMENT).setType("image/*").addCategory(Intent.CATEGORY_OPENABLE);
        startActivityForResult(pick, 20);
    }

    private void pair(LinearLayout row, View left, View right, int gap) {
        LinearLayout.LayoutParams l = new LinearLayout.LayoutParams(0, -2, 1);
        l.rightMargin = dp(gap);
        row.addView(left, l);
        row.addView(right, new LinearLayout.LayoutParams(0, -2, 1));
    }

    private void segment(LinearLayout owner, String first, String second, boolean right, Consumer<Boolean> onChange) {
        LinearLayout row = style.row();
        row.setPadding(dp(3), dp(3), dp(3), dp(3));
        row.setBackground(style.surface(FIELD, 12, false));
        LinearLayout.LayoutParams placement = new LinearLayout.LayoutParams(-1, -2);
        placement.setMargins(0, dp(12), 0, dp(8));
        owner.addView(row, placement);
        Button left = style.button(first, 44), rightButton = style.button(second, 44);
        Consumer<Boolean> update = selected -> {
            switchTab(left, !selected);
            switchTab(rightButton, selected);
        };
        pair(row, left, rightButton, 3);
        update.accept(right);
        left.setOnClickListener(v -> { if (!busy) { update.accept(false); onChange.accept(false); } });
        rightButton.setOnClickListener(v -> { if (!busy) { update.accept(true); onChange.accept(true); } });
    }

    private void switchTab(Button button, boolean selected) {
        style.type(button, 14, INK, selected ? 600 : 400);
        style.actionSurface(button, selected ? WHITE : FIELD, 10, false);
        button.setSelected(selected);
    }

    private void clearCapture() {
        photo = null;
        loadedDefaults = false;
        draft = new JSONObject();
        draftText.clear();
    }

    private void reset() { clearCapture(); nickname = ""; email = ""; userId = 0; }
    private void camera(boolean rearLens) {
        rear = rearLens;
        if (checkSelfPermission(Manifest.permission.CAMERA) != PackageManager.PERMISSION_GRANTED) {
            requestPermissions(new String[]{Manifest.permission.CAMERA}, 21); return;
        }
        camera = new CaptureDialog(this, rear, side, bytes -> decode(ImageDecoder.createSource(ByteBuffer.wrap(bytes))), this::notice);
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
        boolean sideView = side;
        task(() -> {
            Photo selected=Photo.decode(source);
            if (sideView) selected.requireSideFace(); else selected.requireOneFace();
            return selected;
        }, selected -> { photo = selected; capture(); });
    }
    private static void put(JSONObject o, String key, Object value) {
        try { o.put(key, value); } catch (org.json.JSONException e) { throw new IllegalArgumentException(key, e); }
    }
    private void question(String title, boolean required) {
        LinearLayout row = style.row();
        row.addView(style.text(title, 16, INK, 600), new LinearLayout.LayoutParams(0, -2, 1));
        if (required) row.addView(style.text("필수", 12, MUTED, 500));
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
        lp.setMargins(0, dp(11), 0, dp(8));
        page.addView(row, lp);
    }

    private Button chip(String title) {
        Button chip = style.button(title, 44);
        chip.setPadding(dp(4), dp(6), dp(4), dp(6));
        return chip;
    }

    private void selectChip(Button chip, boolean selected) {
        style.type(chip, 14, selected ? WHITE : INK, selected ? 600 : 400);
        style.actionSurface(chip, selected ? INK : WHITE, 24, !selected);
        chip.setSelected(selected);
    }

    private void placeChips(List<Button> chips, int columns) {
        for (int i = 0; i < chips.size(); i += columns) {
            LinearLayout row = style.row();
            for (int j = 0; j < columns; j++) {
                boolean hasChip = i + j < chips.size();
                LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, hasChip ? -2 : 0, 1);
                if (j < columns - 1) lp.rightMargin = dp(7);
                row.addView(hasChip ? chips.get(i + j) : new View(this), lp);
            }
            LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, -2);
            lp.bottomMargin = dp(8);
            page.addView(row, lp);
        }
    }

    private void choices(JSONObject target, String key, String title, boolean required, int columns,
                         String[] labels, Object[] values, Runnable changed) {
        question(title, required);
        List<Button> chips = new ArrayList<>();
        for (int i = 0; i < labels.length; i++) {
            Button chip = chip(labels[i]);
            Object value = values[i];
            selectChip(chip, java.util.Objects.equals(target.opt(key), value));
            chips.add(chip);
            chip.setOnClickListener(view -> {
                if (busy) return;
                if (value == null || (!required && chip.isSelected())) target.remove(key);
                else put(target, key, value);
                for (int j = 0; j < chips.size(); j++)
                    selectChip(chips.get(j), java.util.Objects.equals(target.opt(key), values[j]));
                if (changed != null) changed.run();
            });
        }
        placeChips(chips, columns);
    }

    private void multi(JSONObject target, String key, String title, String note, int columns, int limit,
                       String[] labels, String[] codes) {
        question(title, false);
        if (note != null) label(page, note, 13, MUTED, 400, 0, 8);
        List<Button> chips = new ArrayList<>();
        JSONArray saved = target.optJSONArray(key);
        for (int i = 0; i < labels.length; i++) {
            Button chip = chip(labels[i]);
            for (int j = 0; saved != null && j < saved.length(); j++) {
                if (codes[i].equals(saved.optString(j))) { chip.setSelected(true); break; }
            }
            selectChip(chip, chip.isSelected());
            chips.add(chip);
            chip.setOnClickListener(view -> {
                if (busy) return;
                boolean wasSelected = chip.isSelected();
                JSONArray selection = new JSONArray();
                for (int j = 0; j < chips.size(); j++) {
                    Button candidate = chips.get(j);
                    if (candidate == chip ? !wasSelected : candidate.isSelected()) selection.put(codes[j]);
                }
                if (selection.length() > limit) { notice("고민은 최대 3개까지 선택할 수 있어요."); return; }
                selectChip(chip, !wasSelected);
                if (selection.length() == 0) target.remove(key);
                else put(target, key, selection);
            });
        }
        placeChips(chips, columns);
    }

    private void survey() {
        page("survey", null);
        toolbar("", this::capture, "사진으로 돌아가기", this::closeCapture);
        stepIndicator(true);
        hero("기본 정보를 알려 주세요.", "추천 성분을 고르는 데 쓰여요.");
        Button next = footer("다음", this::optionalSurvey);
        Runnable update = () -> style.primary(next, draft.has("gender") && draft.has("ageBand"));
        choices(draft, "gender", "성별", true, 2, new String[]{"여성", "남성"},
                new Object[]{"female", "male"}, update);
        choices(draft, "ageBand", "연령대", true, 4, new String[]{"10대","20대","30대","40대","50대","60대","70대"},
                new Object[]{"10s","20s","30s","40s","50s","60s","70s"}, update);
        choices(draft, "skinType", "피부 타입", false, 3, new String[]{"건성","중성","지성","복합성","잘 모르겠어요"},
                new Object[]{"dry","normal","oily","combination",null}, update);
        update.run();
    }

    private EditText draftField(String key, String title, String hint, int type) {
        question(title, false);
        EditText field = field(hint, type);
        field.setText(draftText.getOrDefault(key, ""));
        field.addTextChangedListener(new android.text.TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int start, int count, int after) {}
            @Override public void onTextChanged(CharSequence s, int start, int before, int count) {
                draftText.put(key, s.toString());
            }
            @Override public void afterTextChanged(android.text.Editable edit) {}
        });
        return field;
    }

    private void optionalSurvey() {
        page("optional", null);
        toolbar("", this::survey, "이전 단계", this::closeCapture);
        stepIndicator(true);
        hero("피부 상태와 생활 습관", "모두 선택 사항이에요. 답하지 않아도 분석할 수 있어요.");
        label(page, "최근 피부 상태", 20, INK, 700, 2, 3);
        label(page, "이번 촬영의 자가 응답으로 기록해요. 현재 이미지 분류에는 사진만 사용해요.",
                14, MUTED, 400, 0, 9);
        JSONObject symptoms = draft.optJSONObject("symptomProfile");
        if (symptoms == null) {
            symptoms = new JSONObject();
            put(draft, "symptomProfile", symptoms);
        }
        choices(symptoms, "itch", "가려움", false, 3, new String[]{"없음","가끔","자주"},
                new Object[]{"none","occasional","frequent"}, null);
        choices(symptoms, "flaking", "각질", false, 4, new String[]{"없음","건조함","기름짐","둘 다"},
                new Object[]{"none","dry","greasy","both"}, null);
        choices(symptoms, "recurringRedness", "반복되는 붉은기", false, 2, new String[]{"아니요","예"},
                new Object[]{false,true}, null);
        choices(symptoms, "visiblePlugs", "눈에 보이는 면포", false, 2, new String[]{"아니요","예"},
                new Object[]{false,true}, null);
        choices(symptoms, "onset", "처음 알아차린 시점", false, 3, new String[]{"1주 미만","1~4주","4주 넘음"},
                new Object[]{"under_one_week","one_to_four_weeks","over_four_weeks"}, null);
        multi(symptoms, "areas", "신경 쓰이는 부위", null, 3, 6,
                new String[]{"이마","머리카락 경계·두피","눈썹 주변","코 주변","볼","턱"},
                new String[]{"forehead","hairline_scalp","eyebrows","around_nose","cheeks","jaw_chin"});
        label(page, "생활 습관", 20, INK, 700, 13, 3);
        EditText hours = draftField("sleep", "하루 수면 시간", "0~14시간", InputType.TYPE_CLASS_NUMBER);
        Object[] levels = {"low","medium","high"};
        choices(draft, "waterIntakeLevel", "물 섭취량", false, 3, new String[]{"적음","보통","많음"}, levels, null);
        choices(draft, "sunExposureLevel", "햇빛 노출", false, 3, new String[]{"낮음","보통","높음"}, levels, null);
        choices(draft, "stressLevel", "스트레스", false, 3, new String[]{"낮음","보통","높음"}, levels, null);
        multi(draft, "concerns", "피부 고민", "최대 3개 · 정상으로 분류되면 여기서 고른 고민을 바탕으로 추천해요.", 3, 3,
                new String[]{"피부 톤·잡티","모공","주름","트러블","붉은기","건조·각질","탄력","민감함"},
                new String[]{"pigmentation","pore","wrinkle","acne","redness","dryness","sagging","sensitivity"});
        EditText avoid = draftField("avoid", "피하고 싶은 성분", "쉼표로 구분", InputType.TYPE_CLASS_TEXT);
        EditText products = draftField("products", "사용 중인 제품", "최대 5개 · 쉼표로 구분", InputType.TYPE_CLASS_TEXT);
        EditText note = draftField("note", "추가로 알려 주실 내용", "예: 여름에 번들거림이 심해요", InputType.TYPE_CLASS_TEXT);
        footer("분석 시작", () -> submit(avoid, hours, products, note));
    }

    private JSONArray commaSeparated(EditText input, String key, int count, int length, String error) {
        JSONArray previous = draft.optJSONArray(key);
        if (previous != null && listText(previous).contentEquals(input.getText())) return previous;
        JSONArray result = new JSONArray();
        for (String part : input.getText().toString().split(",")) {
            String item = part.trim();
            if (item.isEmpty()) continue;
            if (item.length() > length || result.length() >= count) throw new IllegalArgumentException(error);
            result.put(item);
        }
        return result;
    }

    private void submit(EditText avoid, EditText hours, EditText products, EditText note) {
        if (photo == null || !draft.has("gender") || !draft.has("ageBand")) return;
        JSONObject answer;
        try {
            answer = new JSONObject(draft.toString());
            put(answer, "captureView", side ? "side" : "front");
            JSONObject symptoms = answer.optJSONObject("symptomProfile");
            if (symptoms != null && symptoms.length() == 0) answer.remove("symptomProfile");
            answer.remove("avoidIngredients");
            JSONArray exclusions = commaSeparated(avoid, "avoidIngredients", 30, 100, "회피 성분은 30개까지, 이름은 100자 이내로 입력해 주세요.");
            if (exclusions.length() > 0) put(answer, "avoidIngredients", exclusions);
            String sleep = hours.getText().toString().trim();
            if (!sleep.isEmpty()) {
                if (!sleep.matches("[0-9]{1,2}") || Integer.parseInt(sleep) > 14)
                    throw new IllegalArgumentException("수면 시간은 0~14시간으로 입력해 주세요.");
                put(answer, "sleepHours", Integer.parseInt(sleep));
            }
            answer.remove("currentProducts");
            JSONArray used = commaSeparated(products, "currentProducts", 5, 30, "제품은 5개까지, 이름은 30자 이내로 입력해 주세요.");
            if (used.length() > 0) put(answer, "currentProducts", used);
            String extra = note.getText().toString().trim();
            if (extra.length() > 300) throw new IllegalArgumentException("추가 내용은 300자 이내로 입력해 주세요.");
            if (!extra.isEmpty()) put(answer, "note", extra);
        } catch (IllegalArgumentException | org.json.JSONException invalid) {
            notice(invalid.getMessage());
            return;
        }
        byte[] jpeg = photo.jpeg;
        task(() -> api.submit(jpeg, answer), result -> {
            clearCapture();
            reportBack = "home";
            openReport(result);
        });
    }
    private void history(int index) {
        historyPage = index;
        page("history", "이력");
        tabs("history");
        task(() -> api.history(index), list -> {
            JSONArray rows = list.optJSONArray("items");
            if (rows == null || rows.length() == 0) {
                LinearLayout empty = card(page, true, 20);
                label(empty, "아직 분석 기록이 없어요.", 17, INK, 600, 2, 6);
                label(empty, "피부 분석을 시작하면 결과를 여기서 다시 볼 수 있어요.", 14, MUTED, 400, 0, 8);
                addAction(empty, "피부 분석 시작", true, this::startCapture);
            } else {
                String previous = "";
                for (int i = 0; i < rows.length(); i++) {
                    JSONObject item = rows.optJSONObject(i);
                    if (item == null) continue;
                    String date = item.optString("createdAt");
                    String month = date.length() >= 7 ? date.substring(0, 4) + "년 " + date.substring(5, 7) + "월" : "";
                    if (!month.equals(previous)) label(page, month, 16, INK, 600, 9, 10);
                    previous = month;
                    historyRow(page, item, "history");
                }
            }
            if (index>1) button("이전 페이지",false,()->history(index-1));
            JSONObject bounds=list.optJSONObject("page");
            if (bounds!=null && index<bounds.optInt("totalPages")) button("다음 페이지",false,()->history(index+1));
        }, ()->history(index));
    }

    private void historyRow(LinearLayout owner, JSONObject item, String back) {
        LinearLayout container = card(owner, true, 0);
        LinearLayout row = style.row();
        row.setPadding(dp(14), dp(14), dp(14), dp(14));
        row.addView(iconBadge("scan", SOFT, 44), dp(44), dp(44));
        LinearLayout words = style.column();
        words.setPadding(dp(12), 0, dp(12), 0);
        String date = item.optString("createdAt").split("T")[0];
        JSONObject disease = item.optJSONObject("disease");
        String title = disease == null ? "피부 분석" : disease.optString("label", "피부 분석");
        label(words, date, 12, MUTED, 400, 0, 4);
        label(words, title, 17, INK, 600, 0, 3);
        label(words, stateName(item.optString("status")), 13, MUTED, 500, 0, 0);
        row.addView(words, new LinearLayout.LayoutParams(0, -2, 1));
        row.addView(style.text("›", 24, MUTED, 400));
        row.setContentDescription(date + " " + title + " " + stateName(item.optString("status")));
        row.setFocusable(true);
        style.actionSurface(row, WHITE, 24, true);
        row.setOnClickListener(v -> {
            if (!busy) task(() -> api.detail(item.optString("analysisId")), detail -> {
                reportBack = back;
                openReport(detail);
            });
        });
        container.addView(row);
        if ("history".equals(back)) container.addView(link("기록 삭제", () ->
                new AlertDialog.Builder(this).setMessage("이 분석 기록을 삭제할까요? 삭제한 기록은 되돌릴 수 없어요.")
                        .setNegativeButton("취소", null)
                        .setPositiveButton("삭제", (dialog, which) -> task(() -> {
                            api.deleteAnalysis(item.getString("analysisId"));
                            return true;
                        }, ok -> history(1))).show()));
    }
    private static String stateName(String status) {
        switch(status) {
            case "QUEUED": return "접수"; case "GENERATING": return "추천 작성 중";
            case "COMPLETED": return "완료"; case "WITHHELD": return "추천 보류"; case "FAILED": return "처리 실패";
            default: return "상태 확인 필요";
        }
    }
    void openReport(JSONObject value) { pollStart=SystemClock.elapsedRealtime(); report(value); }
    static boolean showRecommendation(JSONObject r) {
        JSONObject meta=r.optJSONObject("generation");
        return "COMPLETED".equals(r.optString("status")) && "generated".equals(r.optString("recommendationStatus"))
                && r.optJSONObject("recommendation")!=null && (meta==null || !("not_generated".equals(meta.optString("origin"))
                || "withheld".equals(meta.optString("qualityStatus")) || "withheld".equals(meta.optString("evidenceStatus"))));
    }
    private void lines(LinearLayout owner, JSONArray values) {
        for (int i = 0; values != null && i < values.length(); i++)
            label(owner, values.optString(i), 15, MUTED, 400, 3, 4);
    }

    private void backFromReport() {
        if ("history".equals(reportBack)) history(historyPage);
        else home();
    }

    private void report(JSONObject value) {
        page("report", null);
        currentReport = value;
        toolbar("분석 결과", this::backFromReport, "돌아가기", null);
        JSONObject disease = value.optJSONObject("disease");
        if (disease != null) {
            LinearLayout result = card(page, false, 22);
            LinearLayout caption = style.row();
            TextView mode = style.text("이미지 분류 참고 결과", 14, MUTED, 500);
            caption.addView(mode, new LinearLayout.LayoutParams(0, -2, 1));
            String timestamp = value.optString("createdAt");
            if (!timestamp.isEmpty()) {
                try {
                    timestamp = OffsetDateTime.parse(timestamp).atZoneSameInstant(java.time.ZoneId.systemDefault())
                            .format(DateTimeFormatter.ofPattern("M월 d일 HH:mm", Locale.KOREAN));
                    caption.addView(style.text(timestamp, 12, MUTED, 400));
                } catch (java.time.format.DateTimeParseException ignored) {
                    // Some older records have no parseable server timestamp.
                }
            }
            result.addView(caption);
            JSONObject recordedSurvey = value.optJSONObject("survey");
            if (recordedSurvey != null && "side".equals(recordedSurvey.optString("captureView")))
                label(result, "측면 사진 · 시험 기능", 14, MUTED, 500, 0, 5);
            label(result, disease.optString("label"), 44, INK, 700, 0, 14);
            label(result, "모델 분류 점수", 13, MUTED, 500, 0, 3);
            double score = disease.optDouble("confidence", 0);
            label(result, percent(score), 24, INK, 700, 0, 8);
            if (disease.optBoolean("uncertain"))
                label(result, "판단 보류 · 분류 점수가 낮아 결과가 불확실해요.", 14, MUTED, 500, 10, 0);
            JSONObject scores = disease.optJSONObject("probabilities");
            if (scores != null && scores.length() > 0) {
                LinearLayout breakdown = disclosure(page, "6종 모델 분류 점수");
                label(breakdown, "질환 확률이 아니에요.", 13, MUTED, 400, 4, 7);
                List<String> labels = new ArrayList<>(java.util.Arrays.asList("건선", "아토피", "여드름", "정상", "주사", "지루"));
                scores.keys().forEachRemaining(key -> { if (!labels.contains(key)) labels.add(key); });
                for (String key : labels) {
                    if (!scores.has(key)) continue;
                    double amount = scores.optDouble(key, 0);
                    label(breakdown, key + "   " + percent(amount), 14, INK, 500, 8, 6);
                    meter(breakdown, amount);
                }
            }
            label(page, "이미지 분류 참고 결과이며 의학적 진단이 아닙니다.", 13, MUTED, 400, 5, 13);
            android.graphics.Bitmap map = heatmap(disease);
            if (map != null) {
                label(page, "분류기가 참고한 영역", 20, INK, 700, 4, 9);
                LinearLayout explanation = card(page, true, 16);
                ImageView image = new ImageView(this);
                image.setImageBitmap(map);
                image.setContentDescription("분류기가 참고한 영역");
                explanation.addView(image, -1, dp(144));
                label(explanation, "밝은 부분은 분류기가 더 많이 참고한 영역이에요. 병변의 경계를 표시한 그림은 아니에요.",
                        14, MUTED, 400, 9, 0);
            }
        }
        lines(page, value.optJSONArray("guidance"));
        String status = value.optString("status"), id = value.optString("analysisId");
        label(page, "맞춤 추천", 20, INK, 700, 13, 10);
        LinearLayout update = card(page, false, 18);
        label(update, stateName(status), 14, INK, 600, 0, 8);
        if (showRecommendation(value)) {
            JSONObject recommendation = value.optJSONObject("recommendation");
            String source = sourceNotice(value);
            if (!source.isEmpty()) label(update, source, 13, MUTED, 500, 0, 7);
            JSONArray ingredients = recommendation.optJSONArray("ingredients");
            if (ingredients != null && ingredients.length() > 0) {
                label(update, "추천 성분", 13, MUTED, 500, 0, 5);
                for (int i = 0; i < ingredients.length(); i++) {
                    JSONObject item = ingredients.optJSONObject(i);
                    if (item != null) numberedRow(update, i + 1, item.optString("name"), "", WHITE);
                }
            } else {
                label(update, "맞춤 성분을 찾지 못했어요. 추천 이유를 확인해 주세요.", 14, MUTED, 400, 1, 5);
            }
            addAction(update, "추천 자세히 보기", true, () -> recommendation(value, false));
        } else if ("WITHHELD".equals(status) || "COMPLETED".equals(status)) {
            String reason = value.optString("recommendationStatus");
            String message = switch (reason) {
                case "uncertain" -> "사진 분류가 불확실해 추천을 보류했어요.";
                case "no_concern" -> "정상으로 분류됐고 선택한 고민이 없어 추천을 생략했어요.";
                case "quality_rejected", "not_generated" -> "추천이 근거·품질 기준을 충족하지 않아 보류했어요.";
                default -> "이번 분석에서는 성분 추천을 제공하지 않아요.";
            };
            label(update, message, 16, MUTED, 400, 0, 4);
        } else if ("FAILED".equals(status)) {
            JSONObject error = value.optJSONObject("error");
            label(update, error == null ? "분류 결과는 그대로 있어요. 다시 시도하면 추천만 새로 만들어요."
                    : error.optString("message"), 14, MUTED, 400, 0, 8);
            addAction(update, "추천 다시 요청", true, () -> task(() -> api.retry(id), this::openReport));
        } else if ("QUEUED".equals(status) || "GENERATING".equals(status)) {
            long elapsed = SystemClock.elapsedRealtime() - pollStart;
            String message = elapsed >= 150000 ? "시간이 오래 걸리고 있어요." :
                    "GENERATING".equals(status) ? "성분과 관리법을 정리하고 있어요." : "맞춤 추천을 기다리고 있어요.";
            label(update, message, 16, INK, 600, 0, 7);
            label(update, "화면을 나가도 추천은 계속 만들어져요. 이력에서 다시 볼 수 있어요.",
                    14, MUTED, 400, 0, 0);
            if (elapsed < 1800000) {
                pendingReport = id;
                if (foreground) main.postDelayed(() -> poll(id), elapsed < 180000 ? 3000 : 10000);
            } else addAction(update, "상태 다시 확인", false, () -> { pollStart = SystemClock.elapsedRealtime(); poll(id); });
        }
        button("지난 분석 보기", false, () -> history(1));
        button("새 사진 분석", false, this::startCapture);
    }

    private String percent(double score) {
        return Math.round(score * 100) + "%";
    }

    private void meter(LinearLayout owner, double score) {
        ProgressBar meter = new ProgressBar(this, null, android.R.attr.progressBarStyleHorizontal);
        meter.setMax(1000);
        meter.setProgress((int) Math.round(score * 1000));
        meter.setProgressTintList(android.content.res.ColorStateList.valueOf(INK));
        meter.setProgressBackgroundTintList(android.content.res.ColorStateList.valueOf(LINE));
        meter.setImportantForAccessibility(View.IMPORTANT_FOR_ACCESSIBILITY_NO);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(-1, dp(6));
        lp.bottomMargin = dp(3);
        owner.addView(meter, lp);
    }

    private LinearLayout disclosure(LinearLayout owner, String title) {
        LinearLayout container = card(owner, true, 14);
        LinearLayout detail = style.column();
        detail.setVisibility(View.GONE);
        Button toggle = style.button(title, 44);
        toggle.setGravity(Gravity.CENTER_VERTICAL | Gravity.START);
        toggle.setPadding(0, 0, 0, 0);
        style.actionSurface(toggle, WHITE, 12, false);
        toggle.setText(title + "  ＋");
        toggle.setOnClickListener(v -> {
            boolean show = detail.getVisibility() != View.VISIBLE;
            detail.setVisibility(show ? View.VISIBLE : View.GONE);
            toggle.setText(title + (show ? "  −" : "  ＋"));
        });
        container.addView(toggle);
        container.addView(detail);
        return detail;
    }

    private String sourceNotice(JSONObject report) {
        JSONObject metadata = report.optJSONObject("generation");
        if (metadata == null) return "";
        return switch (metadata.optString("origin")) {
            case "source_cards" -> "근거 자료를 바탕으로 구성한 대체 안내예요.";
            case "rule_fallback" -> "기본 관리 규칙으로 구성한 대체 안내예요.";
            default -> "";
        };
    }

    private void numberedRow(LinearLayout owner, int index, String name, String detail, int bubbleColor) {
        LinearLayout row = style.row();
        row.setPadding(0, dp(7), 0, dp(7));
        TextView number = style.text(String.valueOf(index), 13, INK, 600);
        number.setGravity(Gravity.CENTER);
        number.setBackground(style.surface(bubbleColor, 20, false));
        row.addView(number, dp(32), dp(32));
        LinearLayout words = style.column();
        words.setPadding(dp(11), 0, 0, 0);
        label(words, name, 16, INK, 600, 0, 0);
        if (!detail.isEmpty()) label(words, detail, 14, MUTED, 400, 4, 0);
        row.addView(words, new LinearLayout.LayoutParams(0, -2, 1));
        owner.addView(row, -1, -2);
    }

    private void recommendation(JSONObject value, boolean evening) {
        if (!showRecommendation(value)) return;
        page("recommendation", null);
        toolbar("맞춤 추천", () -> report(value), "분석 결과로", null);
        JSONObject rec = value.optJSONObject("recommendation");
        String source = sourceNotice(value);
        if (!source.isEmpty()) label(page, source, 14, MUTED, 500, 0, 9);
        String answer = rec.isNull("answer") ? "" : rec.optString("answer");
        if (!answer.isEmpty()) {
            LinearLayout summary = card(page, false, 20);
            label(summary, "관리 안내", 14, MUTED, 500, 0, 8);
            label(summary, answer, 17, INK, 400, 0, 0);
        }
        label(page, "추천 성분", 20, INK, 700, 12, 3);
        JSONArray ingredients = rec.optJSONArray("ingredients");
        if (ingredients != null && ingredients.length() > 0) {
            label(page, "우선순위 순", 13, MUTED, 400, 0, 9);
            List<JSONObject> sorted = objects(ingredients);
            sorted.sort(java.util.Comparator.comparingInt(i -> i.optInt("priority", Integer.MAX_VALUE)));
            for (int i = 0; i < sorted.size(); i++) {
                JSONObject item = sorted.get(i);
                numberedRow(card(page, true, 12), i + 1, item.optString("name"),
                        item.isNull("purpose") ? "" : item.optString("purpose"), SOFT);
            }
        } else label(page, "맞춤 성분을 찾지 못했어요. 추천 이유를 확인해 주세요.", 14, MUTED, 400, 0, 7);
        List<JSONObject> steps = objects(rec.optJSONArray("routine"));
        steps.sort(java.util.Comparator.comparingInt(step -> step.optInt("step", Integer.MAX_VALUE)));
        if (!steps.isEmpty()) {
            label(page, "관리 루틴", 20, INK, 700, 13, 3);
            java.util.Map<String,List<String>> other = new java.util.HashMap<>();
            boolean timed = false;
            for (JSONObject step : steps) {
                switch (step.optString("time")) {
                    case "morning": case "evening": case "daily": timed = true; break;
                    case "weekly": other.computeIfAbsent("주간 관리", k -> new ArrayList<>()).add(step.optString("action")); break;
                    case "anytime": other.computeIfAbsent("시간대 무관", k -> new ArrayList<>()).add(step.optString("action")); break;
                    default: other.computeIfAbsent("기타 관리", k -> new ArrayList<>()).add(step.optString("action"));
                }
            }
            if (timed) {
                LinearLayout timeline = style.column();
                segment(page, "아침", "저녁", evening, selected -> routine(timeline, steps, selected));
                page.addView(timeline);
                routine(timeline, steps, evening);
            }
            for (String title : new String[]{"주간 관리", "시간대 무관", "기타 관리"}) {
                if (!other.containsKey(title)) continue;
                LinearLayout card = card(page, false, 16);
                label(card, title, 14, MUTED, 500, 0, 4);
                for (String action : other.get(title)) label(card, action, 15, INK, 400, 5, 3);
            }
        }
        careCards(value, ingredients);
        JSONArray reasoning = rec.optJSONArray("reasoning");
        if (reasoning != null && reasoning.length() > 0) lines(disclosure(page, "추천 이유"), reasoning);
        JSONArray notes = rec.optJSONArray("inputNotes");
        if (notes != null && notes.length() > 0) lines(disclosure(page, "이렇게 가정했어요"), notes);
        if (!rec.isNull("disclaimer")) label(page, rec.optString("disclaimer"), 13, MUTED, 400, 10, 0);
    }

    private void sourceLink(LinearLayout owner, String caption, String url) {
        owner.addView(link(caption, () -> {
            try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url))); }
            catch (android.content.ActivityNotFoundException unavailable) { notice(url); }
        }));
    }

    private void careCards(JSONObject value, JSONArray ingredients) {
        JSONObject disease = value.optJSONObject("disease");
        if (disease == null || disease.optBoolean("uncertain", true)) return;
        CareGuide guides = new CareGuide(this);
        String name = disease.optString("label");
        for (String section : new String[]{"care", "diet"}) {
            JSONObject item = guides.data.optJSONObject(section).optJSONObject(name);
            boolean general = section.equals("diet") && item == null;
            if (general) item = guides.data.optJSONObject(section).optJSONObject("general");
            if (item == null) continue;
            LinearLayout box = card(page, true, 15);
            label(box, section.equals("care") ? "일상 관리" : "식습관 메모", 18, INK, 600, 0, 6);
            label(box, item.optString("body"), 15, INK, 400, 0, 5);
            sourceLink(box, general ? "세계보건기구 자료" : "미국피부과학회 자료", item.optString("source"));
        }
        JSONObject survey = value.optJSONObject("survey");
        var products = guides.products(ingredients, survey == null ? null : survey.optJSONArray("avoidIngredients"));
        LinearLayout box = card(page, true, 15);
        label(box, "추천 성분이 든 제품 예시", 18, INK, 600, 0, 6);
        if (products.isEmpty()) label(box, "추천 성분과 회피 조건을 함께 확인한 제품이 없어요.", 14, MUTED, 400, 0, 0);
        for (JSONObject product : products) {
            label(box, product.optString("name"), 16, INK, 600, 6, 2);
            label(box, "일치한 추천 성분 · " + String.join(", ", guides.matchedNames(product, ingredients)), 14, INK, 500, 1, 2);
            label(box, product.optString("category") + " · 구매 전 국내 포장의 전성분을 확인해 주세요.", 14, MUTED, 400, 0, 3);
            sourceLink(box, "제조사 성분표", product.optString("source"));
        }
    }

    private List<JSONObject> objects(JSONArray data) {
        List<JSONObject> result = new ArrayList<>();
        for (int i = 0; data != null && i < data.length(); i++) {
            JSONObject item = data.optJSONObject(i);
            if (item != null) result.add(item);
        }
        return result;
    }

    private void routine(LinearLayout timeline, List<JSONObject> steps, boolean evening) {
        timeline.removeAllViews();
        int index = 0;
        for (JSONObject step : steps) {
            String time = step.optString("time");
            if (!"daily".equals(time) && !(evening ? "evening" : "morning").equals(time)) continue;
            numberedRow(timeline, ++index, step.optString("action"), "", SOFT);
        }
        if (index == 0) label(timeline, "이 시간대에는 따로 할 일이 없어요.", 14, MUTED, 400, 6, 8);
    }

    private void poll(String id) {
        if (!foreground || busy || !"report".equals(screen)) return;
        pendingReport = null;
        task(() -> api.detail(id), value -> {
            int position = scroll.getScrollY();
            report(value);
            ScrollView update = scroll;
            update.post(() -> update.scrollTo(0, position));
        }, () -> poll(id));
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
    @Override public void onBackPressed() {
        if (busy) return;
        switch (screen) {
            case "signup": auth(false); break;
            case "guide": closeCapture(); break;
            case "capture":
                if (getPreferences(MODE_PRIVATE).getBoolean("hideGuide", false)) closeCapture();
                else guide();
                break;
            case "survey": capture(); break;
            case "optional": survey(); break;
            case "history": case "my": case "diary": home(); break;
            case "report": backFromReport(); break;
            case "recommendation": report(currentReport); break;
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
