import SwiftUI

/// 측정 흐름(SCR-04~07) 상태. 흐름이 닫히면 이미지와 함께 사라진다.
@MainActor
@Observable
final class CaptureFlowModel {
    enum Step: Hashable {
        case capture, survey
    }

    var path: [Step] = []
    /// 흐름 시작 시점의 "다시 보지 않기" 값으로 고정 (도중에 바꿔도 루트가 바뀌지 않게)
    let startsWithGuide: Bool

    private(set) var image: ProcessedImage?
    private(set) var previewImage: UIImage?
    private(set) var imageError: String?
    private(set) var isProcessingImage = false
    /// E2001·E2002로 돌아왔을 때 촬영 화면 상단 배너 (SCR-05)
    private(set) var retakeReason: String?

    var survey = Survey()
    private(set) var aiAvailable = true
    private(set) var isSubmitting = false
    var alert: AlertItem?

    private var didLoadDefaults = false

    init(startsWithGuide: Bool) {
        self.startsWithGuide = startsWithGuide
    }

    /// 서버 상태 확인 + 직전 분석의 설문으로 기본값 채우기 (FR-SUR-01)
    func loadInitial(api: APIClient) async {
        if let status = try? await api.send(SystemAPI.status()) {
            aiAvailable = status.aiAvailable
        }
        guard !didLoadDefaults else { return }
        didLoadDefaults = true
        guard let latest = try? await api.send(AnalysisAPI.list(page: 1, size: 1)).items.first,
              let previous = try? await api.send(AnalysisAPI.detail(id: latest.analysisId)).survey,
              survey == Survey() else { return }
        survey = previous.sanitized()
    }

    func handlePickedImage(_ data: Data) async {
        isProcessingImage = true
        imageError = nil
        defer { isProcessingImage = false }

        let result = await Task.detached(priority: .userInitiated) {
            Result { () throws(ImageValidationError) -> ProcessedImage in try ImageProcessor.process(data) }
        }.value

        switch result {
        case .success(let processed):
            image = processed
            previewImage = UIImage(data: processed.jpegData)
            retakeReason = nil
        case .failure(let error):
            image = nil
            previewImage = nil
            imageError = error.message
        }
    }

    func handleImageLoadFailure() {
        imageError = ImageValidationError.unreadable.message
    }

    var canSubmit: Bool {
        image != nil && survey.hasRequiredFields && aiAvailable && !isSubmitting
    }

    /// SCR-07: 제출 → 응답에 따라 이동 (화면 설계서 SCR-07 표)
    func submit(api: APIClient, router: AppRouter) async {
        guard let image, survey.hasRequiredFields else { return }
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            let submission = try await api.send(AnalysisAPI.submit(imageJPEG: image.jpegData, survey: survey))
            discardImage()
            router.showReport(analysisID: submission.analysisId)
        } catch let error as APIError {
            switch error.code {
            case "E2001":
                returnToCapture(reason: "얼굴을 찾지 못했어요. 정면에서 다시 찍어 주세요.")
            case "E2002":
                returnToCapture(reason: "사진이 흐리거나 너무 어두워요. 밝은 곳에서 다시 찍어 주세요.")
            case "E3001":
                aiAvailable = false
                alert = AlertItem(title: "분석 서버 점검 중", message: "지금은 분석 서버 점검 중이에요. 잠시 후 다시 시도해 주세요.")
            default:
                alert = AlertItem(message: error.userMessage)
            }
        } catch {
            alert = AlertItem(message: error.userMessage)
        }
    }

    /// 재촬영: 설문 입력값은 유지하고 촬영 화면으로 (SCR-07)
    private func returnToCapture(reason: String) {
        discardImage()
        retakeReason = reason
        path = startsWithGuide ? [.capture] : []
    }

    /// 업로드가 끝난 이미지는 메모리에서 바로 버린다 (NFR-PRI-01)
    private func discardImage() {
        image = nil
        previewImage = nil
    }
}
