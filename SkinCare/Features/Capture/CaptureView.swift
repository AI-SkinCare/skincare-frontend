import AVFoundation
import PhotosUI
import SwiftUI

/// SCR-05 촬영·업로드 (FR-CAP-02, 03). 사전 검증·변환은 ImageProcessor.
struct CaptureView: View {
    @Environment(CaptureFlowModel.self) private var model
    @State private var pickerItem: PhotosPickerItem?

    @State private var showsCamera = Self.opensCameraOnStart

    /// 전면 카메라가 있을 때만 촬영 버튼을 보인다. Debug 빌드는 시뮬레이터에서도 카메라 화면을 확인할 수 있게 항상 보인다.
    private var cameraAvailable: Bool {
        #if DEBUG
        true
        #else
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) != nil
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
                             subtitle: model.image == nil ? "정면 얼굴이 잘 보이는 사진 한 장이면 돼요." : "이 사진으로 분석할게요.")

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

                sourceButtons
            }
            .padding(.horizontal, Spacing.screen)
            .padding(.vertical, Spacing.xs)
        }
        .safeAreaInset(edge: .bottom) {
            BottomActionBar {
                Button("다음") { model.path.append(.survey) }
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
            CameraView { data in
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
