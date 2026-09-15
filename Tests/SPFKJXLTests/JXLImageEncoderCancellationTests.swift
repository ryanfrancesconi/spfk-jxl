// Copyright Ryan Francesconi. All Rights Reserved.

import CoreGraphics
import Foundation
import SPFKImage
import SPFKJXL
import Testing

/// Cancelling a conversion has to reach inside libjxl: an encode is one synchronous call that otherwise runs to the end.
struct JXLImageEncoderCancellationTests {
    /// Noise, so the encode takes long enough to cancel, and deterministic, so its length does not vary between runs.
    private static func noise(width: Int, height: Int) throws -> CGImage {
        var state: UInt32 = 0x9E37_79B9
        var bytes = [UInt8](repeating: 255, count: width * height * 4)

        for index in bytes.indices where index % 4 != 3 {
            state = state &* 1_664_525 &+ 1_013_904_223
            bytes[index] = UInt8(truncatingIfNeeded: state >> 24)
        }

        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(bytes) as CFData),
              let image = CGImage(
                  width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4, space: space,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue), provider: provider,
                  decode: nil, shouldInterpolate: false, intent: .defaultIntent
              )
        else { throw ImageConversionError.renderFailed }

        return image
    }

    @Test func cancellingStopsTheEncodePromptly() async throws {
        try #require(JXLImageEncoder() != nil)

        let task = Task.detached {
            let input = try ImageFileEncoderInput(image: Self.noise(width: 2400, height: 1600), quality: 0.9, exif: nil, xmp: nil)
            guard let encoder = JXLImageEncoder() else { throw ImageConversionError.renderFailed }
            return try encoder.encode(input)
        }

        try await Task.sleep(for: .milliseconds(500))

        let cancelled = Date()
        task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await task.value
        }

        #expect(Date().timeIntervalSince(cancelled) < 2)
    }
}
