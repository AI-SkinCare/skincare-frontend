import CryptoKit
import SwiftUI

struct DailySkinJournal: View {
    struct Entry: Codable {
        let score: Int
        let product: String
    }

    let userID: Int
    @State private var entries: [String: Entry] = [:]
    @State private var score: Int?
    @State private var product = ""
    @State private var editingDay = ""
    @State private var error: String?
    @State private var deleting: String?

    private var today: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }

    private static func folder(_ userID: Int) throws -> URL {
        let account = "\(AppConfig.apiBaseURL.absoluteString)#\(userID)"
        let hash = SHA256.hash(data: Data(account.utf8)).map { String(format: "%02x", $0) }.joined()
        return try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask,
                                           appropriateFor: nil, create: true).appendingPathComponent("skin-diary-" + hash)
    }

    static func erase(userID: Int) throws {
        let directory = try folder(userID)
        if FileManager.default.fileExists(atPath: directory.path) { try FileManager.default.removeItem(at: directory) }
    }

    private func read() throws -> [String: Entry] {
        let file = try Self.folder(userID).appendingPathComponent("entries.json")
        guard FileManager.default.fileExists(atPath: file.path) else { return [:] }
        return try JSONDecoder().decode([String: Entry].self, from: Data(contentsOf: file))
    }

    private func reload() {
        do {
            entries = try read()
            editingDay = today
            score = entries[editingDay]?.score
            product = entries[editingDay]?.product ?? ""
            error = nil
        } catch { self.error = "기록을 읽지 못했어요. 잠시 후 다시 열어 주세요." }
    }

    private func update(_ day: String, entry: Entry?) {
        do {
            var latest = try read()
            latest[day] = entry
            var directory = try Self.folder(userID)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            var properties = URLResourceValues()
            properties.isExcludedFromBackup = true
            try directory.setResourceValues(properties)
            try JSONEncoder().encode(latest).write(to: directory.appendingPathComponent("entries.json"),
                                                   options: [.atomic, .completeFileProtection])
            reload()
        } catch { self.error = "기록을 저장하지 못했어요. 다시 시도해 주세요." }
    }

    var body: some View {
        let days = entries.keys.sorted(by: >)
        List {
            Section("오늘 피부는 얼마나 편안했나요?") {
                Text("0점은 매우 불편, 10점은 매우 편안이에요. 매일 비슷한 시간에 직접 기록해 보세요.")
                Picker("피부 편안함", selection: $score) {
                    Text("점수 선택").tag(nil as Int?)
                    ForEach(0...10, id: \.self) { Text("\($0)점").tag(Optional($0)) }
                }
                TextField("오늘 쓴 제품 (선택)", text: $product)
                    .onChange(of: product) { _, value in if value.count > 100 { product = String(value.prefix(100)) } }
                Button(entries[editingDay] == nil ? "오늘 기록 저장" : "오늘 기록 수정") {
                    guard editingDay == today else { reload(); error = "날짜가 바뀌었어요. 오늘 기록을 확인해 주세요."; return }
                    if let score { update(today, entry: Entry(score: score, product: product.trimmingCharacters(in: .whitespacesAndNewlines))) }
                }.disabled(score == nil)
            }
            if let error { Text(error) }
            Section("날짜별 변화") {
                Text("점수는 내가 느낀 편안함이에요. 이 기기의 내 계정에 저장됩니다.").font(.footnote)
                if days.isEmpty { Text("첫 기록부터 날짜별로 쌓여요.") }
                ForEach(Array(days.enumerated()), id: \.element) { index, day in
                    if let entry = entries[day] {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(day)   \(entry.score)/10").font(.headline)
                            ProgressView(value: Double(entry.score), total: 10).accessibilityHidden(true)
                            if index + 1 < days.count, let previous = entries[days[index + 1]] {
                                let diff = entry.score - previous.score
                                let change = diff == 0 ? "같음" : "\(abs(diff))점 " + (diff > 0 ? "상승" : "하락")
                                Text("\(days[index + 1]) 대비 \(change)")
                            } else { Text("첫 기록") }
                            if !entry.product.isEmpty { Text("사용 제품 · " + entry.product) }
                        }.swipeActions {
                            Button("삭제", role: .destructive) { deleting = day }
                        }
                    }
                }
            }
        }
        .navigationTitle("매일 피부 기록")
        .onAppear { reload() }
        .alert("이 날짜의 기록을 지울까요?", isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
               presenting: deleting) { day in
            Button("삭제", role: .destructive) { update(day, entry: nil) }
            Button("취소", role: .cancel) {}
        }
    }
}
