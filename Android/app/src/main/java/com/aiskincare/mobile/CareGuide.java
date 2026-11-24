package com.aiskincare.mobile;

import android.content.Context;
import org.json.JSONArray;
import org.json.JSONObject;
import java.io.BufferedReader;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.stream.Collectors;

final class CareGuide {
    final JSONObject data;

    CareGuide(Context context) {
        try (var input = context.getAssets().open("care-guide.json");
             var reader = new BufferedReader(new InputStreamReader(input, StandardCharsets.UTF_8))) {
            data = new JSONObject(reader.lines().collect(Collectors.joining("\n")));
        } catch (Exception e) {
            throw new IllegalStateException("관리 안내 자료를 읽을 수 없어요.", e);
        }
    }

    private String key(String name) {
        String normalized = name.toLowerCase(Locale.ROOT).replaceAll("\\s+", "");
        JSONObject aliases = data.optJSONObject("aliases");
        for (var it = aliases.keys(); it.hasNext();) {
            String key = it.next();
            if (key.equals(normalized) || contains(aliases.optJSONArray(key), normalized)) return key;
        }
        return "";
    }

    private static boolean contains(JSONArray items, String value) {
        for (int i = 0; i < items.length(); i++) if (items.optString(i).equals(value)) return true;
        return false;
    }

    JSONObject generalSource(String ingredient) {
        return data.optJSONObject("generalSources").optJSONObject(key(ingredient));
    }

    List<JSONObject> products(JSONArray ingredients, JSONArray avoid) {
        List<JSONObject> result = new ArrayList<>();
        if (ingredients == null || avoid == null) return result;
        JSONArray catalog = data.optJSONArray("products");
        for (int i = 0; i < catalog.length(); i++) {
            JSONObject product = catalog.optJSONObject(i);
            boolean checked = true;
            for (int j = 0; j < avoid.length(); j++) {
                if (!contains(product.optJSONArray("absent"), key(avoid.optString(j)))) { checked = false; break; }
            }
            if (!checked) continue;
            if (!matchedNames(product, ingredients).isEmpty()) result.add(product);
        }
        return result;
    }

    List<String> matchedNames(JSONObject product, JSONArray ingredients) {
        List<String> names = new ArrayList<>();
        for (int i = 0; i < ingredients.length(); i++) {
            JSONObject ingredient = ingredients.optJSONObject(i);
            if (ingredient == null) continue;
            String match = key(ingredient.optString("name"));
            if (contains(product.optJSONArray("matches"), match) && !names.contains(match)) names.add(match);
        }
        return names;
    }
}
