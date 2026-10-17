import CoreGraphics
import Foundation
import ImageIO
@testable import SkinCare
import Testing
import UniformTypeIdentifiers

struct ImageProcessorTests {
    @Test("짧은 변 720px 미만이면 거부")
    func rejectsSmallImage() throws {
        let data = try makeJPEG(width: 700, height: 1000)
        #expect(throws: ImageValidationError.tooSmall) { try ImageProcessor.process(data) }
    }

    @Test("이미지가 아니면 거부")
    func rejectsNonImage() {
        #expect(throws: ImageValidationError.unreadable) { try ImageProcessor.process(Data("not an image".utf8)) }
    }

    @Test("긴 변을 1600px로 줄인다")
    func resizesLongSide() throws {
        let result = try ImageProcessor.process(try makeJPEG(width: 4000, height: 3000))
        #expect(result.width == 1600)
        #expect(result.height == 1200)
    }

    @Test("1600px보다 작으면 키우지 않는다")
    func doesNotUpscale() throws {
        let result = try ImageProcessor.process(try makeJPEG(width: 800, height: 1000))
        #expect(result.width == 800)
        #expect(result.height == 1000)
    }

    @Test("EXIF 방향을 반영해서 회전한다")
    func appliesOrientation() throws {
        // 저장은 가로 1200×800, orientation 6(90° 회전) → 화면상 세로 800×1200
        let result = try ImageProcessor.process(try makeJPEG(width: 1200, height: 800, orientation: 6))
        #expect(result.width == 800)
        #expect(result.height == 1200)
    }

    @Test("결과는 JPEG이고 GPS·EXIF 메타데이터가 없다 (NFR-PRI-01)")
    func stripsMetadata() throws {
        let result = try ImageProcessor.process(try makeJPEG(width: 1000, height: 1000, withGPS: true))
        let source = try #require(CGImageSourceCreateWithData(result.jpegData as CFData, nil))
        #expect(CGImageSourceGetType(source) as String? == UTType.jpeg.identifier)
        let properties = try #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any])
        #expect(properties[kCGImagePropertyGPSDictionary] == nil)
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any]
        #expect(exif?[kCGImagePropertyExifDateTimeOriginal] == nil)
    }

    // MARK: - 테스트 이미지

    private func makeJPEG(width: Int, height: Int, orientation: Int = 1, withGPS: Bool = false) throws -> Data {
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.setFillColor(CGColor(red: 0.8, green: 0.6, blue: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())

        var properties: [CFString: Any] = [kCGImagePropertyOrientation: orientation]
        if withGPS {
            properties[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSLatitude: 37.5665, kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 126.978, kCGImagePropertyGPSLongitudeRef: "E",
            ]
            properties[kCGImagePropertyExifDictionary] = [kCGImagePropertyExifDateTimeOriginal: "2026:10:10 12:00:00"]
        }

        let output = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(output, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
        return output as Data
    }
}
