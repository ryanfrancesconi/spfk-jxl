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

    /// Starts an encode, yielding once the input is built so the timing covers libjxl alone.
    private static func startEncode() -> (task: Task<Data, Error>, started: AsyncStream<Void>) {
        let (started, continuation) = AsyncStream<Void>.makeStream()

        let task = Task.detached {
            let input = try ImageFileEncoderInput(image: Self.noise(width: 2400, height: 1600), quality: 0.9, exif: nil, xmp: nil)
            guard let encoder = JXLImageEncoder() else { throw ImageConversionError.renderFailed }
            continuation.yield()
            continuation.finish()
            return try encoder.encode(input)
        }

        return (task, started)
    }

    /// The bound is relative to a full encode in the same run, so machine load scales both sides.
    @Test func cancellingStopsTheEncodePromptly() async throws {
        try #require(JXLImageEncoder() != nil)

        let full = Self.startEncode()
        for await _ in full.started {}
        let fullStart = ContinuousClock.now
        _ = try await full.task.value
        let fullDuration = ContinuousClock.now - fullStart

        let cancelledRun = Self.startEncode()
        for await _ in cancelledRun.started {}
        try await Task.sleep(for: fullDuration / 10)

        let cancelled = ContinuousClock.now
        cancelledRun.task.cancel()

        await #expect(throws: CancellationError.self) {
            _ = try await cancelledRun.task.value
        }

        let latency = ContinuousClock.now - cancelled
        #expect(latency < fullDuration / 2, "cancelled after \(latency), a full encode took \(fullDuration)")
    }
}
