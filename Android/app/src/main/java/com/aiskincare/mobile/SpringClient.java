package com.aiskincare.mobile;

import android.net.Uri;
import org.json.JSONObject;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.UUID;

/** Called from one worker thread. Credentials live only for the current app session. */
final class SpringClient {
    private final String base;
    private String access = "", refresh = "";
    SpringClient(String base) { this.base = base; }

    static class Failure extends IOException {
        final int status;
        Failure(int status, String message) { super(message); this.status = status; }
    }

    interface Body { void write(OutputStream out) throws Exception; }

    private JSONObject request(String method, String path, boolean authenticated,
                               String contentType, Body body) throws Exception {
        try {
            return exchange(method, path, authenticated, contentType, body);
        } catch (Failure error) {
            if (error.status != 401 || !authenticated || refresh.isEmpty()) throw error;
            try {
                remember(json("POST", "/auth/refresh", false, new JSONObject().put("refreshToken", refresh)));
            } catch (Failure rejected) {
                if (rejected.status == 401) forget();
                throw rejected;
            }
            return exchange(method, path, true, contentType, body);
        }
    }

    private JSONObject exchange(String method, String path, boolean authenticated,
                                String type, Body body) throws Exception {
        if (base.isEmpty()) throw new IOException("Spring 서버 주소가 설정되지 않았어요.");
        HttpURLConnection connection = (HttpURLConnection) new URL(base + path).openConnection();
        try {
            connection.setRequestMethod(method);
            connection.setConnectTimeout(15000);
            connection.setReadTimeout(45000);
            connection.setInstanceFollowRedirects(false);
            connection.setUseCaches(false);
            connection.setRequestProperty("Accept", "application/json");
            connection.setRequestProperty("X-Client", "android");
            if (authenticated) connection.setRequestProperty("Authorization", "Bearer " + access);
            if (body != null) {
                connection.setDoOutput(true);
                connection.setRequestProperty("Content-Type", type);
                try (OutputStream out = connection.getOutputStream()) { body.write(out); }
            }
            int status = connection.getResponseCode();
            if (status == 204) return new JSONObject();
            if (status < 200 || status >= 300) {
                String message = "서버 요청을 완료하지 못했어요. (" + status + ")";
                try (InputStream in = connection.getErrorStream()) {
                    JSONObject error = new JSONObject(read(in)).optJSONObject("error");
                    if (error != null) message = error.optString("message", message);
                } catch (Exception ignored) { /* An upstream proxy may send HTML. */ }
                throw new Failure(status, message);
            }
            try (InputStream in = connection.getInputStream()) {
                return new JSONObject(read(in)).getJSONObject("data");
            }
        } finally { connection.disconnect(); }
    }

    private static String read(InputStream in) throws IOException {
        ByteArrayOutputStream bytes = new ByteArrayOutputStream();
        byte[] buf = new byte[8192];
        int count;
        while ((count = in.read(buf)) != -1) bytes.write(buf, 0, count);
        return bytes.toString("UTF-8");
    }

    private JSONObject json(String method, String path, boolean authenticated, JSONObject body) throws Exception {
        return request(method, path, authenticated, "application/json",
                body == null ? null : out -> out.write(body.toString().getBytes(StandardCharsets.UTF_8)));
    }
    private void remember(JSONObject tokens) throws Exception {
        String nextAccess = tokens.getString("accessToken"), nextRefresh = tokens.getString("refreshToken");
        access = nextAccess;
        refresh = nextRefresh;
    }
    void forget() { access = ""; refresh = ""; }
    void deleteAccount() throws Exception { json("DELETE", "/users/me", true, null); forget(); }
    void login(String email, String password) throws Exception {
        remember(json("POST", "/auth/login", false, new JSONObject().put("email", email).put("password", password)));
    }
    void signup(String email, String password, String nickname, JSONObject agreements) throws Exception {
        json("POST", "/auth/signup", false, new JSONObject().put("email", email).put("password", password)
                .put("nickname", nickname).put("agreements", agreements));
    }
    void logout() throws Exception {
        // Refresh may rotate the token before a second attempt.
        try { request("POST", "/auth/logout", true, "application/json", out ->
                out.write(new JSONObject().put("refreshToken", refresh).toString().getBytes(StandardCharsets.UTF_8))); }
        finally { forget(); }
    }
    JSONObject submit(byte[] photo, JSONObject survey) throws Exception {
        String boundary = "skin-" + UUID.randomUUID();
        return request("POST", "/analyses", true, "multipart/form-data; boundary=" + boundary, out -> {
            write(out, "--" + boundary + "\r\nContent-Disposition: form-data; name=\"image\"; filename=\"face.jpg\"\r\nContent-Type: image/jpeg\r\n\r\n");
            out.write(photo);
            write(out, "\r\n--" + boundary + "\r\nContent-Disposition: form-data; name=\"survey\"\r\nContent-Type: text/plain; charset=utf-8\r\n\r\n");
            write(out, survey.toString() + "\r\n--" + boundary + "--\r\n");
        });
    }
    private static void write(OutputStream out, String text) throws IOException {
        out.write(text.getBytes(StandardCharsets.UTF_8));
    }
    JSONObject history(int page) throws Exception { return json("GET", "/analyses?page=" + page + "&size=20", true, null); }
    JSONObject detail(String id) throws Exception { return json("GET", "/analyses/" + Uri.encode(id), true, null); }
    JSONObject retry(String id) throws Exception {
        return json("POST", "/analyses/" + Uri.encode(id) + "/recommendation/retry", true, null);
    }
}
