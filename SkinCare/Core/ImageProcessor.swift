import Foundation
import ImageIO
import UniformTypeIdentifiers
import Vision

/// 업로드할 얼굴 사진. JPEG, 메타데이터 없음.
struct ProcessedImage: Sendable, Equatable {
    let jpegData: Data
    let width: Int
    let height: Int
}

enum ImageValidationError: Error, Equatable {
    case unreadable
    case tooSmall
    case tooLarge
    case uniform
    case faceFraming

    var message: String {
        switch self {
        case .unreadable: "사진을 읽지 못했어요. 다른 사진을 골라 주세요."
        case .tooSmall: "사진 해상도가 낮아요. 더 선명한 사진을 골라 주세요."
        case .tooLarge: "사진 용량이 너무 커요. 다른 사진을 골라 주세요."
        case .uniform: "사진 전체가 단색에 가까워요. 얼굴과 주변이 보이게 다시 찍어 주세요."
        case .faceFraming: "한 사람의 얼굴이 잘 보이는 정면 사진으로 다시 시도해 주세요."
        }
    }
}

/// 사진 사전 검증 + 변환 (패치 §1 FR-CAP-02, §2 SCR-05).
/// - HEIC 등 어떤 형식이든 받아서 JPEG로 바꾼다.
/// - 짧은 변 720px 이상(원본 기준), 전송 파일 10MB 이하(변환 후 기준).
/// - EXIF 방향을 반영해 긴 변 1600px로 줄이고, 메타데이터(GPS 등)는 넣지 않는다.
/// - 메모리에서만 다루고 파일로 쓰지 않는다 (NFR-PRI-01).
enum ImageProcessor {
    static let minShortSide = 720
    static let maxLongSide = 1600
    static let maxUploadBytes = 10 * 1024 * 1024
    static let jpegQuality = 0.9

    static func prepareForAnalysis(_ data: Data) throws(ImageValidationError) -> ProcessedImage {
        let photo = try process(data)
        let detection = VNDetectFaceRectanglesRequest()
        do {
            try VNImageRequestHandler(data: photo.jpegData, options: [:]).perform([detection])
        } catch { throw .faceFraming }
        guard let faces = detection.results, faces.count == 1,
              faces[0].boundingBox.width >= 0.18 else { throw .faceFraming }
        return photo
    }

    static func process(_ data: Data) throws(ImageValidationError) -> ProcessedImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int,
              let pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int else {
            throw .unreadable
        }

        guard min(pixelWidth, pixelHeight) >= minShortSide else { throw .tooSmall }

        let targetLongSide = min(max(pixelWidth, pixelHeight), maxLongSide)
        let thumbnailOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true, // EXIF 방향 반영
            kCGImageSourceThumbnailMaxPixelSize: targetLongSide,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbnailOptions as CFDictionary) else {
            throw .unreadable
        }

        if isUniform(image) { throw .uniform }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil) else {
            throw .unreadable
        }
        // 원본 properties를 넘기지 않으므로 EXIF·GPS·TIFF 메타데이터가 들어가지 않는다.
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: jpegQuality] as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw .unreadable }

        guard output.length <= maxUploadBytes else { throw .tooLarge }
        return ProcessedImage(jpegData: output as Data, width: image.width, height: image.height)
    }

    private static func isUniform(_ image: CGImage) -> Bool {
        let side = 24
        guard let context = CGContext(data: nil, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue),
              let data = context.data else { return false }
        context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
        let pixels = data.assumingMemoryBound(to: UInt8.self)
        return (0..<3).allSatisfy { channel in
            let values = stride(from: channel, to: side * side * 4, by: 4).map { Int(pixels[$0]) }
            return (values.max() ?? 255) - (values.min() ?? 0) <= 2
        }
    }
}
