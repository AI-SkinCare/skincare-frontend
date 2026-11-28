package com.aiskincare.mobile;

import org.json.JSONObject;

import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;

/** Renders the classifier response without inferring symptoms from a score or heatmap. */
final class ClassificationDisplay {
    private static final List<String> LABELS = List.of("건선", "아토피", "여드름", "정상", "주사", "지루");

    record Candidate(String label, double score) {}

    private ClassificationDisplay() {}

    private static int tenths(double value) {
        if (!Double.isFinite(value) || value < 0 || value > 1) return -1;
        return (int) Math.round(value * 1000);
    }

    private static String pointsFromTenths(int value) {
        return (value / 10) + "." + (value % 10) + "점";
    }

    static String points(double value) {
        int score = tenths(value);
        return score < 0 ? null : pointsFromTenths(score);
    }

    static List<Candidate> candidates(JSONObject disease) {
        JSONObject probabilities = disease.optJSONObject("probabilities");
        if (probabilities == null) return List.of();
        List<Candidate> known = new ArrayList<>();
        for (String label : LABELS) {
            double score = probabilities.optDouble(label, Double.NaN);
            if (tenths(score) >= 0) known.add(new Candidate(label, score));
        }
        List<Candidate> extra = new ArrayList<>();
        probabilities.keys().forEachRemaining(label -> {
            double score = probabilities.optDouble(label, Double.NaN);
            if (!LABELS.contains(label) && tenths(score) >= 0) extra.add(new Candidate(label, score));
        });
        extra.sort(Comparator.comparingDouble(Candidate::score).reversed().thenComparing(Candidate::label));
        known.addAll(extra);
        return known;
    }

    static String reason(JSONObject disease, List<Candidate> candidates) {
        String label = disease.optString("label");
        Candidate selected = null, runnerUp = null;
        for (Candidate candidate : candidates) {
            if (label.equals(candidate.label())) selected = candidate;
            else if (runnerUp == null || candidate.score() > runnerUp.score()) runnerUp = candidate;
        }
        if (selected == null || runnerUp == null || selected.score() < runnerUp.score()
                || tenths(selected.score()) != tenths(disease.optDouble("confidence", Double.NaN))) {
            return "이 결과에서는 분류 후보별 점수를 비교할 수 없어요.";
        }
        int first = tenths(selected.score()), second = tenths(runnerUp.score());
        String comparison = "‘" + label + "’ " + pointsFromTenths(first)
                + ", 다음 후보 ‘" + runnerUp.label() + "’ " + pointsFromTenths(second);
        if (first == second) return comparison + "으로 표시 점수가 같아요.";
        return comparison + "으로 " + pointsFromTenths(first - second) + " 차이가 났어요.";
    }

    static String context(JSONObject disease, String captureView) {
        List<String> parts = new ArrayList<>(2);
        if ("front".equals(captureView)) parts.add("정면 사진");
        else if ("side".equals(captureView)) parts.add("측면 사진");
        String version = disease.optString("modelVersion");
        if (version.startsWith("densenet121")) parts.add("DenseNet121");
        else if (version.startsWith("dinov2")) parts.add("DINOv2");
        return String.join(" · ", parts);
    }
}
