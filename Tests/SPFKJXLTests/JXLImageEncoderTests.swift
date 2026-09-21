// Copyright Ryan Francesconi. All Rights Reserved.

import CoreGraphics
import Foundation
import ImageIO
import SPFKBase
import SPFKImage
import SPFKJXL
import SPFKTesting
import Testing
import UniformTypeIdentifiers

/// `songbird.jpg` converted to JPEG XL through `ImageFormatConverter` and read back through ImageIO. Sources are
/// generated inside each test, and a property a test relies on is asserted before use.
@Suite(.tags(.file))
final class JXLImageEncoderTests: BinTestCase {
    static let captureDate = "2024:05:17 14:32:10"
    static let latitude = 37.7749
    static let keywords: Set<String> = ["alpha", "beta"]

    private struct ReadBack {
        let type: String?
        let properties: [String: Any]
        let metadata: CGImageMetadata?

        var exif: [String: Any] { properties[kCGImagePropertyExifDictionary as String] as? [String: Any] ?? [:] }
        var gps: [String: Any] { properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] ?? [:] }
        var orientation: Int { properties[kCGImagePropertyOrientation as String] as? Int ?? 1 }
        var width: Int { properties[kCGImagePropertyPixelWidth as String] as? Int ?? 0 }
        var height: Int { properties[kCGImagePropertyPixelHeight as String] as? Int ?? 0 }
        var depth: Int? { properties[kCGImagePropertyDepth as String] as? Int }

        var keywords: Set<String> {
            guard let metadata,
                  let tag = CGImageMetadataCopyTagWithPath(metadata, nil, "dc:subject" as CFString),
                  let items = CGImageMetadataTagCopyValue(tag) as? [CGImageMetadataTag]
            else { return [] }

            return Set(items.compactMap { CGImageMetadataTagCopyValue($0) as? String })
        }

        var hasLocationInXMP: Bool {
            guard let metadata else { return false }
            var found = false

            CGImageMetadataEnumerateTagsUsingBlock(metadata, nil, nil) { _, tag in
                found = found || (CGImageMetadataTagCopyName(tag) as String?)?.hasPrefix("GPS") == true
                return true
            }

            return found
        }
    }

    // MARK: - Helpers

    private func readBack(_ url: URL) throws -> ReadBack {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))

        return try ReadBack(
            type: CGImageSourceGetType(source) as String?,
            properties: #require(CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]),
            metadata: CGImageSourceCopyMetadataAtIndex(source, 0, nil)
        )
    }

    /// The encoder, on a system that declares JPEG XL and whose ImageIO reads it back.
    private func encoder() throws -> JXLImageEncoder {
        let encoder = try #require(JXLImageEncoder())
        try #require(ImageConversionFormats(encoders: [encoder]).canWrite(encoder.type))
        return encoder
    }

    private func songbird() throws -> CGImage {
        let source = try #require(CGImageSourceCreateWithURL(TestBundleResources.shared.songbird as CFURL, nil))
        return try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    }

    private func write(_ image: CGImage, named name: String, type: UTType, metadata: CGImageMetadata? = nil, orientation: Int = 1) throws -> URL {
        let url = bin.appending(component: name, directoryHint: .notDirectory).appendingPathExtension(for: type)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))

        CGImageDestinationAddImageAndMetadata(destination, image, metadata, [kCGImagePropertyOrientation: orientation] as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))

        return url
    }

    /// `songbird.jpg` tagged with orientation 6, a capture date, a GPS latitude and `dc:subject`.
    private func taggedSource() throws -> URL {
        let metadata = CGImageMetadataCreateMutable()

        try #require(CGImageMetadataSetValueMatchingImageProperty(
            metadata, kCGImagePropertyExifDictionary, kCGImagePropertyExifDateTimeOriginal, Self.captureDate as CFString
        ))
        try #require(CGImageMetadataSetValueMatchingImageProperty(
            metadata, kCGImagePropertyGPSDictionary, kCGImagePropertyGPSLatitude, Self.latitude as CFNumber
        ))
        try #require(CGImageMetadataSetValueMatchingImageProperty(
            metadata, kCGImagePropertyGPSDictionary, kCGImagePropertyGPSLatitudeRef, "N" as CFString
        ))

        let subject = try #require(CGImageMetadataTagCreate(
            kCGImageMetadataNamespaceDublinCore, kCGImageMetadataPrefixDublinCore, "subject" as CFString,
            .arrayUnordered, Array(Self.keywords) as CFArray
        ))
        try #require(CGImageMetadataSetTagWithPath(metadata, nil, "dc:subject" as CFString, subject))

        let url = try write(songbird(), named: "tagged", type: .jpeg, metadata: metadata, orientation: 6)

        let source = try readBack(url)
        try #require(source.orientation == 6)
        try #require(source.keywords == Self.keywords)
        try #require(source.gps.isNotEmpty)

        return url
    }

    private func convert(
        _ input: URL,
        named name: String,
        quality: Double = 0.9,
        metadata: ImageMetadataCopyScheme = .copyAll
    ) throws -> URL {
        let encoder = try encoder()
        let output = bin.appending(component: name, directoryHint: .notDirectory).appendingPathExtension("jxl")
        let options = ImageConversionOptions(format: encoder.type.identifier, quality: quality, metadata: metadata)

        return try ImageFormatConverter(
            source: ImageConversionSource(input: input, output: output, options: options),
            formats: ImageConversionFormats(encoders: [encoder])
        ).convert().output
    }

    /// The EXIF block ImageIO writes into a JPEG holding only a capture date, as the TIFF structure after `Exif\0\0`.
    private func captureDateEXIFBlock() throws -> Data {
        let data = NSMutableData()
        let destination = try #require(CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil))
        let properties = [kCGImagePropertyExifDictionary: [kCGImagePropertyExifDateTimeOriginal: Self.captureDate]]

        CGImageDestinationAddImage(destination, try songbird(), properties as CFDictionary)
        try #require(CGImageDestinationFinalize(destination))

        let bytes = [UInt8](data as Data)
        let header: [UInt8] = [0x45, 0x78, 0x69, 0x66, 0, 0]
        var offset = 2

        while offset + 4 <= bytes.count, bytes[offset] == 0xFF, bytes[offset + 1] != 0xDA {
            let end = offset + 2 + (Int(bytes[offset + 2]) << 8 | Int(bytes[offset + 3]))
            let payload = offset + 4

            if bytes[offset + 1] == 0xE1, end - payload > header.count, Array(bytes[payload ..< payload + header.count]) == header {
                return Data(bytes[(payload + header.count) ..< end])
            }

            offset = end
        }

        Issue.record("No EXIF segment")
        return Data()
    }

    // MARK: - Pixels

    @Test func aRotatedSourceIsWrittenUprightAtItsDisplayedSize() throws {
        let input = try taggedSource()
        let source = try readBack(input)

        let output = try readBack(convert(input, named: "upright"))

        #expect(try output.type == encoder().type.identifier)
        #expect(output.width == source.height)
        #expect(output.height == source.width)
        #expect(output.orientation == 1)
    }

    @Test func lowerQualityWritesASmallerFile() throws {
        let input = try taggedSource()

        let low = try convert(input, named: "low", quality: 0.1)
        let high = try convert(input, named: "high", quality: 0.9)

        let lowSize = try #require(low.resourceValues(forKeys: [.fileSizeKey]).fileSize)
        let highSize = try #require(high.resourceValues(forKeys: [.fileSizeKey]).fileSize)

        #expect(lowSize < highSize)
    }

    @Test func aSixteenBitSourceKeepsSixteenBits() throws {
        let image = try songbird()
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: image.width, height: image.height, bitsPerComponent: 16, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))

        let input = try write(#require(context.makeImage()), named: "sixteen-bit", type: .png)
        try #require(readBack(input).depth == 16)

        let output = try readBack(convert(input, named: "sixteen-bit"))

        #expect(output.depth == 16)
        #expect(output.width == image.width)
    }

    @Test func transparencyIsKept() throws {
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        let context = try #require(CGContext(
            data: nil, width: 64, height: 48, bitsPerComponent: 8, bytesPerRow: 0, space: space,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.clear(CGRect(x: 0, y: 0, width: 64, height: 48))
        context.setFillColor(CGColor(red: 0.4, green: 0.3, blue: 0.2, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 32, height: 48))

        let input = try write(#require(context.makeImage()), named: "transparent", type: .png)
        let output = try convert(input, named: "transparent")

        let decoded = try #require(CGImageSourceCreateWithURL(output as CFURL, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) })
        let pixels = try ImageFileEncoderInput(image: decoded, quality: 1, exif: nil, xmp: nil).rgbaPixels(bitsPerComponent: 8)
        let alpha = { (x: Int) in Int(pixels.data[(24 * 64 + x) * 4 + 3]) }

        #expect(pixels.hasAlpha)
        #expect(alpha(4) >= 250)
        #expect(alpha(60) <= 5)
    }

    // MARK: - Metadata

    @Test func copyAllKeepsTheCaptureDateLocationAndKeywords() throws {
        let output = try readBack(convert(taggedSource(), named: "copy-all"))

        #expect(output.exif[kCGImagePropertyExifDateTimeOriginal as String] as? String == Self.captureDate)
        #expect(output.exif[kCGImagePropertyExifPixelXDimension as String] as? Int == output.width)
        #expect(abs((output.gps[kCGImagePropertyGPSLatitude as String] as? Double ?? 0) - Self.latitude) < 0.001)
        #expect(output.keywords == Self.keywords)
    }

    @Test func copyAllExceptLocationRemovesOnlyTheLocation() throws {
        let output = try readBack(convert(taggedSource(), named: "no-location", metadata: .copyAllExceptLocation))

        #expect(output.gps.isEmpty)
        #expect(!output.hasLocationInXMP)
        #expect(output.exif[kCGImagePropertyExifDateTimeOriginal as String] as? String == Self.captureDate)
        #expect(output.keywords == Self.keywords)
    }

    @Test func stripAllKeepsNoMetadata() throws {
        let output = try readBack(convert(taggedSource(), named: "strip-all", metadata: .stripAll))

        #expect(output.exif[kCGImagePropertyExifDateTimeOriginal as String] == nil)
        #expect(output.gps.isEmpty)
        #expect(output.keywords.isEmpty)
        #expect(output.orientation == 1)
    }

    /// Checked with no XMP packet, since ImageIO reads the capture date from either.
    @Test func anEXIFBlockAloneIsReadBack() throws {
        let data = try encoder().encode(ImageFileEncoderInput(image: songbird(), quality: 0.9, exif: captureDateEXIFBlock(), xmp: nil))
        let url = bin.appending(component: "exif-only", directoryHint: .notDirectory).appendingPathExtension("jxl")
        try data.write(to: url)

        #expect(try readBack(url).exif[kCGImagePropertyExifDateTimeOriginal as String] as? String == Self.captureDate)
    }

    @Test func qualityOneIsLossless() throws {
        let image = try songbird()
        let data = try encoder().encode(ImageFileEncoderInput(image: image, quality: 1, exif: nil, xmp: nil))

        let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
        let decoded = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let pixels: (CGImage) throws -> Data = { try ImageFileEncoderInput(image: $0, quality: 1, exif: nil, xmp: nil).rgbaPixels(bitsPerComponent: 8).data }

        #expect(try pixels(decoded) == pixels(image))
    }
}
