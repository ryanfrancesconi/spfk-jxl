// Copyright Ryan Francesconi. All Rights Reserved. Revision History at https://github.com/ryanfrancesconi/spfk-jxl

import Accelerate
import Foundation
import libjxl
import SPFKImage
import UniformTypeIdentifiers

/// Writes JPEG XL through libjxl, with the ICC profile, and EXIF and XMP in boxes.
///
/// Quality 1 is lossless. An image deeper than 8 bits is written at 16.
public struct JXLImageEncoder: ImageFileEncoder {
    public let type: UTType

    /// `nil` on a system that does not declare JPEG XL.
    public init?() {
        guard let type = UTType("public.jpeg-xl") else { return nil }
        self.type = type
    }

    public var usesQuality: Bool { true }

    public var maxPixelSize: Int? { nil }

    public func encode(_ input: ImageFileEncoderInput) throws -> Data {
        let bitsPerComponent = input.image.bitsPerComponent > 8 ? 16 : 8
        let pixels = try input.rgbaPixels(bitsPerComponent: bitsPerComponent)
        let lossless = input.quality >= 1

        guard let threads = JxlThreadParallelRunnerCreate(nil, JxlThreadParallelRunnerDefaultNumWorkerThreads()) else {
            throw failure
        }

        defer { JxlThreadParallelRunnerDestroy(threads) }

        guard let encoder = JxlEncoderCreate(nil) else { throw failure }

        defer { JxlEncoderDestroy(encoder) }

        // libjxl hands each stage of the encode to the runner, so refusing a stage is how Cancel stops it.
        try check(JxlEncoderSetParallelRunner(encoder, { runner, jpegxl, initialize, run, start, end in
            Task.isCancelled
                ? JXL_PARALLEL_RET_RUNNER_ERROR
                : JxlThreadParallelRunner(runner, jpegxl, initialize, run, start, end)
        }, threads))

        var info = JxlBasicInfo()
        JxlEncoderInitBasicInfo(&info)
        info.xsize = UInt32(pixels.width)
        info.ysize = UInt32(pixels.height)
        info.bits_per_sample = UInt32(bitsPerComponent)
        info.num_color_channels = 3
        info.orientation = JXL_ORIENT_IDENTITY
        info.uses_original_profile = lossless ? JXL_TRUE : JXL_FALSE

        if pixels.hasAlpha {
            info.alpha_bits = UInt32(bitsPerComponent)
            info.num_extra_channels = 1
        }

        try check(JxlEncoderUseBoxes(encoder))
        try check(JxlEncoderSetBasicInfo(encoder, &info))

        try pixels.iccProfile.withUnsafeBytes {
            try check(JxlEncoderSetICCProfile(encoder, $0.bindMemory(to: UInt8.self).baseAddress, $0.count))
        }

        if let exif = input.exif {
            // The box starts with the offset of the TIFF header within it.
            try addBox(to: encoder, type: "Exif", contents: Data(count: 4) + exif)
        }

        if let xmp = input.xmp {
            try addBox(to: encoder, type: "xml ", contents: xmp)
        }

        guard let settings = JxlEncoderFrameSettingsCreate(encoder, nil) else { throw failure }

        if lossless {
            try check(JxlEncoderSetFrameLossless(settings, JXL_TRUE))
        } else {
            try check(JxlEncoderSetFrameDistance(settings, JxlEncoderDistanceFromQuality(Float(input.quality * 100))))
        }

        var format = JxlPixelFormat(
            num_channels: pixels.hasAlpha ? 4 : 3,
            data_type: bitsPerComponent == 16 ? JXL_TYPE_UINT16 : JXL_TYPE_UINT8,
            endianness: JXL_LITTLE_ENDIAN,
            align: 0
        )

        let samples = pixels.hasAlpha ? pixels.data : try Self.droppingAlpha(pixels)

        try samples.withUnsafeBytes {
            try check(JxlEncoderAddImageFrame(settings, &format, $0.baseAddress, $0.count))
        }

        JxlEncoderCloseInput(encoder)

        return try output(of: encoder)
    }

    /// The RGB samples of an image with no alpha channel.
    static func droppingAlpha(_ pixels: RGBAPixelBuffer) throws -> Data {
        let bytesPerComponent = pixels.bitsPerComponent / 8
        var rgb = Data(count: pixels.width * pixels.height * 3 * bytesPerComponent)

        let error = pixels.data.withUnsafeBytes { rgbaBytes in
            rgb.withUnsafeMutableBytes { rgbBytes in
                var source = vImage_Buffer(
                    data: rgbaBytes.baseAddress.map { UnsafeMutableRawPointer(mutating: $0) },
                    height: vImagePixelCount(pixels.height),
                    width: vImagePixelCount(pixels.width),
                    rowBytes: pixels.width * 4 * bytesPerComponent
                )

                var destination = vImage_Buffer(
                    data: rgbBytes.baseAddress,
                    height: vImagePixelCount(pixels.height),
                    width: vImagePixelCount(pixels.width),
                    rowBytes: pixels.width * 3 * bytesPerComponent
                )

                return pixels.bitsPerComponent == 16
                    ? vImageConvert_RGBA16UtoRGB16U(&source, &destination, vImage_Flags(kvImageNoFlags))
                    : vImageConvert_RGBA8888toRGB888(&source, &destination, vImage_Flags(kvImageNoFlags))
            }
        }

        guard error == kvImageNoError else { throw ImageConversionError.renderFailed }

        return rgb
    }

    private func addBox(to encoder: OpaquePointer, type boxType: String, contents: Data) throws {
        try contents.withUnsafeBytes {
            try check(JxlEncoderAddBox(encoder, boxType, $0.bindMemory(to: UInt8.self).baseAddress, $0.count, JXL_FALSE))
        }
    }

    private func output(of encoder: OpaquePointer) throws -> Data {
        var data = Data(count: 1 << 16)
        var written = 0

        while true {
            let status = data.withUnsafeMutableBytes { bytes -> JxlEncoderStatus in
                guard let base = bytes.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return JXL_ENC_ERROR }

                var next: UnsafeMutablePointer<UInt8>? = base + written
                var available = bytes.count - written
                let status = JxlEncoderProcessOutput(encoder, &next, &available)
                written = bytes.count - available

                return status
            }

            guard status == JXL_ENC_NEED_MORE_OUTPUT else {
                try check(status)
                data.count = written
                return data
            }

            data.count *= 2
        }
    }

    /// A failure after the task was cancelled is the runner refusing a stage, and reports as the cancellation.
    private func check(_ status: JxlEncoderStatus) throws {
        guard status == JXL_ENC_SUCCESS else {
            try Task.checkCancellation()
            throw failure
        }
    }

    private var failure: ImageConversionError {
        .encodeFailed(type.identifier)
    }
}
