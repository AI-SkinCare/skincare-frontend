import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// Compiled with the app's actual APIClient/transport/DTO sources; no copied API implementation.
private final class EphemeralTokens: RefreshTokenStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var token: String?
    func load() -> String? { lock.withLock { token } }
    func save(_ token: String) { lock.withLock { self.token = token } }
    func clear() { lock.withLock { token = nil } }
}

private struct FlowCase: Decodable {
    let name: String
    let imageBase64: String
    let survey: Survey
    let expectedRecommendationStatus: String
}

private struct FlowInput: Decodable {
    let baseURL: String
    let outputDirectory: String
    let cases: [FlowCase]
}

private enum FlowFailure: Error { case check(String) }

@main struct LiveFlow {
    static func require(_ condition: Bool, _ message: String) throws {
        if !condition { throw FlowFailure.check(message) }
    }

    static func main() async throws {
        let input = try JSONDecoder().decode(FlowInput.self, from: FileHandle.standardInput.readDataToEndOfFile())
        guard let base = URL(string: input.baseURL) else { throw FlowFailure.check("base URL") }
        let store = EphemeralTokens()
        let session = URLSession(configuration: .ephemeral)
        let api = APIClient(baseURL: base, session: session, store: store)
        let email = "flow-\(UUID().uuidString.lowercased())@example.invalid"
        let password = "Flow!\(UUID().uuidString)"
        _ = try await api.send(AuthAPI.signup(SignupRequest(email: email, password: password, nickname: "연동시험",
            agreements: .init(terms: true, privacy: true, imageProcessing: true, over14: true))))
        let login = try await api.send(AuthAPI.login(email: email, password: password))
        await api.tokens.apply(login)
        var results: [[String: Any]] = []
        var ids: [String] = []
        do {
            let status = try await api.send(SystemAPI.status())
            try require(status.aiAvailable, "AI not ready")
            for item in input.cases {
                guard let image = Data(base64Encoded: item.imageBase64) else { throw FlowFailure.check("image data") }
                let start = Date()
                var analysis = try await api.send(AnalysisAPI.submit(imageJPEG: image, survey: item.survey))
                let initial = analysis.disease
                ids.append(analysis.analysisId)
                var states = [analysis.status.rawValue]
                while analysis.status.isInProgress && Date().timeIntervalSince(start) < 180 {
                    try await Task.sleep(for: .seconds(1))
                    analysis = try await api.send(AnalysisAPI.detail(id: analysis.analysisId))
                    if states.last != analysis.status.rawValue { states.append(analysis.status.rawValue) }
                }
                // Save response before assertions to diagnose a real failure without re-running generation.
                var request = URLRequest(url: base.appending(path: "/analyses/\(analysis.analysisId)"))
                request.setValue("Bearer \(await api.tokens.currentAccessToken ?? "")", forHTTPHeaderField: "Authorization")
                let (raw, response) = try await session.data(for: request)
                try require((response as? HTTPURLResponse)?.statusCode == 200, "raw detail status")
                try raw.write(to: URL(fileURLWithPath: input.outputDirectory).appending(path: "\(item.name)-response.json"))
                try require(!analysis.status.isInProgress, "poll deadline")
                try require(analysis.disease == initial, "classification changed while polling")
                try require(analysis.disease.explanation?.heatmapData(for: analysis.disease) != nil,
                            "validated Grad-CAM missing from saved classification")
                try require(analysis.error == nil, "analysis failed")
                try require(analysis.recommendationStatus?.rawValue == item.expectedRecommendationStatus,
                            "unexpected terminal state for \(item.name): \(analysis.recommendationStatus?.rawValue ?? "nil")")
                try require(analysis.survey?.avoidIngredients ?? [] == item.survey.sanitized().avoidIngredients ?? [], "avoidance lost")
                if analysis.status == .withheld {
                    try require(!analysis.canDisplayRecommendation && analysis.recommendation == nil, "withheld displayed as success")
                    try require(!analysis.guidance.isEmpty, "withheld guidance missing")
                    do {
                        _ = try await api.send(AnalysisAPI.retryRecommendation(id: analysis.analysisId))
                        throw FlowFailure.check("withheld retry unexpectedly accepted")
                    } catch APIError.server(let code, let error, _, _) {
                        try require(code == 409 && error == "E4005", "wrong withheld retry response")
                    }
                } else {
                    try require(analysis.canDisplayRecommendation, "generated recommendation hidden")
                    try require(analysis.recommendation?.ingredients?.isEmpty == false, "empty ingredients")
                    try require(analysis.recommendation?.routine?.isEmpty == false, "empty routine")
                }
                if item.expectedRecommendationStatus == "quality_rejected" {
                    try require(analysis.generation?.origin == .notGenerated, "not_generated lost")
                    try require(analysis.generation?.qualityIssues?.contains("evidence_no_eligible_claims") == true, "quality reason lost")
                }
                results.append(["case": item.name, "states": states, "recommendationStatus": item.expectedRecommendationStatus,
                    "origin": analysis.generation?.origin?.rawValue ?? "unknown", "seconds": Date().timeIntervalSince(start),
                    "canDisplayRecommendation": analysis.canDisplayRecommendation, "classificationPreserved": true,
                    "avoidIngredientsPreserved": true, "gradCAMMatchesClassification": true])
                print("PASS \(item.name) \(analysis.status.rawValue) \(analysis.generation?.origin?.rawValue ?? "unknown")")
            }
            let page = try await api.send(AnalysisAPI.list(page: 1))
            try require(Set(page.items.map(\.analysisId)) == Set(ids), "history mismatch")
            try require(page.items.allSatisfy { $0.disease.explanation == nil }, "history contains unnecessary map data")
            let fresh = try await api.send(AuthAPI.refresh(refreshToken: store.load()))
            await api.tokens.apply(fresh)
            _ = try await api.send(UsersAPI.me())
            for id in ids {
                _ = try await api.send(AnalysisAPI.delete(id: id))
                do {
                    _ = try await api.send(AnalysisAPI.detail(id: id))
                    throw FlowFailure.check("deleted analysis visible")
                } catch APIError.server(let code, let error, _, _) {
                    try require(code == 404 && error == "E4003", "wrong deleted response")
                }
            }
            _ = try await api.send(UsersAPI.deleteMe())
            await api.tokens.clear()
            let summary: [String: Any] = ["passed": true, "cases": results, "history": true,
                "tokenRefresh": true, "analysisDeletion": true, "accountCleanup": true,
                "runtime": "Swift 6 Linux actual app APIClient → Spring HTTP → FastAPI HTTP actual models",
                "iOSUIExecuted": false, "clinicalValidation": false]
            try JSONSerialization.data(withJSONObject: summary, options: [.prettyPrinted, .sortedKeys])
                .write(to: URL(fileURLWithPath: input.outputDirectory).appending(path: "live-summary.json"))
        } catch {
            _ = try? await api.send(UsersAPI.deleteMe())
            await api.tokens.clear()
            throw error
        }
    }
}
