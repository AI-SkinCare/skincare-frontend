import ImageIO
import SwiftUI
import UniformTypeIdentifiers
import Vision

enum ConfirmedPhoto: Sendable {
    case encoded(Data)
    case sideCrop(OrientedImage, CGRect)
}

/// 앨범 사진의 얼굴을 타원 가이드 안에 맞추는 화면 (패치 §2 SCR-05).
/// 사진을 드래그·확대해서 맞추고, 얼굴이 가이드 안에 들어왔을 때만 사용할 수 있다. 확인하면 가이드 주변만 잘라서 넘긴다.
/// 사진은 메모리에서만 다룬다 (NFR-PRI-01).
struct AlbumFaceAlignView: View {
    let imageData: Data
    var sideView = false
    let onConfirm: (ConfirmedPhoto) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var loaded: AlbumImage?
    @State private var loadFailed = false
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var gestureScale: CGFloat = 1
    @State private var gestureOffset: CGSize = .zero
    /// 사용자가 직접 옮기거나 확대했는지. 그 전에는 화면 크기가 바뀔 때마다(전체 화면 전환 애니메이션 등) 다시 맞춘다.
    @State private var userAdjusted = false
    @State private var defaultSideCrop: CGRect?
    @State private var isExporting = false
    /// 전체 화면(안전 영역 무시) 크기 — 사진·가이드 좌표의 기준
    @State private var canvasSize: CGSize = .zero

    private var guide: CGRect { FaceGuideLayout.guideRect(in: canvasSize) }

    var body: some View {
        let evaluation = evaluate(size: canvasSize, guide: guide)
        ZStack {
            // 사진과 가이드는 전체 화면 좌표로 그린다 (카메라 화면과 같은 위치)
            GeometryReader { proxy in
                ZStack {
                    Color.black
                    if let loaded {
                        Image(decorative: loaded.image.cgImage, scale: 1)
                            .resizable()
                            .frame(width: loaded.pixelSize.width * currentScale, height: loaded.pixelSize.height * currentScale)
                            .position(x: proxy.size.width / 2 + currentOffset.width, y: proxy.size.height / 2 + currentOffset.height)
                            .gesture(dragAndZoom)
                            .accessibilityLabel(sideView ? "선택한 사진. 사각형 안의 사진으로 분석해요."
                                                : "선택한 사진. 드래그하고 두 손가락으로 확대해서 얼굴을 원 안에 맞춰 주세요")
                    } else if !loadFailed {
                        ProgressView().tint(.white)
                    }
                    let visibleGuide = FaceGuideLayout.guideRect(in: proxy.size)
                    FaceGuideOverlay(guide: sideView ? FaceGuideLayout.cropArea(for: visibleGuide, side: true) : visibleGuide,
                                     isAligned: evaluation.canUse, square: sideView)
                }
                .onAppear { canvasSize = proxy.size }
                .onChange(of: proxy.size) { _, size in
                    canvasSize = size
                    if !userAdjusted { autoFit(size: size, guide: FaceGuideLayout.guideRect(in: size)) }
                }
            }
            .ignoresSafeArea()

            // 버튼·문구는 안전 영역 안에
            VStack(spacing: 0) {
                topBar
                message(evaluation)
                    .padding(.top, Spacing.md)
                Spacer()
                bottomControls(evaluation: evaluation, size: canvasSize, guide: guide)
            }
            .padding(.horizontal, Spacing.screen)
        }
        .statusBarHidden()
        .task { await load() }
        .onChange(of: loaded?.id) { autoFit(size: canvasSize, guide: guide) }
    }

    // MARK: - 화면

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: ControlSize.minTouch, height: ControlSize.minTouch)
                    .background(.white.opacity(0.16), in: Circle())
            }
            .accessibilityLabel("취소")
            Spacer()
            Text("얼굴 위치 맞추기").appText(.link).foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: ControlSize.minTouch, height: ControlSize.minTouch)
        }
        .padding(.top, Spacing.xs)
    }

    @ViewBuilder
    private func message(_ evaluation: Evaluation) -> some View {
        if loadFailed {
            FaceGuideMessageText("사진을 읽지 못했어요. 다른 사진을 골라 주세요")
        } else if let loaded, loaded.faces.isEmpty {
            FaceGuideMessageText("사진에서 얼굴을 찾지 못했어요. 다른 사진을 골라 주세요")
        } else if evaluation.cropTooSmall {
            FaceGuideMessageText("너무 확대했어요. 조금 축소해 주세요")
        } else if loaded != nil {
            FaceGuideMessage(result: evaluation.result)
        }
    }

    private func bottomControls(evaluation: Evaluation, size: CGSize, guide: CGRect) -> some View {
        VStack(spacing: Spacing.sm) {
            Button {
                Task { await confirm(size: size, guide: guide) }
            } label: {
                HStack(spacing: Spacing.xs) {
                    if isExporting { ProgressView().tint(.ink) }
                    Text("이 사진 사용")
                }
                .appText(.link)
                .foregroundStyle(evaluation.canUse ? .ink : .white.opacity(0.5))
                .frame(maxWidth: .infinity, minHeight: ControlSize.buttonHeight)
                .background(evaluation.canUse ? Color.white : Color.white.opacity(0.16), in: Capsule())
            }
            .buttonStyle(PressableStyle())
            .disabled(!evaluation.canUse || isExporting)

            if let loaded, !loaded.faces.isEmpty {
                Button("얼굴에 자동으로 맞추기") {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        userAdjusted = false
                        autoFit(size: size, guide: guide)
                    }
                }
                .appText(.bodySmall)
                .foregroundStyle(.white.opacity(0.8))
                .frame(minHeight: ControlSize.minTouch)
            }
        }
        .padding(.bottom, Spacing.md)
    }

    // MARK: - 판정

    struct Evaluation {
        var result: FaceAlignment.Result
        var cropTooSmall: Bool
        var canUse: Bool { result.isAligned && !cropTooSmall }
    }

    private var currentScale: CGFloat { scale * gestureScale }
    private var currentOffset: CGSize {
        CGSize(width: offset.width + gestureOffset.width, height: offset.height + gestureOffset.height)
    }

    /// 화면에 놓인 사진의 사각형 (화면 좌표)
    private func imageFrame(size: CGSize, pixelSize: CGSize) -> CGRect {
        let width = pixelSize.width * currentScale
        let height = pixelSize.height * currentScale
        return CGRect(x: size.width / 2 + currentOffset.width - width / 2,
                      y: size.height / 2 + currentOffset.height - height / 2,
                      width: width, height: height)
    }

    private func evaluate(size: CGSize, guide: CGRect) -> Evaluation {
        guard let loaded, !loaded.faces.isEmpty else { return Evaluation(result: .noFace, cropTooSmall: false) }
        if defaultSideCrop != nil && !userAdjusted { return Evaluation(result: .aligned, cropTooSmall: false) }
        let frame = imageFrame(size: size, pixelSize: loaded.pixelSize)
        let faces = loaded.faces.map { face in
            FaceAlignment.Face(
                rect: CGRect(x: frame.minX + face.rect.minX * currentScale, y: frame.minY + face.rect.minY * currentScale,
                             width: face.rect.width * currentScale, height: face.rect.height * currentScale),
                yaw: face.yaw, roll: face.roll
            )
        }
        let crop = cropRect(size: size, guide: guide, loaded: loaded)
        let tooSmall = crop.map { min($0.width, $0.height) < CGFloat(ImageProcessor.minShortSide) } ?? true
        let framing = sideView ? FaceGuideLayout.cropArea(for: guide, side: true) : guide
        let result = FaceAlignment.evaluate(faces: faces, guide: framing, side: sideView)
        if sideView, result.isAligned, let crop, !crop.contains(loaded.faces[0].rect) {
            return Evaluation(result: .offCenter, cropTooSmall: tooSmall)
        }
        return Evaluation(result: result, cropTooSmall: tooSmall)
    }

    /// 잘라낼 영역 (사진 픽셀 좌표): 가이드 주변으로 여유를 둔다.
    private func cropRect(size: CGSize, guide: CGRect, loaded: AlbumImage) -> CGRect? {
        if let defaultSideCrop, !userAdjusted { return defaultSideCrop }
        let frame = imageFrame(size: size, pixelSize: loaded.pixelSize)
        let area = FaceGuideLayout.cropArea(for: guide, side: sideView)
        let inImage = CGRect(x: (area.minX - frame.minX) / currentScale, y: (area.minY - frame.minY) / currentScale,
                             width: area.width / currentScale, height: area.height / currentScale)
        let clipped = inImage.intersection(CGRect(origin: .zero, size: loaded.pixelSize)).integral
        return clipped.isNull || clipped.isEmpty ? nil : clipped
    }

    // MARK: - 제스처

    private var dragAndZoom: some Gesture {
        SimultaneousGesture(
            DragGesture()
                .onChanged {
                    userAdjusted = true
                    gestureOffset = $0.translation
                }
                .onEnded { value in
                    offset.width += value.translation.width
                    offset.height += value.translation.height
                    gestureOffset = .zero
                },
            MagnifyGesture()
                .onChanged {
                    userAdjusted = true
                    gestureScale = clampedGestureScale($0.magnification)
                }
                .onEnded { value in
                    scale *= clampedGestureScale(value.magnification)
                    gestureScale = 1
                }
        )
    }

    private func clampedGestureScale(_ magnification: CGFloat) -> CGFloat {
        guard let loaded else { return magnification }
        let next = scale * magnification
        let clamped = min(max(next, loaded.minScale), loaded.maxScale)
        return clamped / scale
    }

    // MARK: - 동작

    private func load() async {
        let data = imageData
        let result = await Task.detached(priority: .userInitiated) { AlbumImage.load(from: data) }.value
        if let result { loaded = result } else { loadFailed = true }
    }

    /// 얼굴(첫 번째)을 가이드 가운데에, 적당한 크기로 놓는다. 얼굴이 없으면 화면을 채운다.
    private func autoFit(size: CGSize, guide: CGRect) {
        guard var loaded, size.width > 0 else { return }
        defaultSideCrop = nil
        let fill = max(size.width / loaded.pixelSize.width, size.height / loaded.pixelSize.height)
        guard let face = loaded.faces.first?.rect else {
            scale = fill
            offset = .zero
            loaded.setScaleRange(base: fill)
            self.loaded = loaded
            return
        }
        let crop = FaceGuideLayout.centeredSideCrop(in: loaded.pixelSize)
        let faces = loaded.faces.map { FaceAlignment.Face(rect: $0.rect, yaw: $0.yaw, roll: $0.roll) }
        if sideView, crop.width >= CGFloat(ImageProcessor.minShortSide), crop.contains(face),
           FaceAlignment.evaluate(faces: faces, guide: crop, side: true).isAligned {
            defaultSideCrop = crop
        }
        let anchor = defaultSideCrop ?? face
        let target = 0.6 * (guide.width * guide.height).squareRoot()
        let fitted = defaultSideCrop.map { FaceGuideLayout.cropArea(for: guide, side: true).width / $0.width }
            ?? target / (face.width * face.height).squareRoot()
        scale = fitted
        offset = CGSize(
            width: guide.midX - size.width / 2 - (anchor.midX - loaded.pixelSize.width / 2) * fitted,
            height: guide.midY - size.height / 2 - (anchor.midY - loaded.pixelSize.height / 2) * fitted
        )
        loaded.setScaleRange(base: min(fitted, fill))
        self.loaded = loaded
    }

    private func confirm(size: CGSize, guide: CGRect) async {
        guard let loaded, evaluate(size: size, guide: guide).canUse, let crop = cropRect(size: size, guide: guide, loaded: loaded)
        else { return }
        isExporting = true
        defer { isExporting = false }
        let image = loaded.image
        if sideView {
            onConfirm(.sideCrop(image, crop))
            dismiss()
            return
        }
        let data = await Task.detached(priority: .userInitiated) { image.jpegData(cropping: crop) }.value
        guard let data else { return }
        onConfirm(.encoded(data))
        dismiss()
    }
}

/// 안내 문구 (판정 결과가 아닌 고정 문구용)
private struct FaceGuideMessageText: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .appText(.title)
            .foregroundStyle(.white)
            .multilineTextAlignment(.center)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(.black.opacity(0.35), in: RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
    }
}

// MARK: - 사진 읽기 · 얼굴 찾기

/// 방향을 바로잡은 사진과 그 안의 얼굴 (픽셀 좌표, 왼쪽 위 원점)
struct AlbumImage {
    struct DetectedFace {
        let rect: CGRect
        let yaw: Double?
        let roll: Double?
    }

    let id = UUID()
    let image: OrientedImage
    let pixelSize: CGSize
    let faces: [DetectedFace]
    private(set) var minScale: CGFloat = 0.01
    private(set) var maxScale: CGFloat = 100

    mutating func setScaleRange(base: CGFloat) {
        minScale = base * 0.3
        maxScale = base * 4
    }

    /// 긴 변 3000px로 줄이며 EXIF 방향을 반영해 읽고, Vision으로 얼굴을 찾는다.
    static func load(from data: Data) -> AlbumImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 3000,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let size = CGSize(width: cgImage.width, height: cgImage.height)

        let request = VNDetectFaceRectanglesRequest()
        try? VNImageRequestHandler(cgImage: cgImage, orientation: .up).perform([request])
        let faces = (request.results ?? [])
            .sorted { $0.boundingBox.width * $0.boundingBox.height > $1.boundingBox.width * $1.boundingBox.height }
            .map { observation in
                // Vision은 0–1, 왼쪽 아래 원점 → 픽셀, 왼쪽 위 원점
                let box = observation.boundingBox
                return DetectedFace(
                    rect: CGRect(x: box.minX * size.width, y: (1 - box.maxY) * size.height,
                                 width: box.width * size.width, height: box.height * size.height),
                    yaw: observation.yaw.map { $0.doubleValue * 180 / .pi },
                    roll: observation.roll.map { $0.doubleValue * 180 / .pi }
                )
            }
        return AlbumImage(image: OrientedImage(cgImage: cgImage), pixelSize: size, faces: faces)
    }
}

/// 스레드 사이로 넘기는 읽기 전용 이미지
final class OrientedImage: @unchecked Sendable {
    let cgImage: CGImage
    init(cgImage: CGImage) { self.cgImage = cgImage }

    /// 카메라 사진 데이터(EXIF 방향·좌우 반전 포함)를 똑바로 세워 읽는다.
    static func upright(from data: Data, maxPixelSize: Int = 4096) -> OrientedImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        return CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary).map(OrientedImage.init(cgImage:))
    }

    var pixelSize: CGSize { CGSize(width: cgImage.width, height: cgImage.height) }

    /// 영역을 잘라 JPEG로. 메타데이터는 넣지 않는다 (업로드 직전 ImageProcessor가 다시 검증·변환한다).
    func jpegData(cropping rect: CGRect) -> Data? {
        guard let cropped = cgImage.cropping(to: rect) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(destination, cropped, [kCGImageDestinationLossyCompressionQuality: 0.95] as CFDictionary)
        return CGImageDestinationFinalize(destination) ? output as Data : nil
    }
}
