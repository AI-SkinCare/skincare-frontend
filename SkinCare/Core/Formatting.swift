import Foundation

/// 화면 표시용 포맷. 시간은 항상 KST (API 공통 규약: 저장 UTC, 표시 KST).
enum Formatting {
    static let kst = TimeZone(identifier: "Asia/Seoul") ?? .current

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = kst
        return calendar
    }

    /// 2026.10.15 18:12
    static func dateTime(_ date: Date) -> String {
        let hour = Date.FormatStyle.Symbol.VerbatimHour.twoDigits(clock: .twentyFourHour, hourCycle: .zeroBased)
        return date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(year: .defaultDigits).\(month: .twoDigits).\(day: .twoDigits) \(hour: hour):\(minute: .twoDigits)",
                timeZone: kst,
                calendar: calendar
            )
        )
    }

    /// 2026.10.15
    static func date(_ date: Date) -> String {
        date.formatted(
            Date.VerbatimFormatStyle(
                format: "\(year: .defaultDigits).\(month: .twoDigits).\(day: .twoDigits)",
                timeZone: kst,
                calendar: calendar
            )
        )
    }

    /// 10월 15일 목요일
    static func dayWithWeekday(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(locale: Locale(identifier: "ko_KR"), calendar: calendar, timeZone: kst)
                .month().day().weekday(.wide)
        )
    }

    /// 2026년 10월 (이력 그룹 제목)
    static func yearMonth(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle(locale: Locale(identifier: "ko_KR"), calendar: calendar, timeZone: kst).year().month(.wide)
        )
    }

    /// 10.15 (목)
    static func shortDay(_ date: Date) -> String {
        let day = date.formatted(
            Date.VerbatimFormatStyle(format: "\(month: .twoDigits).\(day: .twoDigits)", timeZone: kst, calendar: calendar)
        )
        let weekday = date.formatted(
            Date.FormatStyle(locale: Locale(identifier: "ko_KR"), calendar: calendar, timeZone: kst).weekday(.abbreviated)
        )
        return "\(day) (\(weekday))"
    }

    /// 예상 대기 시간 문구: "1분 이내", "약 2분"
    static func waitTime(seconds: Int) -> String {
        guard seconds > 60 else { return "1분 이내" }
        return "약 \(Int((Double(seconds) / 60).rounded(.up)))분"
    }

    /// 요약 문단에서 앞 2문장 (SCR-08 "요약 문단(answer 앞 2문장)")
    static func leadingSentences(_ text: String, count: Int = 2) -> String {
        var sentences: [String] = []
        text.enumerateSubstrings(in: text.startIndex..., options: [.bySentences, .localized]) { substring, _, _, stop in
            if let sentence = substring?.trimmingCharacters(in: .whitespacesAndNewlines), !sentence.isEmpty {
                sentences.append(sentence)
            }
            if sentences.count >= count { stop = true }
        }
        return sentences.isEmpty ? text : sentences.joined(separator: " ")
    }
}
