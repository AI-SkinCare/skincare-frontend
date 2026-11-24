import AVFoundation
import PhotosUI
import SwiftUI

/// SCR-05 촬영·업로드 (FR-CAP-02, 03). 사전 검증·변환은 ImageProcessor.
struct CaptureView: View {
    @Environment(CaptureFlowModel.self) private var model
    @Environment(\.api) private var api
    @State private var pickerItem: PhotosPickerItem?
    @State private var useRearCamera = false

    @State private var showsCamera = Self.opensCameraOnStart

    private var cameraAvailable: Bool {
        #if DEBUG
        true
        #else
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: useRearCamera ? .back : .front) != nil
        #endif
    }

    private static var opensCameraOnStart: Bool {
        #if DEBUG
        DebugLaunch.startScreen == .camera
        #else
        false
        #endif
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                CaptureStepIndicator(current: 0)
                ScreenHeader(title: "얼굴 사진을 준비해 주세요.",
                             subtitle: model.image == nil ? "촬영 각도를 고른 뒤 사진 한 장을 준비해 주세요." : "이 사진으로 분석할게요.")
                Picker("촬영 각도", selection: Binding(get: { model.sideView }, set: { model.sideView = $0 })) {
                    Text("정면").tag(false)
                    Text("측면").tag(true)
                }
                .pickerStyle(.segmented)
                .disabled(model.isProcessingImage)

                if let reason = model.retakeReason {
                    NoticeBanner(message: reason, systemImage: "arrow.counterclockwise")
                }
                if !model.aiAvailable {
                    NoticeBanner(message: AppCopy.serverMaintenance, systemImage: "wrench.and.screwdriver")
                }

                preview

                if let error = model.imageError {
                    Label(error, systemImage: "exclamationmark.circle")
                        .appText(.bodySmall)
                        .foregroundStyle(.negative)
                }

                Picker("촬영 방법", selection: $useRearCamera) {
                    Text("셀프 촬영").tag(false)
                    Text("다른 사람이 촬영").tag(true)
                }
                .pickerStyle(.segmented)
                Text(model.sideView ? "한쪽 볼과 코 윤곽이 보이게 30~60도 돌려 주세요. 측면 분류는 시험 기능이며 실제 환자에서 정확도 검증이 필요해요." : "눈높이에서 양쪽 볼이 보이게 정면을 찍어 주세요.")
                    .appText(.bodySmall)
                    .foregroundStyle(.textMuted)
                sourceButtons
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.xs)
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                Button("다음") { Task { await model.enterSurvey(api: api) } }
                    .buttonStyle(.primary)
                    .disabled(model.image == nil || !model.aiAvailable)
            }
        }
        .background(Color.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .captureCloseButton()
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await model.handlePickedImage(data)
                } else {
                    model.handleImageLoadFailure()
                }
                pickerItem = nil
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            CameraView(useRearCamera: useRearCamera, sideView: model.sideView) { data in
                Task { await model.handlePickedImage(data) }
            }
        }
    }

    private var preview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                .fill(Color.canvasSoft)
            if let image = model.previewImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
                    .accessibilityLabel("선택한 얼굴 사진 미리보기")
            } else if model.isProcessingImage {
                ProgressView().tint(.ink)
            } else {
                FaceGuide()
            }
        }
        .aspectRatio(4 / 5, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var sourceButtons: some View {
        let albumTitle = model.image == nil ? "앨범에서 선택" : "다른 사진"
        return HStack(spacing: Spacing.sm) {
            if cameraAvailable {
                Button { showsCamera = true } label: {
                    Label(model.image == nil ? "촬영하기" : "다시 찍기", systemImage: "camera")
                }
                .buttonStyle(.outline)
            }
            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Label(albumTitle, systemImage: "photo.on.rectangle")
            }
            .buttonStyle(.outline)
        }
    }
}

/// 사진이 없을 때 얼굴 위치 가이드
private struct FaceGuide: View {
    var body: some View {
        VStack(spacing: Spacing.md) {
            Ellipse()
                .strokeBorder(Color.textFaint, style: StrokeStyle(lineWidth: 1.5, dash: [6, 6]))
                .frame(width: 168, height: 224)
                .overlay {
                    Image(systemName: "face.smiling")
                        .font(.system(size: 44, weight: .ultraLight))
                        .foregroundStyle(.textFaint)
                }
            Text("얼굴이 이 안에 오도록 찍어 주세요")
                .appText(.caption)
                .foregroundStyle(.textMuted)
        }
        .accessibilityElement(children: .combine)
    }
}
