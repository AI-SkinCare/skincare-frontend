import AVFoundation
import PhotosUI
import SwiftUI

/// SCR-05 촬영·업로드 (FR-CAP-02, 03). 사전 검증·변환은 ImageProcessor.
struct CaptureView: View {
    @Environment(CaptureFlowModel.self) private var model
    @Environment(\.api) private var api
    @State private var pickerItem: PhotosPickerItem?
    @State private var useRearCamera = false
    @State private var isLoadingAlbum = false
    /// 앨범에서 고른 사진 — 얼굴 위치 맞추기 화면을 거친다
    @State private var albumPick: AlbumPick?

    private struct AlbumPick: Identifiable {
        let id = UUID()
        let data: Data
        let angle: CaptureFlowModel.Angle
    }

    @State private var showsCamera = false
    #if DEBUG
    @State private var didOpenDebugSource = false
    #endif

    private var cameraAvailable: Bool {
        #if DEBUG
        true
        #else
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: useRearCamera ? .back : .front) != nil
        #endif
    }

    private var photoHint: String {
        switch model.captureAngle {
        case nil: "정면은 양쪽 볼, 측면은 한쪽 볼과 코 윤곽이 보이는 사진이에요."
        case .front: "눈높이에서 양쪽 볼이 보이게 정면을 찍어 주세요."
        case .side: "한쪽 볼과 코 윤곽이 보이게 30~60도 돌려 주세요. 측면 분류는 시험 기능이에요."
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Spacing.lg) {
                CaptureStepIndicator(current: 0)
                ScreenHeader(title: "얼굴 사진을 준비해 주세요.",
                             subtitle: model.image == nil ? "촬영 각도를 고른 뒤 사진 한 장을 준비해 주세요." : "이 사진으로 분석할게요.")
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    HStack {
                        Text("사진 각도").appText(.link)
                        Spacer()
                        Text("필수").appText(.caption).foregroundStyle(.textMuted)
                    }
                    PillSegmentedControl<CaptureFlowModel.Angle?>(
                        options: [(.front, "정면"), (.side, "측면")],
                        selection: Binding(get: { model.captureAngle }, set: { model.captureAngle = $0 })
                    )
                    .accessibilityIdentifier("capture-angle")
                    .disabled(model.isProcessingImage || isLoadingAlbum)
                }

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
                Text(photoHint)
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
                    .disabled(model.captureAngle == nil || model.image == nil || !model.aiAvailable)
            }
        }
        .background(Color.canvas)
        .navigationBarTitleDisplayMode(.inline)
        .captureCloseButton()
        .onChange(of: pickerItem) { _, item in
            guard let item, let angle = model.captureAngle else { return }
            isLoadingAlbum = true
            Task {
                defer { isLoadingAlbum = false; pickerItem = nil }
                let data = try? await item.loadTransferable(type: Data.self)
                guard model.captureAngle == angle else { return }
                if let data {
                    albumPick = AlbumPick(data: data, angle: angle)
                } else {
                    model.handleImageLoadFailure()
                }
            }
        }
        #if DEBUG
        .onAppear {
            guard !didOpenDebugSource else { return }
            didOpenDebugSource = true
            if DebugLaunch.startScreen == .albumAlign, let data = DebugLaunch.sampleAlbumImage() {
                model.captureAngle = .front
                albumPick = AlbumPick(data: data, angle: .front)
            } else if DebugLaunch.startScreen == .camera {
                model.captureAngle = .front
                showsCamera = true
            }
        }
        #endif
        .fullScreenCover(item: $albumPick) { pick in
            AlbumFaceAlignView(imageData: pick.data, sideView: pick.angle.isSide) { cropped in
                Task { await model.handlePickedImage(cropped, angle: pick.angle) }
            }
        }
        .fullScreenCover(isPresented: $showsCamera) {
            if let angle = model.captureAngle {
                CameraView(useRearCamera: useRearCamera, sideView: angle.isSide) { data in
                    Task { await model.handlePickedImage(data, angle: angle) }
                }
            }
        }
    }

    /// 틀(4:5, 화면 너비)을 먼저 정하고 사진은 overlay로 채운다.
    /// 사진을 ZStack 안에 scaledToFill로 두면 사진 크기가 레이아웃을 키워 화면 전체가 옆으로 밀린다.
    private var preview: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
        return shape
            .fill(Color.canvasSoft)
            .aspectRatio(4 / 5, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                if let image = model.previewImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .accessibilityLabel("선택한 얼굴 사진 미리보기")
                } else if model.isProcessingImage {
                    ProgressView().tint(.ink)
                } else {
                    FaceGuide()
                }
            }
            .clipShape(shape)
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
            .accessibilityIdentifier("capture-album")
        }
        .disabled(model.captureAngle == nil || model.isProcessingImage || isLoadingAlbum)
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
