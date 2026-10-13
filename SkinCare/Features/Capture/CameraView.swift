@preconcurrency import AVFoundation
import SwiftUI

/// 앱 내장 전면 카메라 + 얼굴 타원 가이드 (패치 §2 SCR-05).
/// 촬영 결과는 메모리(Data)로만 넘기고 사진 앱이나 파일에 저장하지 않는다 (NFR-PRI-01).
struct CameraView: View {
    let onCapture: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var camera = CameraController()
    @State private var state: CameraState = .preparing
    @State private var isCapturing = false
    @State private var flash = false

    enum CameraState: Equatable {
        case preparing, ready, denied, unavailable
        case failed(String)
    }

    var body: some View {
        GeometryReader { proxy in
            let guide = guideRect(in: proxy.size)
            ZStack {
                Color.black.ignoresSafeArea()

                if state == .ready {
                    CameraPreview(session: camera.session)
                        .ignoresSafeArea()
                }

                FaceGuideOverlay(guide: guide)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    topBar
                    guideMessage
                        .padding(.top, Spacing.md)
                    Spacer()
                    bottomControls
                }
                .padding(.horizontal, Spacing.screen)

                if case .denied = state { permissionNotice }
                if case .unavailable = state { unavailableNotice("이 기기에서는 카메라를 쓸 수 없어요.") }
                if case .failed(let message) = state { unavailableNotice(message) }

                Color.white.opacity(flash ? 0.8 : 0).ignoresSafeArea().allowsHitTesting(false)
            }
        }
        .statusBarHidden()
        .task { await start() }
        .onDisappear {
            camera.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - 레이아웃

    /// 얼굴 타원: 화면 너비 68%, 세로 4:3, 위 안내 문구와 아래 셔터 사이 가운데
    private func guideRect(in size: CGSize) -> CGRect {
        let width = size.width * 0.68
        let height = width * 4 / 3
        return CGRect(x: (size.width - width) / 2, y: size.height * 0.48 - height / 2, width: width, height: height)
    }

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: ControlSize.minTouch, height: ControlSize.minTouch)
                    .background(.white.opacity(0.16), in: Circle())
            }
            .accessibilityLabel("닫기")
            Spacer()
        }
        .padding(.top, Spacing.xs)
    }

    private var guideMessage: some View {
        VStack(spacing: Spacing.xs) {
            Text("얼굴을 원 안에 맞춰 주세요")
                .appText(.title)
                .foregroundStyle(.white)
            HStack(spacing: Spacing.xs) {
                ForEach(["정면", "자연광", "맨얼굴"], id: \.self) { hint in
                    Text(hint)
                        .appText(.label)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.16), in: Capsule())
                }
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var bottomControls: some View {
        VStack(spacing: Spacing.md) {
            Button {
                Task { await capture() }
            } label: {
                ZStack {
                    Circle().strokeBorder(.white, lineWidth: 4).frame(width: 80, height: 80)
                    Circle().fill(.white).frame(width: 64, height: 64)
                        .scaleEffect(isCapturing ? 0.85 : 1)
                    if isCapturing { ProgressView().tint(.ink) }
                }
            }
            .buttonStyle(.plain)
            .disabled(state != .ready || isCapturing)
            .opacity(state == .ready ? 1 : 0.4)
            .accessibilityLabel("촬영")

            Text(AppCopy.imageConsentShort)
                .appText(.caption)
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(.bottom, Spacing.lg)
    }

    private var permissionNotice: some View {
        VStack(spacing: Spacing.md) {
            Image(systemName: "camera")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(.ink)
                .frame(width: 64, height: 64)
                .background(Color.canvasSoft, in: Circle())
            Text("카메라 권한이 필요해요.").appText(.title).foregroundStyle(.ink)
            Text("설정에서 카메라 접근을 허용하면 바로 촬영할 수 있어요.\n앨범에서 사진을 골라도 돼요.")
                .appText(.bodySmall)
                .foregroundStyle(.textMuted)
                .multilineTextAlignment(.center)
            VStack(spacing: Spacing.sm) {
                Button("설정 열기") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
                }
                .buttonStyle(.primary)
                Button("앨범에서 고르기") { dismiss() }
                    .buttonStyle(.outline)
            }
        }
        .padding(Spacing.lg)
        .background(Color.canvas, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .padding(.horizontal, Spacing.screen)
    }

    private func unavailableNotice(_ message: String) -> some View {
        VStack(spacing: Spacing.md) {
            Text(message).appText(.body).foregroundStyle(.ink).multilineTextAlignment(.center)
            Button("앨범에서 고르기") { dismiss() }
                .buttonStyle(.outline)
        }
        .padding(Spacing.lg)
        .background(Color.canvas, in: RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        .padding(.horizontal, Spacing.screen)
    }

    // MARK: - 동작

    private func start() async {
        UIApplication.shared.isIdleTimerDisabled = true // 촬영 중 화면 꺼짐 방지
        switch await CameraController.requestAccess() {
        case false:
            state = AVCaptureDevice.authorizationStatus(for: .video) == .denied
                || AVCaptureDevice.authorizationStatus(for: .video) == .restricted ? .denied : .unavailable
        case true:
            do {
                try await camera.configure()
                camera.start()
                state = .ready
            } catch CameraController.CameraError.noFrontCamera {
                state = .unavailable
            } catch {
                state = .failed("카메라를 켜지 못했어요. 잠시 후 다시 시도해 주세요.")
            }
        }
    }

    private func capture() async {
        isCapturing = true
        defer { isCapturing = false }
        do {
            let data = try await camera.capturePhoto()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeOut(duration: 0.1)) { flash = true }
            try? await Task.sleep(for: .milliseconds(120))
            onCapture(data)
            dismiss()
        } catch {
            state = .failed("사진을 찍지 못했어요. 다시 시도해 주세요.")
        }
    }
}

// MARK: - 가이드 오버레이

/// 타원 바깥을 어둡게 하고 타원 테두리를 그린다.
private struct FaceGuideOverlay: View {
    let guide: CGRect

    var body: some View {
        ZStack {
            Path { path in
                path.addRect(CGRect(x: -1000, y: -1000, width: 4000, height: 4000))
                path.addEllipse(in: guide)
            }
            .fill(Color.black.opacity(0.55), style: FillStyle(eoFill: true))

            Ellipse()
                .stroke(.white, lineWidth: 2.5)
                .frame(width: guide.width, height: guide.height)
                .position(x: guide.midX, y: guide.midY)

            Ellipse()
                .stroke(.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                .frame(width: guide.width * 0.82, height: guide.height * 0.82)
                .position(x: guide.midX, y: guide.midY)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - 미리보기

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        // swiftlint:disable:next force_cast
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }
}

// MARK: - 카메라 세션

/// AVCaptureSession 설정·촬영. 세션 작업은 전용 큐에서 한다 (startRunning은 블로킹).
final class CameraController: NSObject, @unchecked Sendable {
    enum CameraError: Error {
        case noFrontCamera, configurationFailed, captureFailed
    }

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let queue = DispatchQueue(label: "com.aiskincare.skincare.camera")
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    func configure() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
                    continuation.resume(throwing: CameraError.noFrontCamera)
                    return
                }
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    session.beginConfiguration()
                    session.sessionPreset = .photo
                    guard session.canAddInput(input), session.canAddOutput(output) else {
                        session.commitConfiguration()
                        continuation.resume(throwing: CameraError.configurationFailed)
                        return
                    }
                    session.addInput(input)
                    session.addOutput(output)
                    output.maxPhotoQualityPrioritization = .quality
                    session.commitConfiguration()
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func start() {
        queue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    func capturePhoto() async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            lock.withLock { self.continuation = continuation }
            queue.async { [self] in
                let settings = AVCapturePhotoSettings()
                settings.photoQualityPrioritization = .quality
                output.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func finish(_ result: Result<Data, Error>) {
        let continuation = lock.withLock {
            defer { self.continuation = nil }
            return self.continuation
        }
        continuation?.resume(with: result)
    }
}

extension CameraController: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            finish(.failure(error))
        } else if let data = photo.fileDataRepresentation() {
            finish(.success(data))
        } else {
            finish(.failure(CameraError.captureFailed))
        }
    }
}
