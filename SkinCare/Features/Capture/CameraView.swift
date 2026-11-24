@preconcurrency import AVFoundation
import SwiftUI

/// 앱 내장 전면 카메라 + 얼굴 타원 가이드 (패치 §2 SCR-05).
/// 얼굴이 가이드 안에 일정 시간 들어와 있을 때만 셔터가 켜진다 (FaceAlignment).
/// 촬영 결과는 메모리(Data)로만 넘기고 사진 앱이나 파일에 저장하지 않는다 (NFR-PRI-01).
struct CameraView: View {
    var useRearCamera = false
    var sideView = false
    let onCapture: (Data) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var camera = CameraController()
    @State private var tracker = FaceTracker()
    @State private var state: CameraState = .preparing
    @State private var isCapturing = false
    @State private var flash = false
    /// 미리보기(전체 화면) 크기. 찍은 사진을 가이드 영역으로 자를 때 쓴다.
    @State private var viewSize: CGSize = .zero

    enum CameraState: Equatable {
        case preparing, ready, denied, unavailable
        case failed(String)
    }

    private var canCapture: Bool { state == .ready && tracker.isStable && !isCapturing }

    var body: some View {
        ZStack {
            GeometryReader { proxy in
                let guide = FaceGuideLayout.guideRect(in: proxy.size)
                ZStack {
                    Color.black
                    if state == .ready {
                        CameraPreview(session: camera.session, guide: guide) { camera.setGuide(metadataRect: $0) }
                    }
                    FaceGuideOverlay(guide: guide, isAligned: tracker.isStable)
                }
                .onAppear { viewSize = proxy.size }
                .onChange(of: proxy.size) { _, size in viewSize = size }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                FaceGuideMessage(result: state == .ready ? tracker.result : .noFace)
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
        .statusBarHidden()
        .task { await start() }
        .task { await tracker.runStalenessCheck() }
        .onChange(of: tracker.isStable) { _, stable in
            if stable { UISelectionFeedbackGenerator().selectionChanged() }
        }
        .onDisappear {
            camera.stop()
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    // MARK: - 레이아웃

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
            HStack(spacing: Spacing.xs) {
                ForEach([sideView ? "측면" : "정면", "자연광", "맨얼굴"], id: \.self) { hint in
                    Text(hint)
                        .appText(.label)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(.white.opacity(0.16), in: Capsule())
                }
            }
            .accessibilityElement(children: .combine)
        }
        .padding(.top, Spacing.xs)
    }

    private var bottomControls: some View {
        VStack(spacing: Spacing.md) {
            ShutterButton(isEnabled: canCapture, isBusy: isCapturing) {
                Task { await capture() }
            }
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
                let tracker = tracker
                camera.onAlignment = { result in
                    Task { @MainActor in tracker.update(result) }
                }
                try await camera.configure(position: useRearCamera ? .back : .front, side: sideView)
                camera.start()
                state = .ready
            } catch CameraController.CameraError.noCamera {
                state = .failed("선택한 카메라를 사용할 수 없어요. 다른 촬영 방법이나 앨범을 선택해 주세요.")
            } catch {
                state = .failed("카메라를 켜지 못했어요. 잠시 후 다시 시도해 주세요.")
            }
        }
    }

    private func capture() async {
        guard canCapture else { return }
        isCapturing = true
        defer { isCapturing = false }
        do {
            let raw = try await camera.capturePhoto()
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            withAnimation(.easeOut(duration: 0.1)) { flash = true }
            let size = viewSize
            let area = FaceGuideLayout.cropArea(for: FaceGuideLayout.guideRect(in: size))
            // 미리보기에서 보이던 그대로(좌우 반전 포함) 가이드 주변만 자른다. 실패하면 원본을 넘긴다.
            let data = await Task.detached(priority: .userInitiated) {
                guard let image = OrientedImage.upright(from: raw),
                      let rect = FaceGuideLayout.pixelRect(of: area, viewSize: size, imageSize: image.pixelSize)
                else { return raw }
                return image.jpegData(cropping: rect) ?? raw
            }.value
            try? await Task.sleep(for: .milliseconds(120))
            onCapture(data)
            dismiss()
        } catch {
            state = .failed("사진을 찍지 못했어요. 다시 시도해 주세요.")
        }
    }
}

// MARK: - 얼굴 판정 상태

/// 카메라 얼굴 판정 결과를 화면 상태로. 조건을 일정 시간 계속 만족해야 셔터를 켠다.
@MainActor
@Observable
final class FaceTracker {
    /// 셔터를 켜기 전에 조건을 유지해야 하는 시간
    static let stableDuration: TimeInterval = 0.5
    /// 얼굴 갱신이 이보다 오래 없으면 얼굴이 사라진 것으로 본다
    static let staleAfter: TimeInterval = 0.7

    private(set) var result: FaceAlignment.Result = .noFace
    private(set) var isStable = false
    private var alignedSince: Date?
    private var lastUpdate = Date.distantPast

    func update(_ newResult: FaceAlignment.Result) {
        lastUpdate = Date()
        result = newResult
        if newResult.isAligned {
            if alignedSince == nil { alignedSince = Date() }
        } else {
            alignedSince = nil
        }
        refresh()
    }

    /// 시간 조건(유지 시간, 얼굴 사라짐)을 주기적으로 다시 계산한다.
    func runStalenessCheck() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(150))
            if Date().timeIntervalSince(lastUpdate) > Self.staleAfter, result != .noFace {
                result = .noFace
                alignedSince = nil
            }
            refresh()
        }
    }

    private func refresh() {
        let stable = alignedSince.map { Date().timeIntervalSince($0) >= Self.stableDuration } ?? false
        if stable != isStable { isStable = stable }
    }
}

// MARK: - 미리보기

private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    /// 화면 좌표의 가이드. 미리보기 레이어 기준 메타데이터 좌표로 바꿔서 넘긴다.
    let guide: CGRect
    let onMetadataGuide: (CGRect) -> Void

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        view.guide = guide
        view.onMetadataGuide = onMetadataGuide
        view.publishGuide()
    }

    final class PreviewView: UIView {
        override static var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        // swiftlint:disable:next force_cast
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        var guide: CGRect = .zero
        var onMetadataGuide: ((CGRect) -> Void)?

        override func layoutSubviews() {
            super.layoutSubviews()
            publishGuide()
        }

        /// 가이드(레이어 좌표)를 카메라 메타데이터 좌표(0–1, 센서 방향)로 바꾼다. 화면 회전·좌우 반전·화면 채움 비율이 반영된다.
        func publishGuide() {
            guard bounds.width > 0, guide.width > 0, previewLayer.connection != nil else { return }
            onMetadataGuide?(previewLayer.metadataOutputRectConverted(fromLayerRect: guide))
        }
    }
}

// MARK: - 카메라 세션

/// AVCaptureSession 설정·촬영·얼굴 감지. 세션 작업은 전용 큐에서 한다 (startRunning은 블로킹).
final class CameraController: NSObject, @unchecked Sendable {
    enum CameraError: Error {
        case noCamera, configurationFailed, captureFailed
    }

    let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private let metadataOutput = AVCaptureMetadataOutput()
    private let queue = DispatchQueue(label: "com.aiskincare.skincare.camera")
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Data, Error>?
    private var guideInMetadata: CGRect?
    private var sideCapture = false
    private var alignmentHandler: (@Sendable (FaceAlignment.Result) -> Void)?

    /// 얼굴 판정 결과 (카메라 큐에서 호출된다)
    var onAlignment: (@Sendable (FaceAlignment.Result) -> Void)? {
        get { lock.withLock { alignmentHandler } }
        set { lock.withLock { alignmentHandler = newValue } }
    }

    static func requestAccess() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: true
        case .notDetermined: await AVCaptureDevice.requestAccess(for: .video)
        default: false
        }
    }

    func setGuide(metadataRect: CGRect) {
        lock.withLock { guideInMetadata = metadataRect }
    }

    func configure(position: AVCaptureDevice.Position, side: Bool) async throws {
        lock.withLock { sideCapture = side }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) else {
                    continuation.resume(throwing: CameraError.noCamera)
                    return
                }
                do {
                    let input = try AVCaptureDeviceInput(device: device)
                    session.beginConfiguration()
                    session.sessionPreset = .photo
                    guard session.canAddInput(input), session.canAddOutput(output), session.canAddOutput(metadataOutput) else {
                        session.commitConfiguration()
                        continuation.resume(throwing: CameraError.configurationFailed)
                        return
                    }
                    session.addInput(input)
                    session.addOutput(output)
                    session.addOutput(metadataOutput)
                    output.maxPhotoQualityPrioritization = .quality
                    // 전면 카메라 미리보기는 거울처럼 보인다. 찍은 사진도 보이던 그대로(좌우 반전) 나오게 맞춘다.
                    if let connection = output.connection(with: .video) {
                        if connection.isVideoMirroringSupported {
                            connection.automaticallyAdjustsVideoMirroring = false
                            connection.isVideoMirrored = position == .front
                        }
                        if connection.isVideoRotationAngleSupported(90) { connection.videoRotationAngle = 90 }
                    }
                    if metadataOutput.availableMetadataObjectTypes.contains(.face) {
                        metadataOutput.metadataObjectTypes = [.face]
                        metadataOutput.setMetadataObjectsDelegate(self, queue: queue)
                    }
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

extension CameraController: AVCaptureMetadataOutputObjectsDelegate {
    /// 얼굴 사각형(메타데이터 좌표)을 같은 좌표로 바꾼 가이드와 비교한다.
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        let (guide, handler, side) = lock.withLock { (guideInMetadata, alignmentHandler, sideCapture) }
        guard let guide, let handler else { return }
        let faces = metadataObjects.compactMap { $0 as? AVMetadataFaceObject }.map { face in
            FaceAlignment.Face(
                rect: face.bounds,
                yaw: face.hasYawAngle ? Double(face.yawAngle) : nil,
                roll: face.hasRollAngle ? Double(face.rollAngle) : nil
            )
        }
        handler(FaceAlignment.evaluate(faces: faces, guide: guide, side: side))
    }
}
