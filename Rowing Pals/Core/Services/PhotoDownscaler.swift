//
//  PhotoDownscaler.swift
//  Rowing Pals
//

import UIKit

/// Shrinks a photo to JPEG with its longest side capped, off the main actor. Decoding a camera
/// photo, redrawing it and encoding the JPEG ran on the main thread after every shutter press and
/// library pick; the result is the same, only where it runs moved.
nonisolated enum PhotoDownscaler {
    /// - Parameters:
    ///   - maxPixelSide: the longest side, in pixels, after shrinking.
    ///   - quality: JPEG compression quality.
    ///   - screenFormat: draw with `UIGraphicsImageRendererFormat.default()` (the library pickers)
    ///     rather than `UIGraphicsImageRendererFormat()` (the camera), as each did before.
    ///   - reencodesSmallPhotos: a photo already within the cap is encoded as it is, not redrawn.
    @concurrent
    static func jpeg(
        from data: Data,
        maxPixelSide: CGFloat,
        quality: CGFloat,
        screenFormat: Bool = false,
        reencodesSmallPhotos: Bool = false
    ) async -> Data? {
        guard let image = UIImage(data: data) else { return nil }
        let longest = max(image.size.width, image.size.height)
        guard longest > 0 else { return nil }
        if reencodesSmallPhotos, longest <= maxPixelSide {
            return image.jpegData(compressionQuality: quality)
        }
        let scale = min(1, maxPixelSide / longest)
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        // Without an explicit scale the renderer uses the screen's (3x), and `size` is in points:
        // that would silently render three times the pixels.
        let format = screenFormat ? UIGraphicsImageRendererFormat.default() : UIGraphicsImageRendererFormat()
        format.scale = 1
        let resized = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return resized.jpegData(compressionQuality: quality)
    }
}
